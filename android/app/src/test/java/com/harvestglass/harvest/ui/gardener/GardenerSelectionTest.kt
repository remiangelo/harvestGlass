package com.harvestglass.harvest.ui.gardener

import android.net.Uri
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The picker is opened with the tier's cap, but the cap is applied again here:
 * a picker limit is a UI affordance, not a guarantee, and a 20-image request
 * is several megabytes.
 */
class GardenerSelectionTest {

    private fun uris(n: Int): List<Uri> = List(n) { i ->
        mockk<Uri>().also { every { it.toString() } returns "uri-$i" }
    }

    @Test
    fun `a selection within the cap is untouched`() {
        val picked = uris(3)
        assertEquals(picked, GardenerViewModel.clampSelection(picked, cap = 6))
    }

    @Test
    fun `an over-long selection keeps the first cap images`() {
        val picked = uris(9)
        val clamped = GardenerViewModel.clampSelection(picked, cap = 6)

        assertEquals(6, clamped.size)
        assertEquals(picked.take(6), clamped)
    }

    /** An unknown tier decodes as 1, and must not become "unlimited". */
    @Test
    fun `a cap of one keeps a single image`() {
        assertEquals(1, GardenerViewModel.clampSelection(uris(5), cap = 1).size)
    }

    @Test
    fun `a nonsense cap still sends one image rather than none`() {
        assertEquals(1, GardenerViewModel.clampSelection(uris(5), cap = 0).size)
    }

    @Test
    fun `an empty selection stays empty`() {
        assertEquals(emptyList<Uri>(), GardenerViewModel.clampSelection(emptyList(), cap = 6))
    }

    @Test
    fun `a selection within budget is accepted`() {
        assertNull(GardenerViewModel.payloadRejection(listOf("a".repeat(1000), "b".repeat(1000))))
    }

    @Test
    fun `an oversized selection is refused by count, not by bytes`() {
        val huge = List(3) { "x".repeat(3_000_000) }
        val message = GardenerViewModel.payloadRejection(huge)

        assertNotNull(message)
        assertTrue(message!!.contains("3 images"))
    }
}
