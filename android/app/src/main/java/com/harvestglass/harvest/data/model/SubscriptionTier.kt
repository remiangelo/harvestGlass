package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors TierName in Harvest/Models/SubscriptionTier.swift. */
@Serializable
enum class TierName(val raw: String) {
    @SerialName("seed") SEED("seed"),
    @SerialName("green") GREEN("green"),
    @SerialName("gold") GOLD("gold");

    companion object {
        /** Unknown names fall back to the free tier rather than throwing. */
        fun fromRaw(raw: String?): TierName =
            entries.firstOrNull { it.raw == raw?.lowercase() } ?: SEED
    }
}

/**
 * Mirrors SubscriptionTier in Harvest/Models/SubscriptionTier.swift.
 *
 * Numeric columns are nullable with defaults because the table has grown over
 * time and older rows don't carry every field.
 */
@Serializable
data class SubscriptionTier(
    val id: String,
    val name: TierName,
    @SerialName("display_name") val displayName: String = "",
    val description: String? = null,
    @SerialName("price_monthly") val priceMonthly: Double = 0.0,
    @SerialName("price_weekly") val priceWeekly: Double? = null,
    @SerialName("gardener_conversations_per_day") val gardenerConversationsPerDay: Int = 0,
    @SerialName("gardener_character_limit") val gardenerCharacterLimit: Int = 0,
    @SerialName("gardener_screenshots_per_day") val gardenerScreenshotsPerDay: Int = 0,
    @SerialName("field_filter_level") val fieldFilterLevelRaw: String? = null,
    @SerialName("has_deep_soil_insights") val hasDeepSoilInsights: Boolean = false,
    @SerialName("has_growth_features") val hasGrowthFeatures: Boolean = false,
    @SerialName("can_disable_mindful_messaging") val canDisableMindfulMessaging: Boolean = false,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("daily_seed_limit") val dailySeedLimit: Int = DEFAULT_SEED_LIMIT
) {
    val isPaid: Boolean get() = priceMonthly > 0

    /**
     * What the paywall calls this tier. The green tier is stored as "green" but
     * sold as "Grow"; the others use their stored display name.
     */
    val marketingDisplayName: String
        get() = if (name == TierName.GREEN) "Grow" else displayName

    val fieldFilterLevel: FieldFilterLevel get() = FieldFilterLevel.fromRaw(fieldFilterLevelRaw)

    companion object {
        /** What the free Seed tier allows, and the fallback for an older row. */
        const val DEFAULT_SEED_LIMIT = 3
    }
}

@Serializable
data class UserSubscription(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("tier_id") val tierId: String,
    val status: String,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("cancelled_at") val cancelledAt: String? = null
)
