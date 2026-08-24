package com.harvestglass.harvest.ui.gardener

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Chat characters and screenshot reviews are separate daily budgets. A
 * screenshot review used to cost 1,000 chat characters, which let one review
 * swallow a free user's whole day — these lock that separation in.
 */
class GardenerBudgetTest {

    @Test
    fun `spending every character does not lock the composer`() {
        val state = GardenerUiState(
            characterLimit = 2000,
            charactersUsedToday = 2000,
            screenshotLimit = 1,
            screenshotsUsedToday = 0
        )

        assertTrue(state.isAtCharacterLimit)
        assertFalse(state.isAtScreenshotLimit)
        assertFalse(state.isFullyLocked)
    }

    @Test
    fun `spending the screenshot allowance does not lock the composer`() {
        val state = GardenerUiState(
            characterLimit = 2000,
            charactersUsedToday = 100,
            screenshotLimit = 1,
            screenshotsUsedToday = 1
        )

        assertTrue(state.isAtScreenshotLimit)
        assertFalse(state.isFullyLocked)
    }

    @Test
    fun `only both budgets spent locks the composer`() {
        val state = GardenerUiState(
            characterLimit = 2000,
            charactersUsedToday = 2000,
            screenshotLimit = 1,
            screenshotsUsedToday = 1
        )

        assertTrue(state.isFullyLocked)
    }

    @Test
    fun `overspending never reports a negative remainder`() {
        val state = GardenerUiState(
            characterLimit = 2000,
            charactersUsedToday = 2500,
            screenshotLimit = 1,
            screenshotsUsedToday = 3
        )

        assertEquals(0, state.remainingCharacters)
        assertEquals(0, state.remainingScreenshots)
    }

    @Test
    fun `a fresh state carries the free tier allowances`() {
        val state = GardenerUiState()

        assertEquals(2000, state.remainingCharacters)
        assertEquals(1, state.remainingScreenshots)
        assertFalse(state.isFullyLocked)
    }
}
