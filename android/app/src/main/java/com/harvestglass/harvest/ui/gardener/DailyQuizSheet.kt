package com.harvestglass.harvest.ui.gardener

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.data.model.DailyQuiz
import com.harvestglass.harvest.ui.components.GlassBadge
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Fallback insight text, matching the one iOS falls back to inline. */
private const val GENERIC_INSIGHT =
    "Great reflection! Self-awareness is key to meaningful connections."

/**
 * Port of Harvest/Views/Gardener/DailyQuizPopup.swift.
 *
 * Submission is one-way: once answered, the options lock and the insight
 * replaces the Submit button, exactly as on iOS.
 */
@Composable
fun DailyQuizSheet(
    quiz: DailyQuiz,
    isSubmitting: Boolean,
    onAnswer: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedOption by remember(quiz.id) { mutableStateOf(quiz.selectedAnswer) }
    var isSubmitted by remember(quiz.id) { mutableStateOf(quiz.isAnswered) }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            horizontalArrangement = Arrangement.End,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Icon(
                Icons.Filled.Cancel,
                contentDescription = "Close",
                tint = HarvestTheme.Colors.textTertiary,
                modifier = Modifier
                    .size(24.dp)
                    .clickable { onDismiss() }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = HarvestTheme.Spacing.md)
                .padding(bottom = HarvestTheme.Spacing.lg)
                .navigationBarsPadding()
        ) {
            GlassBadge(
                text = quiz.category.raw.replace('_', ' ')
                    .split(' ')
                    .joinToString(" ") { word -> word.replaceFirstChar { it.uppercase() } },
                color = HarvestTheme.Colors.accent
            )

            Text(
                text = "Daily Reflection",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )

            Text(
                text = quiz.question,
                style = HarvestTheme.Typography.bodyLarge,
                color = HarvestTheme.Colors.textPrimary,
                textAlign = TextAlign.Center
            )

            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                quiz.options.forEach { option ->
                    GlassCard(
                        modifier = Modifier.clickable(enabled = !isSubmitted) {
                            selectedOption = option.text
                        }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = option.text,
                                style = HarvestTheme.Typography.bodyRegular,
                                color = HarvestTheme.Colors.textPrimary,
                                modifier = Modifier.weight(1f)
                            )
                            val isChosen = selectedOption == option.text
                            Icon(
                                imageVector = when {
                                    isChosen && isSubmitted -> Icons.Filled.CheckCircle
                                    isChosen -> Icons.Filled.Circle
                                    else -> Icons.Outlined.Circle
                                },
                                contentDescription = null,
                                tint = if (isChosen) {
                                    HarvestTheme.Colors.primary
                                } else {
                                    HarvestTheme.Colors.textTertiary
                                },
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }

            if (isSubmitted) {
                GlassCard {
                    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                        ) {
                            Icon(
                                Icons.Filled.Lightbulb,
                                contentDescription = null,
                                tint = HarvestTheme.Colors.warning,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = "Insight",
                                style = HarvestTheme.Typography.h4,
                                color = HarvestTheme.Colors.textPrimary
                            )
                        }
                        Text(
                            text = quiz.insight
                                ?: if (isSubmitting) "Thinking…" else GENERIC_INSIGHT,
                            style = HarvestTheme.Typography.bodySmall,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }
            }

            if (isSubmitted) {
                HarvestButton(
                    text = "Close",
                    kind = HarvestButtonKind.SECONDARY,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onDismiss
                )
            } else {
                HarvestButton(
                    text = "Submit",
                    icon = Icons.Filled.Check,
                    kind = HarvestButtonKind.PRIMARY,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    val answer = selectedOption ?: return@HarvestButton
                    onAnswer(answer)
                    isSubmitted = true
                }
            }
        }
    }
}
