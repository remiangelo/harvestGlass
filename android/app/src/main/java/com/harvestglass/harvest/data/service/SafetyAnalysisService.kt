package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.RedFlagCategory
import com.harvestglass.harvest.data.model.RedFlagReport
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.data.model.SafetyFlagSnapshot
import com.harvestglass.harvest.util.KeywordMatcher
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put
import java.time.Instant
import java.util.UUID

/**
 * Port of Harvest/Services/SafetyAnalysisService.swift.
 *
 * Scores a conversation from the red flags its messages trip, and gates
 * contact sharing on that score. Keyword-driven and on-device — the score
 * decides whether someone is nudged away from moving off-platform, so it never
 * depends on a network call succeeding.
 */
class SafetyAnalysisService(private val client: SupabaseClient) {

    @Serializable
    private data class ConversationLookup(
        val id: String,
        @SerialName("user1_id") val user1Id: String? = null,
        @SerialName("user2_id") val user2Id: String? = null
    )

    @Serializable
    private data class MatchLookup(
        val id: String,
        @SerialName("user1_id") val user1Id: String? = null,
        @SerialName("user2_id") val user2Id: String? = null
    )

    @Serializable
    private data class TimestampRow(@SerialName("created_at") val createdAt: String? = null)

    @Serializable
    private data class IdRow(val id: String)

    /**
     * The analysis row for this match, creating a clean one if there is none.
     */
    suspend fun getOrCreateAnalysis(
        matchId: String,
        userId: String,
        otherUserId: String
    ): SafetyAnalysis {
        val conversation = fetchConversation(matchId)
            ?: throw IllegalStateException("Conversation not found for match")

        client.postgrest.from("safety_analyses")
            .select {
                filter {
                    eq("conversation_id", conversation.id)
                    eq("user_id", userId)
                }
            }
            .decodeList<SafetyAnalysis>()
            .firstOrNull()
            ?.let { return hydrate(it, otherUserId, conversation.id) }

        val created = client.postgrest.from("safety_analyses").insert(
            buildJsonObject {
                put("conversation_id", conversation.id)
                put("user_id", userId)
                put("match_id", matchId)
                put("safety_score", CLEAN_SCORE)
                put("red_flags", buildJsonArray { })
                put("recommendations", buildJsonArray { })
                put("allow_contact_sharing", false)
            }
        ) {
            select()
        }
            .decodeList<SafetyAnalysis>()
            .firstOrNull()
            ?: throw IllegalStateException("Failed to create safety analysis")

        return hydrate(created, otherUserId, conversation.id)
    }

    /**
     * Scores one message against the lexicons and folds any flags into the
     * analysis. Returns the conversation's red flags as they now stand.
     */
    suspend fun analyzeMessage(message: String, analysisId: String): List<RedFlagReport> {
        val analysis = getAnalysisById(analysisId) ?: return emptyList()

        val fresh = detectFlags(message)
        if (fresh.isEmpty()) return emptyList()

        val flags = analysis.redFlags + fresh
        val score = computeSafetyScore(flags)
        val totalMessages = fetchMessageCount(analysis.conversationId)

        val updated = analysis.copy(
            redFlags = flags,
            safetyScore = score,
            recommendations = recommendations(score, totalMessages)
        ).also {
            it.otherUserId = analysis.otherUserId
            it.totalMessages = totalMessages
            it.firstMessageAt = analysis.firstMessageAt
        }

        val allowContact = canShareContact(updated)

        // Persisting the moderator-facing reports is best-effort: the score
        // itself is what gates the user, and it is already computed.
        runCatching {
            replaceAiDetectedFlags(analysis.conversationId, analysis.otherUserId, flags)
        }

        persist(analysisId, score, flags, updated.recommendations, allowContact)
        return getRedFlags(analysisId)
    }

