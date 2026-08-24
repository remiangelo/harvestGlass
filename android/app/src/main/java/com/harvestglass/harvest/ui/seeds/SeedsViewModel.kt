package com.harvestglass.harvest.ui.seeds

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.ConversationWithProfile
import com.harvestglass.harvest.data.model.Seed
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.SeedService
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

enum class SeedsSegment { REQUESTS, CONVERSATIONS }

enum class RequestKind { RECEIVED, SENT }

data class SeedsUiState(
    val segment: SeedsSegment = SeedsSegment.REQUESTS,
    val requestKind: RequestKind = RequestKind.RECEIVED,
    val received: List<Seed> = emptyList(),
    val sent: List<Seed> = emptyList(),
    val conversations: List<ConversationWithProfile> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    /** Set when a Seed is accepted so the view can route into the conversation. */
    val openedConversationId: String? = null,
    /** Partner user id for the opened conversation (the sender of the accepted seed). */
    val openedPartnerUserId: String? = null
) {
    val visibleRequests: List<Seed>
        get() = if (requestKind == RequestKind.RECEIVED) received else sent
}

/** Mirrors Harvest/ViewModels/SeedsViewModel.swift, plus the conversation list. */
@HiltViewModel
class SeedsViewModel @Inject constructor(
    private val seedService: SeedService,
    private val matchService: MatchService
) : ViewModel() {

    private val _state = MutableStateFlow(SeedsUiState())
    val state: StateFlow<SeedsUiState> = _state.asStateFlow()

    fun setSegment(segment: SeedsSegment) = _state.update { it.copy(segment = segment) }

    fun setRequestKind(kind: RequestKind) = _state.update { it.copy(requestKind = kind) }

    fun clearOpenedConversation() = _state.update {
        it.copy(openedConversationId = null, openedPartnerUserId = null)
    }

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val received = async { seedService.receivedPending(userId) }
                val sent = async { seedService.sentPending(userId) }
                // The conversation list degrades to empty rather than failing
                // the whole tab — the requests half is still useful without it.
                val conversations = async {
                    runCatching { matchService.getConversations(userId) }.getOrNull()
                }
                _state.update {
                    it.copy(
                        received = received.await(),
                        sent = sent.await(),
                        conversations = conversations.await().orEmpty(),
                        error = null
                    )
                }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun accept(seed: Seed, userId: String) = viewModelScope.launch {
        try {
            val conversationId = seedService.acceptSeed(seed.id)
            _state.update {
                it.copy(
                    received = it.received.filterNot { s -> s.id == seed.id },
                    // The partner is whoever SENT the seed we just accepted.
                    openedPartnerUserId = seed.senderId,
                    openedConversationId = conversationId,
                    error = null
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    fun decline(seed: Seed, userId: String) = viewModelScope.launch {
        try {
            seedService.declineSeed(seed.id)
            _state.update {
                it.copy(received = it.received.filterNot { s -> s.id == seed.id }, error = null)
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }
}
