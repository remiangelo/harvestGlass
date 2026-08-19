package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Value.swift. */
@Serializable
data class Value(
    val id: String,
    val name: String,
    val category: String,
    @SerialName("display_order") val displayOrder: Int? = null
)

@Serializable
data class UserValue(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("value_id") val valueId: String,
    val ranking: Int? = null
)
