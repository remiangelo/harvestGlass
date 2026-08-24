package com.harvestglass.harvest.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors RoomMemberFilter in Harvest/Models/ProfileFilterOptions.swift.
 *
 * Note the asymmetry, which the Swift comment ("an unset attribute on a
 * profile never excludes it") states more broadly than the code does:
 *  - AGE and HEIGHT guard on the profile's value being present, so a profile
 *    with no age or height survives any range.
 *  - Every other attribute compares directly, so a profile with a null value
 *    IS excluded once that filter is set.
 *
 * These tests pin the real behaviour, not the comment.
 */
class RoomMemberFilterTest {

    private fun profile(
        id: String = "u1",
        nickname: String? = "Ada",
        age: Int? = 30,
        gender: String? = "female",
        bio: String? = null,
        location: String? = null,
        lookingFor: String? = null,
        heightCm: Int? = null,
        smoking: String? = null,
        childrenStatus: String? = null
    ) = UserProfile(
        id = id, nickname = nickname, age = age, gender = gender, bio = bio,
        location = location, lookingFor = lookingFor, heightCm = heightCm,
        smoking = smoking, childrenStatus = childrenStatus
    )

    @Test
    fun `a default filter matches everyone`() {
        assertTrue(RoomMemberFilter().matches(profile()))
        assertTrue(RoomMemberFilter().matches(profile(age = null, gender = null)))
    }

    @Test
    fun `a missing age or height never excludes a profile`() {
        // These two guard on the profile's own value, so a blank profile survives.
        assertTrue(RoomMemberFilter(ageMin = 25, ageMax = 35).matches(profile(age = null)))
        assertTrue(RoomMemberFilter(heightMin = 170).matches(profile(heightCm = null)))
    }

    @Test
    fun `a set categorical filter does exclude a profile that never answered`() {
        // Direct comparison, so null != "never" and the profile drops out.
        // Matches Swift; worth pinning because the source comment reads wider.
        assertFalse(RoomMemberFilter(smoking = "never").matches(profile(smoking = null)))
        assertFalse(RoomMemberFilter(childrenStatus = "none").matches(profile(childrenStatus = null)))
    }

    @Test
    fun `a set attribute that disagrees excludes`() {
        assertFalse(RoomMemberFilter(smoking = "never").matches(profile(smoking = "often")))
        assertTrue(RoomMemberFilter(smoking = "never").matches(profile(smoking = "never")))
    }

    @Test
    fun `age is filtered inclusively`() {
        val filter = RoomMemberFilter(ageMin = 25, ageMax = 35)
        assertTrue(filter.matches(profile(age = 25)))
        assertTrue(filter.matches(profile(age = 35)))
        assertFalse(filter.matches(profile(age = 24)))
        assertFalse(filter.matches(profile(age = 36)))
        // No age on the profile: not excluded.
        assertTrue(filter.matches(profile(age = null)))
    }

    @Test
    fun `gender comparison ignores case`() {
        assertTrue(RoomMemberFilter(gender = "Female").matches(profile(gender = "female")))
    }

    @Test
    fun `search covers name, location and bio`() {
        val p = profile(nickname = "Ada", location = "Lisbon", bio = "loves hiking")
        assertTrue(RoomMemberFilter(search = "ada").matches(p))
        assertTrue(RoomMemberFilter(search = "lisbon").matches(p))
        assertTrue(RoomMemberFilter(search = "hiking").matches(p))
        assertFalse(RoomMemberFilter(search = "berlin").matches(p))
    }

    @Test
    fun `search ignores surrounding whitespace and case`() {
        assertTrue(RoomMemberFilter(search = "  ADA  ").matches(profile(nickname = "Ada")))
    }

    @Test
    fun `height bounds only apply when the profile has a height`() {
        val filter = RoomMemberFilter(heightMin = 170, heightMax = 190)
        assertTrue(filter.matches(profile(heightCm = 175)))
        assertFalse(filter.matches(profile(heightCm = 160)))
        assertTrue(filter.matches(profile(heightCm = null)))
    }

    @Test
    fun `isDefault is only true for an untouched filter`() {
        assertTrue(RoomMemberFilter().isDefault)
        assertFalse(RoomMemberFilter(gender = "female").isDefault)
        assertFalse(RoomMemberFilter(ageMin = 21).isDefault)
    }

    @Test
    fun `the active attribute count excludes free-text search`() {
        assertEquals(0, RoomMemberFilter(search = "ada").activeAttributeCount)
        assertEquals(1, RoomMemberFilter(gender = "female").activeAttributeCount)
        assertEquals(2, RoomMemberFilter(gender = "female", smoking = "never").activeAttributeCount)
        // An age range counts once, however many bounds moved.
        assertEquals(1, RoomMemberFilter(ageMin = 25, ageMax = 35).activeAttributeCount)
        // Height counts once too.
        assertEquals(1, RoomMemberFilter(heightMin = 170).activeAttributeCount)
    }

    @Test
    fun `filter levels gate the paid tiers`() {
        assertFalse(FieldFilterLevel.NONE.unlocksAdvanced)
        assertFalse(FieldFilterLevel.NONE.unlocksFull)
        assertTrue(FieldFilterLevel.ADVANCED.unlocksAdvanced)
        assertFalse(FieldFilterLevel.ADVANCED.unlocksFull)
        assertTrue(FieldFilterLevel.FULL.unlocksAdvanced)
        assertTrue(FieldFilterLevel.FULL.unlocksFull)
    }

    @Test
    fun `an unknown filter level decodes as locked`() {
        // "a filter that silently stays locked is a better failure than a tier
        // that won't load"
        assertEquals(FieldFilterLevel.NONE, FieldFilterLevel.fromRaw("platinum"))
        assertEquals(FieldFilterLevel.NONE, FieldFilterLevel.fromRaw(null))
        assertEquals(FieldFilterLevel.FULL, FieldFilterLevel.fromRaw("FULL"))
    }

    @Test
    fun `display name falls back through nickname then email`() {
        assertEquals("Ada", UserProfile(id = "u", nickname = "Ada").displayName)
        assertEquals("ada", UserProfile(id = "u", email = "ada@example.com").displayName)
        assertEquals("User", UserProfile(id = "u").displayName)
    }
}
