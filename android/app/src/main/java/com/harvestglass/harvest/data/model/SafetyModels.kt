package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Duration
import java.time.Instant

/** Mirrors RedFlagSeverity in Harvest/Models/SafetyModels.swift. */
@Serializable
enum class RedFlagSeverity(val raw: String, val weight: Int) {
    @SerialName("low") LOW("low", 10),
    @SerialName("medium") MEDIUM("medium", 20),
    @SerialName("high") HIGH("high", 25),
    @SerialName("critical") CRITICAL("critical", 30);

    companion object {
        fun fromRaw(raw: String?): RedFlagSeverity =
            entries.firstOrNull { it.raw == raw } ?: LOW
    }
}

/** Mirrors RedFlagCategory. The severity per category is fixed, not stored. */
@Serializable
enum class RedFlagCategory(val raw: String, val severity: RedFlagSeverity) {
    @SerialName("financial") FINANCIAL("financial", RedFlagSeverity.CRITICAL),
    @SerialName("personal_info") PERSONAL_INFO("personal_info", RedFlagSeverity.CRITICAL),
    @SerialName("catfishing") CATFISHING("catfishing", RedFlagSeverity.HIGH),
    @SerialName("manipulation") MANIPULATION("manipulation", RedFlagSeverity.MEDIUM),
    @SerialName("harassment") HARASSMENT("harassment", RedFlagSeverity.HIGH),
    @SerialName("inappropriate") INAPPROPRIATE("inappropriate", RedFlagSeverity.MEDIUM),
    @SerialName("spam") SPAM("spam", RedFlagSeverity.LOW);

    val weight: Int get() = severity.weight

    companion object {
        /** Unknown types read as spam, matching Swift's `?? .spam`. */
        fun fromRaw(raw: String?): RedFlagCategory =
            entries.firstOrNull { it.raw == raw } ?: SPAM
    }
}

/** Mirrors SafetyLevel. Colours live in the UI layer, as they do on iOS. */
enum class SafetyLevel(val raw: String) {
    BLOCK("block"),
    WARNING("warning"),
    CAUTION("caution"),
    SAFE("safe"),
    VERIFIED("verified");

    val displayName: String get() = raw.replaceFirstChar { it.uppercase() }
}

@Serializable
data class SafetyFlagSnapshot(
    val id: String,
    val category: RedFlagCategory,
    val severity: RedFlagSeverity,
    val evidence: String,
    @SerialName("message_id") val messageId: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

/** Mirrors SafetyAnalysis in Harvest/Models/SafetyModels.swift. */
@Serializable
data class SafetyAnalysis(
    val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("match_id") val matchId: String,
    @SerialName("safety_score") val safetyScore: Int = 100,
    @SerialName("red_flags") val redFlags: List<SafetyFlagSnapshot> = emptyList(),
    val recommendations: List<String> = emptyList(),
    @SerialName("allow_contact_sharing") val allowContactSharing: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null
) {
    // Derived app-side fields, populated by the service rather than the table.
    @kotlinx.serialization.Transient
    var otherUserId: String = ""

    @kotlinx.serialization.Transient
    var totalMessages: Int = 0

    @kotlinx.serialization.Transient
    var firstMessageAt: String? = null

    val redFlagCount: Int get() = redFlags.size

    /**
     * Whether the conversation is at least a day old. Falls back to the
     * analysis row's own timestamp when no message has been sent yet.
     */
    val has24HourHistory: Boolean
        get() {
            val reference = firstMessageAt ?: createdAt ?: return false
            val started = runCatching { Instant.parse(reference) }.getOrNull() ?: return false
            return Duration.between(started, Instant.now()).toHours() >= 24
        }

    val safetyLevel: SafetyLevel
        get() = when {
            safetyScore < 20 -> SafetyLevel.BLOCK
            safetyScore < 50 -> SafetyLevel.WARNING
            safetyScore < 70 -> SafetyLevel.CAUTION
            safetyScore < 80 -> SafetyLevel.SAFE
            else -> SafetyLevel.VERIFIED
        }
}

@Serializable
data class RedFlagReport(
    val id: String,
    @SerialName("reporter_id") val reporterId: String? = null,
    @SerialName("reported_user_id") val reportedUserId: String? = null,
    @SerialName("conversation_id") val conversationId: String? = null,
    @SerialName("flag_type") val flagType: String,
    val severity: RedFlagSeverity? = null,
    val evidence: String? = null,
    @SerialName("ai_detected") val aiDetected: Boolean = false,
    @SerialName("user_reported") val userReported: Boolean = false,
    val reviewed: Boolean = false,
    @SerialName("action_taken") val actionTaken: String? = null,
    @SerialName("reviewed_by") val reviewedBy: String? = null,
    @SerialName("reviewed_at") val reviewedAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    val category: RedFlagCategory get() = RedFlagCategory.fromRaw(flagType)

    val detail: String get() = evidence.orEmpty()
}
