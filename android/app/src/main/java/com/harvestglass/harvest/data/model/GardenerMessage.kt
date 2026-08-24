package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/GardenerMessage.swift. */
@Serializable
data class GardenerMessage(
    val id: String,
    @SerialName("user_id") val userId: String,
    /** "user" or "assistant" — the DB column is `sender` with "gardener". */
    val role: String,
    val content: String,
    @SerialName("created_at") val createdAt: String? = null
)
