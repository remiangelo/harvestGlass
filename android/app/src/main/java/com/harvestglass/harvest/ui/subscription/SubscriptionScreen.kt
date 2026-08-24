package com.harvestglass.harvest.ui.subscription

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.HighlightOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.billing.BillingPeriod
import com.harvestglass.harvest.data.model.FieldFilterLevel
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Gold's crown, the one colour outside the palette. Matches iOS's F59E0B. */
private val GoldAccent = Color(0xFFF59E0B)

/** Where Play sends users to cancel or switch plans. */
private const val PLAY_SUBSCRIPTIONS_URL = "https://play.google.com/store/account/subscriptions"

/**
 * Port of Harvest/Views/Subscription/SubscriptionView.swift.
 *
 * Two deliberate differences from iOS, both store-driven: "Manage Subscription"
 * opens Play rather than Apple, and the fine print names Google Play.
 */
@Composable
fun SubscriptionScreen(
    userId: String,
    onBack: () -> Unit,
    viewModel: SubscriptionViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var purchaseTier by remember { mutableStateOf<SubscriptionTier?>(null) }
    var billingPeriod by remember { mutableStateOf(BillingPeriod.WEEKLY) }

    LaunchedEffect(userId) {
        viewModel.loadSubscriptionData(userId)
        viewModel.loadProducts()
        viewModel.checkSubscriptionStatus(userId)
    }

    purchaseTier?.let { tier ->
        PurchaseSheet(
            tier = tier,
            userId = userId,
            state = state,
            billingPeriod = billingPeriod,
            onBillingPeriodChange = { billingPeriod = it },
            onRetryProducts = { viewModel.loadProducts() },
            onSubscribe = { details ->
                val activity = context.findActivity()
                if (activity != null) viewModel.purchase(activity, details, userId)
            },
            onDismiss = { purchaseTier = null }
        )
        // The sheet fills the screen, so the list underneath isn't drawn at all.
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        SubscriptionTopBar(
            onBack = onBack,
            onRestore = { viewModel.restorePurchases(userId) }
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            Text(
                text = "Choose Your Plan",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Unlock premium features to grow your connections",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary
            )

            if (state.showsManageCard) {
                GlassCard(style = GlassCardStyle.LIGHT) {
                    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                        Text(
                            text = "Manage Your Subscription",
                            style = HarvestTheme.Typography.h4,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        Text(
                            text = "Restore Purchases is for syncing an existing subscription " +
                                "on this device. To cancel or change your plan, use Google " +
                                "Play's subscription settings.",
                            style = HarvestTheme.Typography.bodySmall,
                            color = HarvestTheme.Colors.textSecondary
                        )
                        SubscriptionActionButton(
                            title = "Manage Subscription",
                            icon = Icons.Filled.OpenInNew
                        ) {
                            context.openPlaySubscriptions()
                        }
                    }
                }
            }

            state.tiers.forEach { tier ->
                TierCard(
                    tier = tier,
                    isCurrent = state.isCurrentTier(tier),
                    onUpgrade = {
                        billingPeriod = BillingPeriod.WEEKLY
                        purchaseTier = tier
                    }
                )
            }
        }
    }

    state.error?.let { message ->
        MessageDialog("Error", message) { viewModel.clearError() }
    }
    state.successMessage?.let { message ->
        MessageDialog("Success", message) { viewModel.clearSuccess() }
    }
}

@Composable
private fun SubscriptionTopBar(onBack: () -> Unit, onRestore: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .statusBarsPadding()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.clickable { onBack() }
        )
        Text(
            text = "Subscription",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "Restore Purchases",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.accent,
            modifier = Modifier.clickable { onRestore() }
        )
    }
}

