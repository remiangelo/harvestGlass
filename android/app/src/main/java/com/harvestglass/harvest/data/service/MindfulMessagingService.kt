package com.harvestglass.harvest.data.service

import android.content.Context
import com.harvestglass.harvest.util.KeywordMatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject
import javax.inject.Singleton

/** Mirrors MindfulAnalysis.Severity. */
enum class MindfulSeverity(val raw: String) {
    LOW("low"), MEDIUM("medium"), HIGH("high");

    companion object {
        fun fromRaw(raw: String?): MindfulSeverity =
            entries.firstOrNull { it.raw == raw } ?: LOW
    }
}

data class GrowthLesson(val title: String, val reflection: String)

/** Mirrors MindfulAnalysis in Harvest/Services/MindfulMessagingService.swift. */
data class MindfulAnalysis(
    val category: String?,
    val needsReview: Boolean,
    val severity: MindfulSeverity,
    val reason: String,
    val growthLesson: GrowthLesson?,
    val flaggedWords: List<String>
) {
    companion object {
        val CLEAR = MindfulAnalysis(
            category = null,
            needsReview = false,
            severity = MindfulSeverity.LOW,
            reason = "",
            growthLesson = null,
            flaggedWords = emptyList()
        )
    }
}

/**
 * Port of Harvest/Services/MindfulMessagingService.swift.
 *
 * Two paths: a synchronous lexicon scan that never leaves the device, and an
 * OpenAI pass for what the lexicons miss. The lexicons run first, so a clearly
 * concerning message never waits on the network.
 */
