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
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * Chat completions, proxied through the `openai-chat` Edge Function.
 *
 * The OpenAI key lives on the server — the client never holds it, which is
 * why this ports to Android with no secret handling at all. Mirrors
 * Harvest/Services/OpenAIService.swift.
 */
class OpenAIService(private val client: SupabaseClient) {

    /** One piece of a message. A message is either all text, or text plus images. */
    sealed interface ContentPart {
        data class Text(val value: String) : ContentPart

        /** A `data:` or `https:` URL. */
        data class ImageUrl(val url: String) : ContentPart
    }

    /**
     * A chat message. Text-only messages encode `content` as a plain string,
     * exactly as before; a multipart message encodes it as OpenAI's array form.
     */
    data class ChatMessage(val role: String, val parts: List<ContentPart>) {
        constructor(role: String, content: String) : this(role, listOf(ContentPart.Text(content)))

        /** The text halves joined, for call sites that only ever send text. */
        val content: String
            get() = parts.filterIsInstance<ContentPart.Text>().joinToString("\n") { it.value }
    }

    suspend fun sendChat(
        messages: List<ChatMessage>,
        model: String = DEFAULT_MODEL,
        temperature: Double = 0.7,
        maxTokens: Int = 500
    ): String {
        val session = client.auth.currentSessionOrNull()
            ?: throw IllegalStateException("Not authenticated")

        val body = buildJsonObject {
            put("model", model)
            put("temperature", temperature)
            put("max_tokens", maxTokens)
            put("messages", JsonArray(messages.map { it.encode() }))
        }

        val response = client.httpClient.post("${Config.SUPABASE_URL}/functions/v1/openai-chat") {
            header("Authorization", "Bearer ${session.accessToken}")
            header("apikey", Config.SUPABASE_ANON_KEY)
            contentType(ContentType.Application.Json)
            setBody(body)
        }

        if (!response.status.isSuccess()) {
            throw IllegalStateException("openai-chat failed with ${response.status.value}")
        }

        return JSON.parseToJsonElement(response.bodyAsText())
            .jsonObject["choices"]
            ?.jsonArray
            ?.firstOrNull()
            ?.jsonObject
            ?.get("message")
            ?.jsonObject
            ?.get("content")
            ?.jsonPrimitive
            ?.content
            ?: throw IllegalStateException("openai-chat returned no message")
    }

    private fun ChatMessage.encode(): JsonElement = buildJsonObject {
        put("role", role)

        // A single text part encodes as a bare string — the shape every
        // pre-existing call site sent, and the one OpenAI expects for text.
        val only = parts.singleOrNull()
        if (only is ContentPart.Text) {
            put("content", only.value)
            return@buildJsonObject
        }

        put(
            "content",
            buildJsonArray {
                parts.forEach { part ->
                    add(
                        when (part) {
                            is ContentPart.Text -> buildJsonObject {
                                put("type", "text")
                                put("text", part.value)
                            }

                            is ContentPart.ImageUrl -> buildJsonObject {
                                put("type", "image_url")
                                put(
                                    "image_url",
                                    JsonObject(mapOf("url" to JsonPrimitive(part.url)))
                                )
                            }
                        }
                    )
                }
            }
        )
    }

    companion object {
        private const val DEFAULT_MODEL = "gpt-4.1-mini"
        private val JSON = Json { ignoreUnknownKeys = true }
    }
}
