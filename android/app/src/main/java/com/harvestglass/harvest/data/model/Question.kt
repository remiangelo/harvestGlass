package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.sqrt

/** Mirrors Harvest/Models/Question.swift. */
@Serializable
enum class ValueAxis(val serialName: String, val displayName: String) {
    @SerialName("emotional_intelligence")
    EMOTIONAL_INTELLIGENCE("emotional_intelligence", "Emotional Intelligence"),

    @SerialName("stability")
    STABILITY("stability", "Stability"),

    @SerialName("integrity")
    INTEGRITY("integrity", "Integrity"),

    @SerialName("connection")
    CONNECTION("connection", "Connection"),

    @SerialName("growth")
    GROWTH("growth", "Growth")
}

@Serializable
enum class QuestionWeighting {
    @SerialName("need") NEED,
    @SerialName("bring") BRING,
    @SerialName("both") BOTH
}

@Serializable
data class QuestionOption(
    val id: String,
    @SerialName("question_id") val questionId: String,
    val label: String,
    val axis: ValueAxis,
    @SerialName("display_order") val displayOrder: Int
)

@Serializable
data class Question(
    val id: String,
    val prompt: String,
    val weighting: QuestionWeighting,
    @SerialName("display_order") val displayOrder: Int,
    val options: List<QuestionOption> = emptyList()
)

@Serializable
data class UserQuestionAnswer(
    @SerialName("user_id") val userId: String,
    @SerialName("question_id") val questionId: String,
    @SerialName("option_id") val optionId: String
)

/**
 * A five-axis score vector.
 *
 * Swift declares these `var` and mutates in place; here [add] returns a copy so
 * the type stays a value with no shared-mutation hazards.
 */
data class AxisScores(
    val emotionalIntelligence: Double = 0.0,
    val stability: Double = 0.0,
    val integrity: Double = 0.0,
    val connection: Double = 0.0,
    val growth: Double = 0.0
) {
    val sum: Double
        get() = emotionalIntelligence + stability + integrity + connection + growth

    val isZero: Boolean get() = sum == 0.0

    fun value(axis: ValueAxis): Double = when (axis) {
        ValueAxis.EMOTIONAL_INTELLIGENCE -> emotionalIntelligence
        ValueAxis.STABILITY -> stability
        ValueAxis.INTEGRITY -> integrity
        ValueAxis.CONNECTION -> connection
        ValueAxis.GROWTH -> growth
    }

    fun add(delta: Double, axis: ValueAxis): AxisScores = when (axis) {
        ValueAxis.EMOTIONAL_INTELLIGENCE -> copy(emotionalIntelligence = emotionalIntelligence + delta)
        ValueAxis.STABILITY -> copy(stability = stability + delta)
        ValueAxis.INTEGRITY -> copy(integrity = integrity + delta)
        ValueAxis.CONNECTION -> copy(connection = connection + delta)
        ValueAxis.GROWTH -> copy(growth = growth + delta)
    }

    fun normalized(): AxisScores {
        val total = sum
        if (total <= 0.0) return this
        return AxisScores(
            emotionalIntelligence = emotionalIntelligence / total,
            stability = stability / total,
            integrity = integrity / total,
            connection = connection / total,
            growth = growth / total
        )
    }

    companion object {
        /** Standard cosine similarity in [-1, 1]; 0 when either is a zero vector. */
        fun cosine(a: AxisScores, b: AxisScores): Double {
            val dot = a.emotionalIntelligence * b.emotionalIntelligence +
                a.stability * b.stability +
                a.integrity * b.integrity +
                a.connection * b.connection +
                a.growth * b.growth
            val magA = sqrt(
                a.emotionalIntelligence * a.emotionalIntelligence +
                    a.stability * a.stability +
                    a.integrity * a.integrity +
                    a.connection * a.connection +
                    a.growth * a.growth
            )
            val magB = sqrt(
                b.emotionalIntelligence * b.emotionalIntelligence +
                    b.stability * b.stability +
                    b.integrity * b.integrity +
                    b.connection * b.connection +
                    b.growth * b.growth
            )
            if (magA <= 0.0 || magB <= 0.0) return 0.0
            return dot / (magA * magB)
        }
    }
}

object AxisScoring {

    /**
     * (needSideWeight, bringSideWeight) for a question with the given weighting.
     * Pure NEED and pure BRING questions contribute to one side only;
     * BOTH splits evenly.
     */
    fun weights(weighting: QuestionWeighting): Pair<Double, Double> = when (weighting) {
        QuestionWeighting.NEED -> 2.0 to 0.0
        QuestionWeighting.BRING -> 0.0 to 2.0
        QuestionWeighting.BOTH -> 1.0 to 1.0
    }

    /**
     * The user's RAW (un-normalized) (need, bring) axis vectors — the actual
     * per-category point totals (0–28 possible per axis). The matching algorithm
     * and the radar's tiered display both work from these raw scores.
     */
    fun computeRawVectors(
        answers: Map<String, String>,   // questionId -> optionId
        questions: List<Question>
    ): Pair<AxisScores, AxisScores> {
        var rawNeed = AxisScores()
        var rawBring = AxisScores()
        val byId = questions.associateBy { it.id }

        answers.forEach { (questionId, optionId) ->
            val q = byId[questionId] ?: return@forEach
            val option = q.options.firstOrNull { it.id == optionId } ?: return@forEach
            val (needWeight, bringWeight) = weights(q.weighting)
            rawNeed = rawNeed.add(needWeight, option.axis)
            rawBring = rawBring.add(bringWeight, option.axis)
        }

        return rawNeed to rawBring
    }

    /** The user's normalized (need, bring) axis vectors. */
    fun computeVectors(
        answers: Map<String, String>,
        questions: List<Question>
    ): Pair<AxisScores, AxisScores> {
        val (need, bring) = computeRawVectors(answers, questions)
        return need.normalized() to bring.normalized()
    }
}

/**
 * Visual display tier for the values radar.
 *
 * The matching algorithm always works from raw category scores; the radar maps
 * each raw score (0–28 possible) into one of four tiers so the chart
 * communicates the *shape* of a values profile rather than plotting raw points.
 *
 * The Swift enum also carries an SF Symbol name; the Android radar picks its own
 * icons in P2b, so that property is deliberately not ported.
 */
enum class ValuesTier(
    val level: Int,
    val displayName: String,
    val rangeLabel: String,
    val ringLabel: String
) {
    LOW_PRESENCE(1, "Low Presence", "0 – 5", "1st ring"),
    GROWING_PRESENCE(2, "Growing Presence", "6 – 10", "2nd ring"),
    STRONG_PRESENCE(3, "Strong Presence", "11 – 17", "3rd ring"),
    CORE_VALUE(4, "Core Value", "18 – 28", "4th ring");

    /** "Level N" label. */
    val levelLabel: String get() = "Level $level"

    /** Position on the radar as a fraction of the full radius. */
    val radiusFraction: Double get() = level.toDouble() / entries.size.toDouble()

    companion object {
        fun fromRawScore(rawScore: Double): ValuesTier = when {
            rawScore < 6 -> LOW_PRESENCE
            rawScore < 11 -> GROWING_PRESENCE
            rawScore < 18 -> STRONG_PRESENCE
            else -> CORE_VALUE
        }
    }
}
