package com.harvestglass.harvest.data

import com.harvestglass.harvest.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.json.Json

/** Mirrors Harvest/Services/SupabaseManager.swift. */
object SupabaseManager {

    val client: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = Config.SUPABASE_URL,
            supabaseKey = Config.SUPABASE_ANON_KEY
        ) {
            // Rows carry columns the slice models don't declare yet; ignoring
            // unknown keys keeps decoding from breaking as the port fans out.
            defaultSerializer = KotlinXSerializer(Json { ignoreUnknownKeys = true })

            install(Postgrest)
            install(Auth) {
                // Matches Config.appScheme on iOS: harvestapp://auth/callback
                scheme = Config.APP_SCHEME
                host = "auth"
            }
            install(Realtime)
            install(Storage)
        }
    }
}
