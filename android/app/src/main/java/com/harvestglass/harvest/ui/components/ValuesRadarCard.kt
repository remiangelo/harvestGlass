package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BubbleChart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.ValueAxis
import com.harvestglass.harvest.data.model.ValuesTier
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestTheme
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Axis order as drawn, matching ValuesRadarCard.swift. */
val RADAR_AXES = listOf(
    ValueAxis.EMOTIONAL_INTELLIGENCE,
    ValueAxis.STABILITY,
    ValueAxis.INTEGRITY,
    ValueAxis.CONNECTION,
    ValueAxis.GROWTH
)

/**
 * A vertex on the radar.
 *
 * [magnitude] is already a radius fraction in [0, 1] (a tier ring position),
 * and is clamped defensively — the same guard the Swift version carries.
 */
internal fun radarAxisPoint(
    center: Offset,
    radius: Float,
    index: Int,
    axisCount: Int,
    magnitude: Float
): Offset {
    val angle = (2.0 * PI * index / axisCount) - PI / 2.0
    val clamped = magnitude.coerceIn(0f, 1f)
    val r = radius * clamped
    return Offset(
        x = center.x + (r * cos(angle)).toFloat(),
        y = center.y + (r * sin(angle)).toFloat()
    )
}

/**
 * Port of Harvest/Views/Components/ValuesRadarCard.swift.
 *
 * The chart plots visual TIERS, not raw scores: each axis's raw score (0–28)
 * goes through `ValuesTier.fromRawScore(...).radiusFraction` first, so the
 * chart communicates the *shape* of a values profile rather than points.
 */
@OptIn(ExperimentalTextApi::class)
@Composable
fun ValuesRadarCard(
    primary: AxisScores,
    primaryLabel: String,
    modifier: Modifier = Modifier,
    title: String = "Your Values Map",
    subtitle: String? = null,
    primaryColor: Color = HarvestTheme.Colors.primary,
    secondary: AxisScores? = null,
    secondaryLabel: String? = null,
    secondaryColor: Color = HarvestTheme.Colors.accent,
    onEmptyTap: (() -> Unit)? = null
) {
    val measurer = rememberTextMeasurer()
    val isEmpty = primary.isZero && (secondary?.isZero ?: true)

    GlassCard(modifier = modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = title,
                    style = HarvestTheme.Typography.h4,
                    color = HarvestTheme.Colors.textPrimary
                )
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }

            if (isEmpty) {
                EmptyState(onEmptyTap)
            } else {
                RadarChart(
                    primary = primary,
                    primaryColor = primaryColor,
                    secondary = secondary,
                    secondaryColor = secondaryColor,
                    measurer = measurer
                )
                Legend(
                    primaryColor = primaryColor,
                    primaryLabel = primaryLabel,
                    secondary = secondary,
                    secondaryColor = secondaryColor,
                    secondaryLabel = secondaryLabel
                )
            }
        }
    }
}

@Composable
private fun EmptyState(onEmptyTap: (() -> Unit)?) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.sm,
            Alignment.CenterVertically
        ),
        modifier = Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 240.dp)
    ) {
        Icon(
            imageVector = Icons.Filled.BubbleChart,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(32.dp)
        )
        Text(
            text = "Answer a few questions to map your values.",
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
        if (onEmptyTap != null) {
            HarvestButton(text = "Start", kind = HarvestButtonKind.PRIMARY, onClick = onEmptyTap)
        }
    }
}