@Singleton
class MindfulMessagingService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val openAI: OpenAIService
) {

    /**
     * One category's vocabulary, split by how much context a term needs.
     *
     * [standalone] terms are concerning wherever they appear. [directed] terms
     * are only concerning when aimed at the other person, so they require a
     * second-person word in the same clause — that is what keeps "I need to
     * kill some time" apart from "I'll kill you", and what stops a gardening
     * app flagging "my new hoe".
     */
    private data class Lexicon(
        val category: String,
        val weight: Int,
        val standalone: Set<String>,
        val directed: Set<String> = emptySet()
    )

    val isEnabled: Boolean
        get() = prefs().getBoolean(KEY_ENABLED, true)

    fun setEnabled(enabled: Boolean) {
        prefs().edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /**
     * Synchronous, on-device keyword flag for an *incoming* message. Returns
     * the analysis when the message should be blurred for the recipient, else
     * null. Callers gate on [isEnabled] — the recipient's own toggle.
     */
    fun localFlag(text: String): MindfulAnalysis? =
        keywordAnalysis(text).takeIf { it.needsReview }

    /**
     * The pre-send check. Lexicons first; only what they clear goes to the
     * model, and a failed call falls back to the lexicon verdict rather than
     * blocking the send.
     */
    suspend fun analyzeMessage(text: String): MindfulAnalysis {
        val keywordResult = keywordAnalysis(text)
        if (keywordResult.needsReview) return keywordResult

        return try {
            val response = openAI.sendChat(
                messages = listOf(
                    OpenAIService.ChatMessage("system", ANALYSIS_PROMPT),
                    OpenAIService.ChatMessage("user", text)
                ),
                temperature = 0.3,
                maxTokens = 300
            )

            parseAnalysis(response)
        } catch (_: Exception) {
            keywordAnalysis(text)
        }
    }

    private fun parseAnalysis(response: String): MindfulAnalysis {
        val json = runCatching {
            val start = response.indexOf('{')
            val end = response.lastIndexOf('}')
            if (start < 0 || end <= start) return@runCatching null
            JSON.parseToJsonElement(response.substring(start, end + 1)).jsonObject
        }.getOrNull() ?: return MindfulAnalysis.CLEAR

        val needsReview = json["needsReview"]?.jsonPrimitive?.booleanOrNull ?: false
        if (!needsReview) return MindfulAnalysis.CLEAR

        val severity = MindfulSeverity.fromRaw(json["severity"]?.jsonPrimitive?.content)

        // The model judges a single message with no conversation around it, and
        // its low-severity calls are where the harmless ones ("hi!!", an
        // enthusiastic compliment) land. Anything genuinely low-severity is
        // already covered by the lexicons.
        if (severity == MindfulSeverity.LOW) return MindfulAnalysis.CLEAR

        val category = json["category"]?.jsonPrimitive?.content ?: "general"
        return MindfulAnalysis(
            category = if (category == "none") null else category,
            needsReview = true,
            severity = severity,
            reason = json["reason"]?.jsonPrimitive?.content
                ?: "This message may need review.",
            growthLesson = GROWTH_LESSONS[category],
            flaggedWords = emptyList()
        )
    }

    private fun keywordAnalysis(text: String): MindfulAnalysis {
        val normalized = KeywordMatcher.normalize(text)
        val clauses = KeywordMatcher.clauses(text)
        val flaggedWords = mutableListOf<String>()
        var highestCategory: String? = null
        var highestWeight = 0

        for (lexicon in LEXICONS) {
            var matched = false

            lexicon.standalone
                .filter { KeywordMatcher.contains(it, normalized) }
                .forEach { flaggedWords.add(it); matched = true }

            lexicon.directed
                .filter { KeywordMatcher.containsDirected(it, clauses) }
                .forEach { flaggedWords.add(it); matched = true }

            if (matched && lexicon.weight > highestWeight) {
                highestWeight = lexicon.weight
                highestCategory = lexicon.category
            }
        }

        for (pattern in PHONE_PATTERNS) {
            if (pattern.containsMatchIn(text)) {
                flaggedWords.add("[phone number]")
                if (PHONE_WEIGHT > highestWeight) {
                    highestWeight = PHONE_WEIGHT
                    highestCategory = "phone_number"
                }
            }
        }

        val category = highestCategory
        if (flaggedWords.isEmpty() || category == null) return MindfulAnalysis.CLEAR

        val severity = when {
            highestWeight >= 25 -> MindfulSeverity.HIGH
            highestWeight >= 15 -> MindfulSeverity.MEDIUM
            else -> MindfulSeverity.LOW
        }

        return MindfulAnalysis(
            category = category,
            needsReview = true,
            severity = severity,
            reason = "Your message contains language that may be concerning.",
            growthLesson = GROWTH_LESSONS[category],
            flaggedWords = flaggedWords
        )
    }

    private fun prefs() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS = "harvest_prefs"
        private const val KEY_ENABLED = "mindful_messaging_enabled"
        private const val PHONE_WEIGHT = 30

        private val JSON = Json { ignoreUnknownKeys = true }

        private val AGGRESSIVE_STANDALONE = setOf(
            "fuck", "fucking", "fuckin", "fuck you", "fuck off", "motherfucker",
            "mother fucker", "shit", "bullshit", "dipshit", "eat shit",
            "piece of shit", "piece of crap", "asshole", "ass hole", "arsehole",
            "arse hole", "jackass", "dickhead", "prick", "cunt", "twat", "bitch",
            "bastard", "douche", "douchebag", "scumbag", "slut", "whore", "skank",
            "retard", "moron", "wtf", "shut up", "shut the fuck up", "screw you",
            "screw off", "piss off", "fk you", "f off", "f u",
            "hate you", "you suck", "you're nothing", "nobody likes you",
            "waste of space", "sick of you", "can't stand you",
            "hurt you", "kill you", "kill yourself", "kys"
        )

        /**
         * Insults and threats — harmless as ordinary vocabulary, concerning
         * when pointed at someone.
         */
        private val AGGRESSIVE_DIRECTED = setOf(
            "stupid", "idiot", "dumb", "ugly", "fat", "disgusting", "pathetic",
            "loser", "worthless", "useless", "freak", "psycho", "annoying",
            "trash", "garbage", "scum", "hoe", "pussy",
            "kill", "murder", "stab", "choke", "strangle", "suffocate", "drown",
            "punch", "slap", "destroy", "ruin", "torture", "die"
        )

        private val POSSESSIVE_STANDALONE = setOf(
            "you're mine", "belong to me", "my property", "i own you", "control you",
            "won't let you", "you need me", "only mine", "can't leave me",
            "i forbid you", "not allowed to talk"
        )

        private val PRESSURING_STANDALONE = setOf(
            "don't be scared", "what are you afraid of", "why won't you",
            "nothing will happen", "no one will know", "man up", "prove it"
        )

        private val MANIPULATIVE_STANDALONE = setOf(
            "if you loved me", "if you really loved me", "no one will ever",
            "you'll never find", "lucky to have me", "you owe me", "nobody else will",
            "after everything i did", "you made me", "all your fault", "i blame you",
            "guilt trip", "ungrateful"
        )

        private val SEXUAL_PRESSURE_STANDALONE = setOf(
            "send pics", "send nudes", "send me pics", "nudes", "dick pic", "dick pics",
            "show me your body", "show me your tits", "what are you wearing",
            "take it off", "undress", "get naked", "strip for me"
        )

        private val SEXUAL_PRESSURE_DIRECTED = setOf("naked")

        /**
         * Love-bombing markers only. Ordinary affection ("I love you",
         * "forever") was removed: warning people for saying it, and blurring it
         * for the person receiving it, is worse than missing the rare early
         * over-step.
         */
        private val EXCESSIVE_INTENSITY_STANDALONE = setOf(
            "marry me", "can't live without you", "addicted to you", "obsessed with you",
            "soul mate", "soulmate", "you're my everything", "meant to be together"
        )

        private val PERSONAL_INFO_STANDALONE = setOf(
            "social security", "ssn", "bank account", "credit card", "routing number",
            "password", "login credentials", "venmo me", "cashapp", "send money",
            "wire transfer", "bitcoin", "cryptocurrency", "crypto wallet", "gift card"
        )

        private val LEXICONS = listOf(
            Lexicon("aggressive", 20, AGGRESSIVE_STANDALONE, AGGRESSIVE_DIRECTED),
            Lexicon("possessive", 25, POSSESSIVE_STANDALONE),
            Lexicon("pressuring", 15, PRESSURING_STANDALONE),
            Lexicon("manipulative", 20, MANIPULATIVE_STANDALONE),
            Lexicon("sexual_pressure", 25, SEXUAL_PRESSURE_STANDALONE, SEXUAL_PRESSURE_DIRECTED),
            Lexicon("excessive_intensity", 10, EXCESSIVE_INTENSITY_STANDALONE),
            Lexicon("personal_info", 30, PERSONAL_INFO_STANDALONE)
        )

        private val PHONE_PATTERNS = listOf(
            Regex("""\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"""),
            Regex("""\b\(\d{3}\)\s?\d{3}[-.]?\d{4}\b"""),
            Regex("""\b\+?1?\s?\d{3}\s?\d{3}\s?\d{4}\b"""),
            Regex("""\b\d{10,11}\b""")
        )

        private val GROWTH_LESSONS = mapOf(
            "aggressive" to GrowthLesson(
                "Mindful Communication",
                "Pause & reflect — how do you think this might land on the other side?"
            ),
            "possessive" to GrowthLesson(
                "Respecting Autonomy",
                "Quick check-in — how might this come across from their point of view?"
            ),
            "pressuring" to GrowthLesson(
                "Consent & Choice",
                "Growth nudge — what options does this leave on their end?"
            ),
            "manipulative" to GrowthLesson(
                "Authentic Expression",
                "Reflection moment — what do you think this communicates beneath the words?"
            ),
            "sexual_pressure" to GrowthLesson(
                "Respecting Boundaries",
                "Heads up — how might this be received at this point in the conversation?"
            ),
            "excessive_intensity" to GrowthLesson(
                "Balanced Connection",
                "Real quick — how does this fit the stage you’re in right now?"
            ),
            "general" to GrowthLesson(
                "Pause & Reflect",
                "Quick reflection — how do you imagine this being received?"
            ),
            "personal_info" to GrowthLesson(
                "Stay Safe",
                "Heads up — is this the level of sharing you want at this moment?"
            ),
            "phone_number" to GrowthLesson(
                "Stay Safe",
                "Heads up — is this the level of sharing you want at this moment?"
            )
        )

        private val ANALYSIS_PROMPT = """
            You are a dating safety analyst reviewing one outgoing message.

            Flag ONLY what would concern a reasonable person on a dating app: insults, threats, coercion, sexual pressure, controlling or manipulative language, or requests for money and sensitive personal data.

            Ordinary conversation is not a concern. Greetings ("hi", "hello", "hey!!"), small talk, compliments, jokes, flirting, emoji, repeated punctuation or capitals for emphasis, enthusiasm, plans to meet, and short or low-effort messages are all fine — return needsReview false for them.

            You are seeing the message without its conversation, so when it reads two ways, assume the ordinary one. If you are not confident, return needsReview false: a false alarm on a harmless message costs more here than a missed borderline one.

            Respond with JSON only: {"needsReview": bool, "severity": "low"|"medium"|"high", "reason": "brief explanation", "category": "aggressive"|"possessive"|"pressuring"|"manipulative"|"sexual_pressure"|"excessive_intensity"|"personal_info"|"none"}
        """.trimIndent()

        /**
         * Lightweight synchronous filter for clearly objectionable
         * user-generated text. Used to screen profile fields before they are
         * saved: a bio has no one to direct an insult at, so only the
         * standalone terms apply — context-dependent words like "trash" or
         * "hoe" would just block innocent bios.
         */
        fun containsObjectionableContent(text: String): Boolean {
            val normalized = KeywordMatcher.normalize(text)
            return (AGGRESSIVE_STANDALONE + SEXUAL_PRESSURE_STANDALONE)
                .any { KeywordMatcher.contains(it, normalized) }
        }
    }
}
