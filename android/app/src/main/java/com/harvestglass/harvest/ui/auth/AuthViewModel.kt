package com.harvestglass.harvest.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.AuthService
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
    private val authService: AuthService
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
                // iOS also creates the profile row and initialises the
                // subscription here; both port with their features in P2.
                _state.update {
                    it.copy(
                        isLoading = false,
                        isAuthenticated = userId != null,
                        currentUserId = userId
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
