package com.harvestglass.harvest.data.model

import kotlinx.serialization.Serializable

/** Mirrors QuizCategory in Harvest/Models/DailyQuiz.swift. */
@Serializable
enum class QuizCategory(val raw: String) {
    DATING_STYLE("dating_style"),
    VALUES("values"),
    COMMUNICATION("communication"),
    RELATIONSHIP_GOALS("relationship_goals"),
    PERSONALITY("personality");

    companion object {
        /** Unknown categories fall back to dating style, as Swift's `?? .datingStyle` does. */
        fun fromRaw(raw: String?): QuizCategory =
            entries.firstOrNull { it.raw == raw } ?: DATING_STYLE
    }
}

@Serializable
data class QuizOption(val id: String, val text: String)

/** Mirrors DailyQuiz in Harvest/Models/DailyQuiz.swift. */
data class DailyQuiz(
    val id: String,
    val trackingId: String,
    val questionId: String,
    val question: String,
    val options: List<QuizOption>,
    val category: QuizCategory,
    val selectedAnswer: String? = null,
    val insight: String? = null,
    val shownAt: String? = null,
    val isAnswered: Boolean = false
)
