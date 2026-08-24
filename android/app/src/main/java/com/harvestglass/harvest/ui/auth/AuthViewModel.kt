package com.harvestglass.harvest.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = true,
    val isAuthenticated: Boolean = false,
    val profile: UserProfile? = null,
    val currentUserId: String? = null,
    val error: String? = null
) {
    /**
     * Mirrors AuthViewModel.swift exactly:
     *   onboardingCompleted != true && (age == nil || gender == nil || photos.isEmpty)
     */
    val needsOnboarding: Boolean
        get() {
            val p = profile ?: return true
            return p.onboardingCompleted != true &&
                (p.age == null || p.gender == null || p.photos.isNullOrEmpty())
        }
}

/** Mirrors Harvest/ViewModels/AuthViewModel.swift. */
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authService: AuthService,
    private val profileService: ProfileService,
    private val subscriptionService: SubscriptionService
) : ViewModel() {

    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun checkSession() = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        val userId = runCatching { authService.currentUserId() }.getOrNull()
        if (userId == null) {
            _state.update { it.copy(isLoading = false, isAuthenticated = false) }
            return@launch
        }
        val profile = runCatching { authService.loadProfile(userId) }.getOrNull()
        _state.update {
            it.copy(
                isLoading = false,
                isAuthenticated = true,
                currentUserId = userId,
                profile = profile
            )
        }
    }

    fun login(email: String, password: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching { authService.signIn(email, password) }
            .onSuccess { userId ->
                val profile = runCatching { authService.loadProfile(userId) }.getOrNull()
                _state.update {
                    it.copy(
                        isLoading = false,
                        isAuthenticated = true,
                        currentUserId = userId,
                        profile = profile
                    )
                }
            }
            .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.userMessage()) } }
    }

    fun register(email: String, password: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching { authService.signUp(email, password) }
            .onSuccess { userId ->
                if (userId != null) {
                    // Signup fails if the profile row doesn't land — everything
                    // downstream reads it. Swift throws here for the same reason.
                    val created = runCatching { profileService.createProfile(userId, email) }
                    if (created.isFailure) {
                        _state.update {
                            it.copy(
                                isLoading = false,
                                error = created.exceptionOrNull()?.userMessage()
                            )
                        }
                        return@onSuccess
                    }

                    // Best-effort, as on iOS: a missing row just reads as the
                    // free tier, which is what a new account gets anyway.
                    runCatching { subscriptionService.initializeUserSubscription(userId) }
                }

                val profile = userId?.let {
                    runCatching { authService.loadProfile(it) }.getOrNull()
                }
                _state.update {
                    it.copy(
                        isLoading = false,
                        isAuthenticated = userId != null,
                        currentUserId = userId,
                        profile = profile
                    )
                }
            }
            .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.userMessage()) } }
    }

    fun logout() = viewModelScope.launch {
        runCatching { authService.signOut() }
        _state.value = AuthUiState(isLoading = false, isAuthenticated = false)
    }
}
