package com.harvestglass.harvest.ui.components

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ValuesRadarCardTest {
    @get:Rule val rule = createComposeRule()

    @Test
    fun emptyScoresShowThePrompt() {
        rule.setContent { HarvestAppTheme { ValuesRadarCard(AxisScores(), "I Need") } }
        rule.onNodeWithText("Answer a few questions to map your values.").assertIsDisplayed()
    }

    @Test
    fun emptyStateStartButtonFires() {
        var tapped = false
        rule.setContent {
            HarvestAppTheme {
                ValuesRadarCard(AxisScores(), "I Need", onEmptyTap = { tapped = true })
            }
        }
        rule.onNodeWithText("Start").performClick()
        assertTrue(tapped)
    }

    @Test
    fun theEmptyStateHasNoStartButtonWithoutAnAction() {
        rule.setContent { HarvestAppTheme { ValuesRadarCard(AxisScores(), "I Need") } }
        rule.onNodeWithText("Start").assertDoesNotExist()
    }

    @Test
    fun nonEmptyScoresShowTheLegendNotThePrompt() {
        rule.setContent {
            HarvestAppTheme { ValuesRadarCard(AxisScores(connection = 22.0), "I Need") }
        }
        rule.onNodeWithText("I Need").assertIsDisplayed()
        rule.onNodeWithText("Answer a few questions to map your values.").assertDoesNotExist()
    }

    @Test
    fun bothSeriesAppearInTheLegend() {
        rule.setContent {
            HarvestAppTheme {
                ValuesRadarCard(
                    primary = AxisScores(connection = 22.0),
                    primaryLabel = "I Need",
                    secondary = AxisScores(growth = 12.0),
                    secondaryLabel = "They Bring"
                )
            }
        }
        rule.onNodeWithText("I Need").assertIsDisplayed()
        rule.onNodeWithText("They Bring").assertIsDisplayed()
    }

    @Test
    fun aZeroSecondarySeriesIsLeftOutOfTheLegend() {
        rule.setContent {
            HarvestAppTheme {
                ValuesRadarCard(
                    primary = AxisScores(connection = 22.0),
                    primaryLabel = "I Need",
                    secondary = AxisScores(),
                    secondaryLabel = "They Bring"
                )
            }
        }
        rule.onNodeWithText("They Bring").assertDoesNotExist()
    }

    @Test
    fun theDefaultTitleIsShown() {
        rule.setContent { HarvestAppTheme { ValuesRadarCard(AxisScores(), "I Need") } }
        rule.onNodeWithText("Your Values Map").assertIsDisplayed()
    }
}
