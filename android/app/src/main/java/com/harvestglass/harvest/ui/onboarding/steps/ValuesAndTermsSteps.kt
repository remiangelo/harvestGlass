package com.harvestglass.harvest.ui.onboarding.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.onboarding.OnboardingUiState
import com.harvestglass.harvest.ui.onboarding.OnboardingViewModel
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Ports of ValuesStepView, ReflectionsStepView, TermsStepView and CompleteView. */

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ValuesStep(
    state: OnboardingUiState,
    onToggleBrought: (String) -> Unit,
    onToggleSought: (String) -> Unit
) {
    var broughtMode by remember { mutableIntStateOf(0) }
    val isBrought = broughtMode == 0
    val currentSet = if (isBrought) state.selectedValuesBrought else state.selectedValuesSought
    val max = OnboardingViewModel.MAX_VALUE_SELECTIONS

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier.fillMaxSize()
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
            modifier = Modifier.padding(top = HarvestTheme.Spacing.md)
        ) {
            Icon(
                Icons.Filled.Favorite,
                contentDescription = null,
                tint = HarvestTheme.Colors.primary,
                modifier = Modifier.size(40.dp)
            )
            Text(
                text = "Your values",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Pick what you bring and what you seek. We match on values, not just photos.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
            )
        }

        // Stands in for the iOS segmented Picker.
        Row(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
        ) {
            SegmentButton("I bring", isBrought) { broughtMode = 0 }
            SegmentButton("I seek", !isBrought) { broughtMode = 1 }
        }

        Text(
            text = "${currentSet.size}/$max selected · pick at least 1",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )

        if (state.isLoadingValues) {
            Spacer(Modifier.weight(1f))
            CircularProgressIndicator(color = HarvestTheme.Colors.primary)
            Spacer(Modifier.weight(1f))
        } else {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = HarvestTheme.Spacing.lg)
            ) {
                state.allValues.forEach { value ->
                    ChipView(
                        title = value.name,
                        isSelected = currentSet.contains(value.id),
                        lightStyle = true,
                        onTap = {
                            if (isBrought) onToggleBrought(value.id) else onToggleSought(value.id)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SegmentButton(label: String, isSelected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
    Text(
        text = label,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) HarvestTheme.Colors.textOnRedPrimary else HarvestTheme.Colors.textPrimary,
        modifier = Modifier
            .background(
                if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.formSurface,
                shape
            )
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .clickable { onClick() }
            .padding(horizontal = HarvestTheme.Spacing.lg, vertical = HarvestTheme.Spacing.sm)
    )
}

@Composable
fun ReflectionsStep(
    state: OnboardingUiState,
    onAnswer: (questionId: String, optionId: String) -> Unit,
    onIndexChange: (Int) -> Unit,
    onFinish: () -> Unit
) {
    val question = state.allQuestions.getOrNull(state.currentReflectionIndex)
    val selectedOptionId = question?.let { state.reflectionAnswers[it.id] }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = HarvestTheme.Spacing.lg)
            .padding(bottom = HarvestTheme.Spacing.lg)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
            modifier = Modifier.padding(top = HarvestTheme.Spacing.md)
        ) {
            Icon(
                Icons.Filled.AutoAwesome,
                contentDescription = null,
                tint = HarvestTheme.Colors.primary,
                modifier = Modifier.size(40.dp)
            )
            Text(
                text = "A few reflections",
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )
            if (state.allQuestions.isNotEmpty()) {
                Text(
                    text = "Question ${state.currentReflectionIndex + 1} of ${state.allQuestions.size}",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary
                )
            }
        }

        when {
            state.isLoadingQuestions -> {
                Spacer(Modifier.weight(1f))
                CircularProgressIndicator(color = HarvestTheme.Colors.primary)
                Spacer(Modifier.weight(1f))
            }

            question != null -> {
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                ) {
                    Text(
                        text = question.prompt,
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.padding(bottom = HarvestTheme.Spacing.xs)
                    )
                    question.options.forEach { option ->
                        OptionRow(
                            label = option.label,
                            isSelected = selectedOptionId == option.id,
                            onClick = { onAnswer(option.questionId, option.id) }
                        )
                    }
                }

                // The container hides its own Back/Continue on this step, so
                // reflections owns its advance (one question at a time).
                Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                    if (state.currentReflectionIndex > 0) {
                        GlassButton(
                            title = "Back",
                            style = HarvestButtonKind.PRIMARY,
                            modifier = Modifier.weight(1f)
                        ) { onIndexChange(state.currentReflectionIndex - 1) }
                    }
                    GlassButton(
                        title = "Continue",
                        style = HarvestButtonKind.PRIMARY,
                        modifier = Modifier
                            .weight(1f)
                            .alpha(if (selectedOptionId == null) 0.5f else 1f)
                    ) {
                        if (selectedOptionId == null) return@GlassButton
                        if (state.currentReflectionIndex >= state.allQuestions.size - 1) {
                            onFinish()
                        } else {
                            onIndexChange(state.currentReflectionIndex + 1)
                        }
                    }
                }
            }

            else -> Text(
                text = "No questions available.",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary
            )
        }
    }
}

