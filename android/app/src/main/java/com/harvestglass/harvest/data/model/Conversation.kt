package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Conversation.swift. */
@Serializable
data class Conversation(
    val id: String,
    @SerialName("match_id") val matchId: String? = null,
    @SerialName("last_message_at") val lastMessageAt: String? = null,
    @SerialName("last_message_preview") val lastMessagePreview: String? = null,
    @SerialName("user1_id") val user1Id: String? = null,
    @SerialName("user2_id") val user2Id: String? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    /**
     * The participant who isn't [currentUserId], or null when this
     * conversation doesn't involve them.
     *
     * Comparison is case-insensitive: Supabase returns lowercased uuids but a
     * caller may not, and a mismatch would show the wrong participant.
     */
    fun otherUserId(currentUserId: String): String? {
        val me = currentUserId.lowercase()
        return when (me) {
            user1Id?.lowercase() -> user2Id
            user2Id?.lowercase() -> user1Id
            else -> null
        }
    }
}

/** A conversation paired with the other participant's profile, for the list. */
data class ConversationWithProfile(
    val conversation: Conversation,
    val profile: UserProfile,
    val hasReplyHighlight: Boolean = false
) {
    val id: String get() = conversation.id
}
