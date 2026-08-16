package com.harvestglass.harvest.ui.components.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.time.Instant
import java.time.temporal.ChronoUnit

/** Mirrors DateSeparator.label in Harvest/Views/Components/Chat/DateSeparator.swift. */
class DateSeparatorTest {

    private val now: Instant = Instant.parse("2026-08-16T12:00:00Z")

    private fun daysBefore(n: Long): Instant = now.minus(n, ChronoUnit.DAYS)

    @Test
    fun `same day reads Today`() {
        assertEquals("Today", dateSeparatorLabel(now, now))
    }

    @Test
    fun `one day back reads Yesterday`() {
        assertEquals("Yesterday", dateSeparatorLabel(daysBefore(1), now))
    }

    @Test
    fun `two to six days back reads as a weekday`() {
        val label = dateSeparatorLabel(daysBefore(3), now)
        assertNotEquals("Today", label)
        assertNotEquals("Yesterday", label)
        // A weekday name, not a numeric date.
        assertEquals(true, label.any { it.isLetter() } && label.none { it.isDigit() })
    }

    @Test
    fun `beyond a week falls back to a full date`() {
        val label = dateSeparatorLabel(daysBefore(30), now)
        assertEquals(true, label.any { it.isDigit() })
    }

    @Test
    fun `a future date does not render as a weekday`() {
        // Shouldn't happen, but must not read as "next Tuesday".
        val label = dateSeparatorLabel(now.plus(5, ChronoUnit.DAYS), now)
        assertEquals(true, label.any { it.isDigit() })
    }
}
