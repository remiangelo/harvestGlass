package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Match.swift. */
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

/** Mirrors MatchWithProfile in Harvest/Models/Match.swift. */
data class MatchWithProfile(val match: Match, val profile: UserProfile) {
    val id: String get() = match.id
}

/**
 * Mirrors SwipeAction in Harvest/Models/Swipe.swift.
 *
 * Swipes predate the Seeds pivot. Nothing creates a new one except a reply to
 * an inbound like, which is why the enum is here and not in a Discover module.
 */
@Serializable
enum class SwipeAction(val raw: String) {
    @SerialName("like") LIKE("like"),
    @SerialName("nope") NOPE("nope"),
    @SerialName("super_like") SUPER_LIKE("super_like")
}

@Serializable
data class Swipe(
    val id: String,
    @SerialName("swiper_id") val swiperId: String,
    @SerialName("swiped_id") val swipedId: String,
    val action: SwipeAction,
    @SerialName("created_at") val createdAt: String? = null
)

/** Mirrors InboundLikeWithProfile in Harvest/Models/Match.swift. */
data class InboundLikeWithProfile(val swipe: Swipe, val profile: UserProfile) {
    val id: String get() = swipe.id
}
