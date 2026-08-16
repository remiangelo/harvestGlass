package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.UserProfile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.Flow

/** Mirrors Harvest/Services/AuthService.swift. */
class AuthService(private val client: SupabaseClient) {

    /**
     * iOS uses `session.user.id.uuidString.lowercased()` everywhere. RLS
     * comparisons depend on the lowercase form, so normalise on the way out.
     */
    private fun String.normalizedId() = lowercase()

    suspend fun signUp(email: String, password: String): String? {
        val user = client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        return user?.id?.normalizedId()
    }

    suspend fun signIn(email: String, password: String): String {
        client.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        return requireNotNull(currentUserId()) { "Sign-in returned no session" }
    }

    suspend fun signOut() = client.auth.signOut()

    fun currentUserIdOrNull(): String? = client.auth.currentUserOrNull()?.id?.normalizedId()

    suspend fun currentUserId(): String? = currentUserIdOrNull()

    fun sessionStatus(): Flow<SessionStatus> = client.auth.sessionStatus

    suspend fun loadProfile(userId: String): UserProfile? =
        client.postgrest.from("users")
            .select { filter { eq("id", userId) } }
            .decodeSingleOrNull<UserProfile>()
}
