package com.harvestglass.harvest.data.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Gardener re-paragraphs its own replies so a wall of text never lands in
 * the chat. Mirrors formatResponse/splitIntoSentences in GardenerService.swift.
 */
class GardenerFormatTest {

    @Test
    fun `text that already has paragraphs is left alone`() {
        val input = "First thought.\n\nSecond thought."
        assertEquals(input, GardenerFormatter.format(input))
    }

    @Test
    fun `single newlines become paragraph breaks`() {
        assertEquals(
            "One.\n\nTwo.\n\nThree.",
            GardenerFormatter.format("One.\nTwo.\nThree.")
        )
    }

    @Test
    fun `three sentences or fewer stay as one paragraph`() {
        val input = "One. Two. Three."
        assertEquals(input, GardenerFormatter.format(input))
    }

    @Test
    fun `four or more sentences are grouped in pairs`() {
        assertEquals(
            "One. Two.\n\nThree. Four.",
            GardenerFormatter.format("One. Two. Three. Four.")
        )
    }

    @Test
    fun `a trailing group of three stays together`() {
        // 5 sentences: 2 + 3, never leaving a orphan.
        assertEquals(
            "One. Two.\n\nThree. Four. Five.",
            GardenerFormatter.format("One. Two. Three. Four. Five.")
        )
    }

    @Test
    fun `question and exclamation marks end sentences too`() {
        assertEquals(
            "One? Two!\n\nThree. Four.",
            GardenerFormatter.format("One? Two! Three. Four.")
        )
    }

    @Test
    fun `text with no terminator is returned as-is`() {
        assertEquals("no terminator here", GardenerFormatter.format("no terminator here"))
    }

    @Test
    fun `an unterminated tail is folded into the last sentence`() {
        val out = GardenerFormatter.format("One. Two. Three. Four and then some")
        assertTrue(out.endsWith("Four and then some"))
    }

    @Test
    fun `carriage returns are normalised and edges trimmed`() {
        assertEquals("One.\n\nTwo.", GardenerFormatter.format("  One.\r\nTwo.  "))
    }

    @Test
    fun `blank input is returned unchanged`() {
        assertEquals("   ", GardenerFormatter.format("   "))
    }
}
