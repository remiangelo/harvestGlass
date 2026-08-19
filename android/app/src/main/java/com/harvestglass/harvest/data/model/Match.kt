package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Mirrors Harvest/Models/Match.swift. Only the parts the conversation list
 * needs are ported; the matching queue lands with Discover.
 */
@Serializable
data class Match(
    val id: String,
    @SerialName("user1_id") val user1Id: String,
    @SerialName("user2_id") val user2Id: String,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("matched_at") val matchedAt: String? = null,
    @SerialName("unmatched_at") val unmatchedAt: String? = null
) {
    /** Case-insensitive, matching the Swift original. */
    fun otherUserId(currentUserId: String): String? {
        val me = currentUserId.lowercase()
        return when (me) {
            user1Id.lowercase() -> user2Id
            user2Id.lowercase() -> user1Id
            else -> null
        }
    }
}
