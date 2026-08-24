package com.harvestglass.harvest.ui.values

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.AxisScoring
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.data.service.ValuesService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

enum class ValuesSide(val raw: String) { NEED("need"), BRING("bring") }

enum class DisplayToggle(val column: String) {
    BROUGHT("show_values_brought"),
    BLURB("show_values_blurb"),
    GRAPH("show_values_graph")
}

data class ValuesUiState(
    val profile: UserProfile? = null,
    val valuesBrought: List<Value> = emptyList(),
    val valuesSought: List<Value> = emptyList(),
    val allValues: List<Value> = emptyList(),
    val allQuestions: List<Question> = emptyList(),
    /** questionId -> optionId */
    val answers: Map<String, String> = emptyMap(),
    val side: ValuesSide = ValuesSide.NEED,
    val isLoading: Boolean = false,
    val loadError: String? = null,
    val saveError: String? = null,
    val toggleError: String? = null,
    /**
     * Gold's "premium growth features" — the Tips library is what that buys
     * today. Defaults to locked so a failed tier lookup can't hand it out.
     */
    val hasGrowthFeatures: Boolean = false
) {
    // Raw per-category scores — the radar maps these into visual tiers.
    val needScores: AxisScores
        get() = AxisScoring.computeRawVectors(answers, allQuestions).first

    val bringScores: AxisScores
        get() = AxisScoring.computeRawVectors(answers, allQuestions).second

    val activeScores: AxisScores
        get() = if (side == ValuesSide.NEED) needScores else bringScores

    /**
     * NEED shows what you're looking for, which is `valuesSought`; BRING shows
     * `valuesBrought`. The inversion is deliberate — do not "fix" it.
     */
    val activeValueIds: Set<String>
        get() = (if (side == ValuesSide.NEED) valuesSought else valuesBrought).map { it.id }.toSet()

    val answeredQuestionCount: Int get() = answers.size
    val totalQuestionCount: Int get() = allQuestions.size
    val remainingQuestionCount: Int get() = (totalQuestionCount - answeredQuestionCount).coerceAtLeast(0)
    val showRetakeBanner: Boolean get() = answeredQuestionCount < ONBOARDING_ANSWER_FLOOR

    val unansweredQuestions: List<Question>
        get() = allQuestions.filter { answers[it.id] == null }.sortedBy { it.displayOrder }

    companion object {
        /** Onboarding collects 10; below that the tab nudges the user to retake. */
        const val ONBOARDING_ANSWER_FLOOR = 10
    }
}

/** Mirrors Harvest/ViewModels/ValuesViewModel.swift. */
@HiltViewModel
class ValuesViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val valuesService: ValuesService,
    private val questionsService: QuestionsService,
    private val subscriptionService: SubscriptionService
) : ViewModel() {

    private val _state = MutableStateFlow(ValuesUiState())
    val state: StateFlow<ValuesUiState> = _state.asStateFlow()

    private val maxValueSelections = 3

    fun setSide(side: ValuesSide) = _state.update { it.copy(side = side) }

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                // All run concurrently, as the Swift `async let` block does.
                val profile = async { profileService.getProfile(userId) }
                val brought = async { runCatching { valuesService.getUserValuesBrought(userId) }.getOrNull() }
                val sought = async { runCatching { valuesService.getUserValuesSought(userId) }.getOrNull() }
                val allValues = async { runCatching { valuesService.getAllValues() }.getOrNull() }
                val allQuestions = async { runCatching { questionsService.getAllQuestions() }.getOrNull() }
                val answers = async { runCatching { questionsService.getUserAnswers(userId) }.getOrNull() }
                // Fail-closed: a null tier leaves the paid features locked.
                val growth = async { subscriptionService.currentTier(userId)?.hasGrowthFeatures }

                // Only the profile fetch can set loadError; the rest degrade to
                // empty, matching Swift's `(try? await …) ?? []`.
                val loadedProfile = profile.await()
                _state.update {
                    it.copy(
                        profile = loadedProfile,
                        valuesBrought = brought.await().orEmpty(),
                        valuesSought = sought.await().orEmpty(),
                        allValues = allValues.await().orEmpty(),
                        allQuestions = allQuestions.await().orEmpty(),
                        answers = answers.await().orEmpty(),
                        hasGrowthFeatures = growth.await() ?: false,
                        loadError = null
                    )
                }
            }
        } catch (e: Exception) {
            _state.update { it.copy(loadError = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    /** Toggles the value on the active side. Optimistic; reverts on save failure. */
    fun toggleValue(userId: String, valueId: String) = viewModelScope.launch {
        val before = _state.value
        val current = if (before.side == ValuesSide.NEED) before.valuesSought else before.valuesBrought

        val next = when {
            current.any { it.id == valueId } -> current.filterNot { it.id == valueId }
            current.size < maxValueSelections ->
                before.allValues.firstOrNull { it.id == valueId }?.let { current + it } ?: return@launch
            // At the cap and not already selected: the Swift version returns
            // without touching anything.
            else -> return@launch
        }

        _state.update {
            if (before.side == ValuesSide.NEED) it.copy(valuesSought = next) else it.copy(valuesBrought = next)
        }

        try {
            if (before.side == ValuesSide.NEED) {
                valuesService.saveUserValuesSought(userId, next.map { it.id })
            } else {
                valuesService.saveUserValuesBrought(userId, next.map { it.id })
            }
            _state.update { it.copy(saveError = null) }
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    valuesBrought = before.valuesBrought,
                    valuesSought = before.valuesSought,
                    saveError = e.userMessage()
                )
            }
        }
    }

    fun saveAnswer(userId: String, questionId: String, optionId: String) = viewModelScope.launch {
        val previous = _state.value.answers[questionId]
        _state.update { it.copy(answers = it.answers + (questionId to optionId)) }

        try {
            questionsService.saveAnswer(userId, questionId, optionId)
            _state.update { it.copy(saveError = null) }
        } catch (e: Exception) {
            _state.update {
                val restored = if (previous != null) {
                    it.answers + (questionId to previous)
                } else {
                    it.answers - questionId
                }
                it.copy(answers = restored, saveError = e.userMessage())
            }
        }
    }

    fun setDisplayToggle(userId: String, key: DisplayToggle, isOn: Boolean) = viewModelScope.launch {
        val previous = _state.value.profile
        _state.update { it.copy(profile = it.profile?.withToggle(key, isOn)) }

        try {
            val updated = profileService.updateProfile(
                userId,
                buildJsonObject { put(key.column, isOn) }
            )
            _state.update { it.copy(profile = updated ?: it.profile, toggleError = null) }
        } catch (e: Exception) {
            _state.update { it.copy(profile = previous, toggleError = e.userMessage()) }
        }
    }

    fun setGraphSide(userId: String, side: ValuesSide) = viewModelScope.launch {
        val previous = _state.value.profile
        _state.update { it.copy(profile = it.profile?.copy(profileGraphSide = side.raw)) }

        try {
            val updated = profileService.updateProfile(
                userId,
                buildJsonObject { put("profile_graph_side", side.raw) }
            )
            _state.update { it.copy(profile = updated ?: it.profile, toggleError = null) }
        } catch (e: Exception) {
            _state.update { it.copy(profile = previous, toggleError = e.userMessage()) }
        }
    }

    private fun UserProfile.withToggle(key: DisplayToggle, isOn: Boolean): UserProfile = when (key) {
        DisplayToggle.BROUGHT -> copy(showValuesBrought = isOn)
        DisplayToggle.BLURB -> copy(showValuesBlurb = isOn)
        DisplayToggle.GRAPH -> copy(showValuesGraph = isOn)
    }
}
