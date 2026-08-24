package com.harvestglass.harvest.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.ChatService
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.ProfileService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ChatUiState(
    val messages: List<Message> = emptyList(),
    val partner: UserProfile? = null,
    val draft: String = "",
    val isLoading: Boolean = false,
    val isSending: Boolean = false,
    val error: String? = null
)

/**
 * Mirrors the message-transport half of Harvest/ViewModels/ChatViewModel.swift.
 *
 * The mindful pre-send warning and the safety "ready to move" analysis are NOT
 * ported here — both are OpenAI-backed and belong to the Gardener/AI subsystem.
 * Everything about sending, receiving, echo de-duplication and read receipts is
 * reproduced.
 */
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatService: ChatService,
    private val profileService: ProfileService,
    private val matchService: MatchService
) : ViewModel() {

    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    private var conversationId: String = ""
    private var userId: String = ""
    private var messageJob: Job? = null

    fun start(conversationId: String, userId: String, partnerUserId: String) {
        this.conversationId = conversationId
        this.userId = userId

        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val messages = chatService.getMessages(conversationId)
                val partner = runCatching { profileService.getProfile(partnerUserId) }.getOrNull()
                _state.update { it.copy(messages = messages, partner = partner, error = null) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }

            messageJob?.cancel()
            messageJob = viewModelScope.launch {
                chatService.subscribeToMessages(conversationId).collect { msg ->
                    // Keyed on id: the sender already inserted it optimistically.
                    if (_state.value.messages.none { it.id == msg.id }) {
                        _state.update { it.copy(messages = it.messages + msg) }
                    }
                }
            }
        }
    }

    fun onDraftChange(text: String) = _state.update { it.copy(draft = text) }

    fun send(content: String = _state.value.draft) = viewModelScope.launch {
        if (_state.value.isSending) return@launch
        val text = content.trim()
        if (text.isEmpty()) return@launch

        _state.update { it.copy(isSending = true, draft = "", error = null) }
        try {
            val sent = chatService.sendMessage(conversationId, userId, text)
            _state.update { s ->
                val alreadyThere = sent == null || s.messages.any { it.id == sent.id }
                s.copy(messages = if (alreadyThere) s.messages else s.messages + sent!!)
            }
        } catch (e: Exception) {
            // Hand the text back so a failed send isn't a lost message.
            _state.update { it.copy(draft = text, error = e.message) }
        } finally {
            _state.update { it.copy(isSending = false) }
        }
    }

    fun markRead(messageId: String) = viewModelScope.launch {
        runCatching { chatService.markAsRead(messageId) }
    }

    fun report(reportedUserId: String, category: String, description: String) =
        viewModelScope.launch {
            try {
                matchService.reportUser(userId, reportedUserId, category, description)
                _state.update { it.copy(error = null) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            }
        }

    fun block(blockedUserId: String) = viewModelScope.launch {
        try {
            matchService.blockUser(userId, blockedUserId)
            _state.update { it.copy(error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.message) }
        }
    }

    fun unmatch(matchId: String) = viewModelScope.launch {
        try {
            matchService.unmatchUser(matchId)
            _state.update { it.copy(error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.message) }
        }
    }

    override fun onCleared() {
        super.onCleared()
        messageJob?.cancel()
    }
}
