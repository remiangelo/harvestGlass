package com.harvestglass.harvest.data.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Both `otherUserId` and `isSentBy` lowercase before comparing on iOS. Getting
 * that wrong shows the wrong participant in a conversation, or attributes a
 * message to the wrong side of the transcript.
 */
class ConversationTest {
    private val json = Json { ignoreUnknownKeys = true }

    private fun conversation(u1: String?, u2: String?) = Conversation(
        id = "c1", matchId = null, lastMessageAt = null, lastMessagePreview = null,
        user1Id = u1, user2Id = u2, createdAt = null
    )

    @Test
    fun `the other user is whichever slot is not me`() {
        assertEquals("u2", conversation("u1", "u2").otherUserId("u1"))
        assertEquals("u1", conversation("u1", "u2").otherUserId("u2"))
    }

    @Test
    fun `id comparison ignores case`() {
        assertEquals("u2", conversation("U1", "u2").otherUserId("u1"))
        assertEquals("u2", conversation("u1", "u2").otherUserId("U1"))
    }

    @Test
    fun `a conversation I am not part of has no other user`() {
        assertNull(conversation("u1", "u2").otherUserId("u9"))
    }

    @Test
    fun `a half-populated conversation degrades rather than throwing`() {
        assertNull(conversation(null, null).otherUserId("u1"))
    }

    @Test
    fun `message authorship ignores case`() {
        val m = Message(
            id = "m1", conversationId = "c1", senderId = "U1",
            content = "hi", isRead = false, createdAt = null
        )
        assertTrue(m.isSentBy("u1"))
        assertFalse(m.isSentBy("u2"))
    }

    @Test
    fun `seed decodes snake_case columns and its status`() {
        val row = """
            {"id":"s1","sender_id":"u1","recipient_id":"u2","opening_message":"hello",
             "status":"pending","conversation_id":null,"created_at":"2026-08-20T10:00:00Z"}
        """.trimIndent()
        val s = json.decodeFromString<Seed>(row)
        assertEquals("u1", s.senderId)
        assertEquals("hello", s.openingMessage)
        assertEquals(SeedStatus.PENDING, s.status)
        assertNull(s.conversationId)
    }

    @Test
    fun `every seed status decodes from its lowercase column value`() {
        assertEquals(SeedStatus.ACCEPTED, json.decodeFromString<SeedStatus>("\"accepted\""))
        assertEquals(SeedStatus.DECLINED, json.decodeFromString<SeedStatus>("\"declined\""))
    }

    @Test
    fun `conversation decodes its preview columns`() {
        val row = """
            {"id":"c1","match_id":"m1","last_message_at":"2026-08-20T10:00:00Z",
             "last_message_preview":"see you then","user1_id":"u1","user2_id":"u2"}
        """.trimIndent()
        val c = json.decodeFromString<Conversation>(row)
        assertEquals("see you then", c.lastMessagePreview)
        assertEquals("m1", c.matchId)
    }

    @Test
    fun `message decodes its read and media columns`() {
        val row = """
            {"id":"m1","conversation_id":"c1","sender_id":"u1","content":"hi",
             "message_type":"text","media_url":null,"is_read":true,
             "read_at":"2026-08-20T10:01:00Z","created_at":"2026-08-20T10:00:00Z"}
        """.trimIndent()
        val m = json.decodeFromString<Message>(row)
        assertTrue(m.isRead)
        assertEquals("text", m.messageType)
        assertNull(m.mediaUrl)
    }
}
