package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.model.ValueAxis
import kotlin.math.abs
import kotlin.math.min

/** Mirrors CompatibilityScore in Harvest/Services/CompatibilityService.swift. */
data class CompatibilityScore(val total: Int, val breakdown: Map<String, Double>) {
    val interestsScore: Int get() = (breakdown["interests"] ?: 0.0).toInt()
    val valuesScore: Int get() = (breakdown["values"] ?: 0.0).toInt()
    val goalsScore: Int get() = (breakdown["goals"] ?: 0.0).toInt()
    val ageScore: Int get() = (breakdown["age"] ?: 0.0).toInt()
    val distanceScore: Int get() = (breakdown["distance"] ?: 0.0).toInt()

    val displayPercentage: String get() = "$total%"

    val compatibilityLevel: String
        get() = when (total) {
            in 80..100 -> "Excellent Match"
            in 60..79 -> "Great Match"
            in 40..59 -> "Good Match"
            in 20..39 -> "Fair Match"
            else -> "Low Match"
        }
}

/**
 * Which of their Bring picks satisfy my Need picks, and vice versa.
 * Mirrors ValueOverlap in CompatibilityService.swift.
 */
data class ValueOverlap(
    val theyBringForMyNeeds: List<Value>,
    val iBringForTheirNeeds: List<Value>
)

/**
 * Port of Harvest/Services/CompatibilityService.swift.
 *
 * Pure scoring — no network, no state. Every neutral fallback below is the
 * Swift value verbatim; changing one would silently reshuffle everyone's
 * scores relative to iOS.
 */
object CompatibilityService {

    /**
     * A 0–100 score across interests, values, goals, age and distance.
     *
     * Axis scores are optional because a user who hasn't answered the question
     * set has none; that path scores the neutral 15 rather than zero.
     */
    fun calculateCompatibility(
        currentUser: UserProfile,
        otherUser: UserProfile,
        currentUserAxisScores: Pair<AxisScores, AxisScores>? = null,
        otherUserAxisScores: Pair<AxisScores, AxisScores>? = null
    ): CompatibilityScore {
        val breakdown = mutableMapOf<String, Double>()
        var total = 0.0

        val interests = interestsScore(
            currentUser.hobbies.orEmpty(),
            otherUser.hobbies.orEmpty()
        )
        breakdown["interests"] = interests
        total += interests

        val values = valuesScore(currentUserAxisScores, otherUserAxisScores)
        breakdown["values"] = values
        total += values

        val goals = goalsScore(currentUser.goalsList, otherUser.goalsList)
        breakdown["goals"] = goals
        total += goals

        val age = if (currentUser.age != null && otherUser.age != null) {
            ageScore(currentUser.age, otherUser.age)
        } else {
            NEUTRAL_AGE
        }
        breakdown["age"] = age
        total += age

        // Distance is a flat allowance: the app has never scored it.
        breakdown["distance"] = FLAT_DISTANCE
        total += FLAT_DISTANCE

        return CompatibilityScore(total = min(100.0, total).toInt(), breakdown = breakdown)
    }

    /** Jaccard similarity over hobbies, scaled to 0–40. */
    private fun interestsScore(userHobbies: List<String>, otherHobbies: List<String>): Double {
        if (userHobbies.isEmpty() || otherHobbies.isEmpty()) return NEUTRAL_INTERESTS

        val mine = userHobbies.map { it.lowercase() }.toSet()
        val theirs = otherHobbies.map { it.lowercase() }.toSet()
        val union = mine.union(theirs).size
        if (union == 0) return NEUTRAL_INTERESTS

        val similarity = mine.intersect(theirs).size.toDouble() / union
        return min(40.0, similarity * 80.0)
    }

