package com.harvestglass.harvest.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.ChatService
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.SafetyAnalysisService
import com.harvestglass.harvest.data.service.MindfulAnalysis
import com.harvestglass.harvest.data.service.MindfulMessagingService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.ui.components.ReportTarget
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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
    val safetyAnalysis: SafetyAnalysis? = null,
    /** Shown as a banner above the transcript when the score drops below 50. */
    val safetyWarning: String? = null,
    val showReadyToMoveGate: Boolean = false,
    val isReadyToMove: Boolean = false,
    val readyToMoveReason: String? = null,
    /** Set once a share is recorded, so the screen can confirm it. */
    val readyToMoveMessage: String? = null,
    /** Set when the pre-send check flags a message; drives the warning sheet. */
    val mindfulWarning: MindfulAnalysis? = null,
    /** The flagged text, held so "Send Anyway" posts exactly what was typed. */
    val pendingSend: String? = null,
    /** The partner is typing right now. Clears itself after 3s of silence. */
    val isPartnerTyping: Boolean = false,
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
    private val matchService: MatchService,
    private val mindful: MindfulMessagingService,
    private val safety: SafetyAnalysisService
) : ViewModel() {

    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    private var conversationId: String = ""
    private var userId: String = ""
    private var messageJob: Job? = null
    private var typingJob: Job? = null
    private var typingSendJob: Job? = null
    private var typingDismissJob: Job? = null

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
                _state.update { it.copy(error = e.userMessage()) }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }

            messageJob?.cancel()
            messageJob = viewModelScope.launch {
                chatService.subscribeToMessages(conversationId).collect { msg ->
                    // Keyed on id: the sender already inserted it optimistically.
                    if (_state.value.messages.none { it.id == msg.id }) {
                        _state.update { it.copy(messages = it.messages + msg) }
                        // Only the other person's messages are scored — you are
                        // warned about your own before they are sent.
                        if (!msg.isSentBy(userId)) scoreIncoming(msg.content)
                    }
                }
            }

            loadSafetyAnalysis(partnerUserId)

            typingJob?.cancel()
            typingJob = viewModelScope.launch {
                chatService.subscribeToTyping(conversationId).collect { typistId ->
                    // Your own keystrokes come back on the same channel.
                    if (typistId == userId) return@collect

                    _state.update { it.copy(isPartnerTyping = true) }

                    // Typing has no "stopped" event, so the indicator expires
                    // on its own and every new keystroke restarts the clock.
                    typingDismissJob?.cancel()
                    typingDismissJob = viewModelScope.launch {
                        delay(TYPING_DISMISS_MS)
                        _state.update { it.copy(isPartnerTyping = false) }
                    }
                }
            }
        }
    }

    fun onDraftChange(text: String) {
        _state.update { it.copy(draft = text) }
        if (text.isNotEmpty()) scheduleTypingIndicator()
    }

    /**
     * Broadcasts one "typing" ping per burst of keystrokes rather than one per
     * character — the debounce is what keeps the channel quiet.
     */
    private fun scheduleTypingIndicator() {
        typingSendJob?.cancel()
        typingSendJob = viewModelScope.launch {
            delay(TYPING_DEBOUNCE_MS)
            if (conversationId.isEmpty() || userId.isEmpty()) return@launch
            runCatching { chatService.sendTypingIndicator(conversationId, userId) }
        }
    }

    /**
     * Runs the mindful check before sending. A flagged message opens the
     * warning instead — the send is deferred, not cancelled, so "Send Anyway"
     * still posts exactly what was typed.
     */
    fun send(content: String = _state.value.draft) = viewModelScope.launch {
        if (_state.value.isSending) return@launch
        val text = content.trim()
        if (text.isEmpty()) return@launch

        if (mindful.isEnabled) {
            val analysis = mindful.analyzeMessage(text)
            if (analysis.needsReview) {
                _state.update { it.copy(mindfulWarning = analysis, pendingSend = text) }
                return@launch
            }
        }

        deliver(text)
    }

    /** Dismisses the warning and puts the text back in the composer. */
    fun editFlaggedMessage() = _state.update {
        it.copy(mindfulWarning = null, pendingSend = null, draft = it.pendingSend ?: it.draft)
    }

    /** The nudge is not a block: this posts the message as typed. */
    fun sendAnyway() = viewModelScope.launch {
        val text = _state.value.pendingSend ?: return@launch
        _state.update { it.copy(mindfulWarning = null, pendingSend = null) }
        deliver(text)
    }

    private suspend fun deliver(text: String) {
        _state.update { it.copy(isSending = true, draft = "", error = null) }
        try {
            val sent = chatService.sendMessage(conversationId, userId, text)
            _state.update { s ->
                val alreadyThere = sent == null || s.messages.any { it.id == sent.id }
                s.copy(messages = if (alreadyThere) s.messages else s.messages + sent!!)
            }
        } catch (e: Exception) {
            // Hand the text back so a failed send isn't a lost message.
            _state.update { it.copy(draft = text, error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isSending = false) }
        }
    }

    /**
     * Loads or creates the analysis for this conversation.
     *
     * Every failure here is silent: safety scoring is a background service, and
     * a chat that works is better than one blocked on it.
     */
    private suspend fun loadSafetyAnalysis(partnerUserId: String) {
        // A Seed conversation that never had a match has nothing to key on.
        val matchId = runCatching { chatService.matchId(conversationId) }.getOrNull() ?: return

        val analysis = runCatching {
            safety.getOrCreateAnalysis(
                matchId = matchId,
                userId = userId,
                otherUserId = partnerUserId
            )
        }.getOrNull() ?: return

        _state.update { it.copy(safetyAnalysis = analysis, safetyWarning = warningFor(analysis)) }
    }

    /** Below 50 the conversation gets a standing banner, as on iOS. */
    private fun warningFor(analysis: SafetyAnalysis): String? =
        if (analysis.safetyScore < 50) {
            "Safety concern detected. Be cautious in this conversation."
        } else {
            null
        }

    /** Scores one incoming message and refreshes the banner. */
    private suspend fun scoreIncoming(content: String?) {
        val analysis = _state.value.safetyAnalysis ?: return
        val text = content?.takeIf { it.isNotBlank() } ?: return

        runCatching { safety.analyzeMessage(text, analysis.id) }
        val refreshed = runCatching {
            safety.getOrCreateAnalysis(
                matchId = analysis.matchId,
                userId = userId,
                otherUserId = analysis.otherUserId
            )
        }.getOrNull() ?: return

        _state.update { it.copy(safetyAnalysis = refreshed, safetyWarning = warningFor(refreshed)) }
    }

    /** Opens the ready-to-move gate, refreshing its verdict first. */
    fun presentReadyToMoveGate() = viewModelScope.launch {
        val analysis = _state.value.safetyAnalysis
        if (analysis == null) {
            _state.update {
                it.copy(
                    showReadyToMoveGate = true,
                    isReadyToMove = false,
                    readyToMoveReason = "No safety analysis available yet."
                )
            }
            return@launch
        }

        val (ready, reason) = runCatching { safety.isReadyToMove(analysis.id) }
            .getOrDefault(false to "We couldn't check this conversation just now.")

        _state.update {
            it.copy(showReadyToMoveGate = true, isReadyToMove = ready, readyToMoveReason = reason)
        }
    }

    fun dismissReadyToMoveGate() = _state.update { it.copy(showReadyToMoveGate = false) }

    fun clearReadyToMoveMessage() = _state.update { it.copy(readyToMoveMessage = null) }

    /** Records that the user chose to share contact details. */
    fun markPreferredContactShared() = viewModelScope.launch {
        val analysis = _state.value.safetyAnalysis ?: return@launch
        if (!_state.value.isReadyToMove) return@launch

        try {
            safety.recordReadyToMoveDecision(
                userId = userId,
                matchId = analysis.matchId,
                conversationId = analysis.conversationId,
                safetyScore = analysis.safetyScore,
                approved = true,
                contactShared = true,
                contactMethod = "social"
            )
            _state.update {
                it.copy(
                    showReadyToMoveGate = false,
                    readyToMoveMessage =
                        "You're clear to share your preferred contact details in the chat."
                )
            }
        } catch (_: Exception) {
            _state.update {
                it.copy(
                    readyToMoveMessage =
                        "We couldn't record your sharing action. Please try again."
                )
            }
        }
    }

    /**
     * Which lexicon an incoming message trips, or null when it is clean or the
     * recipient has turned mindful messaging off.
     */
    fun flaggedCategory(content: String?): String? {
        if (!mindful.isEnabled) return null
        return mindful.localFlag(content.orEmpty())?.category
    }

    fun markRead(messageId: String) = viewModelScope.launch {
        runCatching { chatService.markAsRead(messageId) }
    }

    fun report(
        reportedUserId: String,
        category: String,
        description: String,
        target: ReportTarget = ReportTarget.Profile
    ) =
        viewModelScope.launch {
            try {
                matchService.reportUser(
                    reporterId = userId,
                    reportedUserId = reportedUserId,
                    category = category,
                    description = description,
                    targetType = target.typeString,
                    targetId = target.targetId
                )
                _state.update { it.copy(error = null) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.userMessage()) }
            }
        }

    fun block(blockedUserId: String) = viewModelScope.launch {
        try {
            matchService.blockUser(userId, blockedUserId)
            _state.update { it.copy(error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    fun unmatch(matchId: String) = viewModelScope.launch {
        try {
            matchService.unmatchUser(matchId)
            _state.update { it.copy(error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    override fun onCleared() {
        super.onCleared()
        messageJob?.cancel()
        typingJob?.cancel()
        typingSendJob?.cancel()
        typingDismissJob?.cancel()
    }

    companion object {
        /** One ping per burst of keystrokes, matching Swift's 500ms debounce. */
        private const val TYPING_DEBOUNCE_MS = 500L

        /** How long an indicator survives without another ping. */
        private const val TYPING_DISMISS_MS = 3000L
    }
}