@OptIn(ExperimentalTextApi::class)
@Composable
private fun RadarChart(
    primary: AxisScores,
    primaryColor: Color,
    secondary: AxisScores?,
    secondaryColor: Color,
    measurer: TextMeasurer
) {
    val gridColor = HarvestTheme.Colors.textSecondary.copy(alpha = 0.25f)
    val labelStyle = HarvestTheme.Typography.caption.copy(
        color = HarvestTheme.Colors.textSecondary
    )
    val ringNumberStyle = HarvestTheme.Typography.caption.copy(
        color = HarvestTheme.Colors.textTertiary
    )

    Canvas(
        Modifier
            .fillMaxWidth()
            .height(280.dp)
    ) {
        val side = minOf(size.width, size.height)
        val center = Offset(size.width / 2f, side / 2f)
        val radius = (side / 2f) - 32.dp.toPx()

        drawGrid(center, radius, gridColor)
        drawAxisLabels(center, radius, measurer, labelStyle)

        if (secondary != null && !secondary.isZero) {
            drawScorePolygon(center, radius, secondary, secondaryColor)
        }
        if (!primary.isZero) {
            drawScorePolygon(center, radius, primary, primaryColor)
        }

        // Drawn last so the tier numbers stay legible over the polygons.
        drawRingNumbers(center, radius, measurer, ringNumberStyle)
    }
}

private fun DrawScope.drawGrid(center: Offset, radius: Float, gridColor: Color) {
    // Four rings, one per ValuesTier (1st → outer).
    listOf(0.25f, 0.5f, 0.75f, 1f).forEach { ring ->
        val path = Path()
        RADAR_AXES.indices.forEach { i ->
            val p = radarAxisPoint(center, radius, i, RADAR_AXES.size, ring)
            if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
        }
        path.close()
        drawPath(path, gridColor, style = Stroke(width = 0.5.dp.toPx()))
    }

    RADAR_AXES.indices.forEach { i ->
        drawLine(
            color = gridColor,
            start = center,
            end = radarAxisPoint(center, radius, i, RADAR_AXES.size, 1f),
            strokeWidth = 0.5.dp.toPx()
        )
    }
}

private fun DrawScope.drawScorePolygon(
    center: Offset,
    radius: Float,
    scores: AxisScores,
    color: Color
) {
    val path = Path()
    RADAR_AXES.forEachIndexed { i, axis ->
        // Translate the raw category score into its visual tier ring position.
        val magnitude = ValuesTier.fromRawScore(scores.value(axis)).radiusFraction.toFloat()
        val p = radarAxisPoint(center, radius, i, RADAR_AXES.size, magnitude)
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    drawPath(path, color.copy(alpha = 0.3f))
    drawPath(path, color, style = Stroke(width = 1.5.dp.toPx()))
}

@OptIn(ExperimentalTextApi::class)
private fun DrawScope.drawAxisLabels(
    center: Offset,
    radius: Float,
    measurer: TextMeasurer,
    style: TextStyle
) {
    RADAR_AXES.forEachIndexed { i, axis ->
        val at = radarAxisPoint(center, radius + 22.dp.toPx(), i, RADAR_AXES.size, 1f)
        val laid = measurer.measure(axis.displayName, style)
        // Compose draws from the top-left; Swift anchors at the centre.
        drawText(
            textLayoutResult = laid,
            topLeft = Offset(at.x - laid.size.width / 2f, at.y - laid.size.height / 2f)
        )
    }
}

@OptIn(ExperimentalTextApi::class)
private fun DrawScope.drawRingNumbers(
    center: Offset,
    radius: Float,
    measurer: TextMeasurer,
    style: TextStyle
) {
    // Tier numbers (1…4) stacked up the centre line, just left of the top spoke.
    ValuesTier.entries.forEach { tier ->
        val y = center.y - radius * tier.radiusFraction.toFloat()
        val laid = measurer.measure(tier.level.toString(), style)
        drawText(
            textLayoutResult = laid,
            topLeft = Offset(
                center.x - 12.dp.toPx() - laid.size.width / 2f,
                y - laid.size.height / 2f
            )
        )
    }
}

@Composable
private fun Legend(
    primaryColor: Color,
    primaryLabel: String,
    secondary: AxisScores?,
    secondaryColor: Color,
    secondaryLabel: String?
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.lg,
            Alignment.CenterHorizontally
        ),
        modifier = Modifier.fillMaxWidth()
    ) {
        LegendDot(primaryColor, primaryLabel)
        if (secondary != null && !secondary.isZero && secondaryLabel != null) {
            LegendDot(secondaryColor, secondaryLabel)
        }
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(10.dp).background(color, CircleShape))
        Text(
            text = label,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}
