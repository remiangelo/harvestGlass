package com.harvestglass.harvest.ui.gardener

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.GardenerMessage
import com.harvestglass.harvest.data.service.GardenerService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class GardenerUiState(
    val messages: List<GardenerMessage> = emptyList(),
    val draft: String = "",
    val isLoading: Boolean = false,
    val isThinking: Boolean = false,
    val error: String? = null
)

/** Mirrors the chat half of Harvest/ViewModels/GardenerViewModel.swift. */
@HiltViewModel
class GardenerViewModel @Inject constructor(
    private val service: GardenerService
) : ViewModel() {

    private val _state = MutableStateFlow(GardenerUiState())
    val state: StateFlow<GardenerUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            val history = service.getChatHistory(userId)
            _state.update {
                it.copy(
                    // An empty transcript opens on the welcome line rather than
                    // a blank screen, as iOS does.
                    messages = history.ifEmpty { listOf(welcomeMessage(userId)) },
                    error = null
                )
            }
        } catch (e: Exception) {
            _state.update {
                it.copy(messages = listOf(welcomeMessage(userId)), error = e.userMessage())
            }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun updateDraft(text: String) = _state.update { it.copy(draft = text) }

    fun send(userId: String, content: String = _state.value.draft) = viewModelScope.launch {
        if (_state.value.isThinking) return@launch
        val text = content.trim()
        if (text.isEmpty()) return@launch

        val optimistic = GardenerMessage(
            id = "local-${System.nanoTime()}",
            userId = userId,
            role = "user",
            content = text
        )
        _state.update {
            it.copy(messages = it.messages + optimistic, draft = "", isThinking = true, error = null)
        }

        try {
            val reply = service.sendMessage(userId, text, _state.value.messages.dropLast(1))
            _state.update {
                it.copy(
                    messages = it.messages + GardenerMessage(
                        id = "reply-${System.nanoTime()}",
                        userId = userId,
                        role = "assistant",
                        content = reply
                    )
                )
            }
        } catch (e: Exception) {
            // Hand the text back so a failed turn isn't a lost message.
            _state.update {
                it.copy(
                    messages = it.messages.filterNot { m -> m.id == optimistic.id },
                    draft = text,
                    error = e.userMessage()
                )
            }
        } finally {
            _state.update { it.copy(isThinking = false) }
        }
    }

    private fun welcomeMessage(userId: String) = GardenerMessage(
        id = "welcome",
        userId = userId,
        role = "assistant",
        content = GardenerService.WELCOME_MESSAGE
    )
}
