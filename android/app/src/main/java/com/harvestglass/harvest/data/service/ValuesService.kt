package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Value
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Mirrors Harvest/Services/ValuesService.swift. */
class ValuesService(private val client: SupabaseClient) {

    suspend fun getAllValues(): List<Value> {
        val fromDb = runCatching {
            client.postgrest.from("values")
                .select {
                    order("category", Order.ASCENDING)
                    order("name", Order.ASCENDING)
                }
                .decodeList<Value>()
        }.getOrNull()
        // DB unavailable or decode error — fall through to defaults, exactly as
        // the Swift version does. A values list is required to finish onboarding,
        // so an outage must not become a dead end.
        return if (!fromDb.isNullOrEmpty()) fromDb else DEFAULT_VALUES
    }

    @Serializable
    private data class JoinedValue(val values: Value)

    suspend fun getUserValuesBrought(userId: String): List<Value> =
        joined("user_values_brought", userId)

    suspend fun getUserValuesSought(userId: String): List<Value> =
        joined("user_values_sought", userId)

    private suspend fun joined(table: String, userId: String): List<Value> =
        client.postgrest.from(table)
            .select(Columns.raw("value_id, values(*)")) { filter { eq("user_id", userId) } }
            .decodeList<JoinedValue>()
            .map { it.values }

    suspend fun saveUserValuesBrought(userId: String, valueIds: List<String>) =
        replaceUserValues("user_values_brought", userId, valueIds)

    suspend fun saveUserValuesSought(userId: String, valueIds: List<String>) =
        replaceUserValues("user_values_sought", userId, valueIds)

    /** Delete-then-insert, with a 1-based ranking in the given order. */
    private suspend fun replaceUserValues(table: String, userId: String, valueIds: List<String>) {
        client.postgrest.from(table).delete { filter { eq("user_id", userId) } }

        if (valueIds.isEmpty()) return

        val rows = valueIds.mapIndexed { index, valueId ->
            buildJsonObject {
                put("user_id", userId)
                put("value_id", valueId)
                put("ranking", index + 1)
            }
        }
        client.postgrest.from(table).insert(rows)
    }

    companion object {
        /**
         * Built-in catalogue used when the `values` table is empty or
         * unreachable. Ids are `"<category>-<index>"`, matching the Swift
         * fallback so the two clients agree offline.
         */
        val DEFAULT_VALUES: List<Value> = buildList {
            val categories = listOf(
                "communication" to listOf(
                    "Honesty", "Active Listening", "Openness", "Directness",
                    "Vulnerability", "Empathy", "Patience"
                ),
                "relationship" to listOf(
                    "Commitment", "Trust", "Loyalty", "Independence",
                    "Partnership", "Quality Time", "Physical Affection",
                    "Words of Affirmation", "Acts of Service"
                ),
                "lifestyle" to listOf(
                    "Adventure", "Stability", "Ambition", "Work-Life Balance",
                    "Health & Wellness", "Spontaneity", "Routine",
                    "Financial Responsibility", "Minimalism"
                ),
                "personal growth" to listOf(
                    "Self-Awareness", "Continuous Learning", "Resilience",
                    "Accountability", "Gratitude", "Mindfulness",
                    "Emotional Intelligence", "Courage"
                ),
                "social" to listOf(
                    "Family", "Friendship", "Community", "Inclusivity",
                    "Generosity", "Humor", "Respect", "Kindness",
                    "Cultural Awareness"
                ),
                "core beliefs" to listOf(
                    "Authenticity", "Integrity", "Compassion", "Faith",
                    "Justice", "Freedom", "Creativity", "Purpose"
                )
            )
            categories.forEach { (category, names) ->
                names.forEachIndexed { index, name ->
                    add(
                        Value(
                            id = "$category-$index",
                            name = name,
                            category = category,
                            displayOrder = index
                        )
                    )
                }
            }
        }
    }
}
