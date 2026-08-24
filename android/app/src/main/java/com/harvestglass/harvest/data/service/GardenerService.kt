package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.GardenerMessage
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Mirrors the chat half of Harvest/Services/GardenerService.swift.
 *
 * The daily quiz and the screenshot-review flow are not ported here — see the
 * verification checklist.
 */
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

    companion object {
        private const val HISTORY_WINDOW = 10

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
