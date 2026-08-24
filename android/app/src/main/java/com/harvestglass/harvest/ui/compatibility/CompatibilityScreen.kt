package com.harvestglass.harvest.ui.compatibility

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Forest
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Park
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Spa
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.model.ValuesTier
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.SectionHeader
import com.harvestglass.harvest.ui.components.ValuesRadarCard
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Compatibility/CompatibilityView.swift.
 *
 * The radar and the chips are free; the overlap counts and the written read
 * sit behind Grow's deep-insights flag.
 */
@Composable
fun CompatibilityScreen(
    viewerId: String,
    otherUserId: String,
    onDone: () -> Unit,
    viewModel: CompatibilityViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(otherUserId) { viewModel.load(viewerId, otherUserId) }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Values Alignment",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "Done",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier.clickable { onDone() }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(vertical = HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            when {
                state.isLoading -> Box(
                    Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = HarvestTheme.Colors.primary)
                }

                state.loadError != null -> ErrorPanel(state.loadError.orEmpty())

                else -> CompatibilityBody(state, viewModel::setPerspective)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CompatibilityBody(
    state: CompatibilityUiState,
    onPerspectiveChange: (Perspective) -> Unit
) {
    val isYours = state.perspective == Perspective.YOURS
    val name = state.otherName

    PerspectivePicker(state.perspective, onPerspectiveChange)

    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        // Rose is the "need" side, amber the "bring" side, so an amber shape
        // filling the rose one always reads as "what's brought meets what's needed".
        ValuesRadarCard(
            title = if (isYours) "Your Values Map" else "Their Values Map",
            subtitle = if (isYours) {
                "Overlay of what you need and what they bring."
            } else {
                "Overlay of what they need and what you bring."
            },
            primary = if (isYours) state.myNeedScores else state.theirNeedScores,
            primaryLabel = if (isYours) "You (What I Need)" else "$name (What They Need)",
            primaryColor = HarvestTheme.Colors.rose,
            secondary = if (isYours) state.theirBringScores else state.myBringScores,
            secondaryLabel = if (isYours) "$name (What They Bring)" else "You (What You Bring)",
            secondaryColor = HarvestTheme.Colors.amber
        )
    }

    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) { ValuesPresenceGuide() }
    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) { ValuesAlignmentInfoFooter() }

    // Each side is paired with its complement: what you need vs what they
    // bring, and what you bring vs what they need.
    ChipSection(
        primaryLabel = "You need",
        primaryChips = state.myNeeds,
        secondaryLabel = "$name brings",
        secondaryChips = state.theirBrings
    )

    ChipSection(
        primaryLabel = "You bring",
        primaryChips = state.myBrings,
        secondaryLabel = "$name needs",
        secondaryChips = state.theirNeeds
    )

    if (state.hasAdvancedInsights) {
        OverlapSection(state)
        BlurbSection(state.blurb)
    } else {
        Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) { AdvancedInsightsLock() }
    }
}

@Composable
private fun PerspectivePicker(selected: Perspective, onSelect: (Perspective) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = HarvestTheme.Spacing.md)
    ) {
        listOf(Perspective.YOURS to "Your Values", Perspective.THEIRS to "Their Values")
            .forEach { (perspective, label) ->
                val isSelected = perspective == selected
                val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
                Text(
                    text = label,
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
                        .clickable { onSelect(perspective) }
                        .padding(vertical = HarvestTheme.Spacing.sm)
                )
            }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipSection(
    primaryLabel: String,
    primaryChips: List<Value>,
    secondaryLabel: String,
    secondaryChips: List<Value>
) {
    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        GlassCard {
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                // Both columns share the card's height, as the SwiftUI Divider does.
                modifier = Modifier.height(IntrinsicSize.Min)
            ) {
                ChipColumn(primaryLabel, primaryChips, Modifier.weight(1f))
                VerticalDivider(color = HarvestTheme.Colors.divider)
                ChipColumn(secondaryLabel, secondaryChips, Modifier.weight(1f))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipColumn(label: String, chips: List<Value>, modifier: Modifier) {
    Column(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        modifier = modifier.defaultMinSize(minHeight = 48.dp)
    ) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.textSecondary
        )
        if (chips.isEmpty()) {
            Text(
                text = "—",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textTertiary
            )
        } else {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
            ) {
                chips.forEach { ChipView(title = it.name) }
            }
        }
    }
}