    /** Every analysis this user owns, newest first, each hydrated. */
    suspend fun getSafetyDashboard(userId: String): List<SafetyAnalysis> = coroutineScope {
        val analyses = client.postgrest.from("safety_analyses")
            .select {
                filter { eq("user_id", userId) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<SafetyAnalysis>()

        analyses
            .map { analysis ->
                async {
                    val otherUserId = runCatching {
                        fetchOtherUserId(analysis.matchId, analysis.conversationId, userId)
                    }.getOrNull()
                    hydrate(analysis, otherUserId.orEmpty(), analysis.conversationId)
                }
            }
            .map { it.await() }
            .sortedByDescending { it.createdAt.orEmpty() }
    }

    suspend fun getRedFlags(analysisId: String): List<RedFlagReport> {
        val analysis = getAnalysisById(analysisId) ?: return emptyList()

        return client.postgrest.from("red_flag_reports")
            .select {
                filter {
                    eq("conversation_id", analysis.conversationId)
                    eq("reported_user_id", analysis.otherUserId)
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList()
    }

    /**
     * Whether this conversation clears the bar for moving off-platform, and
     * the first reason it doesn't. All three conditions must hold.
     */
    suspend fun isReadyToMove(analysisId: String): Pair<Boolean, String?> {
        val analysis = getAnalysisById(analysisId)
            ?: return false to "Analysis not found"

        if (!analysis.has24HourHistory) {
            return false to "At least 24 hours of conversation history are required"
        }
        if (analysis.totalMessages < MIN_MESSAGES) {
            return false to "Need at least $MIN_MESSAGES messages exchanged"
        }
        if (analysis.safetyScore < SAFE_SCORE) {
            return false to "Safety score is below the threshold"
        }

        return true to null
    }

    /** Files a user-reported flag against the other person. */
    suspend fun reportRedFlag(
        analysisId: String,
        category: RedFlagCategory,
        detail: String,
        messageId: String?
    ) {
        val analysis = getAnalysisById(analysisId) ?: return

        // The message id rides in the evidence string so a moderator can find
        // the message the report is about.
        val evidence = if (!messageId.isNullOrEmpty()) "[$messageId] $detail" else detail

        client.postgrest.from("red_flag_reports").insert(
            buildJsonObject {
                put("reporter_id", analysis.userId)
                put("reported_user_id", analysis.otherUserId)
                put("conversation_id", analysis.conversationId)
                put("flag_type", category.raw)
                put("severity", category.severity.raw)
                put("evidence", evidence)
                put("ai_detected", false)
                put("user_reported", true)
            }
        )
    }

    /** Records the user's decision at the ready-to-move gate. */
    suspend fun recordReadyToMoveDecision(
        userId: String,
        matchId: String,
        conversationId: String,
        safetyScore: Int,
        approved: Boolean,
        contactShared: Boolean,
        contactMethod: String?
    ) {
        client.postgrest.from("ready_to_move_checks").insert(
            buildJsonObject {
                put("user_id", userId)
                put("match_id", matchId)
                put("conversation_id", conversationId)
                put("safety_score", safetyScore)
                put("approved", approved)
                put("contact_shared", contactShared)
                if (contactMethod != null) put("contact_method", contactMethod)
            }
        )
    }

    /** Whether this user has already passed the gate for this conversation. */
    suspend fun hasApprovedReadyToMove(conversationId: String, userId: String): Boolean =
        client.postgrest.from("ready_to_move_checks")
            .select(Columns.list("id")) {
                filter {
                    eq("conversation_id", conversationId)
                    eq("user_id", userId)
                    eq("approved", true)
                }
                limit(1)
            }
            .decodeList<IdRow>()
            .isNotEmpty()

    /**
     * Re-scores a whole conversation from scratch, replacing whatever flags
     * were there. Used by the dashboard's Analyze action for threads that
     * predate the scoring.
     */
    suspend fun analyzeConversationHistory(
        conversationId: String,
        matchId: String,
        userId: String,
        otherUserId: String
    ): SafetyAnalysis {
        val analysis = getOrCreateAnalysis(matchId, userId, otherUserId)

        val messages = client.postgrest.from("messages")
            .select {
                filter { eq("conversation_id", conversationId) }
                order("created_at", Order.ASCENDING)
            }
            .decodeList<Message>()

        // Only the other person's messages count against them.
        val snapshots = messages
            .filter { it.senderId.lowercase() == otherUserId.lowercase() }
            .flatMap { message ->
                message.content?.takeIf { it.isNotEmpty() }
                    ?.let { detectFlags(it, message.id) }
                    .orEmpty()
            }

        val total = fetchMessageCount(conversationId)
        val score = computeSafetyScore(snapshots)
        val recs = recommendations(score, total)

        val rescored = analysis.copy(
            redFlags = snapshots,
            safetyScore = score,
            recommendations = recs
        ).also {
            it.otherUserId = otherUserId
            it.totalMessages = total
            it.firstMessageAt = analysis.firstMessageAt
        }
        val allowContact = canShareContact(rescored)

        runCatching { replaceAiDetectedFlags(conversationId, otherUserId, snapshots) }
        persist(analysis.id, score, snapshots, recs, allowContact)

        return rescored.copy(allowContactSharing = allowContact).also {
            it.otherUserId = otherUserId
            it.totalMessages = total
            it.firstMessageAt = analysis.firstMessageAt
        }
    }

    /** Re-scores every active match. Returns how many conversations ran. */
    suspend fun analyzeAllUserConversations(userId: String): Int {
        val matches = client.postgrest.from("matches")
            .select(Columns.list("id", "user1_id", "user2_id")) {
                filter {
                    eq("is_active", true)
                    or {
                        eq("user1_id", userId)
                        eq("user2_id", userId)
                    }
                }
            }
            .decodeList<MatchLookup>()

        var analyzed = 0
        val me = userId.lowercase()

        for (match in matches) {
            val otherUserId =
                if (match.user1Id?.lowercase() == me) match.user2Id else match.user1Id
            if (otherUserId == null) continue

            val conversation = runCatching { fetchConversation(match.id) }.getOrNull() ?: continue

            // One failed conversation must not stop the sweep.
            val ok = runCatching {
                analyzeConversationHistory(conversation.id, match.id, userId, otherUserId)
            }.isSuccess
            if (ok) analyzed++
        }

        return analyzed
    }

    private suspend fun getAnalysisById(analysisId: String): SafetyAnalysis? {
        val analysis = client.postgrest.from("safety_analyses")
            .select { filter { eq("id", analysisId) } }
            .decodeList<SafetyAnalysis>()
            .firstOrNull()
            ?: return null

        val otherUserId = runCatching {
            fetchOtherUserId(analysis.matchId, analysis.conversationId, analysis.userId)
        }.getOrNull()

        return hydrate(analysis, otherUserId.orEmpty(), analysis.conversationId)
    }

    /**
     * Fills in the fields the table doesn't carry: who the other person is,
     * how far the conversation has got, and what to recommend.
     */
    private suspend fun hydrate(
        analysis: SafetyAnalysis,
        otherUserId: String,
        conversationId: String
    ): SafetyAnalysis {
        val total = runCatching { fetchMessageCount(conversationId) }.getOrNull() ?: 0
        val firstAt = runCatching { fetchFirstMessageAt(conversationId) }.getOrNull()

        val hydrated = analysis.copy(
            recommendations = analysis.recommendations.ifEmpty {
                recommendations(analysis.safetyScore, total)
            }
        )
        hydrated.otherUserId = otherUserId
        hydrated.totalMessages = total
        hydrated.firstMessageAt = firstAt

        return if (analysis.allowContactSharing || canShareContact(hydrated)) {
            hydrated.copy(allowContactSharing = true).also {
                it.otherUserId = otherUserId
                it.totalMessages = total
                it.firstMessageAt = firstAt
            }
        } else {
            hydrated
        }
    }

    private suspend fun fetchConversation(matchId: String): ConversationLookup? =
        client.postgrest.from("conversations")
            .select(Columns.list("id", "user1_id", "user2_id")) {
                filter { eq("match_id", matchId) }
                limit(1)
            }
            .decodeList<ConversationLookup>()
            .firstOrNull()

    /**
     * The other party, from the match row when it exists and the conversation
     * row otherwise — an older conversation may predate its match.
     */
    private suspend fun fetchOtherUserId(
        matchId: String,
        conversationId: String,
        currentUserId: String
    ): String? {
        val me = currentUserId.lowercase()

        client.postgrest.from("matches")
            .select(Columns.list("id", "user1_id", "user2_id")) {
                filter { eq("id", matchId) }
                limit(1)
            }
            .decodeList<MatchLookup>()
            .firstOrNull()
            ?.let { match ->
                if (match.user1Id?.lowercase() == me) return match.user2Id
                if (match.user2Id?.lowercase() == me) return match.user1Id
            }

        val conversation = client.postgrest.from("conversations")
            .select(Columns.list("id", "user1_id", "user2_id")) {
                filter { eq("id", conversationId) }
                limit(1)
            }
            .decodeList<ConversationLookup>()
            .firstOrNull()
            ?: return null

        return when (me) {
            conversation.user1Id?.lowercase() -> conversation.user2Id
            conversation.user2Id?.lowercase() -> conversation.user1Id
            else -> null
        }
    }

    private suspend fun fetchMessageCount(conversationId: String): Int =
        client.postgrest.from("messages")
            .select(Columns.list("id")) {
                filter { eq("conversation_id", conversationId) }
            }
            .decodeList<IdRow>()
            .size

    private suspend fun fetchFirstMessageAt(conversationId: String): String? =
        client.postgrest.from("messages")
            .select(Columns.list("created_at")) {
                filter { eq("conversation_id", conversationId) }
                order("created_at", Order.ASCENDING)
                limit(1)
            }
            .decodeList<TimestampRow>()
            .firstOrNull()
            ?.createdAt

    private suspend fun replaceAiDetectedFlags(
        conversationId: String,
        reportedUserId: String,
        reports: List<SafetyFlagSnapshot>
    ) {
        client.postgrest.from("red_flag_reports").delete {
            filter {
                eq("conversation_id", conversationId)
                eq("reported_user_id", reportedUserId)
                eq("ai_detected", true)
            }
        }

        if (reports.isEmpty()) return

        client.postgrest.from("red_flag_reports").insert(
            reports.map { report ->
                buildJsonObject {
                    put("reported_user_id", reportedUserId)
                    put("conversation_id", conversationId)
                    put("flag_type", report.category.raw)
                    put("severity", report.severity.raw)
                    put("evidence", report.evidence)
                    put("ai_detected", true)
                    put("user_reported", false)
                }
            }
        )
    }

    private suspend fun persist(
        analysisId: String,
        score: Int,
        flags: List<SafetyFlagSnapshot>,
        recommendations: List<String>,
        allowContactSharing: Boolean
    ) {
        client.postgrest.from("safety_analyses").update(
            buildJsonObject {
                put("safety_score", score)
                put("red_flags", JSON.encodeToJsonElement(flags))
                put("recommendations", JSON.encodeToJsonElement(recommendations))
                put("allow_contact_sharing", allowContactSharing)
            }
        ) {
            filter { eq("id", analysisId) }
        }
    }

    companion object {
        private const val CLEAN_SCORE = 100
        private const val SAFE_SCORE = 70
        private const val MIN_MESSAGES = 20

        /** A conversation can never be scored below 10 by keywords alone. */
        private const val MAX_PENALTY = 90

        private val JSON = Json { encodeDefaults = true }

        /**
         * Matched as whole words by [KeywordMatcher], so bare verbs no longer
         * fire on ordinary sentences. Terms that only mean something when aimed
         * at the other person are spelled out with their object ("kill you",
         * not "kill") — a red flag here costs the other person 25-30 safety
         * points and can gate contact sharing, so the bar is a phrase with no
         * innocent reading.
         */
        private val RED_FLAG_KEYWORDS: Map<RedFlagCategory, Set<String>> = mapOf(
            RedFlagCategory.FINANCIAL to setOf(
                "send money", "wire transfer", "bank account", "western union", "moneygram",
                "gift card", "bitcoin", "crypto wallet", "cryptocurrency", "venmo me",
                "cashapp", "paypal me", "investment opportunity", "financial help",
                "loan me", "lend me money", "borrow money"
            ),
            RedFlagCategory.PERSONAL_INFO to setOf(
                "social security", "ssn", "credit card number", "routing number",
                "password", "login credentials", "home address", "work address"
            ),
            RedFlagCategory.CATFISHING to setOf(
                "can't video call", "camera broken", "camera is broken", "too shy for video",
                "deployed overseas", "oil rig", "military deployment", "can't meet yet"
            ),
            RedFlagCategory.MANIPULATION to setOf(
                "if you loved me", "nobody else will", "you owe me",
                "after everything i did", "you're nothing without",
                "no one will ever", "lucky to have me"
            ),
            RedFlagCategory.HARASSMENT to setOf(
                "kill you", "kill yourself", "hurt you", "i'll find you", "i will find you",
                "stalk", "stalker", "revenge", "destroy you",
                "ruin your life", "expose you", "tell everyone"
            ),
            RedFlagCategory.INAPPROPRIATE to setOf(
                "send nudes", "explicit photos", "what are you wearing",
                "take it off", "show me your body"
            ),
            RedFlagCategory.SPAM to setOf(
                "click this link", "free money", "you've won", "act now",
                "limited time offer", "subscribe to", "follow my"
            )
        )

        /**
         * At most one flag per category per message — two financial phrases in
         * one sentence are one concern, not two.
         */
        fun detectFlags(text: String, messageId: String? = null): List<SafetyFlagSnapshot> {
            val normalized = KeywordMatcher.normalize(text)
            val now = Instant.now().toString()

            return RED_FLAG_KEYWORDS.mapNotNull { (category, keywords) ->
                val hit = keywords.firstOrNull { KeywordMatcher.contains(it, normalized) }
                    ?: return@mapNotNull null

                SafetyFlagSnapshot(
                    id = UUID.randomUUID().toString(),
                    category = category,
                    severity = category.severity,
                    evidence = "Message contains: $hit",
                    messageId = messageId,
                    createdAt = now
                )
            }
        }

        fun computeSafetyScore(flags: List<SafetyFlagSnapshot>): Int {
            val totalWeight = flags.sumOf { it.severity.weight }
            return (CLEAN_SCORE - minOf(totalWeight, MAX_PENALTY)).coerceAtLeast(0)
        }

        fun recommendations(score: Int, totalMessages: Int): List<String> {
            val output = mutableListOf<String>()

            if (totalMessages < MIN_MESSAGES) {
                output.add("Keep chatting in-app before sharing contact details.")
            }
            if (score < SAFE_SCORE) {
                output.add("Proceed cautiously and avoid moving off-platform yet.")
            }
            if (score < 50) {
                output.add("Consider reporting or blocking this user if the behavior continues.")
            }
            if (output.isEmpty()) {
                output.add(
                    "This conversation currently looks safe. Stay mindful and trust your instincts."
                )
            }

            return output
        }

        /** All three conditions, matching `canShareContact` on iOS. */
        fun canShareContact(analysis: SafetyAnalysis): Boolean =
            analysis.safetyScore >= SAFE_SCORE &&
                analysis.totalMessages >= MIN_MESSAGES &&
                analysis.has24HourHistory
    }
}
