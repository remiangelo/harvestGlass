package com.harvestglass.harvest.data.model

import com.harvestglass.harvest.util.HeightFormatter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The profile card's derived text: goals parsing (which has to cope with three
 * historical storage shapes), lifestyle value formatting, and height display.
 */
class ProfileDisplayTest {

    private fun profile(block: UserProfile.() -> UserProfile) =
        UserProfile(id = "u1").block()

    // MARK: - goalsList

    @Test
    fun `a JSON array of goals decodes`() {
        val p = profile { copy(goals = """["Dating","Marriage"]""") }
        assertEquals(listOf("Dating", "Marriage"), p.goalsList)
    }

    @Test
    fun `a comma-joined string of goals splits`() {
        // This is what onboarding writes.
        val p = profile { copy(goals = "Dating,Marriage") }
        assertEquals(listOf("Dating", "Marriage"), p.goalsList)
    }

    @Test
    fun `a single goal comes back as one entry`() {
        assertEquals(listOf("Marriage"), profile { copy(goals = "Marriage") }.goalsList)
    }

    @Test
    fun `absent or blank goals yield nothing`() {
        assertTrue(profile { copy(goals = null) }.goalsList.isEmpty())
        assertTrue(profile { copy(goals = "   ") }.goalsList.isEmpty())
    }

    @Test
    fun `legacy goal labels are normalised to current wording`() {
        assertEquals(listOf("Dating"), profile { copy(goals = "short-term dating") }.goalsList)
        assertEquals(listOf("Dating"), profile { copy(goals = "casual") }.goalsList)
        assertEquals(listOf("Dating"), profile { copy(goals = "not sure yet") }.goalsList)
        assertEquals(
            listOf("Long-term Commitment"),
            profile { copy(goals = "long_term_commitment") }.goalsList
        )
    }

    @Test
    fun `quotes and brackets are stripped from a comma-joined list`() {
        val p = profile { copy(goals = """["Dating", "Marriage"]""") }
        assertEquals(listOf("Dating", "Marriage"), p.goalsList)
    }

    // MARK: - lifestyleDetails

    @Test
    fun `an empty profile has no lifestyle details`() {
        assertTrue(profile { this }.lifestyleDetails.isEmpty())
    }

    @Test
    fun `lifestyle details keep the iOS order and labels`() {
        val p = profile {
            copy(
                heightCm = 175, lookingFor = "Marriage", smoking = "never",
                drinking = "socially", cannabis = "never",
                spiritualOrientation = "agnostic", childrenStatus = "want_someday"
            )
        }
        assertEquals(
            listOf(
                "Height", "Looking For", "Smoking", "Drinking",
                "Cannabis", "Spiritual Orientation", "Children"
            ),
            p.lifestyleDetails.map { it.first }
        )
    }

    @Test
    fun `underscores become spaces and words are title-cased`() {
        val p = profile { copy(childrenStatus = "want_someday") }
        assertEquals("Want Someday", p.lifestyleDetails.single().second)
    }

    @Test
    fun `small joining words stay lowercase`() {
        // "and", "to" and "not" are deliberately not capitalised.
        val p = profile { copy(smoking = "prefer_not_to_say") }
        assertEquals("Prefer not to Say", p.lifestyleDetails.single().second)
    }

    @Test
    fun `a blank lifestyle value is omitted rather than shown empty`() {
        assertTrue(profile { copy(smoking = "   ") }.lifestyleDetails.isEmpty())
    }

    // MARK: - height

    @Test
    fun `height converts to feet and inches`() {
        assertEquals("5'9\"", HeightFormatter.string(175))
        assertEquals("6'0\"", HeightFormatter.string(183))
    }

    @Test
    fun `height display is null without a height`() {
        assertNull(profile { this }.heightDisplayValue)
        assertEquals("5'9\"", profile { copy(heightCm = 175) }.heightDisplayValue)
    }
}
