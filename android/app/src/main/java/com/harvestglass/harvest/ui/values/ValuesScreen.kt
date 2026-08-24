package com.harvestglass.harvest.ui.values

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.ValueChipGrid
import com.harvestglass.harvest.ui.components.ValuesRadarCard
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

private enum class ValuesMode { MAIN, TIPS }

private const val MAX_VALUE_SELECTIONS = 3

/**
 * Port of Harvest/Views/Values/ValuesView.swift — the Soil tab.
 *
 * One section of the Swift view is not here: the generated-blurb section,
 * which iOS itself has commented out ("blurbSection — temporarily disabled"),
 * so omitting it IS parity.
 */
@Composable
fun ValuesScreen(
    userId: String,
    viewModel: ValuesViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showQuestionSheet by remember { mutableStateOf(false) }

    LaunchedEffect(userId) { viewModel.load(userId) }

    if (showQuestionSheet) {
        QuestionSheet(
            unanswered = state.unansweredQuestions,
            onAnswer = { q, o -> viewModel.saveAnswer(userId, q, o) },
            onDismiss = { showQuestionSheet = false }
        )
        return
    }

    ValuesContent(
        state = state,
        onSideChange = viewModel::setSide,
        onToggleValue = { value -> viewModel.toggleValue(userId, value.id) },
        onOpenQuestions = { showQuestionSheet = true },
        onDisplayToggle = { key, isOn -> viewModel.setDisplayToggle(userId, key, isOn) },
        onGraphSideChange = { side -> viewModel.setGraphSide(userId, side) }
    )
}

@Composable
fun ValuesContent(
    state: ValuesUiState,
    onSideChange: (ValuesSide) -> Unit,
    onToggleValue: (Value) -> Unit,
    onOpenQuestions: () -> Unit,
    onDisplayToggle: (DisplayToggle, Boolean) -> Unit,
    onGraphSideChange: (ValuesSide) -> Unit
) {
    var mode by remember { mutableStateOf(ValuesMode.MAIN) }

    Column(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
        modifier = Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .verticalScroll(rememberScrollState())
            .padding(vertical = HarvestTheme.Spacing.md)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
        ) {
            Icon(
                Icons.Filled.Favorite,
                contentDescription = null,
                tint = HarvestTheme.Colors.accent
            )
            Text(
                text = "Your relational soil",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
        }

        SegmentedPair(
            leftLabel = "Main",
            rightLabel = "Tips",
            leftSelected = mode == ValuesMode.MAIN,
            onLeft = { mode = ValuesMode.MAIN },
            onRight = { mode = ValuesMode.TIPS }
        )

        when (mode) {
            ValuesMode.MAIN -> MainContent(
                state = state,
                onSideChange = onSideChange,
                onToggleValue = onToggleValue,
                onOpenQuestions = onOpenQuestions,
                onDisplayToggle = onDisplayToggle,
                onGraphSideChange = onGraphSideChange
            )

            ValuesMode.TIPS -> if (state.hasGrowthFeatures) {
                TipsSection()
            } else {
                PremiumGate(featureName = "Values-Based Dating Tips")
            }
        }
    }
}

@Composable
private fun MainContent(
    state: ValuesUiState,
    onSideChange: (ValuesSide) -> Unit,
    onToggleValue: (Value) -> Unit,
    onOpenQuestions: () -> Unit,
    onDisplayToggle: (DisplayToggle, Boolean) -> Unit,
    onGraphSideChange: (ValuesSide) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg)) {
        if (state.showRetakeBanner) {
            RetakeBanner(onOpenQuestions)
        }

        SegmentedPair(
            leftLabel = "What I Need",
            rightLabel = "What I Bring",
            leftSelected = state.side == ValuesSide.NEED,
            onLeft = { onSideChange(ValuesSide.NEED) },
            onRight = { onSideChange(ValuesSide.BRING) }
        )

        ValuesRadarCard(
            primary = state.activeScores,
            primaryLabel = sideLabel(state.side),
            onEmptyTap = onOpenQuestions,
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
        )

        MoreQuestionsButton(state.remainingQuestionCount, onOpenQuestions)

        ValuesPicker(state, onToggleValue)

        DisplayToggles(state, onDisplayToggle, onGraphSideChange)
    }
}

private fun sideLabel(side: ValuesSide) =
    if (side == ValuesSide.NEED) "What I Need" else "What I Bring"

@Composable
private fun RetakeBanner(onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .padding(horizontal = HarvestTheme.Spacing.md)
            .fillMaxWidth()
            .background(HarvestTheme.Colors.glassFillStrong, shape)
            .border(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.3f), shape)
            .clickable { onClick() }
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            Icons.Filled.AutoAwesome,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent
        )
        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = "Your values questionnaire has been updated",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Answer 10 quick questions so we can find new matches for you.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = HarvestTheme.Colors.textSecondary
        )
    }
}

