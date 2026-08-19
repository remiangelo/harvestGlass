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
         * Built-in fallback bank, used when the `questions` table is empty or
         * unreachable. Q1–Q10 are what onboarding presents; Q11–Q35 are the
         * deep-dive pool reached from the Values tab.
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
            ),

            // Deep-dive (Q11-Q35): 12 NEED, 12 BRING, 1 BOTH
            makeQuestion(
                id = "q11",
                prompt = "Someone shares something vulnerable with you. What do you naturally try to offer?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to understand what they are feeling.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I stay steady and present with them.", ValueAxis.STABILITY),
                    Triple("c", "I treat their honesty with respect.", ValueAxis.INTEGRITY),
                    Triple("d", "I move closer emotionally so they do not feel alone.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q12",
                prompt = "Plans change at the last minute. What matters most to you?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They care how the change affects me.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They communicate early and follow through later.", ValueAxis.STABILITY),
                    Triple("c", "They handle the change with respect.", ValueAxis.INTEGRITY),
                    Triple("d", "They try to handle it better next time.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q13",
                prompt = "You feel misunderstood. What helps most?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They ask questions before assuming.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They keep the conversation calm.", ValueAxis.STABILITY),
                    Triple("c", "They speak plainly and fairly.", ValueAxis.INTEGRITY),
                    Triple("d", "They reassure me through closeness.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q14",
                prompt = "When you make a mistake, what do you naturally try to do afterward?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to understand the impact.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I try to show steadier behavior over time.", ValueAxis.STABILITY),
                    Triple("c", "I own my part clearly.", ValueAxis.INTEGRITY),
                    Triple("d", "I reflect on what I can learn from it.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q15",
                prompt = "When you imagine building a life with someone, what do you most need to feel secure?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They are dependable in daily life.", ValueAxis.STABILITY),
                    Triple("b", "They live by strong character.", ValueAxis.INTEGRITY),
                    Triple("c", "They keep closeness active.", ValueAxis.CONNECTION),
                    Triple("d", "They move toward purpose with me.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q16",
                prompt = "Someone you love is nervous before something important. What feels most natural for you to offer?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I notice what they are feeling and try to comfort them.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I help them face the moment honestly.", ValueAxis.INTEGRITY),
                    Triple("c", "I stay close and present.", ValueAxis.CONNECTION),
                    Triple("d", "I remind them what they are capable of.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q17",
                prompt = "What makes you feel respected?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They consider my feelings.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They treat my time with care.", ValueAxis.STABILITY),
                    Triple("c", "They honor my boundaries.", ValueAxis.INTEGRITY),
                    Triple("d", "They take my goals seriously.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q18",
                prompt = "When life gets stressful, what do you hope someone can count on you for?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to be emotionally aware and caring.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I try to stay steady under pressure.", ValueAxis.STABILITY),
                    Triple("c", "I try to act with character even when it is hard.", ValueAxis.INTEGRITY),
                    Triple("d", "I try to keep warmth alive between us.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q19",
                prompt = "You are excited about a personal goal. What response would mean the most?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They understand why it matters to me.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They help me stay grounded.", ValueAxis.STABILITY),
                    Triple("c", "They celebrate with me.", ValueAxis.CONNECTION),
                    Triple("d", "They encourage me toward my potential.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q20",
                prompt = "When attraction starts feeling more serious, what do you most want to bring into the connection?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I want to be emotionally present and aware.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I want my actions to reflect my character.", ValueAxis.INTEGRITY),
                    Triple("c", "I want the spark to feel mutual and alive.", ValueAxis.CONNECTION),
                    Triple("d", "I want to build toward something meaningful.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q21",
                prompt = "A conversation gets tense. What do you need most from the other person?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They listen beneath the words.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They keep the tone steady.", ValueAxis.STABILITY),
                    Triple("c", "They stay fair and truthful.", ValueAxis.INTEGRITY),
                    Triple("d", "They reach for closeness after.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q22",
                prompt = "What do you most naturally do to help someone feel chosen?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I remember what matters to them.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I try to show up consistently over time.", ValueAxis.STABILITY),
                    Triple("c", "I make real time for them.", ValueAxis.CONNECTION),
                    Triple("d", "I build toward the future with them.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q23",
                prompt = "You share a concern. What response builds the most confidence?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "They receive it with care.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "They answer honestly.", ValueAxis.INTEGRITY),
                    Triple("c", "They soften toward me.", ValueAxis.CONNECTION),
                    Triple("d", "They look for a better way forward.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q24",
                prompt = "What do you most want to be dependable for in a relationship?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "Doing what I said I would do.", ValueAxis.STABILITY),
                    Triple("b", "Handling responsibility with character.", ValueAxis.INTEGRITY),
                    Triple("c", "Continuing to invest in closeness.", ValueAxis.CONNECTION),
                    Triple("d", "Learning how to show up better over time.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q25",
                prompt = "You are spending a quiet evening together. What feels most meaningful to you?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "The conversation feels emotionally real.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "The peace feels easy and steady.", ValueAxis.STABILITY),
                    Triple("c", "I feel safe being truthful.", ValueAxis.INTEGRITY),
                    Triple("d", "The closeness feels warm and natural.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q26",
                prompt = "When you are under pressure, what do you hope your character shows?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I still care about people's feelings.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I can remain steady.", ValueAxis.STABILITY),
                    Triple("c", "My values hold even when it is hard.", ValueAxis.INTEGRITY),
                    Triple("d", "I can respond, reflect, and grow.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q27",
                prompt = "What kind of apology means the most to you?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "One that shows they understand my heart.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "One that takes full ownership.", ValueAxis.INTEGRITY),
                    Triple("c", "One that brings us close again.", ValueAxis.CONNECTION),
                    Triple("d", "One that leads to new growth.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q28",
                prompt = "What do you most want to offer so someone feels free to be themselves?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to understand their emotions.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I treat their truth with respect.", ValueAxis.INTEGRITY),
                    Triple("c", "I enjoy their personality.", ValueAxis.CONNECTION),
                    Triple("d", "I give them room to become more fully themselves.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q29",
                prompt = "What makes love feel alive to you?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "Feeling safe in the rhythm.", ValueAxis.STABILITY),
                    Triple("b", "Feeling secure in trust.", ValueAxis.INTEGRITY),
                    Triple("c", "Feeling wanted, playful, and close.", ValueAxis.CONNECTION),
                    Triple("d", "Feeling inspired together.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q30",
                prompt = "When you disagree about something important, what do you naturally try to bring?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I try to care about their perspective.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I try to handle the disagreement with respect.", ValueAxis.INTEGRITY),
                    Triple("c", "I try to protect the bond while talking.", ValueAxis.CONNECTION),
                    Triple("d", "I try to search for a wiser path forward.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q31",
                prompt = "What makes someone feel like a safe long-term choice?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "Their emotional care feels real.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "Their patterns are dependable.", ValueAxis.STABILITY),
                    Triple("c", "Their character is clear.", ValueAxis.INTEGRITY),
                    Triple("d", "Their love feels warm and active.", ValueAxis.CONNECTION)
                )
            ),
            makeQuestion(
                id = "q32",
                prompt = "Shared spiritual or philosophical values feel meaningful when they shape what?",
                weighting = QuestionWeighting.BOTH,
                options = listOf(
                    Triple("a", "The way we make life decisions.", ValueAxis.STABILITY),
                    Triple("b", "The way we treat people.", ValueAxis.INTEGRITY),
                    Triple("c", "The depth of closeness between us.", ValueAxis.CONNECTION),
                    Triple("d", "The meaning we build together.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q33",
                prompt = "What makes you feel supportive in a relationship?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "I can sense what someone may need emotionally.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "I protect their dignity.", ValueAxis.INTEGRITY),
                    Triple("c", "I make them feel loved in real time.", ValueAxis.CONNECTION),
                    Triple("d", "I believe in where they are going.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q34",
                prompt = "What do you hope someone notices about what you bring?",
                weighting = QuestionWeighting.BRING,
                options = listOf(
                    Triple("a", "How deeply I care.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "How steady I try to be.", ValueAxis.STABILITY),
                    Triple("c", "How seriously I take trust.", ValueAxis.INTEGRITY),
                    Triple("d", "How much I am growing.", ValueAxis.GROWTH)
                )
            ),
            makeQuestion(
                id = "q35",
                prompt = "When you imagine healthy love, what feels most like home?",
                weighting = QuestionWeighting.NEED,
                options = listOf(
                    Triple("a", "Being understood with care.", ValueAxis.EMOTIONAL_INTELLIGENCE),
                    Triple("b", "Feeling steady and safe.", ValueAxis.STABILITY),
                    Triple("c", "Feeling close, wanted, and joyful.", ValueAxis.CONNECTION),
                    Triple("d", "Growing into something meaningful together.", ValueAxis.GROWTH)
                )
            )
        )
    }
}
