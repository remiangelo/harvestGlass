package com.harvestglass.harvest.data.service

import io.mockk.mockk
import org.junit.Assert.assertEquals
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
}
