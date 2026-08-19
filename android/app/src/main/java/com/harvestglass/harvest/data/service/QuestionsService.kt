package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.QuestionOption
import com.harvestglass.harvest.data.model.QuestionWeighting
import com.harvestglass.harvest.data.model.UserQuestionAnswer
import com.harvestglass.harvest.data.model.ValueAxis
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Mirrors Harvest/Services/QuestionsService.swift. */
class QuestionsService(private val client: SupabaseClient) {

    /**
     * The full question pool, options included. Falls back to the built-in
     * bank on DB error or an empty result, mirroring ValuesService.
     */
    suspend fun getAllQuestions(): List<Question> {
        val fromDb = runCatching {
            client.postgrest.from("questions")
                .select(
                    Columns.raw("id, prompt, weighting, display_order, options:question_options(*)")
                ) {
                    order("display_order", Order.ASCENDING)
                }
                .decodeList<Question>()
        }.getOrNull()

        val questions = if (!fromDb.isNullOrEmpty()) fromDb else DEFAULT_QUESTIONS
        return questions.map { q -> q.copy(options = q.options.sortedBy { it.displayOrder }) }
    }

    /** questionId -> optionId for the given user. */
    suspend fun getUserAnswers(userId: String): Map<String, String> =
        client.postgrest.from("user_question_answers")
            .select(Columns.raw("user_id, question_id, option_id")) {
                filter { eq("user_id", userId) }
            }
            .decodeList<UserQuestionAnswer>()
            .associate { it.questionId to it.optionId }

    suspend fun saveAnswer(userId: String, questionId: String, optionId: String) {
        client.postgrest.from("user_question_answers").upsert(
            buildJsonObject {
                put("user_id", userId)
                put("question_id", questionId)
                put("option_id", optionId)
            }
        ) { onConflict = "user_id,question_id" }
    }

    suspend fun saveAnswers(userId: String, answers: Map<String, String>) {
        if (answers.isEmpty()) return
        val rows = answers.map { (questionId, optionId) ->
            buildJsonObject {
                put("user_id", userId)
                put("question_id", questionId)
                put("option_id", optionId)
            }
        }
        client.postgrest.from("user_question_answers")
            .upsert(rows) { onConflict = "user_id,question_id" }
    }

    companion object {

        private fun makeQuestion(
            id: String,
            prompt: String,
            weighting: QuestionWeighting,
            options: List<Triple<String, String, ValueAxis>>
        ): Question = Question(
            id = id,
            prompt = prompt,
            weighting = weighting,
            displayOrder = id.drop(1).toIntOrNull() ?: 0,   // "q3" -> 3
            options = options.mapIndexed { i, (suffix, label, axis) ->
                QuestionOption(
                    id = "${id}_$suffix",
                    questionId = id,
                    label = label,
                    axis = axis,
                    displayOrder = i
                )
            }
        )

        /**
         * Built-in fallback bank.
         *
         * Onboarding presents only Q1–Q10, so only those are ported here. The
         * deep-dive pool (Q11–Q35) is reached from the Values tab and lands
         * with that screen in P2b — porting it now would be data no P2a code
         * path can reach.
         */
        val DEFAULT_QUESTIONS: List<Question> = listOf(
            // Onboarding (Q1-Q10): 5 NEED, 5 BRING
            makeQuestion(
                id = "q1",
                prompt = "After a hard day, what would help you feel most cared for?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They really listen before responding.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They stay calm and steady with me.", ValueAxis.STABILITY),
                    Triple("c", "They are honest, respectful, and present with what I am feeling.", ValueAxis.INTEGRITY),
                    Triple("d", "They pull me close and make time for me.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q2",
                prompt = "Someone disappoints you. What helps repair the moment most?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They understand why it hurt.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They show up more consistently afterward.", ValueAxis.STABILITY),
                    Triple("c", "They own their part clearly.", ValueAxis.INTEGRITY),
                    Triple("d", "They reflect on what happened and try to grow from it.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q3",
                prompt = "Someone you care about is stressed. What feels most natural for you to offer?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I help them feel understood.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I help steady the situation.", ValueAxis.STABILITY),
                    Triple("c", "I offer warmth, affection, or closeness.", ValueAxis.CONNECTION),
                    Triple("d", "I encourage their next step forward.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q4",
                prompt = "When conflict happens, what do you naturally try to bring into the moment?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to understand what the other person is really feeling.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I try to own my part honestly.", ValueAxis.INTEGRITY),
                    Triple("c", "I try to protect the bond and come back toward closeness.", ValueAxis.CONNECTION),
                    Triple("d", "I try to learn from it and find a better way forward.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q5",
                prompt = "You are starting to trust someone. What makes that trust grow most for you?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "Their energy stays steady over time.", ValueAxis.STABILITY),
                    Triple("b", "Their actions match their words.", ValueAxis.INTEGRITY),
                    Triple("c", "You feel wanted and close.", ValueAxis.CONNECTION),
                    Triple("d", "You can see shared direction and growth.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q6",
                prompt = "When you picture what you bring to long-term love, what feels most true?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I bring emotional care and understanding.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I bring steadiness and dependability.", ValueAxis.STABILITY),
                    Triple("c", "I bring honesty, loyalty, and respect.", ValueAxis.INTEGRITY),
                    Triple("d", "I bring warmth, affection, and connection.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q7",
                prompt = "You are nervous before something important. What kind of support would help most?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They notice how I am feeling and comfort me.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They help me feel grounded and steady.", ValueAxis.STABILITY),
                    Triple("c", "They help me face the situation honestly.", ValueAxis.INTEGRITY),
                    Triple("d", "They remind me what I am capable of.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q8",
                prompt = "When you realize you may have hurt or disappointed someone, what do you most want to do?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I want to understand how it affected them.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I want to show up better and be more consistent.", ValueAxis.STABILITY),
                    Triple("c", "I want to reconnect and help them feel cared for.", ValueAxis.CONNECTION),
                    Triple("d", "I want to reflect, adjust, and grow from it.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q9",
                prompt = "What makes you feel respected in a relationship?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They consider my feelings.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They honor my boundaries.", ValueAxis.INTEGRITY),
                    Triple("c", "They make space for me in their life.", ValueAxis.CONNECTION),
                    Triple("d", "They take my goals seriously.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q10",
                prompt = "During a quiet evening together, what do you most naturally hope to bring?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "A peaceful, steady presence.", ValueAxis.STABILITY),
                    Triple("b", "A space where honesty feels safe.", ValueAxis.INTEGRITY),
                    Triple("c", "Warmth, closeness, or playfulness.", ValueAxis.CONNECTION),
                    Triple("d", "Meaningful conversation about dreams, purpose, or direction.", ValueAxis.GROWTH)
                )
            )
        )
    }
}