@Composable
private fun OverlapSection(state: CompatibilityUiState) {
    val overlap = state.overlap

    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        GlassCard {
            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                SectionHeader("Value overlap")

                OverlapRow(
                    count = overlap.theyBringForMyNeeds.size,
                    total = state.myNeeds.size,
                    leadingText = "${state.otherName} brings",
                    trailingText = "of your needs",
                    chips = overlap.theyBringForMyNeeds
                )

                HorizontalDivider(color = HarvestTheme.Colors.divider)

                OverlapRow(
                    count = overlap.iBringForTheirNeeds.size,
                    total = state.theirNeeds.size,
                    leadingText = "You bring",
                    trailingText = "of ${state.otherName}'s needs",
                    chips = overlap.iBringForTheirNeeds
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OverlapRow(
    count: Int,
    total: Int,
    leadingText: String,
    trailingText: String,
    chips: List<Value>
) {
    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)) {
        Text(
            text = "$leadingText $count of $total $trailingText",
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary
        )
        if (chips.isNotEmpty()) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
            ) {
                chips.forEach { ChipView(title = it.name) }
            }
        }
    }
}

@Composable
private fun BlurbSection(blurb: String) {
    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        GlassCard {
            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                ) {
                    Icon(
                        Icons.Filled.AutoAwesome,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.accent,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = "In summary",
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary
                    )
                }
                Text(
                    text = blurb,
                    style = HarvestTheme.Typography.bodyRegular,
                    color = HarvestTheme.Colors.textSecondary
                )
            }
        }
    }
}

@Composable
private fun AdvancedInsightsLock() {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.md,
            Alignment.CenterVertically
        ),
        modifier = Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 200.dp)
            .background(HarvestTheme.Colors.blackSurface, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(HarvestTheme.Spacing.lg)
    ) {
        Icon(
            Icons.Filled.Lock,
            contentDescription = null,
            tint = HarvestTheme.Colors.primary,
            modifier = Modifier.size(32.dp)
        )
        Text(
            text = "Value overlap & the written read",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Text(
            text = "Unlock with Grow",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}

/**
 * Port of ValuesPresenceGuide.swift — the legend for the four radar tiers,
 * driven entirely by [ValuesTier].
 */
@Composable
fun ValuesPresenceGuide() {
    GlassCard {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Text(
                text = "Values Presence Guide",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.rose
            )
            Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                ValuesTier.entries.forEach { tier ->
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(
                            imageVector = tier.icon(),
                            contentDescription = null,
                            tint = HarvestTheme.Colors.rose,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = tier.levelLabel,
                            style = HarvestTheme.Typography.bodySmall,
                            fontWeight = FontWeight.SemiBold,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        Text(
                            text = tier.displayName,
                            style = HarvestTheme.Typography.caption,
                            fontWeight = FontWeight.SemiBold,
                            color = HarvestTheme.Colors.roseLight,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = tier.rangeLabel,
                            style = HarvestTheme.Typography.bodySmall,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        Text(
                            text = tier.ringLabel,
                            style = HarvestTheme.Typography.caption,
                            color = HarvestTheme.Colors.textTertiary
                        )
                    }
                }
            }
        }
    }
}

/** Port of ValuesAlignmentInfoFooter.swift. */
@Composable
fun ValuesAlignmentInfoFooter() {
    GlassCard {
        Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Icon(
                Icons.Outlined.Info,
                contentDescription = null,
                tint = HarvestTheme.Colors.rose,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = "Higher tiers extend farther from the center. " +
                    "Greater overlap = stronger alignment.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )
        }
    }
}

@Composable
private fun ErrorPanel(message: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 200.dp)
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            Icons.Filled.Warning,
            contentDescription = null,
            tint = HarvestTheme.Colors.warning,
            modifier = Modifier.size(24.dp)
        )
        Text(
            text = message,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
    }
}

/** The growth metaphor iOS draws with SF Symbols leaf → tree. */
private fun ValuesTier.icon(): ImageVector = when (this) {
    ValuesTier.LOW_PRESENCE -> Icons.Outlined.Spa
    ValuesTier.GROWING_PRESENCE -> Icons.Filled.Spa
    ValuesTier.STRONG_PRESENCE -> Icons.Filled.Park
    ValuesTier.CORE_VALUE -> Icons.Filled.Forest
}
