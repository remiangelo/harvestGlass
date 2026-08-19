package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.Config
import com.harvestglass.harvest.data.model.UserProfile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/** Mirrors Harvest/Services/ProfileService.swift. */
class ProfileService(private val client: SupabaseClient) {

    suspend fun getProfile(userId: String): UserProfile? =
        client.postgrest.from("users")
            .select { filter { eq("id", userId) } }
            .decodeList<UserProfile>()
            .firstOrNull()

    suspend fun createProfile(userId: String, email: String): UserProfile? {
        val now = Instant.now().toString()
        return client.postgrest.from("users")
            .upsert(
                buildJsonObject {
                    put("id", userId)
                    put("email", email)
                    put("nickname", defaultNickname(email))
                    put("bio", "I'm new here!")
                    put("created_at", now)
                    put("updated_at", now)
                }
            ) {
                onConflict = "id"
                select()
            }
            .decodeList<UserProfile>()
            .firstOrNull()
    }

    suspend fun upsertProfile(userId: String, updates: JsonObject): UserProfile? =
        client.postgrest.from("users")
            .upsert(
                buildJsonObject {
                    updates.forEach { (k, v) -> put(k, v) }
                    put("id", userId)
                    put("updated_at", Instant.now().toString())
                }
            ) {
                onConflict = "id"
                select()
            }
            .decodeList<UserProfile>()
            .firstOrNull()

    suspend fun updateProfile(userId: String, updates: JsonObject): UserProfile? =
        client.postgrest.from("users")
            .update(
                buildJsonObject {
                    updates.forEach { (k, v) -> put(k, v) }
                    put("updated_at", Instant.now().toString())
                }
            ) {
                filter { eq("id", userId) }
                select()
            }
            .decodeList<UserProfile>()
            .firstOrNull()

    suspend fun uploadPhoto(userId: String, imageData: ByteArray, photoIndex: Int): String {
        val path = photoObjectPath(userId, photoIndex, System.currentTimeMillis())
        val result = client.storage.from(Config.STORAGE_BUCKET).upload(path, imageData) {
            upsert = true
        }
        return "${Config.SUPABASE_URL}/storage/v1/object/public/${result.path}"
    }

    suspend fun deletePhoto(userId: String, photoUrl: String) {
        // Swift returns silently on an unparseable URL rather than throwing;
        // a malformed row shouldn't block the user from removing the photo.
        val path = storagePathFromUrl(photoUrl) ?: return
        client.storage.from(Config.STORAGE_BUCKET).delete(path)
    }

    // MARK: - Pure helpers, unit-tested without a network

    internal fun photoObjectPath(userId: String, photoIndex: Int, epochMillis: Long): String =
        "$userId/photo_${photoIndex}_$epochMillis.jpg"

    /** The object path inside our bucket, or null when the URL isn't one of ours. */
    internal fun storagePathFromUrl(photoUrl: String): String? {
        val marker = "/storage/v1/object/public/${Config.STORAGE_BUCKET}/"
        val index = photoUrl.indexOf(marker)
        if (index < 0) return null
        return photoUrl.substring(index + marker.length).ifEmpty { null }
    }

    internal fun defaultNickname(email: String): String =
        email.substringBefore('@').ifEmpty { "User" }
}
