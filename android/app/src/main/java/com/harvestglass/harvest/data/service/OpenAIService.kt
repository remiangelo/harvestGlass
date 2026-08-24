package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Chat completions, proxied through the `openai-chat` Edge Function.
 *
 * The OpenAI key lives on the server — the client never holds it, which is
 * why this ports to Android with no secret handling at all. Mirrors
 * Harvest/Services/OpenAIService.swift.
 */
class OpenAIService(private val client: SupabaseClient) {

    @Serializable
    data class ChatMessage(val role: String, val content: String)

    @Serializable
    private data class ChatRequest(
        val model: String,
        val messages: List<ChatMessage>,
        val temperature: Double,
        @SerialName("max_tokens") val maxTokens: Int
    )

    @Serializable
    private data class ChatResponse(val choices: List<Choice> = emptyList()) {
        @Serializable
        data class Choice(val message: ChatMessage? = null)
    }

    suspend fun sendChat(
        messages: List<ChatMessage>,
        model: String = DEFAULT_MODEL,
        temperature: Double = 0.7,
        maxTokens: Int = 500
    ): String {
        val session = client.auth.currentSessionOrNull()
            ?: throw IllegalStateException("Not authenticated")

        val response = client.httpClient.post("${Config.SUPABASE_URL}/functions/v1/openai-chat") {
            header("Authorization", "Bearer ${session.accessToken}")
            header("apikey", Config.SUPABASE_ANON_KEY)
            contentType(ContentType.Application.Json)
            setBody(ChatRequest(model, messages, temperature, maxTokens))
        }

        if (!response.status.isSuccess()) {
            throw IllegalStateException("openai-chat failed with ${response.status.value}")
        }

        val decoded = JSON.decodeFromString<ChatResponse>(response.bodyAsText())
        return decoded.choices.firstOrNull()?.message?.content
            ?: throw IllegalStateException("openai-chat returned no message")
    }

    companion object {
        private const val DEFAULT_MODEL = "gpt-4o-mini"
        private val JSON = Json { ignoreUnknownKeys = true }
    }
}
