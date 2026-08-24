package com.harvestglass.harvest.ui.field

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.FieldFilterLevel
import com.harvestglass.harvest.data.model.RoomMemberFilter
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.CommunityService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RoomMembersUiState(
    val members: List<UserProfile> = emptyList(),
    val filter: RoomMemberFilter = RoomMemberFilter(),
    /**
     * Which filter block the viewer's tier unlocks. Defaults to locked; the
     * tier lookup lands with the Subscription subsystem, and a failure there
     * must leave the paid filters closed rather than open.
     */
    val filterLevel: FieldFilterLevel = FieldFilterLevel.NONE,
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val canAccessAdvanced: Boolean get() = filterLevel.unlocksAdvanced
    val canAccessFull: Boolean get() = filterLevel.unlocksFull

    /** Members matching the filter, excluding the viewer, alphabetical. */
    fun visibleMembers(currentUserId: String): List<UserProfile> =
        members
            .filter { it.id != currentUserId }
            .filter { filter.matches(it) }
            .sortedBy { it.displayName.lowercase() }
}

/** Mirrors Harvest/ViewModels/RoomMembersViewModel.swift. */
@HiltViewModel
class RoomMembersViewModel @Inject constructor(
    private val service: CommunityService
) : ViewModel() {

    private val _state = MutableStateFlow(RoomMembersUiState())
    val state: StateFlow<RoomMembersUiState> = _state.asStateFlow()

    fun load(communityId: String, userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            val members = service.memberProfiles(communityId)
            _state.update { it.copy(members = members, error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun updateFilter(filter: RoomMemberFilter) = _state.update { it.copy(filter = filter) }

    fun setSearch(query: String) = _state.update { it.copy(filter = it.filter.copy(search = query)) }

    fun resetFilter() = _state.update {
        // Search is deliberately preserved — clearing filters shouldn't wipe
        // what someone is actively typing.
        it.copy(filter = RoomMemberFilter(search = it.filter.search))
    }
}
