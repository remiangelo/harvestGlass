package com.harvestglass.harvest.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.storage.storage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Instrumented rather than a plain unit test: the client resolves Ktor's
 * Android engine, which is not on the classpath of a JVM-only test run.
 */
class SupabaseManagerTest {

    @Test
    fun clientInstallsTheFourPluginsTheAppUses() {
        val client = SupabaseManager.client
        // These accessors throw if the corresponding plugin was never installed.
        assertNotNull(client.postgrest)
        assertNotNull(client.auth)
        assertNotNull(client.realtime)
        assertNotNull(client.storage)
    }

    @Test
    fun clientTargetsTheSameProjectAsTheIosApp() {
        assertEquals(
            "https://jutzlxdboayvmcuqwodn.supabase.co",
            com.harvestglass.harvest.Config.SUPABASE_URL
        )
    }
}
