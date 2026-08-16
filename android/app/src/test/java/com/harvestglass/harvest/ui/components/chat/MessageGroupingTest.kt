package com.harvestglass.harvest.ui.components.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Rules mirror MessageGrouping.swift exactly. */
class MessageGroupingTest {

    private fun at(iso: String) = MessageGrouping.date(iso)

    @Test
    fun `microsecond timestamps parse`() {
        // Postgres emits six fractional digits; commit bd4528a fixed this on iOS.
        assertNotNull(MessageGrouping.date("2026-08-16T10:00:00.123456+00:00"))
    }

    @Test
    fun `whole-second timestamps parse`() {
        assertNotNull(MessageGrouping.date("2026-08-16T10:00:00+00:00"))
    }

    @Test
    fun `a null or unusable timestamp yields null`() {
        assertNull(MessageGrouping.date(null))
        assertNull(MessageGrouping.date("not a date"))
    }

    @Test
    fun `consecutive messages from one sender inside the window group`() {
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = at("2026-08-16T10:00:00.000001+00:00"),
            currentSender = "u1", currentDate = at("2026-08-16T10:00:30.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertFalse(p.isFirstInGroup)
        assertTrue(p.isLastInGroup)
    }

    @Test
    fun `a different sender starts a new group`() {
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = at("2026-08-16T10:00:00.000001+00:00"),
            currentSender = "u2", currentDate = at("2026-08-16T10:00:30.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertTrue(p.isFirstInGroup)
        assertTrue(p.isLastInGroup)
    }

    @Test
    fun `the same sender beyond the five minute window starts a new group`() {
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = at("2026-08-16T10:00:00.000001+00:00"),
            currentSender = "u1", currentDate = at("2026-08-16T10:06:00.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertTrue(p.isFirstInGroup)
    }

    @Test
    fun `the top of the transcript always shows a date separator`() {
        val p = MessageGrouping.position(
            previousSender = null, previousDate = null,
            currentSender = "u1", currentDate = at("2026-08-16T10:00:00.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertTrue(p.showsDateSeparator)
    }

    @Test
    fun `a day change shows a date separator`() {
        // A full 24h apart, so this holds in any local zone. Both this and
        // the Swift original compare calendar days in the *local* zone
        // (Calendar.current), so near-midnight UTC pairs are zone-dependent
        // and would make the test, not the logic, flaky.
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = at("2026-08-15T12:00:00.000001+00:00"),
            currentSender = "u1", currentDate = at("2026-08-16T12:00:00.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertTrue(p.showsDateSeparator)
    }

    @Test
    fun `an unusable previous timestamp does not invent a break`() {
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = null,
            currentSender = "u1", currentDate = at("2026-08-16T10:00:00.000001+00:00"),
            nextSender = null, nextDate = null
        )
        assertFalse(p.showsDateSeparator)
    }

    @Test
    fun `a message without a usable timestamp stands alone`() {
        val p = MessageGrouping.position(
            previousSender = "u1", previousDate = at("2026-08-16T10:00:00.000001+00:00"),
            currentSender = "u1", currentDate = null,
            nextSender = "u1", nextDate = at("2026-08-16T10:00:10.000001+00:00")
        )
        assertFalse(p.showsDateSeparator)
        assertTrue(p.isFirstInGroup)
        assertTrue(p.isLastInGroup)
    }
}
