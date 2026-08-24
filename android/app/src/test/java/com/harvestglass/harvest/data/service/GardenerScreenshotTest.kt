package com.harvestglass.harvest.data.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The verdict parser is the one place a model's free-form reply becomes a
 * yes/no decision, so it is locked to the shapes GPT actually returns.
 */
class GardenerScreenshotTest {

    @Test
    fun `a bare verdict object parses`() {
        val verdict = GardenerService.parseVerdict(
            """{"is_chat_screenshot": true, "reply": "They're pulling back."}"""
        )

        assertTrue(verdict.isChatScreenshot)
        assertEquals("They're pulling back.", verdict.reply)
    }

    @Test
    fun `code fences are tolerated`() {
        val verdict = GardenerService.parseVerdict(
            "```json\n{\"is_chat_screenshot\": false, \"reply\": \"\"}\n```"
        )

        assertFalse(verdict.isChatScreenshot)
        assertEquals("", verdict.reply)
    }

    @Test
    fun `prose around the object is tolerated`() {
        val verdict = GardenerService.parseVerdict(
            "Sure! {\"is_chat_screenshot\": true, \"reply\": \"Ask directly.\"} Hope that helps."
        )

        assertTrue(verdict.isChatScreenshot)
        assertEquals("Ask directly.", verdict.reply)
    }

    // Ambiguity has to fail closed: a reply we can't read must not be
    // presented as coaching about a conversation.
    @Test
    fun `a non-boolean flag reads as not a screenshot`() {
        val verdict = GardenerService.parseVerdict("""{"is_chat_screenshot": "yes", "reply": "x"}""")

        assertFalse(verdict.isChatScreenshot)
    }

    @Test(expected = IllegalStateException::class)
    fun `a reply with no object at all throws`() {
        GardenerService.parseVerdict("I'm not sure what that image is.")
    }

    @Test
    fun `the placeholder matches the iOS wording`() {
        assertEquals("📷 Screenshot", GardenerService.screenshotPlaceholder(""))
        assertEquals(
            "📷 Screenshot — is this a red flag?",
            GardenerService.screenshotPlaceholder("is this a red flag?")
        )
    }

    // Same user, same day, same question — the quiz must not reshuffle on
    // every open.
    @Test
    fun `question selection is stable for a user`() {
        val bank = listOf("a", "b", "c", "d", "e")

        val first = GardenerService.selectQuestion(bank, "user-1")
        val second = GardenerService.selectQuestion(bank, "user-1")

        assertEquals(first, second)
        assertTrue(bank.contains(first))
    }

    @Test
    fun `a single-question bank still selects`() {
        assertEquals("only", GardenerService.selectQuestion(listOf("only"), "user-1"))
    }
}