@Composable
private fun OptionRow(label: String, isSelected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isSelected) HarvestTheme.Colors.primary.copy(alpha = 0.15f)
                else HarvestTheme.Colors.formBackground,
                shape
            )
            .border(
                1.dp,
                if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.divider,
                shape
            )
            .clickable { onClick() }
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            imageVector = if (isSelected) Icons.Filled.RadioButtonChecked else Icons.Filled.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.textSecondary
        )
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}

@Composable
fun TermsStep(
    state: OnboardingUiState,
    onAcceptedChange: (Boolean) -> Unit,
    onOpenTerms: () -> Unit,
    onOpenGuidelines: () -> Unit
) {
    StepScaffold(icon = Icons.Filled.Description, title = "Terms & Conditions") {
        GlassCard(
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg),
            style = com.harvestglass.harvest.ui.components.GlassCardStyle.LIGHT,
            padding = HarvestTheme.Spacing.lg
        ) {
            Text(
                text = "By using Harvest, you agree to:",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary
            )
            Spacer(Modifier.height(HarvestTheme.Spacing.sm))
            listOf(
                "Treat others with respect and kindness",
                "Be honest in your profile information",
                "Report any suspicious or harmful behavior",
                "Be at least 18 years old"
            ).forEach { bullet ->
                Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    Text("•", style = HarvestTheme.Typography.bodySmall, color = HarvestTheme.Colors.textSecondary)
                    Text(
                        text = bullet,
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }

            Spacer(Modifier.height(HarvestTheme.Spacing.md))
            Text(
                text = "There is zero tolerance for objectionable content or abusive behavior. " +
                    "Violations result in content removal and account termination, reviewed within 24 hours.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textPrimary
            )

            Spacer(Modifier.height(HarvestTheme.Spacing.sm))
            Text(
                text = "Harvest is built on trust, intentionality, and authentic connection. Users are " +
                    "expected to accurately represent their relationship status. If we determine that " +
                    "someone intentionally misrepresented their relationship status to access communities " +
                    "that do not align with their current relationship season, Harvest reserves the right " +
                    "to restrict, suspend, or remove access to the platform.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textPrimary
            )

            Spacer(Modifier.height(HarvestTheme.Spacing.sm))
            Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                Text(
                    text = "Terms of Service",
                    style = HarvestTheme.Typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.primary,
                    modifier = Modifier.clickable { onOpenTerms() }
                )
                Text(
                    text = "Community Guidelines",
                    style = HarvestTheme.Typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.primary,
                    modifier = Modifier.clickable { onOpenGuidelines() }
                )
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .padding(horizontal = HarvestTheme.Spacing.lg)
                .clickable { onAcceptedChange(!state.termsAccepted) }
        ) {
            Icon(
                imageVector = if (state.termsAccepted) Icons.Filled.CheckBox else Icons.Filled.CheckBoxOutlineBlank,
                contentDescription = null,
                tint = if (state.termsAccepted) {
                    HarvestTheme.Colors.primary
                } else {
                    HarvestTheme.Colors.textSecondary.copy(alpha = 0.55f)
                }
            )
            Text(
                text = "I agree to the Terms, Community Guidelines, and zero-tolerance policy",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textPrimary
            )
        }
    }
}

@Composable
fun CompleteStep(state: OnboardingUiState, onFinish: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xl),
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = HarvestTheme.Spacing.lg)
    ) {
        Spacer(Modifier.weight(1f))

        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(120.dp)
                    .background(HarvestTheme.Colors.accent.copy(alpha = 0.2f), CircleShape)
            )
            Icon(
                Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = HarvestTheme.Colors.accent,
                modifier = Modifier.size(70.dp)
            )
        }

        Text(
            text = "You're all set!",
            style = HarvestTheme.Typography.h1,
            color = HarvestTheme.Colors.textPrimary
        )

        Text(
            text = "Meet your AI coach — let's find values-aligned matches",
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.weight(1f))

        GlassButton(
            title = "Meet The Gardener",
            style = HarvestButtonKind.PRIMARY,
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.lg)
        ) { if (!state.isLoading) onFinish() }

        if (state.isLoading) {
            CircularProgressIndicator(color = HarvestTheme.Colors.primary)
        }

        state.error?.let {
            Text(
                text = it,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                textAlign = TextAlign.Center
            )
        }

        Spacer(Modifier.height(HarvestTheme.Spacing.xxl))
    }
}
