package com.harvestglass.harvest.ui.safety

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.GppGood
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.ui.components.GlassBadge
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.components.color
import com.harvestglass.harvest.ui.components.icon
import com.harvestglass.harvest.ui.settings.SettingsTopBar
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Safety/SafetyDashboardView.swift — one row per
 * conversation, scored.
 */
@Composable
fun SafetyDashboardScreen(
    userId: String,
    onBack: () -> Unit,
    viewModel: SafetyDashboardViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(userId) { viewModel.load(userId) }

    state.selectedAnalysis?.let { analysis ->
        SafetyDetailScreen(
            analysis = analysis,
            redFlags = state.redFlags,
            partnerName = state.profiles[analysis.otherUserId]?.displayName ?: "User",
            onDone = { viewModel.clearSelection() }
        )
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        Box {
            SettingsTopBar(title = "Safety Dashboard", onBack = onBack)
            Text(
                text = if (state.isAnalyzing) "Analyzing…" else "Analyze",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(HarvestTheme.Spacing.md)
                    .clickable(enabled = !state.isAnalyzing && !state.isLoading) {
                        viewModel.runBulkAnalysis(userId)
                    }
            )
        }

        when {
            state.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = HarvestTheme.Colors.primary)
            }

            state.analyses.isEmpty() -> EmptyState()

            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                contentPadding = PaddingValues(HarvestTheme.Spacing.md),
                modifier = Modifier
                    .weight(1f)
                    .navigationBarsPadding()
            ) {
                items(state.analyses, key = { it.id }) { analysis ->
                    AnalysisRow(
                        analysis = analysis,
                        name = state.profiles[analysis.otherUserId]?.displayName ?: "User",
                        onOpen = { viewModel.select(analysis) }
                    )
                }
            }
        }

        state.error?.let {
            Text(
                text = it,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                modifier = Modifier.padding(HarvestTheme.Spacing.md)
            )
        }
    }
}

@Composable
private fun EmptyState() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxWidth()
            .padding(HarvestTheme.Spacing.xxl)
    ) {
        Icon(
            Icons.Filled.GppGood,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(40.dp)
        )
        Text(
            text = "No Safety Data Yet",
            style = HarvestTheme.Typography.h3,
            color = HarvestTheme.Colors.textPrimary
        )
        Text(
            text = "Safety scores will appear as you chat with your matches.",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun AnalysisRow(analysis: SafetyAnalysis, name: String, onOpen: () -> Unit) {
    GlassCard(
        style = GlassCardStyle.LIGHT,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen() }
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)
        ) {
            ScoreRing(analysis, diameter = 50.dp, stroke = 4.dp)

            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = name,
                    style = HarvestTheme.Typography.bodyRegular,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.textPrimary
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        analysis.safetyLevel.icon,
                        contentDescription = null,
                        tint = analysis.safetyLevel.color,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = analysis.safetyLevel.displayName,
                        style = HarvestTheme.Typography.caption,
                        color = analysis.safetyLevel.color
                    )
                }
            }

            if (analysis.redFlagCount > 0) {
                GlassBadge(
                    text = "${analysis.redFlagCount} flags",
                    color = HarvestTheme.Colors.warning
                )
            }

            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = HarvestTheme.Colors.textSecondary
            )
        }
    }
}

