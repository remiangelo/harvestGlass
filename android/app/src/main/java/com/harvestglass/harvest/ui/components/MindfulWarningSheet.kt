package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.data.service.MindfulAnalysis
import com.harvestglass.harvest.data.service.MindfulSeverity
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Components/MindfulWarningView.swift — the pre-send
 * pause when a message trips the mindful check.
 *
 * "Send Anyway" is always available: this is a nudge to reconsider, not a
 * block, and treating it as one would make the app the arbiter of what people
 * are allowed to say to each other.
 */
@Composable
fun MindfulWarningSheet(
    analysis: MindfulAnalysis,
    onEdit: () -> Unit,
    onSendAnyway: () -> Unit
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
                .background(HarvestTheme.Colors.formBackground)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Message Review",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
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
            Box(
                Modifier
                    .size(60.dp)
                    .background(analysis.severity.tint(), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Pause,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.primary,
                    modifier = Modifier.size(28.dp)
                )
            }

            Text(
                text = "Mindful Messaging",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )

            Text(
                text = analysis.reason,
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center
            )

            analysis.growthLesson?.let { lesson ->
                GlassCard(style = GlassCardStyle.LIGHT) {
                    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                        ) {
                            Icon(
                                Icons.Filled.Spa,
                                contentDescription = null,
                                tint = HarvestTheme.Colors.accent,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = lesson.title,
                                style = HarvestTheme.Typography.h4,
                                color = HarvestTheme.Colors.textPrimary
                            )
                        }
                        Text(
                            text = lesson.reflection,
                            style = HarvestTheme.Typography.bodySmall,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }
            }

            Spacer(Modifier.weight(1f))

            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                HarvestButton(
                    text = "Edit Message",
                    icon = Icons.Filled.Edit,
                    kind = HarvestButtonKind.PRIMARY,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onEdit
                )
                HarvestButton(
                    text = "Send Anyway",
                    kind = HarvestButtonKind.SECONDARY,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onSendAnyway
                )
            }
        }
    }
}

/** The three severity tints, hex-for-hex from MindfulWarningView.swift. */
private fun MindfulSeverity.tint(): Color = when (this) {
    MindfulSeverity.LOW -> Color(0xFFF7D9DD)
    MindfulSeverity.MEDIUM -> Color(0xFFF3C5CC)
    MindfulSeverity.HIGH -> Color(0xFFEDB0BA)
}
