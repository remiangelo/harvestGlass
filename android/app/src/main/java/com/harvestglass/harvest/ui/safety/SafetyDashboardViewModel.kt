package com.harvestglass.harvest.ui.safety

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.RedFlagReport
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.SafetyAnalysisService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SafetyDashboardUiState(
    val analyses: List<SafetyAnalysis> = emptyList(),
    /** userId → profile, for the names beside each score. */
    val profiles: Map<String, UserProfile> = emptyMap(),
    val selectedAnalysis: SafetyAnalysis? = null,
    val redFlags: List<RedFlagReport> = emptyList(),
    val isLoading: Boolean = false,
    val isAnalyzing: Boolean = false,
    val error: String? = null
)

/** Mirrors Harvest/ViewModels/SafetyDashboardViewModel.swift. */
@HiltViewModel
class SafetyDashboardViewModel @Inject constructor(
    private val safety: SafetyAnalysisService,
    private val profileService: ProfileService
) : ViewModel() {

    private val _state = MutableStateFlow(SafetyDashboardUiState())
    val state: StateFlow<SafetyDashboardUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            val analyses = safety.getSafetyDashboard(userId)
            _state.update { it.copy(analyses = analyses, error = null) }
            loadProfiles(analyses.map { it.otherUserId }.filter { it.isNotEmpty() }.toSet())
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun select(analysis: SafetyAnalysis) = viewModelScope.launch {
        _state.update { it.copy(selectedAnalysis = analysis, redFlags = emptyList()) }
        val flags = runCatching { safety.getRedFlags(analysis.id) }.getOrNull().orEmpty()
        _state.update { it.copy(redFlags = flags) }
    }

    fun clearSelection() = _state.update { it.copy(selectedAnalysis = null, redFlags = emptyList()) }

    fun clearError() = _state.update { it.copy(error = null) }

    /**
     * Re-scores every conversation. Threads that predate the scoring have no
     * flags at all until this runs.
     */
    fun runBulkAnalysis(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isAnalyzing = true) }
        try {
            safety.analyzeAllUserConversations(userId)
            load(userId).join()
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isAnalyzing = false) }
        }
    }

    private suspend fun loadProfiles(userIds: Set<String>) {
        if (userIds.isEmpty()) return

        val loaded = coroutineScope {
            userIds
                .map { id -> async { runCatching { profileService.getProfile(id) }.getOrNull() } }
                .mapNotNull { it.await() }
                .associateBy { it.id }
        }

        _state.update { it.copy(profiles = it.profiles + loaded) }
    }
}