@Composable
private fun TierCard(
    tier: SubscriptionTier,
    isCurrent: Boolean,
    onUpgrade: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    val outline = if (isCurrent) {
        Modifier.border(2.dp, HarvestTheme.Colors.accent, shape)
    } else {
        Modifier
    }

    GlassCard(style = GlassCardStyle.LIGHT, modifier = outline) {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Row(verticalAlignment = Alignment.Top) {
                Icon(
                    imageVector = tier.name.icon(),
                    contentDescription = null,
                    tint = tier.name.color(),
                    modifier = Modifier.size(28.dp)
                )
                Spacer(Modifier.width(HarvestTheme.Spacing.sm))

                Column(
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                    ) {
                        Text(
                            text = tier.marketingDisplayName,
                            style = HarvestTheme.Typography.h3,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        if (tier.name == TierName.GREEN) MostPopularBadge()
                    }
                    tier.description?.let {
                        Text(
                            text = it,
                            style = HarvestTheme.Typography.caption,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }

                Column(horizontalAlignment = Alignment.End) {
                    if (tier.priceMonthly == 0.0) {
                        Text(
                            text = "Free",
                            style = HarvestTheme.Typography.h3,
                            color = HarvestTheme.Colors.textPrimary
                        )
                    } else {
                        Text(
                            text = tier.priceMonthly.asPrice(),
                            style = HarvestTheme.Typography.h3,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        Text(
                            text = "/month",
                            style = HarvestTheme.Typography.caption,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }
            }

            HorizontalDivider(color = HarvestTheme.Colors.formBorder)

            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                FeatureRow("Seeds per day", "${tier.dailySeedLimit}")
                FeatureRow("Receive Seeds", "Unlimited")
                FeatureRow("Gardener chat", "${tier.gardenerCharacterLimit.grouped()} chars/day")
                FeatureRow("Screenshot reviews", "${tier.gardenerScreenshotsPerDay}/day")
                FeatureRow("Room member filters", tier.fieldFilterLevel.label())
                FeatureCheck("Deeper Soil & value insights", tier.hasDeepSoilInsights)
                FeatureCheck("Advanced compatibility insights", tier.hasDeepSoilInsights)
                FeatureCheck("Premium growth features", tier.hasGrowthFeatures)
            }

            if (isCurrent) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp)
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(HarvestTheme.Spacing.xs))
                    Text(
                        text = "Current Plan",
                        style = HarvestTheme.Typography.buttonText,
                        color = HarvestTheme.Colors.textPrimary
                    )
                }
            } else if (tier.name != TierName.SEED) {
                SubscriptionActionButton(
                    title = "Upgrade to ${tier.marketingDisplayName}",
                    onClick = onUpgrade
                )
            }
        }
    }
}

/**
 * The dark pill iOS declares inline as `subscriptionActionButton` — deliberately
 * not HarvestButton.SECONDARY, which uses a lighter glass fill.
 */
@Composable
private fun SubscriptionActionButton(
    title: String,
    icon: ImageVector? = null,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.sm,
            Alignment.CenterHorizontally
        ),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.blackSurface, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp)
    ) {
        icon?.let {
            Icon(
                imageVector = it,
                contentDescription = null,
                tint = HarvestTheme.Colors.textOnBlack,
                modifier = Modifier.size(18.dp)
            )
        }
        Text(
            text = title,
            style = HarvestTheme.Typography.buttonText,
            color = HarvestTheme.Colors.textOnBlack
        )
    }
}

@Composable
private fun MostPopularBadge() {
    val shape = RoundedCornerShape(HarvestTheme.Radius.full)
    Text(
        text = "Most Popular",
        style = HarvestTheme.Typography.caption,
        fontWeight = FontWeight.SemiBold,
        color = HarvestTheme.Colors.accent,
        modifier = Modifier
            .background(HarvestTheme.Colors.blackSurface, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = HarvestTheme.Spacing.xs)
    )
}

@Composable
internal fun FeatureRow(label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = value,
            style = HarvestTheme.Typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}

@Composable
private fun FeatureCheck(label: String, enabled: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier.weight(1f)
        )
        Icon(
            imageVector = if (enabled) Icons.Filled.CheckCircle else Icons.Outlined.HighlightOff,
            contentDescription = if (enabled) "Included" else "Not included",
            tint = if (enabled) HarvestTheme.Colors.accent else HarvestTheme.Colors.textTertiary,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun MessageDialog(title: String, message: String, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = { TextButton(onClick = onDismiss) { Text("OK") } },
        containerColor = HarvestTheme.Colors.formSurface,
        titleContentColor = HarvestTheme.Colors.textPrimary,
        textContentColor = HarvestTheme.Colors.textSecondary
    )
}

internal fun TierName.icon(): ImageVector = when (this) {
    TierName.SEED -> Icons.Outlined.Eco
    TierName.GREEN -> Icons.Filled.Eco
    TierName.GOLD -> Icons.Filled.WorkspacePremium
}

@Composable
internal fun TierName.color(): Color = when (this) {
    TierName.SEED -> HarvestTheme.Colors.textPrimary
    TierName.GREEN -> HarvestTheme.Colors.accent
    TierName.GOLD -> GoldAccent
}

internal fun FieldFilterLevel.label(): String = when (this) {
    FieldFilterLevel.NONE -> "Search only"
    FieldFilterLevel.ADVANCED -> "Advanced"
    FieldFilterLevel.FULL -> "All filters"
}

/** The table stores dollars; iOS renders them as `$%.2f`. */
internal fun Double.asPrice(): String = "$" + String.format("%.2f", this)

/** iOS uses `Int.formatted()`, which groups thousands. */
internal fun Int.grouped(): String = String.format("%,d", this)

private fun Context.openPlaySubscriptions() {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_SUBSCRIPTIONS_URL))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    // No Play Store and no browser is possible on a stripped device; the card
    // is informational either way, so a dead tap beats a crash.
    try {
        startActivity(intent)
    } catch (_: ActivityNotFoundException) {
    }
}

/** Play's billing flow needs the hosting Activity, which Compose only has as a Context. */
internal fun Context.findActivity(): Activity? {
    var current = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
