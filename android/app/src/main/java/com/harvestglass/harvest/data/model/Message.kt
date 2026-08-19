package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Message.swift — a 1:1 conversation message. */
@Serializable
data class Message(
    val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String? = null,
    @SerialName("message_type") val messageType: String? = null,
    @SerialName("media_url") val mediaUrl: String? = null,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    /** Case-insensitive, matching the Swift original. */
    fun isSentBy(userId: String): Boolean = senderId.lowercase() == userId.lowercase()
}
