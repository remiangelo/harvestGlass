package com.harvestglass.harvest.ui.gardener

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.DailyQuiz
import com.harvestglass.harvest.data.model.GardenerMessage
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.service.GardenerService
import com.harvestglass.harvest.data.service.OpenAIService
import com.harvestglass.harvest.data.service.RateLimitService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.util.ScreenshotEncoder
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class GardenerUiState(
    val messages: List<GardenerMessage> = emptyList(),
    val draft: String = "",
    val isLoading: Boolean = false,
    val isThinking: Boolean = false,
    val error: String? = null,

    /** Images staged in the composer, awaiting send. Never persisted. */
    val pendingScreenshots: List<Uri> = emptyList(),
    /**
     * Encoded images from the last send, kept so a follow-up in the same
     * sitting can be answered by looking again. Dies with the process; never
     * uploaded, never written to chat history.
     */
    val retainedImageUrls: List<String> = emptyList(),
    /** Images allowed per message on the current tier. */
    val imageCap: Int = 1,

    val characterLimit: Int = FREE_CHARACTER_LIMIT,
    val charactersUsedToday: Int = 0,
    val screenshotLimit: Int = FREE_SCREENSHOT_LIMIT,
    val screenshotsUsedToday: Int = 0,

    val dailyQuiz: DailyQuiz? = null,
    val showDailyQuiz: Boolean = false,
    val isSubmittingQuiz: Boolean = false
) {
    val hasPendingScreenshot: Boolean get() = pendingScreenshots.isNotEmpty()

    val remainingCharacters: Int get() = (characterLimit - charactersUsedToday).coerceAtLeast(0)
    val isAtCharacterLimit: Boolean get() = charactersUsedToday >= characterLimit

    val remainingScreenshots: Int get() = (screenshotLimit - screenshotsUsedToday).coerceAtLeast(0)
    val isAtScreenshotLimit: Boolean get() = remainingScreenshots == 0

    /**
     * The composer only locks outright once BOTH budgets are spent — chat
     * characters and screenshot reviews are separate allowances.
     */
    val isFullyLocked: Boolean get() = isAtCharacterLimit && isAtScreenshotLimit

    companion object {
        /** The free tier's allowances, and the offline fallback. */
        const val FREE_CHARACTER_LIMIT = 2000
        const val FREE_SCREENSHOT_LIMIT = 1
    }
}

