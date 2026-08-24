package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/UserProfile.swift. */
@Serializable
data class UserProfile(
    val id: String,
    val email: String? = null,
    val nickname: String? = null,
    val age: Int? = null,
    val bio: String? = null,
    val location: String? = null,
    val gender: String? = null,
    val preferences: String? = null,
    val goals: String? = null,
    val hobbies: List<String>? = null,
    val photos: List<String>? = null,

    @SerialName("distance_preference") val distancePreference: Int? = null,
    @SerialName("interested_in") val interestedIn: List<String>? = null,
    @SerialName("looking_for") val lookingFor: String? = null,
    @SerialName("height_cm") val heightCm: Int? = null,
    val smoking: String? = null,
    val drinking: String? = null,
    val cannabis: String? = null,
    @SerialName("spiritual_orientation") val spiritualOrientation: String? = null,
    @SerialName("children_status") val childrenStatus: String? = null,
    @SerialName("relationship_status") val relationshipStatus: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,

    @SerialName("onboarding_completed") val onboardingCompleted: Boolean? = null,
    @SerialName("is_banned") val isBanned: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,

    // Values / Soil tab display settings.
    @SerialName("values_blurb") val valuesBlurb: String? = null,
    @SerialName("show_values_brought") val showValuesBrought: Boolean? = null,
    @SerialName("show_values_sought") val showValuesSought: Boolean? = null,
    @SerialName("show_values_blurb") val showValuesBlurb: Boolean? = null,
    @SerialName("show_values_graph") val showValuesGraph: Boolean? = null,
    /** "need" | "bring" — which side the profile radar shows. */
    @SerialName("profile_graph_side") val profileGraphSide: String? = null,

    // Notification preferences.
    @SerialName("notif_messages_enabled") val notifMessagesEnabled: Boolean? = null,
    @SerialName("notif_matches_enabled") val notifMatchesEnabled: Boolean? = null,
    @SerialName("notif_likes_enabled") val notifLikesEnabled: Boolean? = null,
    @SerialName("notif_gardener_local_enabled") val notifGardenerLocalEnabled: Boolean? = null,
    @SerialName("notif_gardener_local_hour") val notifGardenerLocalHour: Int? = null
) {
    val displayName: String
        get() = nickname ?: email?.substringBefore('@')?.takeIf { it.isNotEmpty() } ?: "User"

    val primaryPhoto: String? get() = photos?.firstOrNull()
}
