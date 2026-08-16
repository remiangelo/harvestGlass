package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.model.CommunityPrompt
import com.harvestglass.harvest.data.model.CommunityReaction
import com.harvestglass.harvest.data.model.CommunitySender
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.decodeOldRecord
import io.github.jan.supabase.realtime.decodeRecord
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.mapNotNull
import kotlinx.coroutines.flow.merge
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray

/** A live reaction event for one room. */
sealed interface ReactionEvent {
    data class Added(val reaction: CommunityReaction) : ReactionEvent
    data class Removed(val reaction: CommunityReaction) : ReactionEvent
}

/** Mirrors Harvest/Services/CommunityService.swift, method for method. */
class CommunityService(private val client: SupabaseClient) {

    // MARK: - Rooms

    /** Rooms the user is allowed to join (via the access-rules RPC). */
    suspend fun availableCommunities(userId: String): List<Community> =
        client.postgrest
            .rpc("available_communities", buildJsonObject { put("p_user", userId) })
            .decodeList<Community>()

    /** Community ids the user has actively joined. */
    suspend fun joinedCommunityIds(userId: String): Set<String> {
        @Serializable
        data class Row(val community_id: String)

        return client.postgrest.from("community_members")
            .select(Columns.list("community_id")) {
                filter {
                    eq("user_id", userId)
                    eq("status", "active")
                }
            }
            .decodeList<Row>()
            .map { it.community_id }
            .toSet()
    }

    suspend fun join(communityId: String, userId: String) {
        client.postgrest.from("community_members").upsert(
            buildJsonObject {
                put("community_id", communityId)
                put("user_id", userId)
                put("status", "active")
            }
        )
    }

    suspend fun leave(communityId: String, userId: String) {
        client.postgrest.from("community_members").update(
            buildJsonObject { put("status", "left") }
        ) {
            filter {
                eq("community_id", communityId)
                eq("user_id", userId)
            }
        }
    }

    // MARK: - Messages

    /**
     * Latest page of messages, newest-first. Pass the oldest loaded
     * created_at as [before] to fetch the next older page.
     */
    suspend fun messagesPage(
        communityId: String,
        before: String? = null,
        limit: Int = 50
    ): List<CommunityMessage> =
        client.postgrest.from("community_messages")
            .select {
                filter {
                    eq("community_id", communityId)
                    eq("is_removed", false)
                    if (before != null) lt("created_at", before)
                }
                order("created_at", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList()

    /**
     * Fetch specific messages by id — used for quoted-reply previews whose
     * originals fell outside the loaded pages. Includes removed rows so the
     * UI can render "Message removed".
     */
    suspend fun messagesByIds(ids: List<String>): List<CommunityMessage> {
        if (ids.isEmpty()) return emptyList()
        return client.postgrest.from("community_messages")
            .select { filter { isIn("id", ids) } }
            .decodeList()
    }

    /**
     * Returns the inserted row so the sender sees the message immediately,
     * without waiting for the realtime echo. Throws when server-side contact
     * detection rejects the message.
     */
    suspend fun post(
        communityId: String,
        senderId: String,
        content: String,
        replyToId: String? = null,
        mentions: List<String> = emptyList()
    ): CommunityMessage? =
        client.postgrest.from("community_messages")
            .insert(
                buildJsonObject {
                    put("community_id", communityId)
                    put("sender_id", senderId)
                    put("content", content)
                    put("reply_to_id", replyToId)
                    putJsonArray("mentions") { mentions.forEach { add(it) } }
                }
            ) { select() }
            .decodeList<CommunityMessage>()
            .firstOrNull()

    // MARK: - People

    /** Name + avatar for the given user ids (for chat bubbles). */
    suspend fun senderProfiles(ids: List<String>): List<CommunitySender> {
        if (ids.isEmpty()) return emptyList()
        return client.postgrest.from("users")
            .select(Columns.raw("id, nickname, photos")) { filter { isIn("id", ids) } }
            .decodeList()
    }

    /** Active members of a room (for @mention autocomplete). */
    suspend fun members(communityId: String): List<CommunitySender> {
        @Serializable
        data class Row(val users: CommunitySender)

        return client.postgrest.from("community_members")
            .select(Columns.raw("users(id, nickname, photos)")) {
                filter {
                    eq("community_id", communityId)
                    eq("status", "active")
                }
            }
            .decodeList<Row>()
            .map { it.users }
    }

    // MARK: - Reactions

    /** All reactions for the given messages (bulk, one query per page load). */
    suspend fun reactions(messageIds: List<String>): List<CommunityReaction> {
        if (messageIds.isEmpty()) return emptyList()
        return client.postgrest.from("community_message_reactions")
            .select { filter { isIn("message_id", messageIds) } }
            .decodeList()
    }

    suspend fun addReaction(messageId: String, userId: String, emoji: String) {
        // community_id is filled by a DB trigger — never send it.
        client.postgrest.from("community_message_reactions").upsert(
            buildJsonObject {
                put("message_id", messageId)
                put("user_id", userId)
                put("emoji", emoji)
            }
        )
    }

    suspend fun removeReaction(messageId: String, userId: String, emoji: String) {
        client.postgrest.from("community_message_reactions").delete {
            filter {
                eq("message_id", messageId)
                eq("user_id", userId)
                eq("emoji", emoji)
            }
        }
    }

    // MARK: - Prompts

    suspend fun prompts(communityId: String): List<CommunityPrompt> =
        // Room-specific OR global (community_id is null).
        client.postgrest.from("community_prompts")
            .select(Columns.raw("id, text")) {
                filter {
                    or {
                        eq("community_id", communityId)
                        exact("community_id", null)
                    }
                    eq("is_active", true)
                }
                order("display_order", Order.ASCENDING)
            }
            .decodeList()

    // MARK: - Realtime

    /** Live inserts for one room, server-filtered by community_id. */
    fun subscribeMessages(communityId: String): Flow<CommunityMessage> = flow {
        val channel = client.realtime.channel("community:$communityId")
        val changes = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "community_messages"
            filter("community_id", io.github.jan.supabase.postgrest.query.filter.FilterOperator.EQ, communityId)
        }
        channel.subscribe()
        emitAll(changes.mapNotNull { runCatching { it.decodeRecord<CommunityMessage>() }.getOrNull() })
    }

    /**
     * Live reaction add/remove events for one room. INSERT events are
     * server-filtered by community_id; DELETE events are not filterable in
     * postgres_changes and (with RLS) carry only the primary-key columns —
     * that's sufficient, since removal matches on (messageId, userId, emoji)
     * and events for unloaded messages no-op.
     */
    fun subscribeReactions(communityId: String): Flow<ReactionEvent> = flow {
        val channel = client.realtime.channel("community-reactions:$communityId")
        val inserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "community_message_reactions"
            filter("community_id", io.github.jan.supabase.postgrest.query.filter.FilterOperator.EQ, communityId)
        }
        val deletes = channel.postgresChangeFlow<PostgresAction.Delete>(schema = "public") {
            table = "community_message_reactions"
        }
        channel.subscribe()
        emitAll(
            merge(
                inserts.mapNotNull {
                    runCatching { ReactionEvent.Added(it.decodeRecord<CommunityReaction>()) }.getOrNull()
                },
                deletes.mapNotNull {
                    runCatching { ReactionEvent.Removed(it.decodeOldRecord<CommunityReaction>()) }.getOrNull()
                }
            )
        )
    }
}
