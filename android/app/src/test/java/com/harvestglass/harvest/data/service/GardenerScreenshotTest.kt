package com.harvestglass.harvest.data.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The image call returns prose, not JSON. The only structure is the refusal
 * sentinel — the previous JSON verdict was truncated by maxTokens on long
 * replies and surfaced as "The Gardener returned no verdict".
 */
class GardenerScreenshotTest {

    @Test
    fun `a caption becomes a text part before the images`() {
        val parts = GardenerService.imageParts("what do you think?", listOf("data:a", "data:b"))

        assertEquals(3, parts.size)
        assertEquals(OpenAIService.ContentPart.Text("what do you think?"), parts[0])
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:a"), parts[1])
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:b"), parts[2])
    }

    @Test
    fun `an empty caption contributes no text part`() {
        val parts = GardenerService.imageParts("   ", listOf("data:a"))

        assertEquals(1, parts.size)
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:a"), parts[0])
    }

    @Test
    fun `image order is selection order`() {
        val urls = listOf("data:1", "data:2", "data:3")
        val parts = GardenerService.imageParts("", urls)

        assertEquals(urls, parts.map { (it as OpenAIService.ContentPart.ImageUrl).url })
    }

    @Test
    fun `the sentinel becomes the canned refusal`() {
        assertEquals(GardenerService.EXPLICIT_REFUSAL_REPLY, GardenerService.resolveReply("REFUSE_EXPLICIT"))
    }

    @Test
    fun `the sentinel is recognised with surrounding whitespace`() {
        assertEquals(
            GardenerService.EXPLICIT_REFUSAL_REPLY,
            GardenerService.resolveReply("  REFUSE_EXPLICIT\n\n")
        )
    }

    /** A reply that merely mentions the sentinel is a real reply. */
    @Test
    fun `prose containing the word is not a refusal`() {
        val raw = "I won't REFUSE_EXPLICIT anything here — the tone reads warm."
        assertTrue(GardenerService.resolveReply(raw).contains("tone reads warm"))
    }

    @Test
    fun `ordinary prose is formatted and returned`() {
        assertEquals("They're pulling back.", GardenerService.resolveReply("They're pulling back."))
    }

    @Test
    fun `the placeholder is singular for one image`() {
        assertEquals("📷 Screenshot — read this", GardenerService.screenshotPlaceholder("read this", 1))
    }

    @Test
    fun `the placeholder counts several images`() {
        assertEquals("📷 3 screenshots — read this", GardenerService.screenshotPlaceholder("read this", 3))
    }

    @Test
    fun `an empty caption drops the dash`() {
        assertEquals("📷 Screenshot", GardenerService.screenshotPlaceholder("", 1))
        assertEquals("📷 2 screenshots", GardenerService.screenshotPlaceholder("", 2))
    }
}
