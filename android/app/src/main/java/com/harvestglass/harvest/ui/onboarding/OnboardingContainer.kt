package com.harvestglass.harvest.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.onboarding.steps.AgeStep
import com.harvestglass.harvest.ui.onboarding.steps.CompleteStep
import com.harvestglass.harvest.ui.onboarding.steps.GenderStep
import com.harvestglass.harvest.ui.onboarding.steps.GoalsStep
import com.harvestglass.harvest.ui.onboarding.steps.InterestedInStep
import com.harvestglass.harvest.ui.onboarding.steps.LocationStep
import com.harvestglass.harvest.ui.onboarding.steps.NicknameStep
import com.harvestglass.harvest.ui.onboarding.steps.PhotosStep
import com.harvestglass.harvest.ui.onboarding.steps.ReflectionsStep
import com.harvestglass.harvest.ui.onboarding.steps.RelationshipStatusStep
import com.harvestglass.harvest.ui.onboarding.steps.TermsStep
import com.harvestglass.harvest.ui.onboarding.steps.ValuesStep
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme
import kotlinx.coroutines.launch

/**
 * Port of Harvest/Views/Onboarding/OnboardingContainerView.swift.
 *
 * Navigation is driven by `currentStep` rather than a NavHost: the wizard is a
 * strictly linear sequence over one shared draft, so a back stack of
 * destinations would duplicate state that already lives in the ViewModel.
 * The system back button is wired to `previousStep()` so it behaves the way
 * users expect, which is the behaviour a nav graph would have bought.
 */
@Composable
fun OnboardingContainer(
    userId: String,
    onComplete: () -> Unit,
    onSignOut: () -> Unit,
    onOpenTerms: () -> Unit = {},
    onOpenGuidelines: () -> Unit = {},
    viewModel: OnboardingViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    // Values and questions are loaded when their step is first reached.
    LaunchedEffect(state.currentStep) {
        when (state.currentStep) {
            OnboardingStep.VALUES -> viewModel.loadValuesIfNeeded()
            OnboardingStep.REFLECTIONS -> viewModel.loadQuestionsIfNeeded()
            else -> Unit
        }
    }

    BackHandler(enabled = state.currentStep != OnboardingStep.AGE) {
        viewModel.previousStep()
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
            // Background fills the screen; the wizard itself clears the bars.
            .systemBarsPadding()
    ) {
        TopBar(onSignOut = onSignOut)

        LinearProgressIndicator(
            progress = { state.progress },
            color = HarvestTheme.Colors.primary,
            trackColor = HarvestTheme.Colors.formBorder,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = HarvestTheme.Spacing.md)
        )

        Box(Modifier.weight(1f)) {
            when (state.currentStep) {
                OnboardingStep.AGE -> AgeStep(state, viewModel::setBirthDate)
                OnboardingStep.NICKNAME -> NicknameStep(state, viewModel::setNickname)
                OnboardingStep.PHOTOS -> PhotosStep(
                    state = state,
                    onPickPhoto = { bytes -> viewModel.uploadPhoto(userId, bytes) },
                    onRemovePhoto = { index -> viewModel.removePhoto(userId, index) }
                )
                OnboardingStep.GOALS -> GoalsStep(state, viewModel::toggleGoal)
                OnboardingStep.VALUES -> ValuesStep(
                    state = state,
                    onToggleBrought = viewModel::toggleValueBrought,
                    onToggleSought = viewModel::toggleValueSought
                )
                OnboardingStep.REFLECTIONS -> ReflectionsStep(
                    state = state,
                    onAnswer = viewModel::answerReflection,
                    onIndexChange = viewModel::setReflectionIndex,
                    onFinish = viewModel::nextStep
                )
                OnboardingStep.GENDER_IDENTITY -> GenderStep(state, viewModel::setGender)
                OnboardingStep.INTERESTED_IN -> InterestedInStep(state, viewModel::toggleInterestedIn)
                OnboardingStep.RELATIONSHIP_STATUS ->
                    RelationshipStatusStep(state, viewModel::setRelationshipStatus)
                OnboardingStep.LOCATION -> LocationStep(
                    state = state,
                    onQueryChange = viewModel::setLocationQuery,
                    onValidate = { viewModel.validateLocation() },
                    onSelectSuggestion = viewModel::selectLocationSuggestion
                )
                OnboardingStep.TERMS -> TermsStep(
                    state = state,
                    onAcceptedChange = viewModel::setTermsAccepted,
                    onOpenTerms = onOpenTerms,
                    onOpenGuidelines = onOpenGuidelines
                )
                OnboardingStep.COMPLETE -> CompleteStep(state) {
                    scope.launch {
                        if (viewModel.completeOnboarding(userId) != null) onComplete()
                    }
                }
            }
        }

        // iOS hides its own Back/Continue on reflections (which owns its
        // advance) and on complete (which has its own CTA).
        val showsNavButtons = state.currentStep != OnboardingStep.COMPLETE &&
            state.currentStep != OnboardingStep.REFLECTIONS

        if (showsNavButtons) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = HarvestTheme.Spacing.lg)
                    .padding(bottom = HarvestTheme.Spacing.lg)
            ) {
                if (state.currentStep != OnboardingStep.AGE) {
                    GlassButton(
                        title = "Back",
                        style = HarvestButtonKind.PRIMARY,
                        modifier = Modifier.weight(1f),
                        onClick = viewModel::previousStep
                    )
                }
                GlassButton(
                    title = "Continue",
                    style = HarvestButtonKind.PRIMARY,
                    modifier = Modifier
                        .weight(1f)
                        .alpha(if (state.canProceed) 1f else 0.5f)
                ) { if (state.canProceed) viewModel.nextStep() }
            }
        }
    }
}

@Composable
private fun TopBar(onSignOut: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.formBackground)
            .padding(HarvestTheme.Spacing.md)
    ) {
        Text(
            text = "Set Up Profile",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "Sign Out",
            style = HarvestTheme.Typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier
                .clickable { onSignOut() }
                .padding(horizontal = HarvestTheme.Spacing.sm)
        )
    }
}
