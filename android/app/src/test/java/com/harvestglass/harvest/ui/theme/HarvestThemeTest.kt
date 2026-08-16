package com.harvestglass.harvest.ui.theme

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Guards the token port against a mistyped hex. Every expected value is read
 * off Harvest/Theme/HarvestTheme.swift.
 */
class HarvestThemeTest {

    @Test
    fun `core surface tokens match the iOS palette`() {
        assertEquals(Color(0xFFE6C6B6), HarvestTheme.Colors.wineBlack)
        assertEquals(Color(0xFFF0D5C8), HarvestTheme.Colors.deepPlum)
        assertEquals(Color(0xFFFFF9F5), HarvestTheme.Colors.wineCard)
        assertEquals(Color(0xFFFFFFFF), HarvestTheme.Colors.wineRaised)
        assertEquals(Color(0xFF2A1714), HarvestTheme.Colors.photoScrim)
    }

    @Test
    fun `red accent family matches the iOS palette`() {
        assertEquals(Color(0xFFDB2637), HarvestTheme.Colors.rose)
        assertEquals(Color(0xFFEE6A72), HarvestTheme.Colors.roseLight)
        assertEquals(Color(0xFFA81C2B), HarvestTheme.Colors.roseDeep)
        assertEquals(Color(0xFFC94F58), HarvestTheme.Colors.roseBloom)
        assertEquals(Color(0xFFD97A28), HarvestTheme.Colors.amber)
        assertEquals(Color(0xFFC41F2E), HarvestTheme.Colors.accent)
    }

    @Test
    fun `field greens match the iOS palette`() {
        assertEquals(Color(0xFF2E7D5B), HarvestTheme.Colors.fieldGreen)
        assertEquals(Color(0xFF246B4C), HarvestTheme.Colors.fieldGreenLight)
        assertEquals(Color(0xFF1E5A40), HarvestTheme.Colors.fieldGreenDeep)
    }

    @Test
    fun `text tokens are warm darks on a light page`() {
        assertEquals(Color(0xFF2B1A16), HarvestTheme.Colors.textPrimary)
        assertEquals(Color(0xFF6E524A), HarvestTheme.Colors.textSecondary)
        assertEquals(Color(0xFF8A6E66), HarvestTheme.Colors.textTertiary)
        assertEquals(Color(0xFFFFFFFF), HarvestTheme.Colors.textInverse)
    }

    @Test
    fun `semantic aliases point at the same colors as iOS`() {
        assertEquals(HarvestTheme.Colors.rose, HarvestTheme.Colors.primary)
        assertEquals(HarvestTheme.Colors.roseDeep, HarvestTheme.Colors.primaryDark)
        assertEquals(HarvestTheme.Colors.deepPlum, HarvestTheme.Colors.background)
        assertEquals(HarvestTheme.Colors.wineCard, HarvestTheme.Colors.surface)
        assertEquals(HarvestTheme.Colors.wineBlack, HarvestTheme.Colors.tabBarBackground)
        assertEquals(HarvestTheme.Colors.rose, HarvestTheme.Colors.success)
    }
}
