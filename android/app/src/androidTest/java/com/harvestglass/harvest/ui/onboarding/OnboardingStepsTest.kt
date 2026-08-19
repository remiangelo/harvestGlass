package com.harvestglass.harvest.ui.onboarding

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.harvestglass.harvest.ui.onboarding.steps.GenderStep
import com.harvestglass.harvest.ui.onboarding.steps.GoalsStep
import com.harvestglass.harvest.ui.onboarding.steps.InterestedInStep
import com.harvestglass.harvest.ui.onboarding.steps.NicknameStep
import com.harvestglass.harvest.ui.onboarding.steps.RelationshipStatusStep
import com.harvestglass.harvest.ui.onboarding.steps.TermsStep
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/**
 * The labels are what a user reads; the emitted values are what the database
 * stores. A port that mixes them up corrupts data silently, so each choice
 * step is asserted on the value it emits, not the text it shows.
 */
class OnboardingStepsTest {
    @get:Rule val rule = createComposeRule()

    private fun state(step: OnboardingStep) = OnboardingUiState(currentStep = step)

    @Test
    fun relationshipStatusEmitsTheStoredValueNotTheLabel() {
        var picked: String? = null
        rule.setContent {
            HarvestAppTheme {
                RelationshipStatusStep(
                    state = state(OnboardingStep.RELATIONSHIP_STATUS),
                    onSelect = { picked = it }
                )
            }
        }
        rule.onNodeWithText("In a relationship").performClick()
        assertEquals("in_relationship", picked)
    }

    @Test
    fun relationshipStatusShowsTheHonestyExplanation() {
        rule.setContent {
            HarvestAppTheme {
                RelationshipStatusStep(state(OnboardingStep.RELATIONSHIP_STATUS)) {}
            }
        }
        rule.onNodeWithText("What is your current relationship status?").assertIsDisplayed()
        rule.onNodeWithText("Dating / exploring connections").assertIsDisplayed()
    }

    @Test
    fun genderEmitsTheHyphenatedStoredValue() {
        var picked: String? = null
        rule.setContent {
            HarvestAppTheme {
                GenderStep(state(OnboardingStep.GENDER_IDENTITY), onSelect = { picked = it })
            }
        }
        rule.onNodeWithText("Prefer not to say").performClick()
        assertEquals("prefer-not-to-say", picked)
    }

    @Test
    fun interestedInEmitsLowercasedValues() {
        var picked: String? = null
        rule.setContent {
            HarvestAppTheme {
                InterestedInStep(state(OnboardingStep.INTERESTED_IN), onToggle = { picked = it })
            }
        }
        rule.onNodeWithText("Women").performClick()
        assertEquals("women", picked)
    }

    @Test
    fun goalsEmitTheirLabelVerbatimBecauseThatIsWhatIsStored() {
        var picked: String? = null
        rule.setContent {
            HarvestAppTheme {
                GoalsStep(state(OnboardingStep.GOALS), onToggle = { picked = it })
            }
        }
        rule.onNodeWithText("Long-term Commitment").performClick()
        assertEquals("Long-term Commitment", picked)
    }

    @Test
    fun termsToggleFlipsAcceptance() {
        var accepted: Boolean? = null
        rule.setContent {
            HarvestAppTheme {
                TermsStep(
                    state = state(OnboardingStep.TERMS),
                    onAcceptedChange = { accepted = it },
                    onOpenTerms = {},
                    onOpenGuidelines = {}
                )
            }
        }
        rule.onNodeWithText(
            "I agree to the Terms, Community Guidelines, and zero-tolerance policy"
        ).performClick()
        assertEquals(true, accepted)
    }

    @Test
    fun termsShowsTheZeroToleranceClause() {
        rule.setContent {
            HarvestAppTheme {
                TermsStep(state(OnboardingStep.TERMS), {}, {}, {})
            }
        }
        rule.onNodeWithText("Be at least 18 years old").assertIsDisplayed()
    }

    @Test
    fun nicknameFieldReportsWhatIsTyped() {
        var typed: String? = null
        rule.setContent {
            HarvestAppTheme {
                NicknameStep(state(OnboardingStep.NICKNAME), onNicknameChange = { typed = it })
            }
        }
        rule.onNodeWithContentDescription("Your nickname").performTextInput("Ada")
        assertEquals("Ada", typed)
    }
}
