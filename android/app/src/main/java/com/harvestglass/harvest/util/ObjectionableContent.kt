package com.harvestglass.harvest.util

/**
 * Port of the static path through `MindfulMessagingService.containsObjectionableContent`
 * plus the `KeywordMatcher` rules it relies on
 * (Harvest/Utilities/KeywordMatcher.swift).
 *
 * Onboarding's nickname step is the only consumer here. The full mindful
 * messaging analysis — the directed lexicons, clause splitting, and the
 * OpenAI-backed `analyzeMessage` — ports with the P2 chat phase.
 *
 * Both lists used to be scanned with a plain `contains`, which matched *inside*
 * words: "hello" hit "hell", "breakfast" hit "break". Every match here is
 * anchored to word boundaries instead, on a normalized copy of the text.
 */
object ObjectionableContent {

    /** Aggressive terms that are objectionable on their own, not only when aimed at someone. */
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

    private val SEXUAL_PRESSURE_STANDALONE = setOf(
        "send pics", "send nudes", "send me pics", "nudes", "dick pic", "dick pics",
        "show me your body", "show me your tits", "what are you wearing",
        "take it off", "undress", "get naked", "strip for me"
    )

    private val TERMS: Set<String> = AGGRESSIVE_STANDALONE + SEXUAL_PRESSURE_STANDALONE

    /** Apostrophe variants stripped so "can't" and "cant" are one keyword. */
    private val APOSTROPHES = charArrayOf('\'', '’', '‘', 'ʼ', '`', '´')

    private val WHITESPACE_RUN = Regex("\\s+")

    /**
     * Lowercases, drops apostrophes, and reduces every other non-alphanumeric to
     * a single space. The result holds only letters, digits and spaces — which
     * is what makes `\b` mean what it looks like it means.
     */
    fun normalize(text: String): String {
        val lowered = text.lowercase().filterNot { it in APOSTROPHES }
        val stripped = buildString(lowered.length) {
            lowered.forEach { append(if (it.isLetterOrDigit()) it else ' ') }
        }
        return WHITESPACE_RUN.replace(stripped, " ").trim()
    }

    /**
     * True when [keyword] appears in already-normalized [text] as whole words.
     *
     * Single-word keywords also match simple inflections — "stalk" matches
     * "stalks", "stalked", "stalking" — but never a longer stem, so "hell"
     * still does not match "hello".
     */
    fun containsKeyword(keyword: String, text: String): Boolean {
        val normalizedKeyword = normalize(keyword)
        if (normalizedKeyword.isEmpty()) return false

        // Cheap reject first: a substring hit is necessary (inflections only
        // append), so the regex runs for a handful of candidates rather than
        // for every keyword on every check.
        if (!text.contains(normalizedKeyword)) return false

        val escaped = Regex.escape(normalizedKeyword)
        val inflection = if (normalizedKeyword.contains(" ")) "" else "(?:s|es|ed|ing)?"
        return Regex("\\b$escaped$inflection\\b").containsMatchIn(text)
    }

    /** True when the text carries a standalone aggressive or sexual-pressure term. */
    fun contains(text: String): Boolean {
        val normalized = normalize(text)
        if (normalized.isEmpty()) return false
        return TERMS.any { containsKeyword(it, normalized) }
    }
}
