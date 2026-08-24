package com.harvestglass.harvest.ui.subscription

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.android.billingclient.api.ProductDetails
import com.harvestglass.harvest.billing.BillingPeriod
import com.harvestglass.harvest.data.model.FieldFilterLevel
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Subscription/PurchaseSheet.swift.
 *
 * Prices come from Play rather than the tier table — Google localises and
 * converts them, and the store's number is the one the user is charged.
 */
@Composable
fun PurchaseSheet(
    tier: SubscriptionTier,
    userId: String,
    state: SubscriptionUiState,
    billingPeriod: BillingPeriod,
    onBillingPeriodChange: (BillingPeriod) -> Unit,
    onRetryProducts: () -> Unit,
    onSubscribe: (ProductDetails) -> Unit,
    onDismiss: () -> Unit
) {
    val selected = state.product(tier, billingPeriod)

    LaunchedEffect(userId) {
        if (state.products.isEmpty()) onRetryProducts()
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        PurchaseSheetTopBar(onDismiss)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = tier.name.icon(),
                    contentDescription = null,
                    tint = tier.name.color(),
                    modifier = Modifier.size(60.dp)
                )
                Text(
                    text = "Upgrade to ${tier.marketingDisplayName}",
                    style = HarvestTheme.Typography.h2,
                    color = HarvestTheme.Colors.textPrimary,
                    textAlign = TextAlign.Center
                )
                tier.description?.let {
                    Text(
                        text = it,
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textSecondary,
                        textAlign = TextAlign.Center
                    )
                }
            }

            BillingPeriodPicker(billingPeriod, onBillingPeriodChange)

            selected?.let { details ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = details.formattedPrice(),
                        style = HarvestTheme.Typography.display.copy(fontSize = 48.sp),
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = if (billingPeriod == BillingPeriod.WEEKLY) "per week" else "per month",
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }

            GlassCard(style = GlassCardStyle.LIGHT) {
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                    Text(
                        text = "What you get:",
                        style = HarvestTheme.Typography.h3,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                        FeatureRow("Seeds per day", "${tier.dailySeedLimit}")
                        FeatureRow("Receive Seeds", "Unlimited")
                        FeatureRow(
                            "Gardener chat",
                            "${tier.gardenerCharacterLimit.grouped()} characters/day"
                        )
                        FeatureRow("Screenshot reviews", "${tier.gardenerScreenshotsPerDay}/day")

                        when (tier.fieldFilterLevel) {
                            FieldFilterLevel.NONE -> Unit
                            FieldFilterLevel.ADVANCED -> IncludedRow("Advanced room member filters")
                            FieldFilterLevel.FULL -> IncludedRow("Every room member filter")
                        }
                        if (tier.hasDeepSoilInsights) {
                            IncludedRow("Deeper Soil & value insights")
                            IncludedRow("Advanced compatibility insights")
                        }
                        if (tier.hasGrowthFeatures) {
                            IncludedRow("Premium relationship growth features")
                        }
                    }
                }
            }

            if (selected != null) {
                HarvestButton(
                    text = if (state.isPurchasing) "Processing..." else "Subscribe Now",
                    kind = HarvestButtonKind.PRIMARY,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (!state.isPurchasing) onSubscribe(selected)
                }
            } else {
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = if (state.products.isNotEmpty()) {
                            "This subscription product is not available right now."
                        } else {
                            state.error ?: "Loading product information..."
                        },
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textSecondary,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = "Retry",
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.accent,
                        modifier = Modifier.clickable { onRetryProducts() }
                    )
                }
            }

            Column(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.xl)
            ) {
                Text(
                    text = "Payment will be charged to your Google Play account at " +
                        "confirmation of purchase.",
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.textTertiary,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = "Subscription automatically renews unless canceled at least 24 " +
                        "hours before the end of the current period.",
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.textTertiary,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun PurchaseSheetTopBar(onDismiss: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .statusBarsPadding()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Text(
            text = "Subscribe",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "Cancel",
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.accent,
            modifier = Modifier.clickable { onDismiss() }
        )
    }
}

/** Stands in for the iOS segmented Picker, matching the pair used elsewhere. */
@Composable
private fun BillingPeriodPicker(
    selected: BillingPeriod,
    onSelect: (BillingPeriod) -> Unit
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier.fillMaxWidth()
    ) {
        BillingPeriod.entries.forEach { period ->
            val isSelected = period == selected
            val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
            Text(
                text = period.label(),
                style = HarvestTheme.Typography.bodySmall,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) {
                    HarvestTheme.Colors.textOnRedPrimary
                } else {
                    HarvestTheme.Colors.textPrimary
                },
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (isSelected) {
                            HarvestTheme.Colors.primary
                        } else {
                            HarvestTheme.Colors.formSurface
                        },
                        shape
                    )
                    .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                    .clickable { onSelect(period) }
                    .padding(vertical = HarvestTheme.Spacing.sm)
            )
        }
    }
}

@Composable
private fun IncludedRow(label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier.fillMaxWidth()
    ) {
        Icon(
            Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = label,
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}

private fun BillingPeriod.label(): String =
    if (this == BillingPeriod.WEEKLY) "Weekly" else "Monthly"

/**
 * The recurring price Play quotes for this product.
 *
 * A base plan can carry an intro phase, so the last phase is the one that
 * actually recurs — that's the number the sheet's "per week/month" describes.
 */
private fun ProductDetails.formattedPrice(): String =
    subscriptionOfferDetails
        ?.firstOrNull()
        ?.pricingPhases
        ?.pricingPhaseList
        ?.lastOrNull()
        ?.formattedPrice
        .orEmpty()
