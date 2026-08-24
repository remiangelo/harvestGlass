package com.harvestglass.harvest.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.MindfulMessagingService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

/** The per-category notification switches, and the column each writes to. */
enum class NotificationPref(val column: String) {
    MATCHES("notif_matches_enabled"),
    MESSAGES("notif_messages_enabled"),
    LIKES("notif_likes_enabled"),
    GARDENER("notif_gardener_local_enabled")
}

data class SettingsUiState(
    val profile: UserProfile? = null,
    /**
     * The OS-level switch. Actual permission handling lands with the
     * Notifications subsystem; until then this is the app-side master toggle.
     */
    val notificationsEnabled: Boolean = true,
    /** The recipient-side mindful check. Defaults on, as iOS does. */
    val mindfulMessagingEnabled: Boolean = true,
    val error: String? = null
) {
    // iOS defaults every one of these to true when the column is null.
    val matchesEnabled: Boolean get() = profile?.notifMatchesEnabled ?: true
    val messagesEnabled: Boolean get() = profile?.notifMessagesEnabled ?: true
    val likesEnabled: Boolean get() = profile?.notifLikesEnabled ?: true
    val gardenerEnabled: Boolean get() = profile?.notifGardenerLocalEnabled ?: true
}

/** Mirrors the settings half of Harvest/Views/Settings/SettingsView.swift. */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val authService: AuthService,
    private val mindful: MindfulMessagingService
) : ViewModel() {

    private val _state = MutableStateFlow(SettingsUiState())
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(mindfulMessagingEnabled = mindful.isEnabled) }

        runCatching { profileService.getProfile(userId) }
            .onSuccess { profile -> _state.update { it.copy(profile = profile) } }
            .onFailure { e -> _state.update { it.copy(error = e.userMessage()) } }
    }

    fun setNotificationsEnabled(userId: String, enabled: Boolean) =
        _state.update { it.copy(notificationsEnabled = enabled) }

    /** Optimistic, reverting the switch if the write fails. */
    fun setPref(userId: String, pref: NotificationPref, enabled: Boolean) = viewModelScope.launch {
        val previous = _state.value.profile
        _state.update { it.copy(profile = it.profile?.withPref(pref, enabled)) }

        try {
            val updated = profileService.updateProfile(
                userId,
                buildJsonObject { put(pref.column, enabled) }
            )
            _state.update { it.copy(profile = updated ?: it.profile, error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(profile = previous, error = e.userMessage()) }
        }
    }

    fun deleteAccount(userId: String, onDeleted: () -> Unit) = viewModelScope.launch {
        try {
            authService.deleteAccount(userId)
            onDeleted()
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    private fun UserProfile.withPref(pref: NotificationPref, enabled: Boolean) = when (pref) {
        NotificationPref.MATCHES -> copy(notifMatchesEnabled = enabled)
        NotificationPref.MESSAGES -> copy(notifMessagesEnabled = enabled)
        NotificationPref.LIKES -> copy(notifLikesEnabled = enabled)
        NotificationPref.GARDENER -> copy(notifGardenerLocalEnabled = enabled)
    }

    fun setMindfulMessagingEnabled(enabled: Boolean) {
        mindful.setEnabled(enabled)
        _state.update { it.copy(mindfulMessagingEnabled = enabled) }
    }
}
