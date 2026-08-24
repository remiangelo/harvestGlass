package com.harvestglass.harvest.data.model

/**
 * How much of the Field filter set a tier unlocks.
 *
 * Mirrors FieldFilterLevel in Harvest/Models/SubscriptionTier.swift, including
 * its decoding rule: an unknown value falls back to [NONE], because a filter
 * that silently stays locked is a better failure than a tier that won't load.
 */
enum class FieldFilterLevel(val raw: String) {
    NONE("none"),
    ADVANCED("advanced"),
    FULL("full");

    val unlocksAdvanced: Boolean get() = this != NONE
    val unlocksFull: Boolean get() = this == FULL

    companion object {
        fun fromRaw(raw: String?): FieldFilterLevel =
            entries.firstOrNull { it.raw == raw?.lowercase() } ?: NONE
    }
}

/**
 * Mirrors RoomMemberFilter in Harvest/Models/ProfileFilterOptions.swift.
 *
 * Free tier gets search, age and gender; Grow+ adds the "advanced" block and
 * Gold the "full" block. The gating lives in the UI — this model just matches.
 */
data class RoomMemberFilter(
    val search: String = "",
    val ageMin: Int = DEFAULT_AGE_MIN,
    val ageMax: Int = DEFAULT_AGE_MAX,
    val gender: String? = null,

    // Grow+ (advanced)
    val lookingFor: String? = null,
    val heightMin: Int? = null,
    val heightMax: Int? = null,
    val smoking: String? = null,
    val drinking: String? = null,
    val cannabis: String? = null,

    // Gold (full)
    val faith: String? = null,
    val childrenStatus: String? = null
) {
    val isDefault: Boolean get() = this == RoomMemberFilter()

    /** Everything except the free-text search, which the roster shows separately. */
    val activeAttributeCount: Int
        get() {
            var n = 0
            if (ageMin != DEFAULT_AGE_MIN || ageMax != DEFAULT_AGE_MAX) n++
            listOf(gender, lookingFor, smoking, drinking, cannabis, faith, childrenStatus)
                .forEach { if (it != null) n++ }
            if (heightMin != null || heightMax != null) n++
            return n
        }

    fun matches(profile: UserProfile): Boolean {
        val query = search.trim().lowercase()
        if (query.isNotEmpty()) {
            val haystack = listOf(
                profile.displayName,
                profile.location.orEmpty(),
                profile.bio.orEmpty()
            ).joinToString(" ").lowercase()
            if (!haystack.contains(query)) return false
        }

        // An unset attribute on a profile never excludes it — rooms are for
        // meeting people, and half-filled profiles are the norm.
        profile.age?.let { if (it < ageMin || it > ageMax) return false }
        gender?.let { if (profile.gender?.lowercase() != it.lowercase()) return false }
        lookingFor?.let { if (profile.lookingFor != it) return false }
        heightMin?.let { min -> profile.heightCm?.let { if (it < min) return false } }
        heightMax?.let { max -> profile.heightCm?.let { if (it > max) return false } }
        smoking?.let { if (profile.smoking != it) return false }
        drinking?.let { if (profile.drinking != it) return false }
        cannabis?.let { if (profile.cannabis != it) return false }
        faith?.let { if (profile.spiritualOrientation != it) return false }
        childrenStatus?.let { if (profile.childrenStatus != it) return false }
        return true
    }

    companion object {
        const val DEFAULT_AGE_MIN = 18
        const val DEFAULT_AGE_MAX = 99
    }
}
