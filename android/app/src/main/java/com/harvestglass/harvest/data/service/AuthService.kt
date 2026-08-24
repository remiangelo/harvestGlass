package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.network.SupabaseHttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
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

    /**
     * Deletes the account via the `delete-account` Edge Function.
     *
     * Mirrors AuthService.swift, including its friendlier messages: a 404
     * means the function is not deployed, which is a different problem from a
     * failed deletion and should read that way.
     */
    suspend fun deleteAccount(userId: String) {
        val session = client.auth.currentSessionOrNull()
            ?: throw IllegalStateException("Not authenticated")

        val response = client.httpClient.post(
            "${Config.SUPABASE_URL}/functions/v1/delete-account"
        ) {
            header("apikey", Config.SUPABASE_ANON_KEY)
            header("Authorization", "Bearer ${session.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject { put("user_id", userId) })
        }

        if (response.status.isSuccess()) return

        val body = runCatching { response.bodyAsText() }.getOrNull()?.trim()
        throw IllegalStateException(
            when {
                response.status == HttpStatusCode.NotFound ->
                    "Account deletion is not available yet because the delete-account " +
                        "Edge Function has not been deployed."
                !body.isNullOrEmpty() -> body
                else -> "Account deletion failed. Please try again or contact support."
            }
        )
    }

    fun currentUserIdOrNull(): String? = client.auth.currentUserOrNull()?.id?.normalizedId()

    suspend fun currentUserId(): String? = currentUserIdOrNull()

    fun sessionStatus(): Flow<SessionStatus> = client.auth.sessionStatus

    suspend fun loadProfile(userId: String): UserProfile? =
        client.postgrest.from("users")
            .select { filter { eq("id", userId) } }
            .decodeSingleOrNull<UserProfile>()
}
