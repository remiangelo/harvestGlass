package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Seed
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Mirrors the SeedError enum in Harvest/Services/SeedService.swift. */
sealed class SeedError(message: String) : Exception(message) {
    class DailyLimitReached :
        SeedError("You've reached today's Seed limit. Upgrade or try again tomorrow.")

    class Underlying(message: String) : SeedError(message)
}

/** Mirrors Harvest/Services/SeedService.swift. */
class SeedService(private val client: SupabaseClient) {

    /** Send a Seed (opening message) to another user. */
    suspend fun sendSeed(senderId: String, recipientId: String, openingMessage: String) {
        try {
            client.postgrest.from("seeds").insert(
                buildJsonObject {
                    put("sender_id", senderId)
                    put("recipient_id", recipientId)
                    put("opening_message", openingMessage)
                }
            )
        } catch (e: Exception) {
            // Surface the daily-limit Postgres exception as a typed error.
            if (e.toString().contains("SEED_LIMIT_REACHED")) throw SeedError.DailyLimitReached()
            throw SeedError.Underlying(e.toString())
        }
    }

    /**
     * Accept a Seed via the RPC; returns the new conversation id.
     *
     * The function returns a scalar uuid, but the transport may wrap it, so
     * the body is parsed defensively — see [parseConversationId].
     */
    suspend fun acceptSeed(seedId: String): String {
        val raw = client.postgrest
            .rpc("accept_seed", buildJsonObject { put("p_seed_id", seedId) })
            .data
        return parseConversationId(raw)
            ?: throw SeedError.Underlying("accept_seed returned no conversation id")
    }

    suspend fun declineSeed(seedId: String) {
        client.postgrest.from("seeds").update(
            buildJsonObject {
                put("status", "declined")
                put("responded_at", Instant.now().toString())
            }
        ) { filter { eq("id", seedId) } }
    }

    /** Pending Seeds received by the user (incoming requests). */
    suspend fun receivedPending(userId: String): List<Seed> =
        client.postgrest.from("seeds")
            .select {
                filter {
                    eq("recipient_id", userId)
                    eq("status", "pending")
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList()

    /** Pending Seeds the user has sent (outgoing requests). */
    suspend fun sentPending(userId: String): List<Seed> =
        client.postgrest.from("seeds")
            .select {
                filter {
                    eq("sender_id", userId)
                    eq("status", "pending")
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList()

    /**
     * How many Seeds the user has sent since local midnight, matching the
     * server trigger's `date_trunc('day', now())`.
     */
    suspend fun sentTodayCount(userId: String): Int {
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toString()
        return client.postgrest.from("seeds")
            .select {
                filter {
                    eq("sender_id", userId)
                    gte("created_at", startOfDay)
                }
            }
            .decodeList<Seed>()
            .size
    }

    /**
     * The RPC body arrives as a bare JSON scalar, a single-element array, or
     * (depending on transport) an unquoted string. All three shapes are
     * accepted, exactly as the Swift version does.
     */
    internal fun parseConversationId(raw: String): String? {
        runCatching { Json.decodeFromString<String>(raw) }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
            ?.let { return it }

        // A decodable array is authoritative even when empty: falling through
        // to the raw trim below would hand back the literal "[]" as if it were
        // a conversation id. Swift does fall through here; we deliberately do
        // not, because the caller would then navigate to a conversation that
        // does not exist rather than surfacing a clear error.
        val asArray = runCatching { Json.decodeFromString<List<String>>(raw) }.getOrNull()
        if (asArray != null) return asArray.firstOrNull()?.takeIf { it.isNotBlank() }

        return raw.trim(' ', '"', '\n', '\r').takeIf { it.isNotEmpty() }
    }
}