/** The score arc: a full ring behind, the score's share of it in front. */
@Composable
internal fun ScoreRing(
    analysis: SafetyAnalysis,
    diameter: androidx.compose.ui.unit.Dp,
    stroke: androidx.compose.ui.unit.Dp,
    content: @Composable (() -> Unit)? = null
) {
    val levelColor = analysis.safetyLevel.color

    Box(Modifier.size(diameter), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(diameter)) {
            val strokePx = stroke.toPx()
            val inset = strokePx / 2
            val arcSize = Size(size.width - strokePx, size.height - strokePx)

            drawCircle(
                color = levelColor.copy(alpha = 0.3f),
                radius = (size.minDimension - strokePx) / 2,
                style = Stroke(width = strokePx)
            )
            drawArc(
                color = levelColor,
                // -90 starts the arc at 12 o'clock, as the iOS rotation does.
                startAngle = -90f,
                sweepAngle = 360f * (analysis.safetyScore / 100f),
                useCenter = false,
                topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                size = arcSize,
                style = Stroke(width = strokePx, cap = StrokeCap.Round)
            )
        }

        if (content != null) {
            content()
        } else {
            Text(
                text = "${analysis.safetyScore}",
                style = HarvestTheme.Typography.bodySmall,
                fontWeight = FontWeight.Bold,
                color = HarvestTheme.Colors.textPrimary
            )
        }
    }
}

/** Port of the SafetyDetailSheet inside SafetyDashboardView.swift. */
@Composable
private fun SafetyDetailScreen(
    analysis: SafetyAnalysis,
    redFlags: List<com.harvestglass.harvest.data.model.RedFlagReport>,
    partnerName: String,
    onDone: () -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        SettingsTopBar(title = "Safety Details", onBack = onDone)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            ScoreRing(analysis, diameter = 100.dp, stroke = 8.dp) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "${analysis.safetyScore}",
                        style = HarvestTheme.Typography.h1,
                        fontWeight = FontWeight.Bold,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = analysis.safetyLevel.displayName,
                        style = HarvestTheme.Typography.caption,
                        color = analysis.safetyLevel.color
                    )
                }
            }

            GlassCard(style = GlassCardStyle.LIGHT) {
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    StatRow("Total Messages", "${analysis.totalMessages}")
                    StatRow("Red Flags", "${analysis.redFlagCount}")
                }
            }

            // Persisted reports when they loaded, the analysis's own snapshots
            // otherwise — the score is computed from the snapshots either way.
            val rows: List<Pair<String, String>> = when {
                redFlags.isNotEmpty() ->
                    redFlags.map { it.category.raw.titleCase() to it.detail }

                analysis.redFlags.isNotEmpty() ->
                    analysis.redFlags.map { it.category.raw.titleCase() to it.evidence }

                else -> emptyList()
            }

            if (rows.isNotEmpty()) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Red Flags",
                        style = HarvestTheme.Typography.h3,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    rows.forEach { (title, detail) -> FlagRow(title, detail) }
                }
            }

            GlassCard(style = GlassCardStyle.LIGHT) {
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    Text(
                        text = "Recommendations",
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = when {
                            analysis.safetyScore >= 80 ->
                                "This conversation appears safe. Continue enjoying your connection!"

                            analysis.safetyScore >= 50 ->
                                "Some concerns have been noted. Stay mindful and report anything " +
                                    "that makes you uncomfortable."

                            else ->
                                "Multiple concerns detected. Consider reporting or blocking this " +
                                    "user if you feel unsafe."
                        },
                        style = HarvestTheme.Typography.bodySmall,
                        color = if (analysis.safetyScore >= 50) {
                            HarvestTheme.Colors.textSecondary
                        } else {
                            HarvestTheme.Colors.error
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
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
private fun FlagRow(title: String, detail: String) {
    GlassCard(style = GlassCardStyle.LIGHT) {
        Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Icon(
                Icons.Filled.Warning,
                contentDescription = null,
                tint = HarvestTheme.Colors.warning,
                modifier = Modifier.size(18.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = title,
                    style = HarvestTheme.Typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.textPrimary
                )
                Text(
                    text = detail,
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.textSecondary
                )
            }
        }
    }
}

/** "personal_info" → "Personal Info", as iOS's replacingOccurrences + capitalized does. */
private fun String.titleCase(): String =
    replace('_', ' ').split(' ').joinToString(" ") { word ->
        word.replaceFirstChar { it.uppercase() }
    }
