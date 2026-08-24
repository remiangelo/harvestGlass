package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.Config
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.model.UserSubscription
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Reads tier state, and hands a Play purchase to the server for verification.
 *
 * Tier is server-authoritative: the app never decides what someone paid for,
 * it asks. That is why a user who subscribed on iOS already reads correctly
 * here with no cross-store entitlement mechanism.
 *
 * Mirrors the read half of Harvest/Services/SubscriptionService.swift.
 */
class SubscriptionService(private val client: SupabaseClient) {

    suspend fun getSubscriptionTiers(): List<SubscriptionTier> =
        client.postgrest.from("subscription_tiers")
            .select {
                filter { eq("is_active", true) }
                order("sort_order", Order.ASCENDING)
            }
            .decodeList()

    suspend fun getUserSubscription(userId: String): UserSubscription? =
        client.postgrest.from("user_subscriptions")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("status", "active")
                }
                order("updated_at", Order.DESCENDING)
                limit(1)
            }
            .decodeList<UserSubscription>()
            .firstOrNull()

    /**
     * The user's active tier, falling back to the free Seed row.
     *
     * Returns null only when the tier table itself can't be read — callers
     * treat that as "locked", which is the safe default for a paid gate.
     */
    suspend fun currentTier(userId: String): SubscriptionTier? = runCatching {
        val tiers = getSubscriptionTiers()
        val subscription = getUserSubscription(userId)
        tiers.firstOrNull { it.id == subscription?.tierId }
            ?: tiers.firstOrNull { it.name == TierName.SEED }
    }.getOrNull()

    /** Daily Seed-send limit for the active tier; free tier when unknown. */
    suspend fun dailySeedLimit(userId: String): Int =
        currentTier(userId)?.dailySeedLimit ?: SubscriptionTier.DEFAULT_SEED_LIMIT

    /** Gives a brand-new account its free Seed row, if it has none. */
    suspend fun initializeUserSubscription(userId: String) {
        if (getUserSubscription(userId) != null) return
        val seedTierId = tierId(TierName.SEED) ?: return

        client.postgrest.from("user_subscriptions").insert(
            buildJsonObject {
                put("user_id", userId)
                put("tier_id", seedTierId)
                put("status", "active")
            }
        )
    }

    private suspend fun tierId(name: TierName): String? {
        @kotlinx.serialization.Serializable
        data class Row(val id: String)

        return client.postgrest.from("subscription_tiers")
            .select(Columns.list("id")) {
                filter { eq("name", name.raw) }
                limit(1)
            }
            .decodeList<Row>()
            .firstOrNull()
            ?.id
    }

    /**
     * Hands a Play purchase token to `verify-play-purchase`, which validates it
     * against Google's API and writes the tier row.
     *
     * The client deliberately does NOT write the tier itself: a modified APK
     * could otherwise grant its own Gold.
     */
    suspend fun verifyPlayPurchase(userId: String, productId: String, purchaseToken: String) {
        val session = client.auth.currentSessionOrNull()
            ?: throw IllegalStateException("Not authenticated")

        val response = client.httpClient.post(
            "${Config.SUPABASE_URL}/functions/v1/verify-play-purchase"
        ) {
            header("Authorization", "Bearer ${session.accessToken}")
            header("apikey", Config.SUPABASE_ANON_KEY)
            contentType(ContentType.Application.Json)
            setBody(
                buildJsonObject {
                    put("user_id", userId)
                    put("product_id", productId)
                    put("purchase_token", purchaseToken)
                }
            )
        }

        if (!response.status.isSuccess()) {
            throw IllegalStateException("Purchase verification failed (${response.status.value})")
        }
    }
}
