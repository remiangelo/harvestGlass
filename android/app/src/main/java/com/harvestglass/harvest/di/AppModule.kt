package com.harvestglass.harvest.di

import com.harvestglass.harvest.data.SupabaseManager
import com.harvestglass.harvest.data.service.AuthService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Service providers are added here as each service ports. iOS reaches the
 * client through a shared singleton; on Android the services take it by
 * constructor injection so they stay unit-testable with a mocked client.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideClient(): SupabaseClient = SupabaseManager.client

    @Provides
    @Singleton
    fun provideAuthService(client: SupabaseClient) = AuthService(client)
}