/** Mirrors Harvest/ViewModels/GardenerViewModel.swift. */
@HiltViewModel
class GardenerViewModel @Inject constructor(
    private val service: GardenerService,
    private val subscriptionService: SubscriptionService,
    private val rateLimitService: RateLimitService,
    private val openAI: OpenAIService
) : ViewModel() {

    private val _state = MutableStateFlow(GardenerUiState())
    val state: StateFlow<GardenerUiState> = _state.asStateFlow()

    private var currentTier: SubscriptionTier? = null

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }

        loadTierLimits(userId)

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

    fun clearError() = _state.update { it.copy(error = null) }

    fun send(userId: String, content: String = _state.value.draft) = viewModelScope.launch {
        if (_state.value.isThinking) return@launch
        val text = content.trim()
        if (text.isEmpty()) return@launch

        val tier = currentTier
        if (tier == null) {
            _state.update { it.copy(error = "Unable to verify subscription tier") }
            return@launch
        }

        // A failed limit check must not block the send — the budget is a
        // courtesy, and a network blip shouldn't read as "you're out".
        val check = runCatching {
            rateLimitService.checkGardenerLimit(userId, text.length, tier)
        }.getOrNull()

        if (check != null && !check.canSend) {
            _state.update { it.copy(error = check.reason) }
            return@launch
        }

        // A follow-up while images are still in hand goes back through the
        // image call so the Gardener can look again rather than guess — but
        // only after the character-limit check above, so the conversation
        // that follows a review is still metered like any other message.
        // It is not a new review though: trackScreenshotReview and
        // checkScreenshotLimit are deliberately not called for it.
        val retained = _state.value.retainedImageUrls
        if (retained.isNotEmpty()) {
            sendRetained(userId, retained, text)
            return@launch
        }

        val optimistic = GardenerMessage(
            id = "local-${System.nanoTime()}",
            userId = userId,
            role = "user",
            content = text
        )
        _state.update {
            it.copy(
                messages = it.messages + optimistic,
                draft = "",
                isThinking = true,
                error = null,
                charactersUsedToday = it.charactersUsedToday + text.length
            )
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
            runCatching { rateLimitService.trackGardenerConversation(userId, text.length) }
        } catch (e: Exception) {
            // Hand the text back so a failed turn isn't a lost message.
            _state.update {
                it.copy(
                    messages = it.messages.filterNot { m -> m.id == optimistic.id },
                    draft = text,
                    charactersUsedToday =
                        (it.charactersUsedToday - text.length).coerceAtLeast(0),
                    error = e.userMessage()
                )
            }
        } finally {
            _state.update { it.copy(isThinking = false) }
        }
    }

    /**
     * A fresh selection replaces whatever was staged, and drops any images
     * retained from a previous review — the ViewModel is Activity-scoped, so
     * without this a review from an hour ago would silently keep answering
     * an unrelated new question.
     */
    fun stageScreenshots(uris: List<Uri>) = _state.update {
        it.copy(
            pendingScreenshots = clampSelection(uris, it.imageCap),
            retainedImageUrls = emptyList()
        )
    }

    /** Drops one staged image, e.g. from a thumbnail's remove button. */
    fun unstageScreenshot(index: Int) = _state.update {
        it.copy(pendingScreenshots = it.pendingScreenshots.filterIndexed { i, _ -> i != index })
    }

    fun clearScreenshot() = _state.update { it.copy(pendingScreenshots = emptyList()) }

    /**
     * Ends the current follow-up sitting: retained images are dropped, and
     * the next question goes through the metered chat path like any other
     * message. Task 5 wires this to a dismissible "following up on N
     * images" chip.
     */
    fun clearRetainedImages() = _state.update { it.copy(retainedImageUrls = emptyList()) }

    /**
     * Sends the staged images for review. They are encoded inline and
     * dropped — nothing is uploaded to storage. The encoded data URLs are
     * retained in memory afterwards so a same-sitting follow-up question can
     * reuse them without spending another daily review.
     */
    fun sendImages(context: Context, userId: String) = viewModelScope.launch {
        if (_state.value.isThinking) return@launch
        val uris = _state.value.pendingScreenshots
        if (uris.isEmpty()) return@launch

        val tier = currentTier
        if (tier == null) {
            _state.update { it.copy(error = "Unable to verify subscription tier") }
            return@launch
        }

        val check = runCatching {
            rateLimitService.checkScreenshotLimit(userId, tier)
        }.getOrNull()

        if (check != null && !check.canSend) {
            _state.update { it.copy(error = check.reason) }
            return@launch
        }

        val caption = _state.value.draft.trim()

        // Encode before mutating any state, so a bad image leaves the composer
        // exactly as the user left it.
        val target = ScreenshotEncoder.targetDimension(uris.size)
        val dataUrls = try {
            withContext(Dispatchers.IO) { uris.map { ScreenshotEncoder.dataUrl(context, it, target) } }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
            return@launch
        }

        payloadRejection(dataUrls)?.let { message ->
            _state.update { it.copy(error = message) }
            return@launch
        }

        val placeholder = GardenerService.screenshotPlaceholder(caption, uris.size)
        _state.update {
            it.copy(
                draft = "",
                pendingScreenshots = emptyList(),
                retainedImageUrls = dataUrls,
                isThinking = true,
                error = null,
                screenshotsUsedToday = it.screenshotsUsedToday + 1,
                messages = it.messages + GardenerMessage(
                    id = "local-${System.nanoTime()}",
                    userId = userId,
                    role = "user",
                    content = placeholder
                )
            )
        }

        runCatching { rateLimitService.trackScreenshotReview(userId) }

        try {
            val reply = service.sendImages(
                userId = userId,
                imageDataUrls = dataUrls,
                caption = caption,
                history = _state.value.messages.dropLast(1)
            )
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
        } catch (_: Exception) {
            // Transport or decode failure — never presented as "not a
            // screenshot", which would blame the user for a network problem.
            _state.update {
                it.copy(error = "I couldn't read that screenshot just now. Try sending it again.")
            }
        } finally {
            _state.update { it.copy(isThinking = false) }
        }
    }

    /**
     * A follow-up question about images already in hand this sitting. Sends
     * the user's real text (not a placeholder) alongside the retained images,
     * and deliberately calls neither checkScreenshotLimit nor
     * trackScreenshotReview — this is a second question about one review, not
     * a new one. The caller has already run it past checkGardenerLimit, so
     * this still spends and tracks the chat character budget exactly as
     * send() would: the exemption is for the review, not the conversation
     * that follows it.
     */
    private suspend fun sendRetained(userId: String, retained: List<String>, text: String) {
        val optimistic = GardenerMessage(
            id = "local-${System.nanoTime()}",
            userId = userId,
            role = "user",
            content = text
        )
        _state.update {
            it.copy(
                messages = it.messages + optimistic,
                draft = "",
                isThinking = true,
                error = null,
                charactersUsedToday = it.charactersUsedToday + text.length
            )
        }

        try {
            val reply = service.sendImages(
                userId = userId,
                imageDataUrls = retained,
                caption = text,
                history = _state.value.messages.dropLast(1)
            )
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
            runCatching { rateLimitService.trackGardenerConversation(userId, text.length) }
        } catch (_: Exception) {
            _state.update {
                it.copy(
                    charactersUsedToday = (it.charactersUsedToday - text.length).coerceAtLeast(0),
                    error = "I couldn't read that screenshot just now. Try sending it again."
                )
            }
        } finally {
            _state.update { it.copy(isThinking = false) }
        }
    }

    /** Opens today's quiz, if there is one and it hasn't been answered. */
    fun checkDailyQuiz(userId: String) = viewModelScope.launch {
        // Delay slightly for better UX, as iOS does.
        delay(QUIZ_DELAY_MS)

        try {
            val quiz = service.generateDailyQuiz(userId)
            if (quiz != null && !quiz.isAnswered) {
                _state.update { it.copy(dailyQuiz = quiz, showDailyQuiz = true) }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = "Daily quiz failed to load: ${e.userMessage()}") }
        }
    }

    fun dismissDailyQuiz() = _state.update { it.copy(showDailyQuiz = false) }

    fun submitQuizAnswer(userId: String, answer: String) = viewModelScope.launch {
        val quiz = _state.value.dailyQuiz ?: return@launch
        _state.update { it.copy(isSubmittingQuiz = true) }

        val insight = runCatching {
            openAI.sendChat(
                messages = listOf(
                    OpenAIService.ChatMessage(
                        "system",
                        "You are a dating coach. Give a brief 1-2 sentence insight " +
                            "based on this quiz answer."
                    ),
                    OpenAIService.ChatMessage(
                        "user",
                        "Question: ${quiz.question}\nAnswer: $answer"
                    )
                ),
                temperature = 0.7,
                maxTokens = 100
            )
        }.getOrElse { FALLBACK_INSIGHT }

        runCatching { service.saveQuizAnswer(userId, quiz, answer) }

        _state.update {
            it.copy(
                isSubmittingQuiz = false,
                dailyQuiz = quiz.copy(
                    selectedAnswer = answer,
                    insight = insight,
                    isAnswered = true
                )
            )
        }
    }

    /**
     * Adopts the user's tier allowances and reads today's usage back for both
     * budgets. Falls back to the free tier so a failed lookup leaves the
     * composer usable rather than locking someone out.
     */
    private suspend fun loadTierLimits(userId: String) {
        val tier = runCatching { subscriptionService.currentTier(userId) }.getOrNull()

        if (tier != null) {
            currentTier = tier
            val used = runCatching { rateLimitService.charactersUsedToday(userId) }.getOrNull()
            val shots = runCatching { rateLimitService.screenshotsUsedToday(userId) }.getOrNull()
            _state.update {
                it.copy(
                    characterLimit = tier.gardenerCharacterLimit,
                    screenshotLimit = tier.gardenerScreenshotsPerDay,
                    imageCap = tier.gardenerImagesPerReview,
                    charactersUsedToday = used ?: 0,
                    screenshotsUsedToday = shots ?: 0
                )
            }
            return
        }

        currentTier = FREE_FALLBACK
        _state.update {
            it.copy(
                characterLimit = GardenerUiState.FREE_CHARACTER_LIMIT,
                screenshotLimit = GardenerUiState.FREE_SCREENSHOT_LIMIT,
                imageCap = FREE_FALLBACK.gardenerImagesPerReview,
                charactersUsedToday = 0,
                screenshotsUsedToday = 0
            )
        }
    }

    private fun welcomeMessage(userId: String) = GardenerMessage(
        id = "welcome",
        userId = userId,
        role = "assistant",
        content = GardenerService.WELCOME_MESSAGE
    )

    companion object {
        private const val QUIZ_DELAY_MS = 2000L

        private const val FALLBACK_INSIGHT =
            "Interesting choice! Self-awareness is the first step to meaningful connections."

        /** Total encoded budget for one request, in characters of base64. */
        const val PAYLOAD_BUDGET_CHARS = 6_000_000

        /**
         * The images actually sent. The picker is opened with the cap, but a
         * picker limit is an affordance rather than a guarantee — and a cap of
         * zero from a malformed tier row must still let one image through.
         */
        fun clampSelection(picked: List<Uri>, cap: Int): List<Uri> =
            picked.take(cap.coerceAtLeast(1))

        /**
         * Null when the encoded selection fits, otherwise the message to show.
         * Scaling bounds each image; nothing bounds the sum, and a transport
         * error tells the user nothing about what to do differently.
         */
        fun payloadRejection(dataUrls: List<String>): String? {
            val total = dataUrls.sumOf { it.length }
            if (total <= PAYLOAD_BUDGET_CHARS) return null
            return "Those ${dataUrls.size} images are too large to send together. " +
                "Try sending fewer at a time."
        }

        /** The offline tier: free allowances, nothing unlocked. */
        private val FREE_FALLBACK = SubscriptionTier(
            id = "",
            name = TierName.SEED,
            displayName = "Seed",
            gardenerCharacterLimit = GardenerUiState.FREE_CHARACTER_LIMIT,
            gardenerScreenshotsPerDay = GardenerUiState.FREE_SCREENSHOT_LIMIT
        )
    }
}
