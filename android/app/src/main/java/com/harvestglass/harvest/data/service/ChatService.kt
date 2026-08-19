package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Message
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.broadcastFlow
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.decodeRecord
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.mapNotNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant

/** Mirrors Harvest/Services/ChatService.swift. */
class ChatService(private val client: SupabaseClient) {

    suspend fun getMessages(conversationId: String): List<Message> =
        client.postgrest.from("messages")
            .select {
                filter { eq("conversation_id", conversationId) }
                order("created_at", Order.ASCENDING)
            }
            .decodeList()

    /**
     * Inserts the message and updates the conversation's preview columns, so
     * the Seeds list reflects the new activity without a separate refresh.
     */
    suspend fun sendMessage(conversationId: String, senderId: String, content: String): Message? {
        val now = Instant.now().toString()

        val inserted = client.postgrest.from("messages")
            .insert(
                buildJsonObject {
                    put("conversation_id", conversationId)
                    put("sender_id", senderId)
                    put("content", content)
                    put("message_type", "text")
                    put("created_at", now)
                }
            ) { select() }
            .decodeList<Message>()

        client.postgrest.from("conversations").update(
            buildJsonObject {
                put("last_message_at", now)
                put("last_message_preview", content.take(PREVIEW_LENGTH))
            }
        ) { filter { eq("id", conversationId) } }

        return inserted.firstOrNull()
    }

    suspend fun markAsRead(messageId: String) {
        client.postgrest.from("messages").update(
            buildJsonObject {
                put("is_read", true)
                put("read_at", Instant.now().toString())
            }
        ) { filter { eq("id", messageId) } }
    }

    /** Live inserts for one conversation, server-filtered by conversation_id. */
    fun subscribeToMessages(conversationId: String): Flow<Message> = flow {
        val channel = client.realtime.channel("messages:$conversationId")
        val changes = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "messages"
            filter("conversation_id", FilterOperator.EQ, conversationId)
        }
        channel.subscribe()
        emitAll(changes.mapNotNull { runCatching { it.decodeRecord<Message>() }.getOrNull() })
    }

    /**
     * Typing uses a broadcast channel rather than postgres_changes — nothing
     * is persisted, so there is no row to listen to. Emits the sender's id.
     */
    fun subscribeToTyping(conversationId: String): Flow<String> = flow {
        val channel = client.realtime.channel("typing:$conversationId")
        val broadcasts = channel.broadcastFlow<JsonObject>(event = TYPING_EVENT)
        channel.subscribe()
        emitAll(
            broadcasts.mapNotNull { payload ->
                runCatching { payload[TYPING_USER_KEY]?.jsonPrimitive?.content }.getOrNull()
            }
        )
    }

    suspend fun sendTypingIndicator(conversationId: String, userId: String) {
        val channel = client.realtime.channel("typing:$conversationId")
        runCatching {
            channel.subscribe()
            channel.broadcast(
                event = TYPING_EVENT,
                message = buildJsonObject { put(TYPING_USER_KEY, userId) }
            )
        }
        // A failed broadcast is not worth surfacing: the indicator is a nicety
        // and the Swift version only logs it.
    }

    companion object {
        private const val PREVIEW_LENGTH = 100
        private const val TYPING_EVENT = "typing"
        private const val TYPING_USER_KEY = "user_id"
    }
}
