package com.harvestglass.harvest.ui.components.chat

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Only nicknames the message actually mentions get highlighted. A literal
 * "@someone" that was never a real mention stays plain, matching iOS — the
 * highlight is driven by the resolved `mentions` id array, not by scanning
 * the text for at-signs.
 */
class MentionHighlightTest {
    private val tint = Color.Red

    @Test
    fun `text with no mentions is returned unchanged`() {
        val out = highlightMentions("just a message", emptyList(), tint)
        assertEquals("just a message", out.text)
        assertTrue(out.spanStyles.isEmpty())
    }

    @Test
    fun `a mentioned nickname is styled`() {
        val out = highlightMentions("hey @Ada how are you", listOf("Ada"), tint)
        assertEquals("hey @Ada how are you", out.text)
        assertEquals(1, out.spanStyles.size)
        val span = out.spanStyles.first()
        assertEquals("@Ada", out.text.substring(span.start, span.end))
        assertEquals(tint, span.item.color)
    }

    @Test
    fun `an at-sign that is not a real mention stays plain`() {
        val out = highlightMentions("email me @ work", listOf("Ada"), tint)
        assertTrue(out.spanStyles.isEmpty())
    }

    @Test
    fun `several mentions are each styled`() {
        val out = highlightMentions("@Ada and @Bo", listOf("Ada", "Bo"), tint)
        assertEquals(2, out.spanStyles.size)
        assertEquals("@Ada", out.text.substring(out.spanStyles[0].start, out.spanStyles[0].end))
        assertEquals("@Bo", out.text.substring(out.spanStyles[1].start, out.spanStyles[1].end))
    }

    @Test
    fun `the same nickname twice is styled twice`() {
        val out = highlightMentions("@Ada then @Ada", listOf("Ada"), tint)
        assertEquals(2, out.spanStyles.size)
    }

    @Test
    fun `matching ignores case but keeps the original text`() {
        val out = highlightMentions("hi @ADA", listOf("Ada"), tint)
        assertEquals("hi @ADA", out.text)
        assertEquals(1, out.spanStyles.size)
        assertEquals("@ADA", out.text.substring(out.spanStyles[0].start, out.spanStyles[0].end))
    }

    @Test
    fun `a mention at the very end terminates cleanly`() {
        val out = highlightMentions("thanks @Ada", listOf("Ada"), tint)
        assertEquals("thanks @Ada", out.text)
        assertEquals(1, out.spanStyles.size)
    }
}