@Composable
private fun MoreQuestionsButton(remaining: Int, onClick: () -> Unit) {
    val allCaughtUp = remaining == 0
    Box(
        Modifier.fillMaxWidth(),
        contentAlignment = Alignment.Center
    ) {
        HarvestButton(
            text = if (allCaughtUp) "All caught up" else "More questions ($remaining left)",
            kind = HarvestButtonKind.PRIMARY,
            icon = if (allCaughtUp) Icons.Filled.Verified else Icons.Filled.HelpOutline,
            modifier = Modifier.alpha(if (allCaughtUp) 0.5f else 1f)
        ) { if (!allCaughtUp) onClick() }
    }
}

@Composable
private fun ValuesPicker(state: ValuesUiState, onToggleValue: (Value) -> Unit) {
    GlassCard(modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = sideLabel(state.side),
                    style = HarvestTheme.Typography.h4,
                    color = HarvestTheme.Colors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = "${state.activeValueIds.size} / $MAX_VALUE_SELECTIONS",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary
                )
            }
            Text(
                text = "Pick your top 3.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )

            ValueChipGrid(
                values = state.allValues,
                selectedIds = state.activeValueIds,
                maxSelection = MAX_VALUE_SELECTIONS,
                onToggle = onToggleValue
            )

            state.saveError?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.warning
                )
            }
        }
    }
}

@Composable
private fun DisplayToggles(
    state: ValuesUiState,
    onDisplayToggle: (DisplayToggle, Boolean) -> Unit,
    onGraphSideChange: (ValuesSide) -> Unit
) {
    // iOS defaults every one of these to true when the column is null.
    val showBrought = state.profile?.showValuesBrought ?: true
    val showBlurb = state.profile?.showValuesBlurb ?: true
    val showGraph = state.profile?.showValuesGraph ?: true
    val graphSide = if (state.profile?.profileGraphSide == "need") ValuesSide.NEED else ValuesSide.BRING

    GlassCard(modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Text(
                text = "Show on Profile",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )

            ToggleRow("What I Bring", showBrought) { onDisplayToggle(DisplayToggle.BROUGHT, it) }
            ToggleRow("Generated Blurb", showBlurb) { onDisplayToggle(DisplayToggle.BLURB, it) }
            ToggleRow("Values Graph", showGraph) { onDisplayToggle(DisplayToggle.GRAPH, it) }

            if (showGraph) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Graph side",
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Box(Modifier.width(160.dp)) {
                        SegmentedPair(
                            leftLabel = "Need",
                            rightLabel = "Bring",
                            leftSelected = graphSide == ValuesSide.NEED,
                            onLeft = { onGraphSideChange(ValuesSide.NEED) },
                            onRight = { onGraphSideChange(ValuesSide.BRING) },
                            horizontalPadding = 0.dp
                        )
                    }
                }
            }

            state.toggleError?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.warning
                )
            }
        }
    }
}

@Composable
private fun ToggleRow(label: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = isOn,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = HarvestTheme.Colors.pureWhite,
                checkedTrackColor = HarvestTheme.Colors.primary,
                uncheckedThumbColor = HarvestTheme.Colors.pureWhite,
                uncheckedTrackColor = HarvestTheme.Colors.textTertiary.copy(alpha = 0.5f)
            )
        )
    }
}

/** Stands in for the iOS segmented Picker, which Compose has no direct analogue of. */
@Composable
private fun SegmentedPair(
    leftLabel: String,
    rightLabel: String,
    leftSelected: Boolean,
    onLeft: () -> Unit,
    onRight: () -> Unit,
    horizontalPadding: androidx.compose.ui.unit.Dp = HarvestTheme.Spacing.md
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = horizontalPadding)
    ) {
        Segment(leftLabel, leftSelected, Modifier.weight(1f), onLeft)
        Segment(rightLabel, !leftSelected, Modifier.weight(1f), onRight)
    }
}

@Composable
private fun Segment(
    label: String,
    isSelected: Boolean,
    modifier: Modifier,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
    Text(
        text = label,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) HarvestTheme.Colors.textOnRedPrimary else HarvestTheme.Colors.textPrimary,
        textAlign = TextAlign.Center,
        modifier = modifier
            .background(
                if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.formSurface,
                shape
            )
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .clickable { onClick() }
            .padding(vertical = HarvestTheme.Spacing.sm)
    )
}

/** Port of PremiumGateView, minus the upgrade navigation (Subscription subsystem). */
@Composable
private fun PremiumGate(featureName: String) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.md,
            Alignment.CenterVertically
        ),
        modifier = Modifier
            .padding(horizontal = HarvestTheme.Spacing.md)
            .fillMaxWidth()
            .defaultMinSize(minHeight = 220.dp)
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
            text = featureName,
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Text(
            text = "Unlock with Gold",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}
