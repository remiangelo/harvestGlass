package com.harvestglass.harvest.data.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Column names must match the Swift CodingKeys exactly, or Postgrest
 * decoding silently misses fields.
 */
class CommunityTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `community decodes snake_case columns`() {
        val row = """
            {"id":"c1","slug":"single-parents","name":"Single Parents","description":"A room",
             "kind":"status","member_count":12,"display_order":2,"image_url":"https://x/y.png"}
        """.trimIndent()
        val c = json.decodeFromString<Community>(row)
        assertEquals("c1", c.id)
        assertEquals("single-parents", c.slug)
        assertEquals(12, c.memberCount)
        assertEquals(2, c.displayOrder)
        assertEquals("https://x/y.png", c.imageUrl)
    }

    @Test
    fun `community tolerates absent optional columns`() {
        val c = json.decodeFromString<Community>("""{"id":"c1","slug":"s","name":"N","kind":"k"}""")
        assertNull(c.description)
        assertNull(c.memberCount)
        assertNull(c.imageUrl)
    }

    @Test
    fun `message decodes reply and mentions`() {
        val row = """
            {"id":"m1","community_id":"c1","sender_id":"u1","content":"hi","is_removed":false,
             "created_at":"2026-08-16T10:00:00.123456+00:00","reply_to_id":"m0","mentions":["u2"]}
        """.trimIndent()
        val m = json.decodeFromString<CommunityMessage>(row)
        assertEquals("c1", m.communityId)
        assertEquals("u1", m.senderId)
        assertEquals(false, m.isRemoved)
        assertEquals("m0", m.replyToId)
        assertEquals(listOf("u2"), m.mentions)
    }

    @Test
    fun `reaction decodes without a community id, which a trigger fills`() {
        val r = json.decodeFromString<CommunityReaction>(
            """{"message_id":"m1","user_id":"u1","emoji":"🌱"}"""
        )
        assertEquals("m1", r.messageId)
        assertEquals("u1", r.userId)
        assertNull(r.communityId)
    }

    @Test
    fun `curated emoji matches the DB check constraint`() {
        assertEquals(
            listOf("🌱", "💚", "🌻", "😂", "👏", "🤔"),
            CommunityReaction.CURATED_EMOJI
        )
    }

    @Test
    fun `sender photoUrl is the first photo`() {
        val s = json.decodeFromString<CommunitySender>(
            """{"id":"u1","nickname":"Ada","photos":["a.png","b.png"]}"""
        )
        assertEquals("a.png", s.photoUrl)
    }

    @Test
    fun `sender photoUrl is null when there are no photos`() {
        val s = json.decodeFromString<CommunitySender>("""{"id":"u1","nickname":"Ada","photos":[]}""")
        assertNull(s.photoUrl)
    }

    @Test
    fun `user profile decodes the onboarding and ban columns`() {
        val row = """
            {"id":"u1","email":"a@b.c","nickname":"Ada","age":33,"gender":"female",
             "photos":["a.png"],"onboarding_completed":true,"is_banned":false}
        """.trimIndent()
        val p = json.decodeFromString<UserProfile>(row)
        assertEquals(true, p.onboardingCompleted)
        assertEquals(false, p.isBanned)
        assertEquals(33, p.age)
    }

    @Test
    fun `user profile ignores columns the slice does not declare yet`() {
        val row = """{"id":"u1","values_blurb":"x","height_cm":170,"notif_likes_enabled":true}"""
        val p = json.decodeFromString<UserProfile>(row)
        assertEquals("u1", p.id)
    }
}
