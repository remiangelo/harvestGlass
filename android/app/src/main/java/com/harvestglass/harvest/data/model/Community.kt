package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Community.swift. */
@Serializable
data class Community(
    val id: String,
    val slug: String,
    val name: String,
    val description: String? = null,
    val kind: String,
    @SerialName("member_count") val memberCount: Int? = null,
    @SerialName("display_order") val displayOrder: Int? = null,
    @SerialName("image_url") val imageUrl: String? = null
)

@Serializable
data class CommunityMessage(
    val id: String,
    @SerialName("community_id") val communityId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String,
    @SerialName("is_removed") val isRemoved: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("reply_to_id") val replyToId: String? = null,
    val mentions: List<String>? = null
)

/**
 * One emoji reaction by one user on one message.
 * community_id is filled server-side by a trigger; it exists so realtime
 * can filter reaction events per room.
 */
@Serializable
data class CommunityReaction(
    @SerialName("message_id") val messageId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
    @SerialName("community_id") val communityId: String? = null
) {
    companion object {
        /** The curated set — must match the DB check constraint exactly. */
        val CURATED_EMOJI = listOf("🌱", "💚", "🌻", "😂", "👏", "🤔")
    }
}

@Serializable
data class CommunityPrompt(
    val id: String,
    val text: String
)

/** Lightweight sender info for community chat (name + avatar). */
@Serializable
data class CommunitySender(
    val id: String,
    val nickname: String? = null,
    val photos: List<String>? = null
) {
    val photoUrl: String? get() = photos?.firstOrNull()
}
