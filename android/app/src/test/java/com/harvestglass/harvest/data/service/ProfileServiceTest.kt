package com.harvestglass.harvest.data.service

import io.mockk.mockk
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * uploadPhoto builds a public URL and deletePhoto has to parse the storage
 * path back out of it. A mismatch silently leaks orphaned photos, so the
 * round trip is worth pinning down without a network.
 */
class ProfileServiceTest {
    private val service = ProfileService(mockk(relaxed = true))

    @Test
    fun `a public storage url yields the object path`() {
        val url = "https://jutzlxdboayvmcuqwodn.supabase.co/storage/v1/object/public/" +
            "profile-photos/u1/photo_0_1755300000000.jpg"
        assertEquals("u1/photo_0_1755300000000.jpg", service.storagePathFromUrl(url))
    }

    @Test
    fun `a url from another bucket is not treated as ours`() {
        val url = "https://x.supabase.co/storage/v1/object/public/other-bucket/u1/p.jpg"
        assertNull(service.storagePathFromUrl(url))
    }

    @Test
    fun `a non-storage url yields nothing`() {
        assertNull(service.storagePathFromUrl("https://example.com/photo.jpg"))
    }

    @Test
    fun `garbage input yields nothing rather than throwing`() {
        assertNull(service.storagePathFromUrl("not a url"))
    }

    @Test
    fun `the upload path is user-scoped and index-stamped`() {
        val path = service.photoObjectPath(userId = "u1", photoIndex = 2, epochMillis = 1755300000000)
        assertEquals("u1/photo_2_1755300000000.jpg", path)
    }

    @Test
    fun `a freshly built upload path round-trips back through the parser`() {
        val path = service.photoObjectPath("u1", 0, 1755300000000)
        val url = "${com.harvestglass.harvest.Config.SUPABASE_URL}/storage/v1/object/public/" +
            "${com.harvestglass.harvest.Config.STORAGE_BUCKET}/$path"
        assertEquals(path, service.storagePathFromUrl(url))
    }

    @Test
    fun `the default nickname is the local part of the email`() {
        assertEquals("ada", service.defaultNickname("ada@example.com"))
    }

    @Test
    fun `an email with no local part falls back to User`() {
        assertEquals("User", service.defaultNickname("@example.com"))
        assertEquals("User", service.defaultNickname(""))
    }

    // MARK: - upsertPayload
    //
    // users.email is NOT NULL with no default, and Postgres validates the
    // proposed tuple before it resolves ON CONFLICT, so an upsert that leaves
    // email out raises 23502 even when the row already exists. Onboarding's
    // last step is the only caller, which made a missing email strand the user
    // with "Failed to save profile" and no way forward.

    @Test
    fun `the upsert payload carries the email`() {
        val payload = service.upsertPayload(
            userId = "u1",
            email = "ada@example.com",
            updates = buildJsonObject { put("nickname", "Ada") },
            nowIso = "2026-09-02T00:00:00Z"
        )

        assertEquals("ada@example.com", payload["email"]?.jsonPrimitive?.content)
    }

    @Test
    fun `the upsert payload keeps the id, the updates and a fresh timestamp`() {
        val payload = service.upsertPayload(
            userId = "u1",
            email = "ada@example.com",
            updates = buildJsonObject { put("nickname", "Ada") },
            nowIso = "2026-09-02T00:00:00Z"
        )

        assertEquals("u1", payload["id"]?.jsonPrimitive?.content)
        assertEquals("Ada", payload["nickname"]?.jsonPrimitive?.content)
        assertEquals("2026-09-02T00:00:00Z", payload["updated_at"]?.jsonPrimitive?.content)
    }

    // Writing an explicit null would fail the NOT NULL just as surely, and
    // would also blank a good address on an existing row.
    @Test
    fun `an unknown email is left out rather than written as null`() {
        val payload = service.upsertPayload("u1", null, buildJsonObject { }, "2026-09-02T00:00:00Z")

        assertFalse(payload.containsKey("email"))
    }

    @Test
    fun `an email already in the updates wins over the session one`() {
        val payload = service.upsertPayload(
            userId = "u1",
            email = "session@example.com",
            updates = buildJsonObject { put("email", "explicit@example.com") },
            nowIso = "2026-09-02T00:00:00Z"
        )

        assertEquals("explicit@example.com", payload["email"]?.jsonPrimitive?.content)
    }
}
