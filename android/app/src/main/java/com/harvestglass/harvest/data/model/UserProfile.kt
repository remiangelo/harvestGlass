package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Slice subset of Harvest/Models/UserProfile.swift. The Swift struct carries
 * ~35 more fields (values, notification prefs, lifestyle, geo); each ports
 * with the feature that reads it, so decoding tolerates their absence and
 * the client ignores unknown columns.
 */
@Serializable
data class UserProfile(
    val id: String,
    val email: String? = null,
    val nickname: String? = null,
    val age: Int? = null,
    val gender: String? = null,
    val photos: List<String>? = null,
    @SerialName("onboarding_completed") val onboardingCompleted: Boolean? = null,
    @SerialName("is_banned") val isBanned: Boolean? = null,

    // Values / Soil tab display settings.
    @SerialName("values_blurb") val valuesBlurb: String? = null,
    @SerialName("show_values_brought") val showValuesBrought: Boolean? = null,
    @SerialName("show_values_sought") val showValuesSought: Boolean? = null,
    @SerialName("show_values_blurb") val showValuesBlurb: Boolean? = null,
    @SerialName("show_values_graph") val showValuesGraph: Boolean? = null,
    /** "need" | "bring" — which side the profile radar shows. */
    @SerialName("profile_graph_side") val profileGraphSide: String? = null
)