    /**
     * How well my Bring pattern answers their Need pattern and vice versa,
     * averaged and scaled to 0–30.
     */
    private fun valuesScore(
        mine: Pair<AxisScores, AxisScores>?,
        theirs: Pair<AxisScores, AxisScores>?
    ): Double {
        if (mine == null || theirs == null) return NEUTRAL_VALUES
        val (myNeed, myBring) = mine
        val (theirNeed, theirBring) = theirs
        if (myNeed.isZero || myBring.isZero || theirNeed.isZero || theirBring.isZero) {
            return NEUTRAL_VALUES
        }

        val avgCosine =
            (AxisScores.cosine(myNeed, theirBring) + AxisScores.cosine(myBring, theirNeed)) / 2.0
        // Cosine on non-negative vectors is in [0, 1] -> scale to 0...30.
        return maxOf(0.0, avgCosine) * 30.0
    }

    /** Even one shared goal is significant, so this is a step function. */
    private fun goalsScore(userGoals: List<String>, otherGoals: List<String>): Double {
        if (userGoals.isEmpty() || otherGoals.isEmpty()) return NEUTRAL_GOALS

        val shared = userGoals.map { it.lowercase() }.toSet()
            .intersect(otherGoals.map { it.lowercase() }.toSet())
            .size

        return when (shared) {
            0 -> 0.0
            1 -> 10.0
            else -> 15.0
        }
    }

    private fun ageScore(userAge: Int, otherAge: Int): Double =
        when (abs(userAge - otherAge)) {
            in 0..2 -> 10.0
            in 3..5 -> 7.0
            in 6..10 -> 4.0
            else -> 2.0
        }

    /** Profiles sorted by score, highest first. */
    fun rankProfiles(
        currentUser: UserProfile,
        profiles: List<UserProfile>
    ): List<Pair<UserProfile, CompatibilityScore>> =
        profiles
            .map { it to calculateCompatibility(currentUser, it) }
            .sortedByDescending { it.second.total }

    fun valueOverlap(
        myNeeds: List<Value>,
        myBrings: List<Value>,
        theirNeeds: List<Value>,
        theirBrings: List<Value>
    ): ValueOverlap {
        val myNeedIds = myNeeds.map { it.id }.toSet()
        val theirNeedIds = theirNeeds.map { it.id }.toSet()
        return ValueOverlap(
            theyBringForMyNeeds = theirBrings.filter { myNeedIds.contains(it.id) },
            iBringForTheirNeeds = myBrings.filter { theirNeedIds.contains(it.id) }
        )
    }

    /**
     * The axis where the weaker of (my bring, their need) is strongest — the
     * strongest mutual alignment rather than the loudest single voice.
     */
    fun topSharedAxis(myBring: AxisScores, theirNeed: AxisScores): ValueAxis? {
        val top = ValueAxis.entries
            .map { axis -> axis to min(myBring.value(axis), theirNeed.value(axis)) }
            .maxByOrNull { it.second }
            ?: return null

        return if (top.second > 0) top.first else null
    }

    /**
     * One- or two-sentence summary of how two people line up. Template-driven,
     * no model call — same sentences as iOS, chosen in the same order.
     */
    fun compatibilityBlurb(
        otherName: String,
        bringCosine: Double,
        needCosine: Double,
        topSharedAxis: ValueAxis?,
        overlap: ValueOverlap,
        myNeedsCount: Int
    ): String {
        val strongAlignment = (bringCosine + needCosine) / 2.0 >= STRONG_ALIGNMENT
        val theyForMe = overlap.theyBringForMyNeeds.size

        if (topSharedAxis != null && strongAlignment && theyForMe > 0) {
            return "You and $otherName share a strong foundation around " +
                "${topSharedAxis.displayName} — and what they bring lines up with " +
                "$theyForMe of your $myNeedsCount needs."
        }
        if (topSharedAxis != null && strongAlignment) {
            return "You and $otherName share a strong foundation around " +
                "${topSharedAxis.displayName}."
        }
        if (theyForMe > 0) {
            return "$otherName brings $theyForMe of your $myNeedsCount selected needs."
        }
        return "Your value patterns differ — sometimes that's where growth starts."
    }

    // Neutral fallbacks, verbatim from the Swift source.
    private const val NEUTRAL_INTERESTS = 20.0
    private const val NEUTRAL_VALUES = 15.0
    private const val NEUTRAL_GOALS = 7.5
    private const val NEUTRAL_AGE = 5.0
    private const val FLAT_DISTANCE = 5.0
    private const val STRONG_ALIGNMENT = 0.6
}
