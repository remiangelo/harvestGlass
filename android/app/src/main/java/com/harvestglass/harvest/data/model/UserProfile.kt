package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import com.harvestglass.harvest.util.HeightFormatter

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

    /**
     * Goals have been stored three ways over the app's life — a JSON array, a
     * comma-joined string (what onboarding writes), and a bare single value —
     * so all three are accepted and normalised to today's labels.
     */
    val goalsList: List<String>
        get() {
            val trimmed = goals?.trim().orEmpty()
            if (trimmed.isEmpty()) return emptyList()

            if (trimmed.startsWith("[")) {
                runCatching { Json.decodeFromString<List<String>>(trimmed) }
                    .getOrNull()
                    ?.let { decoded ->
                        return decoded.map { normalizeGoalLabel(it.trim()) }.filter { it.isNotEmpty() }
                    }
            }

            if (trimmed.contains(",")) {
                return trimmed.split(",")
                    .map { normalizeGoalLabel(it.trim(*GOAL_TRIM_CHARS)) }
                    .filter { it.isNotEmpty() }
            }

            return normalizeGoalLabel(trimmed.trim(*GOAL_TRIM_CHARS))
                .takeIf { it.isNotEmpty() }
                ?.let { listOf(it) }
                ?: emptyList()
        }

    val heightDisplayValue: String? get() = heightCm?.let { HeightFormatter.string(it) }

    /** Label/value pairs for the profile card, in the order iOS shows them. */
    val lifestyleDetails: List<Pair<String, String>>
        get() = buildList {
            heightDisplayValue?.let { add("Height" to it) }
            lookingFor?.trim()?.let { normalizeGoalLabel(it) }?.takeIf { it.isNotEmpty() }
                ?.let { add("Looking For" to it) }
            formatLifestyleValue(smoking)?.let { add("Smoking" to it) }
            formatLifestyleValue(drinking)?.let { add("Drinking" to it) }
            formatLifestyleValue(cannabis)?.let { add("Cannabis" to it) }
            formatLifestyleValue(spiritualOrientation)?.let { add("Spiritual Orientation" to it) }
            formatLifestyleValue(childrenStatus)?.let { add("Children" to it) }
        }

    private companion object {
        val GOAL_TRIM_CHARS = charArrayOf('"', '[', ']', ' ', '\n', '\t')

        /** Words that stay lowercase when title-casing a stored value. */
        val SMALL_WORDS = setOf("and", "to", "not")

        fun normalizeGoalLabel(value: String): String = when (value.lowercase()) {
            "short-term dating", "casual" -> "Dating"
            "long-term relationship", "long-term commitment", "long_term_commitment" ->
                "Long-term Commitment"
            "relationship" -> "Relationship"
            "marriage" -> "Marriage"
            "not sure yet", "not sure" -> "Dating"
            else -> value
        }

        fun formatLifestyleValue(value: String?): String? {
            val trimmed = value?.trim().orEmpty()
            if (trimmed.isEmpty()) return null

            return trimmed
                .replace("_", " ")
                .split(" ")
                .filter { it.isNotEmpty() }
                .joinToString(" ") { word ->
                    val lower = word.lowercase()
                    if (lower in SMALL_WORDS) lower
                    else word.take(1).uppercase() + word.drop(1).lowercase()
                }
        }
    }
}
