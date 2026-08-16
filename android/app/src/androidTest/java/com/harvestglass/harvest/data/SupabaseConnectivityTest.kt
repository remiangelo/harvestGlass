package com.harvestglass.harvest.data

import com.harvestglass.harvest.data.service.AuthService
import io.github.jan.supabase.auth.exception.AuthRestException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Proves the Android client actually reaches the live Supabase project —
 * DNS, TLS, the Ktor engine, and the auth endpoint — without needing real
 * credentials.
 *
 * Signing in with a deliberately invalid account must come back as an auth
 * REJECTION, not a transport failure. A network/TLS/engine problem would
 * surface as some other exception type, which is exactly what this catches.
 */
class SupabaseConnectivityTest {

    @Test
    fun invalidCredentialsAreRejectedByTheServerRatherThanFailingInTransport() = runBlocking {
        val auth = AuthService(SupabaseManager.client)

        val error = runCatching {
            auth.signIn(
                email = "definitely-not-a-real-account@harvest-android-smoke-test.invalid",
                password = "not-a-real-password"
            )
        }.exceptionOrNull()

        assertTrue(
            "Expected a server-side auth rejection, got: $error",
            error is AuthRestException
        )
    }
}
