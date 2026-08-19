package com.harvestglass.harvest.ui.components

import androidx.compose.ui.geometry.Offset
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.ValueAxis
import com.harvestglass.harvest.data.model.ValuesTier
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The radar's geometry is what makes the chart correct, and it is pure, so it
 * is unit-tested rather than eyeballed on a device.
 */
class RadarGeometryTest {
    private val center = Offset(100f, 100f)

    @Test
    fun `the first axis points straight up`() {
        // Swift starts at -pi/2 so index 0 is at the top.
        val p = radarAxisPoint(center, radius = 50f, index = 0, axisCount = 5, magnitude = 1f)
        assertEquals(100f, p.x, 0.01f)
        assertEquals(50f, p.y, 0.01f)
    }

    @Test
    fun `a zero magnitude collapses to the centre`() {
        val p = radarAxisPoint(center, 50f, 2, 5, 0f)
        assertEquals(center.x, p.x, 0.01f)
        assertEquals(center.y, p.y, 0.01f)
    }

    @Test
    fun `magnitude above one is clamped`() {
        val over = radarAxisPoint(center, 50f, 0, 5, 3f)
        val at = radarAxisPoint(center, 50f, 0, 5, 1f)
        assertEquals(at.y, over.y, 0.01f)
    }

    @Test
    fun `magnitude below zero is clamped`() {
        val under = radarAxisPoint(center, 50f, 0, 5, -2f)
        assertEquals(center.y, under.y, 0.01f)
    }

    @Test
    fun `five axes land on five distinct points`() {
        val points = (0 until 5).map { radarAxisPoint(center, 50f, it, 5, 1f) }
        assertEquals(5, points.distinct().size)
    }

    @Test
    fun `axes are evenly spaced around the circle`() {
        // Every vertex sits on the circle of the given radius.
        (0 until 5).forEach { i ->
            val p = radarAxisPoint(center, 50f, i, 5, 1f)
            val d = kotlin.math.hypot((p.x - center.x).toDouble(), (p.y - center.y).toDouble())
            assertEquals(50.0, d, 0.01)
        }
    }

    @Test
    fun `the plotted radius comes from the tier, not the raw score`() {
        // Raw 22 is CORE_VALUE -> outer ring; raw 3 is LOW_PRESENCE -> 1st ring.
        assertEquals(1.0, ValuesTier.fromRawScore(22.0).radiusFraction, 0.0001)
        assertEquals(0.25, ValuesTier.fromRawScore(3.0).radiusFraction, 0.0001)
    }

    @Test
    fun `two raw scores in the same tier plot at the same radius`() {
        // 11 and 17 are both STRONG_PRESENCE. The chart shows shape, not points.
        assertEquals(
            ValuesTier.fromRawScore(11.0).radiusFraction,
            ValuesTier.fromRawScore(17.0).radiusFraction,
            0.0001
        )
    }

    @Test
    fun `a scores vector reads back per axis`() {
        val s = AxisScores(connection = 22.0)
        assertEquals(22.0, s.value(ValueAxis.CONNECTION), 0.0001)
        assertEquals(0.0, s.value(ValueAxis.GROWTH), 0.0001)
    }

    @Test
    fun `the radar axis order matches the iOS chart`() {
        assertEquals(
            listOf(
                ValueAxis.EMOTIONAL_INTELLIGENCE,
                ValueAxis.STABILITY,
                ValueAxis.INTEGRITY,
                ValueAxis.CONNECTION,
                ValueAxis.GROWTH
            ),
            RADAR_AXES
        )
    }
}
