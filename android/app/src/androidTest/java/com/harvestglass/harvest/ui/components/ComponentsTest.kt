package com.harvestglass.harvest.ui.components

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class ComponentsTest {
    @get:Rule val rule = createComposeRule()

    @Test
    fun glassCardRendersItsContent() {
        rule.setContent { HarvestAppTheme { GlassCard { SectionHeader("Notifications") } } }
        // SectionHeader uppercases, mirroring iOS .textCase(.uppercase)
        rule.onNodeWithText("NOTIFICATIONS").assertIsDisplayed()
    }

    @Test
    fun chipInvokesOnTap() {
        var taps = 0
        rule.setContent { HarvestAppTheme { ChipView(title = "Calm", onTap = { taps++ }) } }
        rule.onNodeWithText("Calm").performClick()
        assertEquals(1, taps)
    }

    @Test
    fun lightChipInvokesOnTap() {
        var taps = 0
        rule.setContent {
            HarvestAppTheme { ChipView(title = "Grounded", lightStyle = true, onTap = { taps++ }) }
        }
        rule.onNodeWithText("Grounded").performClick()
        assertEquals(1, taps)
    }

    @Test
    fun glassBadgeRendersText() {
        rule.setContent { HarvestAppTheme { GlassBadge(text = "Gold") } }
        rule.onNodeWithText("Gold").assertIsDisplayed()
    }

    @Test
    fun glassButtonInvokesOnClick() {
        var clicks = 0
        rule.setContent { HarvestAppTheme { GlassButton(title = "Continue") { clicks++ } } }
        rule.onNodeWithText("Continue").performClick()
        assertEquals(1, clicks)
    }
}
