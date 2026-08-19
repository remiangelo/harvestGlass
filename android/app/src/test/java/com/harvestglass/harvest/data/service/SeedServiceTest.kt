package com.harvestglass.harvest.data.service

import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The accept_seed RPC's response shape varies by transport, and the Swift
 * carries three fallbacks for it. That parsing is pure and worth pinning down —
 * getting it wrong means an accepted Seed opens nothing.
 */
class SeedServiceTest {
    private val service = SeedService(mockk(relaxed = true))

    @Test
    fun `a bare scalar uuid parses`() {
        assertEquals("abc-123", service.parseConversationId("\"abc-123\""))
    }

    @Test
    fun `a single-element array parses`() {
        assertEquals("abc-123", service.parseConversationId("[\"abc-123\"]"))
    }

    @Test
    fun `an unquoted body is trimmed`() {
        assertEquals("abc-123", service.parseConversationId("  abc-123\n"))
    }

    @Test
    fun `an empty body yields nothing`() {
        assertNull(service.parseConversationId("  \n "))
        assertNull(service.parseConversationId("\"\""))
    }

    @Test
    fun `an empty array yields nothing`() {
        // Deliberate divergence: Swift falls through and returns the literal
        // "[]" here, which would navigate to a conversation that doesn't exist.
        assertNull(service.parseConversationId("[]"))
    }

    @Test
    fun `the daily limit error carries the user-facing copy`() {
        assertEquals(
            "You've reached today's Seed limit. Upgrade or try again tomorrow.",
            SeedError.DailyLimitReached().message
        )
    }

    @Test
    fun `an underlying error carries its own message`() {
        assertEquals("boom", SeedError.Underlying("boom").message)
    }
}
