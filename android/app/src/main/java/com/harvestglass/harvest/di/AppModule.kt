package com.harvestglass.harvest.di

import android.content.Context
import com.harvestglass.harvest.data.SupabaseManager
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.CommunityService
import com.harvestglass.harvest.data.service.ChatService
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.SeedService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.ValuesService
import com.harvestglass.harvest.util.Geocoding
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
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

    @Provides
    @Singleton
    fun provideCommunityService(client: SupabaseClient) = CommunityService(client)

    @Provides
    @Singleton
    fun provideProfileService(client: SupabaseClient) = ProfileService(client)

    @Provides
    @Singleton
    fun provideValuesService(client: SupabaseClient) = ValuesService(client)

    @Provides
    @Singleton
    fun provideQuestionsService(client: SupabaseClient) = QuestionsService(client)

    @Provides
    @Singleton
    fun provideGeocoding(@ApplicationContext context: Context) = Geocoding(context)

    @Provides
    @Singleton
    fun provideSeedService(client: SupabaseClient) = SeedService(client)

    @Provides
    @Singleton
    fun provideChatService(client: SupabaseClient) = ChatService(client)

    @Provides
    @Singleton
    fun provideMatchService(client: SupabaseClient, profileService: ProfileService) =
        MatchService(client, profileService)
}
