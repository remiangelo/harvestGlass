package com.harvestglass.harvest.ui.onboarding.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.onboarding.OnboardingUiState
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Ports of GoalsStepView, GenderStepView, InterestedInStepView and
 * RelationshipStatusStepView. All copy and all STORED values are verbatim —
 * the labels are what the user reads, the values are what the database holds.
 */

/** GoalsStepView. Stored verbatim, comma-joined at save time. */
val GOAL_OPTIONS = listOf(
    "Dating",
    "Relationship",
    "Long-term Commitment",
    "Marriage"
)

/** GenderStepView: label -> stored value (lowercased, spaces to hyphens). */
val GENDER_OPTIONS = listOf(
    Triple("Male", "male", Icons.Filled.Accessibility),
    Triple("Female", "female", Icons.Filled.Accessibility),
    Triple("Non-binary", "non-binary", Icons.Filled.Group),
    Triple("Prefer not to say", "prefer-not-to-say", Icons.Filled.PanTool)
)

/** InterestedInStepView: label -> stored value (lowercased). */
val INTERESTED_IN_LABELS = listOf(
    "Men" to "men",
    "Women" to "women",
    "Non-binary" to "non-binary",
    "Everyone" to "everyone"
)

/** RelationshipStatusStepView: stored value -> label. */
val RELATIONSHIP_STATUS_OPTIONS = listOf(
    "single" to "Single",
    "dating" to "Dating / exploring connections",
    "in_relationship" to "In a relationship",
    "engaged" to "Engaged",
    "married" to "Married"
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GoalsStep(state: OnboardingUiState, onToggle: (String) -> Unit) {
    StepScaffold(
        icon = Icons.Filled.TrackChanges,
        title = "What are you looking for?",
        subtitle = "Select all that apply"
    ) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
        ) {
            GOAL_OPTIONS.forEach { goal ->
                val isSelected = state.selectedGoals.contains(goal)
                val shape = RoundedCornerShape(percent = 50)
                Text(
                    text = goal,
                    style = HarvestTheme.Typography.bodySmall,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (isSelected) Color.White else HarvestTheme.Colors.textPrimary,
                    modifier = Modifier
                        .background(
                            if (isSelected) HarvestTheme.Colors.redSurface
                            else HarvestTheme.Colors.formSurface,
                            shape
                        )
                        .border(
                            1.dp,
                            if (isSelected) HarvestTheme.Colors.primaryLight
                            else HarvestTheme.Colors.formBorder,
                            shape
                        )
                        .clickable { onToggle(goal) }
                        .padding(
                            horizontal = HarvestTheme.Spacing.md,
                            vertical = HarvestTheme.Spacing.sm
                        )
                )
            }
        }
    }
}

@Composable
fun GenderStep(state: OnboardingUiState, onSelect: (String) -> Unit) {
    StepScaffold(
        icon = Icons.Filled.HelpOutline,
        title = "What's your gender?"
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
        ) {
            GENDER_OPTIONS.forEach { (label, value, icon) ->
                SelectableRow(
                    label = label,
                    isSelected = state.gender == value,
                    leading = icon,
                    onClick = { onSelect(value) }
                )
            }
        }
    }
}

@Composable
fun InterestedInStep(state: OnboardingUiState, onToggle: (String) -> Unit) {
    StepScaffold(
        icon = Icons.Filled.FavoriteBorder,
        title = "Who are you interested in?",
        subtitle = "Select all that apply"
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
        ) {
            INTERESTED_IN_LABELS.forEach { (label, value) ->
                SelectableRow(
                    label = label,
                    isSelected = state.interestedIn.contains(value),
                    onClick = { onToggle(value) }
                )
            }
        }
    }
}

@Composable
fun RelationshipStatusStep(state: OnboardingUiState, onSelect: (String) -> Unit) {
    // This step is left-aligned on iOS rather than centred, with a longer
    // explanatory paragraph, so it does not use StepScaffold.
    Column(
        verticalArrangement = Arrangement.spacedBy(20.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Text(
            text = "What is your current relationship status?",
            style = HarvestTheme.Typography.h3,
            fontWeight = FontWeight.Bold,
            color = HarvestTheme.Colors.textPrimary
        )

        Text(
            text = "Harvest communities are built around trust and intentional connection. " +
                "Please select your current relationship status honestly so you enter the " +
                "spaces designed for your current season.",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            RELATIONSHIP_STATUS_OPTIONS.forEach { (value, label) ->
                val isSelected = state.relationshipStatus == value
                val shape = RoundedCornerShape(12.dp)
                androidx.compose.foundation.layout.Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(
                            1.dp,
                            if (isSelected) HarvestTheme.Colors.primary
                            else HarvestTheme.Colors.textPrimary.copy(alpha = 0.3f),
                            shape
                        )
                        .clickable { onSelect(value) }
                        .padding(HarvestTheme.Spacing.md)
                ) {
                    Text(
                        text = label,
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    if (isSelected) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = HarvestTheme.Colors.primary
                        )
                    }
                }
            }
        }
    }
}
