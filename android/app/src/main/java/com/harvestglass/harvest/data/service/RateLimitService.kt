package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.SubscriptionTier
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.temporal.TemporalAdjusters

/** Mirrors GardenerLimitCheck in RateLimitService.swift. */
data class GardenerLimitCheck(
    val canSend: Boolean,
    val reason: String?,
    val remainingCharacters: Int,
    val characterLimit: Int
)

/** Mirrors ScreenshotLimitCheck in RateLimitService.swift. */
data class ScreenshotLimitCheck(
    val canSend: Boolean,
    val reason: String?,
    val remaining: Int,
    val limit: Int
)

/**
 * Port of Harvest/Services/RateLimitService.swift.
 *
 * Gardener chat characters and screenshot reviews are separate daily budgets;
 * a screenshot review used to cost 1,000 chat characters, which let one review
 * swallow a free user's whole day.
 *
 * Both budgets live on the weekly `user_usage` row and reset by date, not by
 * elapsed time — matching Swift's `gardener_last_reset_date` comparison.
 */
class RateLimitService(private val client: SupabaseClient) {

    @Serializable
    private data class UsageRow(
        val id: String,
        @SerialName("user_id") val userId: String,
        @SerialName("week_start_date") val weekStartDate: String,
        @SerialName("matches_count") val matchesCount: Int = 0,
        @SerialName("gardener_conversations_today") val conversationsToday: Int = 0,
        @SerialName("gardener_last_reset_date") val lastResetDate: String = "",
        @SerialName("gardener_characters_used_today") val charactersUsedToday: Int = 0,
        // Tolerated as absent so the app keeps working between shipping a build
        // and applying the migration that adds the column.
        @SerialName("gardener_screenshots_today") val screenshotsToday: Int = 0
    )

    suspend fun checkGardenerLimit(
        userId: String,
        messageLength: Int,
        tier: SubscriptionTier
    ): GardenerLimitCheck {
        val usage = normalized(usageRow(userId))
        val remainingBeforeSend =
            (tier.gardenerCharacterLimit - usage.charactersUsedToday).coerceAtLeast(0)

        if (messageLength > remainingBeforeSend) {
            return GardenerLimitCheck(
                canSend = false,
                reason = "Daily character limit reached " +
                    "(${tier.gardenerCharacterLimit} characters per day)",
                remainingCharacters = remainingBeforeSend,
                characterLimit = tier.gardenerCharacterLimit
            )
        }

        return GardenerLimitCheck(
            canSend = true,
            reason = null,
            remainingCharacters = (remainingBeforeSend - messageLength).coerceAtLeast(0),
            characterLimit = tier.gardenerCharacterLimit
        )
    }

    suspend fun trackGardenerConversation(userId: String, characterCount: Int) {
        val usage = normalized(usageRow(userId))

        client.postgrest.from("user_usage").update(
            buildJsonObject {
                put("gardener_conversations_today", usage.conversationsToday)
                put("gardener_characters_used_today", usage.charactersUsedToday + characterCount)
                put("gardener_last_reset_date", today())
                put("updated_at", Instant.now().toString())
            }
        ) {
            filter { eq("id", usage.id) }
        }
    }

    suspend fun checkScreenshotLimit(
        userId: String,
        tier: SubscriptionTier
    ): ScreenshotLimitCheck {
        val usage = normalized(usageRow(userId))
        val limit = tier.gardenerScreenshotsPerDay
        val remaining = (limit - usage.screenshotsToday).coerceAtLeast(0)

        if (remaining == 0) {
            return ScreenshotLimitCheck(
                canSend = false,
                reason = if (limit == 1) {
                    "That's your screenshot review for today. Your plan includes 1 per day."
                } else {
                    "You've used all $limit screenshot reviews for today."
                },
                remaining = 0,
                limit = limit
            )
        }

        return ScreenshotLimitCheck(canSend = true, reason = null, remaining = remaining, limit = limit)
    }

    suspend fun trackScreenshotReview(userId: String) {
        val usage = normalized(usageRow(userId))

        client.postgrest.from("user_usage").update(
            buildJsonObject {
                put("gardener_screenshots_today", usage.screenshotsToday + 1)
                put("gardener_last_reset_date", today())
                put("updated_at", Instant.now().toString())
            }
        ) {
            filter { eq("id", usage.id) }
        }
    }

    suspend fun screenshotsUsedToday(userId: String): Int =
        normalized(usageRow(userId)).screenshotsToday

    /** Characters spent on Gardener chat so far today. */
    suspend fun charactersUsedToday(userId: String): Int =
        normalized(usageRow(userId)).charactersUsedToday

    private suspend fun usageRow(userId: String): UsageRow {
        val weekStart = weekStartDate()

        client.postgrest.from("user_usage")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("week_start_date", weekStart)
                }
                limit(1)
            }
            .decodeList<UsageRow>()
            .firstOrNull()
            ?.let { return it }

        return client.postgrest.from("user_usage").insert(
            buildJsonObject {
                put("user_id", userId)
                put("week_start_date", weekStart)
                put("matches_count", 0)
                put("gardener_conversations_today", 0)
                put("gardener_last_reset_date", today())
                // gardener_screenshots_today is deliberately not written here:
                // it arrives with migration 20260811100000 and defaults to 0.
                // Naming it before that migration lands fails the whole insert,
                // which would silently drop every user to free-tier limits.
                put("gardener_characters_used_today", 0)
                put("updated_at", Instant.now().toString())
            }
        ) {
            select()
        }
            .decodeList<UsageRow>()
            .firstOrNull()
            ?: throw IllegalStateException("Unable to create usage tracking row")
    }

    /** Zeroes the daily counters when the row's reset date isn't today. */
    private suspend fun normalized(usage: UsageRow): UsageRow {
        val today = today()
        if (usage.lastResetDate == today) return usage

        client.postgrest.from("user_usage").update(
            buildJsonObject {
                put("gardener_conversations_today", 0)
                put("gardener_characters_used_today", 0)
                put("gardener_screenshots_today", 0)
                put("gardener_last_reset_date", today)
                put("updated_at", Instant.now().toString())
            }
        ) {
            filter { eq("id", usage.id) }
        }

        return usage.copy(
            conversationsToday = 0,
            charactersUsedToday = 0,
            screenshotsToday = 0,
            lastResetDate = today
        )
    }

    companion object {
        /** UTC, as Swift's formatter pins `secondsFromGMT: 0`. */
        internal fun today(): String = LocalDate.now(ZoneOffset.UTC).toString()

        /** Weeks start Monday, matching Swift's `firstWeekday = 2`. */
        internal fun weekStartDate(): String =
            LocalDate.now(ZoneOffset.UTC)
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .toString()
    }
}
