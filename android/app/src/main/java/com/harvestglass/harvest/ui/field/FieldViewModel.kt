package com.harvestglass.harvest.ui.field

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.data.service.CommunityService
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

data class FieldUiState(
    val available: List<Community> = emptyList(),
    val joinedIds: Set<String> = emptySet(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    fun isJoined(community: Community): Boolean = joinedIds.contains(community.id)
}

/** Mirrors Harvest/ViewModels/FieldViewModel.swift. */
@HiltViewModel
class FieldViewModel @Inject constructor(
    private val service: CommunityService
) : ViewModel() {

    private val _state = MutableStateFlow(FieldUiState())
    val state: StateFlow<FieldUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            // iOS runs both concurrently via `async let`.
            coroutineScope {
                val availableDeferred = async { service.availableCommunities(userId) }
                val joinedDeferred = async { service.joinedCommunityIds(userId) }
                val available = availableDeferred.await()
                val joined = joinedDeferred.await()
                _state.update { it.copy(available = available, joinedIds = joined) }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            // Mirrors the Swift `defer` — clears on failure too.
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun toggleJoin(community: Community, userId: String) = viewModelScope.launch {
        try {
            if (_state.value.joinedIds.contains(community.id)) {
                service.leave(community.id, userId)
                _state.update { it.copy(joinedIds = it.joinedIds - community.id) }
            } else {
                service.join(community.id, userId)
                _state.update { it.copy(joinedIds = it.joinedIds + community.id) }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }
}
