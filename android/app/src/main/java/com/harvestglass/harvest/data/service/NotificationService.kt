package com.harvestglass.harvest.data.service

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/**
 * Device-token registration, mirroring Harvest/Services/NotificationService.swift.
 *
 * Two things to know about the table this writes to:
 *  - The token column is called `apns_token` even for Android. It carries the
 *    FCM registration token for `platform = 'android'` rows; renaming it would
 *    have broken the shipped iOS client and send-push in one deploy.
 *  - `platform` was CHECK-constrained to 'ios' only. Migration
 *    20260825120000_android_push_support.sql widens it; without that migration
 *    applied, every call here fails on the constraint.
 */
class NotificationService(private val client: SupabaseClient) {

    /**
     * De-duplicates against the last token persisted this session, exactly as
     * iOS does — FCM hands back the same token on every app start.
     */
    private var lastPersistedToken: String? = null

    suspend fun registerDevice(userId: String, token: String) {
        if (token == lastPersistedToken) return

        client.postgrest.from("user_devices").upsert(
            buildJsonObject {
                put("user_id", userId)
                put("apns_token", token)
                put("platform", PLATFORM_ANDROID)
                put("updated_at", Instant.now().toString())
            }
        ) { onConflict = "user_id,apns_token" }

        lastPersistedToken = token
    }

    /** Removes this device's row so a signed-out phone stops receiving pushes. */
    suspend fun unregisterDevice(userId: String) {
        val token = lastPersistedToken ?: return
        client.postgrest.from("user_devices").delete {
            filter {
                eq("user_id", userId)
                eq("apns_token", token)
            }
        }
        lastPersistedToken = null
    }

    companion object {
        const val PLATFORM_ANDROID = "android"
    }
}
