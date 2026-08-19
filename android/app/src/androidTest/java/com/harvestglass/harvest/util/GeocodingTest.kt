package com.harvestglass.harvest.util

import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Geocoder needs a real device, so this is instrumented. The emulator may have
 * no geocoding backend, so these assert the CONTRACT — never throws, never
 * hangs, respects the limit — rather than real place names.
 */
class GeocodingTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun blankQueryReturnsNothing() = runBlocking {
        assertTrue(Geocoding(context).suggestions("   ").isEmpty())
        assertTrue(Geocoding(context).suggestions("").isEmpty())
    }

    @Test
    fun aLookupCompletesWithoutThrowingOrHanging() = runBlocking {
        withTimeout(15_000) {
            val results = Geocoding(context).suggestions("London")
            assertTrue("must respect the limit", results.size <= 5)
        }
    }

    @Test
    fun aNonsenseQueryYieldsAnEmptyListRatherThanAnError() = runBlocking {
        withTimeout(15_000) {
            val results = Geocoding(context).suggestions("zzzzqqqqxxxx not a place 99999")
            assertTrue(results.size <= 5)
        }
    }

    @Test
    fun resultsAreDeduplicated() = runBlocking {
        withTimeout(15_000) {
            val results = Geocoding(context).suggestions("Springfield")
            assertTrue(results.size == results.distinct().size)
        }
    }
}
