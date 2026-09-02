package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.DailyQuiz
import com.harvestglass.harvest.data.model.GardenerMessage
import com.harvestglass.harvest.data.model.QuizCategory
import com.harvestglass.harvest.data.model.QuizOption
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import kotlin.math.absoluteValue

/** Mirrors Harvest/Services/GardenerService.swift. */
class GardenerService(
    private val client: SupabaseClient,
    private val openAI: OpenAIService
) {

    @Serializable
    private data class HistoryRow(
        val id: String,
        @SerialName("user_id") val userId: String,
        val sender: String,
        val message: String,
        @SerialName("created_at") val createdAt: String? = null
    )

    /**
     * The Gardener chat is ephemeral: each message is removed 24h after it was
     * sent. This purges the caller's expired rows too — a server cron covers
     * users who never reopen the chat.
     */
    suspend fun getChatHistory(userId: String): List<GardenerMessage> {
        val cutoff = Instant.now().minus(24, ChronoUnit.HOURS).toString()

        runCatching {
            client.postgrest.from("gardener_chat_history").delete {
                filter {
                    eq("user_id", userId)
                    lt("created_at", cutoff)
                }
            }
        }

        return client.postgrest.from("gardener_chat_history")
            .select {
                filter {
                    eq("user_id", userId)
                    gte("created_at", cutoff)
                }
                order("created_at", Order.ASCENDING)
            }
            .decodeList<HistoryRow>()
            .map { row ->
                GardenerMessage(
                    id = row.id,
                    userId = row.userId,
                    role = if (row.sender == "gardener") "assistant" else "user",
                    content = row.message,
                    createdAt = row.createdAt
                )
            }
    }

    /**
     * Sends a message and returns the reply.
     *
     * A failed OpenAI call falls back to a canned line rather than surfacing an
     * error — the Gardener is a companion, and "something went wrong" is a
     * worse answer than a gentle prompt. Persistence failures are likewise
     * swallowed: losing the transcript should not lose the reply.
     */
    suspend fun sendMessage(
        userId: String,
        message: String,
        history: List<GardenerMessage>
    ): String {
        val chatMessages = buildList {
            add(OpenAIService.ChatMessage("system", SYSTEM_PROMPT))
            history.takeLast(HISTORY_WINDOW).forEach { msg ->
                add(
                    OpenAIService.ChatMessage(
                        role = if (msg.role == "assistant") "assistant" else "user",
                        content = msg.content
                    )
                )
            }
            add(OpenAIService.ChatMessage("user", message))
        }

        val raw = runCatching {
            openAI.sendChat(messages = chatMessages, temperature = 0.55, maxTokens = 280)
        }.getOrElse { FALLBACK_RESPONSES.random() }

        val response = GardenerFormatter.format(raw)
        val now = Instant.now().toString()

        runCatching { persist(userId, "user", message, now) }
        runCatching { persist(userId, "gardener", response, now) }

        return response
    }

    /**
     * Sends images for review. They are passed inline as data URLs and never
     * stored; only [userTurn] and the reply are written to chat history.
     *
     * [userTurn] is the exact text to persist as the user's turn, and is the
     * caller's to compose: a fresh review passes
     * [screenshotPlaceholder]`(caption, count)`, a follow-up about images
     * already in hand passes the plain question. Composing it here would file
     * every follow-up as another camera-prefixed review.
     *
     * Throws on transport failure — a user must never be told their
     * screenshot was invalid because the network dropped.
     */
    suspend fun sendImages(
        userId: String,
        imageDataUrls: List<String>,
        caption: String,
        userTurn: String,
        history: List<GardenerMessage>
    ): String {
        val trimmedCaption = caption.trim()

        val chatMessages = buildList {
            add(OpenAIService.ChatMessage("system", IMAGE_SYSTEM_PROMPT))
            history.takeLast(SCREENSHOT_HISTORY_WINDOW).forEach { msg ->
                add(
                    OpenAIService.ChatMessage(
                        role = if (msg.role == "assistant") "assistant" else "user",
                        content = msg.content
                    )
                )
            }
            add(OpenAIService.ChatMessage(role = "user", parts = imageParts(trimmedCaption, imageDataUrls)))
        }

        val raw = openAI.sendChat(messages = chatMessages, temperature = 0.4, maxTokens = 700)
        val response = resolveReply(raw)

        val now = Instant.now().toString()
        runCatching { persist(userId, "user", userTurn, now) }
        runCatching { persist(userId, "gardener", response, now) }

        return response
    }

    /** Characters this user has spent on Gardener chat since midnight. */
    suspend fun getTodayCharacterUsage(userId: String): Int {
        val startOfDay = LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant().toString()

        return client.postgrest.from("gardener_chat_history")
            .select(Columns.list("message")) {
                filter {
                    eq("user_id", userId)
                    eq("sender", "user")
                    gte("created_at", startOfDay)
                }
            }
            .decodeList<ChatContentRow>()
            .sumOf { it.message.length }
    }

    /** Today's quiz, creating the tracking row if this is the first open today. */
    suspend fun generateDailyQuiz(userId: String): DailyQuiz? {
        todayQuiz(userId)?.let { return it }

        val questions = fetchQuestionBank()
        if (questions.isEmpty()) return null

        val question = selectQuestion(questions, userId)

        val tracking = client.postgrest.from("gardener_daily_quiz_tracking").insert(
            buildJsonObject {
                put("user_id", userId)
                put("quiz_date", LocalDate.now().toString())
                put("question_id", question.id)
                put("shown_at", Instant.now().toString())
                put("answered", false)
            }
        ) {
            select()
        }
            .decodeList<QuizTrackingRow>()
            .firstOrNull()
            ?: return null

        return makeQuiz(question, tracking, response = null)
    }

    suspend fun hasQuizToday(userId: String): Boolean = todayQuiz(userId) != null

    /**
     * Records the chosen option and marks today's tracking row answered.
     *
     * The answer has to match one of the quiz's own options — a value that
     * isn't in the list would write a response no question can explain.
     */
    suspend fun saveQuizAnswer(userId: String, quiz: DailyQuiz, answer: String) {
        val option = quiz.options.firstOrNull { it.text == answer }
            ?: throw IllegalArgumentException("Quiz answer does not match available options")

        val now = Instant.now().toString()
        val existing = client.postgrest.from("gardener_quiz_responses")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("question_id", quiz.questionId)
                }
            }
            .decodeList<QuizResponseRow>()

        if (existing.isEmpty()) {
            client.postgrest.from("gardener_quiz_responses").insert(
                buildJsonObject {
                    put("user_id", userId)
                    put("question_id", quiz.questionId)
                    put("selected_option_id", option.id)
                    put("selected_value", option.text)
                    put("answered_at", now)
                }
            )
        } else {
            client.postgrest.from("gardener_quiz_responses").update(
                buildJsonObject {
                    put("selected_option_id", option.id)
                    put("selected_value", option.text)
                    put("answered_at", now)
                }
            ) {
                filter { eq("id", existing[0].id) }
            }
        }

        client.postgrest.from("gardener_daily_quiz_tracking").update(
            buildJsonObject { put("answered", true) }
        ) {
            filter { eq("id", quiz.trackingId) }
        }
    }

    private suspend fun todayQuiz(userId: String): DailyQuiz? {
        val tracking = client.postgrest.from("gardener_daily_quiz_tracking")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("quiz_date", LocalDate.now().toString())
                }
                order("shown_at", Order.DESCENDING)
                limit(1)
            }
            .decodeList<QuizTrackingRow>()
            .firstOrNull()
            ?: return null

        val question = fetchQuestion(tracking.questionId) ?: return null
        val response = fetchQuizResponse(userId, tracking.questionId)
        return makeQuiz(question, tracking, response)
    }

    private suspend fun fetchQuestionBank(): List<QuizQuestionRow> =
        client.postgrest.from("gardener_quiz_questions")
            .select { order("created_at", Order.ASCENDING) }
            .decodeList()

    private suspend fun fetchQuestion(id: String): QuizQuestionRow? =
        client.postgrest.from("gardener_quiz_questions")
            .select {
                filter { eq("id", id) }
                limit(1)
            }
            .decodeList<QuizQuestionRow>()
            .firstOrNull()

    private suspend fun fetchQuizResponse(userId: String, questionId: String): QuizResponseRow? =
        client.postgrest.from("gardener_quiz_responses")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("question_id", questionId)
                }
                order("answered_at", Order.DESCENDING)
                limit(1)
            }
            .decodeList<QuizResponseRow>()
            .firstOrNull()

    private fun makeQuiz(
        question: QuizQuestionRow,
        tracking: QuizTrackingRow,
        response: QuizResponseRow?
    ) = DailyQuiz(
        id = tracking.id,
        trackingId = tracking.id,
        questionId = question.id,
        question = question.question,
        options = question.optionValues(),
        category = QuizCategory.fromRaw(question.category),
        selectedAnswer = response?.selectedValue,
        insight = null,
        shownAt = tracking.shownAt,
        isAnswered = tracking.answered
    )

    private suspend fun persist(userId: String, sender: String, message: String, at: String) {
        client.postgrest.from("gardener_chat_history").insert(
            buildJsonObject {
                put("user_id", userId)
                put("sender", sender)
                put("message", message)
                put("created_at", at)
            }
        )
    }

    @Serializable
    private data class ChatContentRow(val message: String)

    @Serializable
    private data class QuizTrackingRow(
        val id: String,
        @SerialName("user_id") val userId: String,
        @SerialName("quiz_date") val quizDate: String,
        @SerialName("question_id") val questionId: String,
        @SerialName("shown_at") val shownAt: String? = null,
        val answered: Boolean = false
    )

    @Serializable
    private data class QuizResponseRow(
        val id: String,
        @SerialName("user_id") val userId: String,
        @SerialName("question_id") val questionId: String,
        @SerialName("selected_option_id") val selectedOptionId: String,
        @SerialName("selected_value") val selectedValue: String,
        @SerialName("answered_at") val answeredAt: String? = null
    )

    @Serializable
    private data class QuizQuestionRow(
        val id: String,
        val question: String,
        val category: String,
        /**
         * Options are stored either as bare strings or as {id, text} objects,
         * so they decode loosely and [optionValues] normalises them.
         */
        val options: List<JsonElement> = emptyList()
    ) {
        fun optionValues(): List<QuizOption> =
            options.mapIndexed { index, element ->
                val obj = element as? JsonObject
                val text = obj?.get("text")?.jsonPrimitive?.content
                    ?: (element as? JsonPrimitive)?.takeIf { it.isString }?.content
                QuizOption(
                    id = obj?.get("id")?.jsonPrimitive?.content ?: "option_$index",
                    text = text.orEmpty()
                )
            }.filter { it.text.isNotEmpty() }
    }

    companion object {
        private const val HISTORY_WINDOW = 10
        private const val SCREENSHOT_HISTORY_WINDOW = 6

        const val REFUSE_SENTINEL = "REFUSE_EXPLICIT"

        /**
         * Shown verbatim when the model refuses. Fixed in the app rather than
         * written by the model so the promise is worded identically every
         * time, and so it invites a retry — the judgement is the model's and
         * will occasionally be wrong.
         */
        val EXPLICIT_REFUSAL_REPLY = """
            I can't give you a read on that one — it looks explicit, and that's outside what I can coach on.

            Send me a conversation, a profile, or anything else you'd like a view on and I'll take a proper look.
        """.trimIndent()

        /** iOS composes the same placeholder, and both stores read it back. */
        fun screenshotPlaceholder(caption: String, imageCount: Int): String {
            val noun = if (imageCount > 1) "$imageCount screenshots" else "Screenshot"
            return if (caption.isEmpty()) "\uD83D\uDCF7 $noun" else "\uD83D\uDCF7 $noun — $caption"
        }

        /** The user turn: the question first, then every image in selection order. */
        fun imageParts(
            caption: String,
            imageDataUrls: List<String>
        ): List<OpenAIService.ContentPart> = buildList {
            val trimmed = caption.trim()
            if (trimmed.isNotEmpty()) add(OpenAIService.ContentPart.Text(trimmed))
            imageDataUrls.forEach { add(OpenAIService.ContentPart.ImageUrl(it)) }
        }

        /**
         * The model's reply, or our own copy when it refused. Compared against
         * the whole trimmed reply, not searched for: the sentinel appearing
         * inside a sentence is prose, not a refusal.
         */
        fun resolveReply(raw: String): String =
            if (raw.trim() == REFUSE_SENTINEL) EXPLICIT_REFUSAL_REPLY
            else GardenerFormatter.format(raw)

        private val IMAGE_SYSTEM_PROMPT = """
            You are The Gardener, a warm and insightful AI dating coach for the Harvest dating app.

            The user has attached one or more images and may have asked a question about them.

            If they asked a question, ANSWER THAT QUESTION. Ground every claim in what is
            actually visible in the images. Do not substitute general dating advice for the
            thing they asked.

            Several images are one continuous piece of context — usually consecutive
            screenshots of the same conversation, in the order given. Read them as a whole.

            If they asked nothing, give your read: what you notice, then what to do about it.

            Whatever you are looking at — a chat thread, a dating profile, a bio, a photo —
            respond to it as a coach would.

            - Never invent messages or details that aren't visible.
            - Be specific about tone and what the other person appears to be signalling.
            - Keep it concise: short paragraphs of 1-3 sentences, blank line between each.
            - Never give medical or legal advice. If it shows distress, abuse, or risk,
              name that clearly and encourage professional or trusted human support.

            If ANY image is sexually explicit or graphic, reply with exactly REFUSE_EXPLICIT
            and nothing else — no explanation, no other text.
        """.trimIndent()

        /**
         * Picks the same question for the same user, as Swift's
         * `abs(userId.hashValue) % questions.count` does.
         */
        internal fun <T> selectQuestion(questions: List<T>, userId: String): T =
            questions[userId.hashCode().absoluteValue % questions.size]

        const val WELCOME_MESSAGE =
            "Welcome to The Gardener! I'm your personal dating coach, here to help you " +
                "grow authentic connections. Think of me as the friend who always gives " +
                "you the honest (but kind) truth about your dating life. What's on your " +
                "mind today?"

        private val SYSTEM_PROMPT = """
            You are The Gardener, a warm and insightful AI dating coach for the Harvest dating app.
            Give clear, practical, emotionally intelligent advice.
            Priorities:
            - Answer the user's actual question directly in the first 1-2 sentences.
            - Be specific and useful, not vague or overly poetic.
            - Use warmth and empathy, but avoid filler, generic platitudes, or forced gardening metaphors.
            - When helpful, give 2-4 concrete suggestions, examples, or next steps.
            - Ask at most one follow-up question, and only if it meaningfully helps.
            - Keep the response concise: usually 1 short paragraph or a short paragraph plus bullets.
            - Break longer replies into short paragraphs of 1-3 sentences, with a blank line between each thought.
            - Never give medical or legal advice. If someone expresses distress or risk, encourage professional or trusted human support.
        """.trimIndent()

        private val FALLBACK_RESPONSES = listOf(
            "Every connection starts with a single seed of courage. What's on your mind today?",
            "Growth takes time, and that's perfectly okay. I'm here whenever you need to talk about your dating journey.",
            "Remember, the strongest relationships grow from authentic roots. How can I help you cultivate yours?",
            "Sometimes the best thing we can do is pause, reflect, and tend to our own garden before reaching out to others.",
            "Dating can feel overwhelming at times. Let's break it down together - what specific challenge are you facing?",
            "The best relationships bloom when both people are willing to be vulnerable. What does vulnerability look like for you?",
            "A healthy relationship is like a well-tended garden - it needs sunlight, water, and patience. Which of those feels hardest for you right now?",
            "One thing I've learned: the way someone treats a server or barista tells you more than any dating profile ever could.",
            "Compatibility isn't about finding someone identical to you - it's about finding someone whose differences complement your strengths.",
            "Before you can grow with someone else, it helps to know what season you're in yourself. How would you describe where you are right now?",
            "Trust your gut. If something feels off, it probably is. What's your instinct telling you?",
            "Great conversations start with genuine curiosity. Try asking your match about something they're passionate about - you might be surprised.",
            "Rejection isn't a reflection of your worth - it's just a sign that particular garden wasn't meant to grow. What other seeds have you planted?",
            "Setting boundaries isn't selfish - it's essential. Healthy roots need firm soil. Is there a boundary you've been hesitant to set?",
            "Remember: you're not just looking for someone to like you. You're looking for someone you genuinely like too. What qualities matter most to you?"
        )
    }
}
