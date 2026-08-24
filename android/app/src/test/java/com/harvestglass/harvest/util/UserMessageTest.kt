package com.harvestglass.harvest.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Postgrest exceptions stringify the whole request — including
 * `Authorization: Bearer <JWT>` — and those strings were being rendered
 * straight into the UI. Found while previewing the community chat: an invalid
 * room id put the signed-in user's access token on screen.
 */
class UserMessageTest {

    private val postgrestStyle = """
        invalid input syntax for type uuid: "c1"
        URL: https://xyz.supabase.co/rest/v1/community_prompts?or=%28community_id.eq.c1%29
        Headers: [Authorization=[Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.SECRET], apikey=[eyJhb.SECRET]]
        Http Method: GET
    """.trimIndent()

    @Test
    fun `only the first line survives`() {
        assertEquals(
            "invalid input syntax for type uuid: \"c1\"",
            RuntimeException(postgrestStyle).userMessage()
        )
    }

    @Test
    fun `no bearer token can reach the UI`() {
        val shown = RuntimeException(postgrestStyle).userMessage()
        assertFalse(shown.contains("Bearer"))
        assertFalse(shown.contains("eyJhb"))
        assertFalse(shown.contains("apikey"))
    }

    @Test
    fun `a URL on the same line is still cut`() {
        val e = RuntimeException("boom URL: https://xyz.supabase.co/rest/v1/x?apikey=SECRET")
        assertEquals("boom", e.userMessage())
    }

    @Test
    fun `an ordinary message passes through untouched`() {
        assertEquals("You've reached today's Seed limit.", RuntimeException("You've reached today's Seed limit.").userMessage())
    }

    @Test
    fun `an over-long line is capped`() {
        val shown = RuntimeException("x".repeat(500)).userMessage()
        assertTrue(shown.length <= 200)
    }

    @Test
    fun `a message-less exception falls back to something sayable`() {
        assertEquals("Something went wrong. Please try again.", RuntimeException().userMessage())
        assertEquals("Something went wrong. Please try again.", RuntimeException("   ").userMessage())
    }
}
