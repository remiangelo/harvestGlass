package com.harvestglass.harvest.util

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Ten images at full size is several megabytes in one JSON body, and base64
 * inflates that by a third. The target shrinks as the count rises so total
 * payload stays bounded instead of growing linearly.
 */
class ScreenshotEncoderTest {

    @Test
    fun `one or two images keep the full target`() {
        assertEquals(1400, ScreenshotEncoder.targetDimension(1))
        assertEquals(1400, ScreenshotEncoder.targetDimension(2))
    }

    @Test
    fun `three to five images step down`() {
        assertEquals(1100, ScreenshotEncoder.targetDimension(3))
        assertEquals(1100, ScreenshotEncoder.targetDimension(5))
    }

    @Test
    fun `six or more step down again`() {
        assertEquals(900, ScreenshotEncoder.targetDimension(6))
        assertEquals(900, ScreenshotEncoder.targetDimension(10))
    }

    /** A count below one is a caller bug, not a reason to divide by zero. */
    @Test
    fun `a nonsense count falls back to the full target`() {
        assertEquals(1400, ScreenshotEncoder.targetDimension(0))
        assertEquals(1400, ScreenshotEncoder.targetDimension(-3))
    }
}
