package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.model.ValueAxis
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The scores have to match iOS exactly — the same two people must see the same
 * number on both platforms, so every neutral fallback is pinned here.
 */
class CompatibilityServiceTest {

    private fun profile(
        id: String = "u1",
        age: Int? = null,
        hobbies: List<String>? = null,
        goals: String? = null
    ) = UserProfile(id = id, age = age, hobbies = hobbies, goals = goals)

    private fun value(id: String, name: String) = Value(id = id, name = name, category = "c")

    // 20 interests + 15 values + 7.5 goals + 5 age + 5 distance = 52 -> 52.
    @Test
    fun `an empty profile pair scores the neutral floor`() {
        val score = CompatibilityService.calculateCompatibility(profile(), profile("u2"))

        assertEquals(52, score.total)
        assertEquals(20, score.interestsScore)
        assertEquals(15, score.valuesScore)
        assertEquals(5, score.ageScore)
        assertEquals(5, score.distanceScore)
    }

    @Test
    fun `identical hobbies score the full forty`() {
        val score = CompatibilityService.calculateCompatibility(
            profile(hobbies = listOf("Hiking", "Cooking")),
            profile("u2", hobbies = listOf("hiking", "COOKING"))
        )

        assertEquals(40, score.interestsScore)
    }

    @Test
    fun `disjoint hobbies score zero interests`() {
        val score = CompatibilityService.calculateCompatibility(
            profile(hobbies = listOf("Hiking")),
            profile("u2", hobbies = listOf("Chess"))
        )

        assertEquals(0, score.interestsScore)
    }

    @Test
    fun `goals are a step function, not a ratio`() {
        val one = CompatibilityService.calculateCompatibility(
            profile(goals = """["Long term"]"""),
            profile("u2", goals = """["Long term", "Marriage"]""")
        )
        val two = CompatibilityService.calculateCompatibility(
            profile(goals = """["Long term", "Marriage"]"""),
            profile("u2", goals = """["Long term", "Marriage"]""")
        )

        assertEquals(10, one.goalsScore)
        assertEquals(15, two.goalsScore)
    }

    @Test
    fun `age scoring steps down with the gap`() {
        fun scoreFor(a: Int, b: Int) =
            CompatibilityService.calculateCompatibility(profile(age = a), profile("u2", age = b))
                .ageScore

        assertEquals(10, scoreFor(30, 31))
        assertEquals(7, scoreFor(30, 34))
        assertEquals(4, scoreFor(30, 38))
        assertEquals(2, scoreFor(30, 55))
    }

    // A missing age is neutral, never a penalty.
    @Test
    fun `a missing age scores the neutral five`() {
        val score = CompatibilityService.calculateCompatibility(
            profile(age = 30),
            profile("u2", age = null)
        )

        assertEquals(5, score.ageScore)
    }

    @Test
    fun `a zero axis vector falls back to the neutral values score`() {
        val score = CompatibilityService.calculateCompatibility(
            profile(),
            profile("u2"),
            currentUserAxisScores = AxisScores() to AxisScores(),
            otherUserAxisScores = AxisScores() to AxisScores()
        )

        assertEquals(15, score.valuesScore)
    }

    @Test
    fun `the total never exceeds one hundred`() {
        val strong = AxisScores().add(10.0, ValueAxis.CONNECTION)
        val score = CompatibilityService.calculateCompatibility(
            profile(age = 30, hobbies = listOf("a", "b"), goals = """["x", "y"]"""),
            profile("u2", age = 30, hobbies = listOf("a", "b"), goals = """["x", "y"]"""),
            currentUserAxisScores = strong to strong,
            otherUserAxisScores = strong to strong
        )

        assertTrue(score.total <= 100)
    }

    @Test
    fun `overlap pairs each side against the other's needs`() {
        val calm = value("v1", "Calm")
        val trust = value("v2", "Trust")
        val humour = value("v3", "Humour")

        val overlap = CompatibilityService.valueOverlap(
            myNeeds = listOf(calm, trust),
            myBrings = listOf(humour),
            theirNeeds = listOf(humour),
            theirBrings = listOf(calm)
        )

        assertEquals(listOf("v1"), overlap.theyBringForMyNeeds.map { it.id })
        assertEquals(listOf("v3"), overlap.iBringForTheirNeeds.map { it.id })
    }

    // The strongest MUTUAL axis, not simply my loudest one.
    @Test
    fun `the top shared axis is the strongest mutual one`() {
        val myBring = AxisScores()
            .add(20.0, ValueAxis.GROWTH)
            .add(8.0, ValueAxis.INTEGRITY)
        val theirNeed = AxisScores()
            .add(1.0, ValueAxis.GROWTH)
            .add(9.0, ValueAxis.INTEGRITY)

        assertEquals(
            ValueAxis.INTEGRITY,
            CompatibilityService.topSharedAxis(myBring, theirNeed)
        )
    }

    @Test
    fun `no shared axis when nothing overlaps`() {
        val myBring = AxisScores().add(20.0, ValueAxis.GROWTH)
        val theirNeed = AxisScores().add(20.0, ValueAxis.STABILITY)

        assertNull(CompatibilityService.topSharedAxis(myBring, theirNeed))
    }

    @Test
    fun `the blurb names the axis and the count when both are strong`() {
        val calm = value("v1", "Calm")
        val blurb = CompatibilityService.compatibilityBlurb(
            otherName = "Rae",
            bringCosine = 0.9,
            needCosine = 0.9,
            topSharedAxis = ValueAxis.GROWTH,
            overlap = ValueOverlap(listOf(calm), emptyList()),
            myNeedsCount = 3
        )

        assertTrue(blurb.contains("Rae"))
        assertTrue(blurb.contains(ValueAxis.GROWTH.displayName))
        assertTrue(blurb.contains("1 of your 3 needs"))
    }

    @Test
    fun `the blurb falls back to the growth line when nothing lines up`() {
        val blurb = CompatibilityService.compatibilityBlurb(
            otherName = "Rae",
            bringCosine = 0.1,
            needCosine = 0.1,
            topSharedAxis = null,
            overlap = ValueOverlap(emptyList(), emptyList()),
            myNeedsCount = 3
        )

        assertEquals("Your value patterns differ — sometimes that's where growth starts.", blurb)
    }

    @Test
    fun `compatibility levels bracket the score`() {
        fun level(total: Int) = CompatibilityScore(total, emptyMap()).compatibilityLevel

        assertEquals("Excellent Match", level(80))
        assertEquals("Great Match", level(79))
        assertEquals("Good Match", level(40))
        assertEquals("Fair Match", level(39))
        assertEquals("Low Match", level(19))
    }
}
