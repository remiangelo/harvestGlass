package com.harvestglass.harvest.ui.components

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.GppBad
import androidx.compose.material.icons.filled.GppGood
import androidx.compose.material.icons.filled.GppMaybe
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.data.model.SafetyLevel
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** The five level colours, hex-for-hex from SafetyModels.swift. */
val SafetyLevel.color: Color
    get() = when (this) {
        SafetyLevel.BLOCK -> Color(0xFFDC2626)
        SafetyLevel.WARNING -> Color(0xFFF59E0B)
        SafetyLevel.CAUTION -> Color(0xFFF97316)
        SafetyLevel.SAFE -> Color(0xFF27CF8A)
        SafetyLevel.VERIFIED -> Color(0xFF3B82F6)
    }

/** The nearest material equivalents to the SF Symbols iOS names. */
val SafetyLevel.icon: ImageVector
    get() = when (this) {
        SafetyLevel.BLOCK -> Icons.Filled.GppBad
        SafetyLevel.WARNING -> Icons.Filled.GppMaybe
        SafetyLevel.CAUTION -> Icons.Filled.Warning
        SafetyLevel.SAFE -> Icons.Filled.GppGood
        SafetyLevel.VERIFIED -> Icons.Filled.Verified
    }

/** Port of Harvest/Views/Safety/SafetyStatusBadge.swift. */
@Composable
fun SafetyStatusBadge(level: SafetyLevel, modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        modifier = modifier
            .fillMaxWidth()
            .background(level.color, RoundedCornerShape(percent = 50))
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = 6.dp)
            .semantics { contentDescription = "Chat safety status: ${level.displayName}" }
    ) {
        Icon(
            level.icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = "Chat: ${level.displayName}",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
    }
}

/** Port of Harvest/Views/Safety/SafetyWarningView.swift. */
@Composable
fun SafetyWarningBanner(
    level: SafetyLevel,
    message: String,
    onViewDetails: (() -> Unit)? = null
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(level.color.copy(alpha = 0.1f))
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.sm)
    ) {
        Icon(
            level.icon,
            contentDescription = null,
            tint = level.color,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = message,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier.weight(1f)
        )
        onViewDetails?.let {
            Text(
                text = "Details",
                style = HarvestTheme.Typography.caption,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.primary,
                modifier = Modifier.clickable { it() }
            )
        }
    }
}

/**
 * Port of Harvest/Views/Safety/ReadyToMoveGateView.swift.
 *
 * All three conditions have to hold, and the checklist shows which don't —
 * "not yet" is more useful than a bare refusal.
 */
@Composable
fun ReadyToMoveGate(
    analysis: SafetyAnalysis,
    isReady: Boolean,
    reason: String?,
    onSharePreferredContact: (() -> Unit)? = null,
    onDismiss: () -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Done",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onDismiss() },
                textAlign = TextAlign.End
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            Icon(
                imageVector = if (isReady) Icons.Filled.Verified else Icons.Filled.HourglassEmpty,
                contentDescription = null,
                tint = if (isReady) HarvestTheme.Colors.accent else HarvestTheme.Colors.warning,
                modifier = Modifier.size(50.dp)
            )

            Text(
                text = if (isReady) "You're Clear to Share" else "Not Quite Ready",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary,
                textAlign = TextAlign.Center
            )

            reason?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.bodyRegular,
                    color = HarvestTheme.Colors.textSecondary,
                    textAlign = TextAlign.Center
                )
            }

            GlassCard(style = GlassCardStyle.LIGHT) {
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                    ChecklistItem("24 hours elapsed", analysis.has24HourHistory)
                    ChecklistItem("20+ messages exchanged", analysis.totalMessages >= 20)
                    ChecklistItem("Safety score >= 70", analysis.safetyScore >= 70)
                }
            }

            Text(
                text = "Safety score reflects the current conversation risk level based on " +
                    "detected red flags.",
                style = HarvestTheme.Typography.caption,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.xl)
            )

            if (isReady) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "You can now choose to share contact details outside the app.",
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textSecondary,
                        textAlign = TextAlign.Center
                    )
                    onSharePreferredContact?.let { share ->
                        val shape = RoundedCornerShape(HarvestTheme.Radius.md)
                        Text(
                            text = "Share Preferred Contact",
                            style = HarvestTheme.Typography.buttonText,
                            color = HarvestTheme.Colors.textOnBlack,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(HarvestTheme.Colors.blackSurface, shape)
                                .clickable { share() }
                                .padding(vertical = HarvestTheme.Spacing.sm)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChecklistItem(text: String, isComplete: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
    ) {
        Icon(
            imageVector = if (isComplete) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
            contentDescription = null,
            tint = if (isComplete) {
                HarvestTheme.Colors.accent
            } else {
                HarvestTheme.Colors.textSecondary
            },
            modifier = Modifier.size(20.dp)
        )
        Text(
            text = text,
            style = HarvestTheme.Typography.bodyRegular,
            color = if (isComplete) {
                HarvestTheme.Colors.textPrimary
            } else {
                HarvestTheme.Colors.textSecondary
            }
        )
    }
}
