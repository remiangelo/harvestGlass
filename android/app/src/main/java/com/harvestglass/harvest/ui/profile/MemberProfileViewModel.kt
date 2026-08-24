package com.harvestglass.harvest.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.AxisScoring
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.SeedService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.data.service.ValuesService
import com.harvestglass.harvest.ui.components.ReportTarget
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

data class MemberProfileUiState(
    val profile: UserProfile? = null,
    val valuesBrought: List<Value> = emptyList(),
    val allQuestions: List<Question> = emptyList(),
    /** questionId -> optionId, for the person being viewed. */
    val answers: Map<String, String> = emptyMap(),

    /** Seeds sent today and the tier's daily allowance. */
    val seedsSentToday: Int = 0,
    val seedLimit: Int = DEFAULT_SEED_LIMIT,

    val isLoading: Boolean = false,
    val isSending: Boolean = false,
    val error: String? = null,
    /** Set once a Seed lands, so the sheet can close and confirm. */
    val seedSent: Boolean = false,
    /** Set once the viewer blocks this person, so the screen can pop. */
    val blocked: Boolean = false
) {
    val atSeedLimit: Boolean get() = seedsSentToday >= seedLimit

    /**
     * Which side of the radar the person chose to show. `profileGraphSide`
     * defaults to "bring", as it does on iOS.
     */
    val graphScores: AxisScores
        get() {
            val vectors = AxisScoring.computeRawVectors(answers, allQuestions)
            return if (profile?.profileGraphSide == "need") vectors.first else vectors.second
        }

    val graphLabel: String
        get() = if (profile?.profileGraphSide == "need") "Needs" else "Brings"

    companion object {
        const val DEFAULT_SEED_LIMIT = 3
    }
}

/**
 * Backs the read-only view of someone else's profile — Android's counterpart
 * to Harvest/Views/Discover/ProfileDetailView.swift.
 *
 * Despite living under Views/Discover on iOS, this is not swipe-era code: it
 * is the only place a Seed can be sent from, and it is reached from the room
 * roster, community chat, and the inbound-likes list.
 */
@HiltViewModel
class MemberProfileViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val valuesService: ValuesService,
    private val questionsService: QuestionsService,
    private val seedService: SeedService,
    private val subscriptionService: SubscriptionService,
    private val matchService: MatchService
) : ViewModel() {

    private val _state = MutableStateFlow(MemberProfileUiState())
    val state: StateFlow<MemberProfileUiState> = _state.asStateFlow()

    fun load(profileId: String, viewerId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val profile = async { profileService.getProfile(profileId) }
                // Each of these degrades to empty; a missing section is better
                // than an empty screen.
                val brought = async {
                    runCatching { valuesService.getUserValuesBrought(profileId) }.getOrNull()
                }
                val questions = async {
                    runCatching { questionsService.getAllQuestions() }.getOrNull()
                }
                val answers = async {
                    runCatching { questionsService.getUserAnswers(profileId) }.getOrNull()
                }
                val limit = async {
                    runCatching { subscriptionService.dailySeedLimit(viewerId) }.getOrNull()
                }
                val sent = async {
                    runCatching { seedService.sentTodayCount(viewerId) }.getOrNull()
                }

                _state.update {
                    it.copy(
                        profile = profile.await(),
                        valuesBrought = brought.await().orEmpty(),
                        allQuestions = questions.await().orEmpty(),
                        answers = answers.await().orEmpty(),
                        seedLimit = limit.await() ?: MemberProfileUiState.DEFAULT_SEED_LIMIT,
                        seedsSentToday = sent.await() ?: 0,
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

    fun sendSeed(viewerId: String, recipientId: String, message: String) = viewModelScope.launch {
        if (_state.value.isSending || _state.value.atSeedLimit) return@launch
        val text = message.trim()
        if (text.isEmpty()) return@launch

        _state.update { it.copy(isSending = true, error = null) }
        try {
            seedService.sendSeed(viewerId, recipientId, text)
            _state.update {
                it.copy(seedSent = true, seedsSentToday = it.seedsSentToday + 1, error = null)
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isSending = false) }
        }
    }

    fun clearSeedSent() = _state.update { it.copy(seedSent = false) }

    fun clearError() = _state.update { it.copy(error = null) }

    fun report(
        viewerId: String,
        reportedUserId: String,
        category: String,
        description: String,
        target: ReportTarget = ReportTarget.Profile
    ) = viewModelScope.launch {
        try {
            matchService.reportUser(
                reporterId = viewerId,
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

    /**
     * Blocks and auto-files a report, as iOS does — Apple 1.2 requires the
     * developer be notified, and the same expectation applies here.
     */
    fun block(viewerId: String, blockedUserId: String) = viewModelScope.launch {
        try {
            matchService.blockUser(
                userId = viewerId,
                blockedUserId = blockedUserId,
                reason = "Blocked from profile",
                description = "User blocked while browsing profiles — filed for moderator review."
            )
            _state.update { it.copy(blocked = true, error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }
}
