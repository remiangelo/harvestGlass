package com.harvestglass.harvest.ui.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.ValuesService
import com.harvestglass.harvest.util.Geocoding
import com.harvestglass.harvest.util.ObjectionableContent
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.LocalDate
import java.time.Period
import javax.inject.Inject

/** Mirrors OnboardingStep in Harvest/ViewModels/OnboardingViewModel.swift. */
enum class OnboardingStep {
    AGE,
    NICKNAME,
    PHOTOS,
    GOALS,
    VALUES,
    REFLECTIONS,
    GENDER_IDENTITY,
    INTERESTED_IN,
    RELATIONSHIP_STATUS,
    LOCATION,
    TERMS,
    COMPLETE
}

data class OnboardingUiState(
    val currentStep: OnboardingStep = OnboardingStep.AGE,
    val birthDate: LocalDate = LocalDate.now().minusYears(25),
    val nickname: String = "",
    val photoUrls: List<String> = emptyList(),
    val selectedGoals: Set<String> = emptySet(),
    val allValues: List<Value> = emptyList(),
    val selectedValuesBrought: Set<String> = emptySet(),
    val selectedValuesSought: Set<String> = emptySet(),
    val allQuestions: List<Question> = emptyList(),
    /** questionId -> optionId */
    val reflectionAnswers: Map<String, String> = emptyMap(),
    val currentReflectionIndex: Int = 0,
    val gender: String = "",
    val interestedIn: Set<String> = emptySet(),
    /** single|dating|in_relationship|engaged|married */
    val relationshipStatus: String = "",
    val location: String = "",
    val resolvedLocation: String? = null,
    val locationSuggestions: List<String> = emptyList(),
    val termsAccepted: Boolean = false,
    val isLoading: Boolean = false,
    val isValidatingLocation: Boolean = false,
    val isLoadingValues: Boolean = false,
    val isLoadingQuestions: Boolean = false,
    val error: String? = null
) {
    val age: Int get() = Period.between(birthDate, LocalDate.now()).years

    val isAgeValid: Boolean get() = age >= 18

    /** Branch for branch from the Swift `canProceed` switch. */
    val canProceed: Boolean
        get() = when (currentStep) {
            OnboardingStep.AGE -> isAgeValid
            OnboardingStep.NICKNAME -> {
                val trimmed = nickname.trim()
                trimmed.isNotEmpty() && !ObjectionableContent.contains(trimmed)
            }
            OnboardingStep.PHOTOS -> photoUrls.isNotEmpty()
            OnboardingStep.GOALS -> selectedGoals.isNotEmpty()
            OnboardingStep.VALUES ->
                selectedValuesBrought.isNotEmpty() && selectedValuesSought.isNotEmpty()
            OnboardingStep.REFLECTIONS ->
                allQuestions.isNotEmpty() && reflectionAnswers.size >= allQuestions.size
            OnboardingStep.GENDER_IDENTITY -> gender.isNotEmpty()
            OnboardingStep.INTERESTED_IN -> interestedIn.isNotEmpty()
            OnboardingStep.RELATIONSHIP_STATUS -> relationshipStatus.isNotEmpty()
            OnboardingStep.LOCATION -> resolvedLocation != null
            OnboardingStep.TERMS -> termsAccepted
            OnboardingStep.COMPLETE -> true
        }

    val progress: Float
        get() {
            val total = (OnboardingStep.entries.size - 1).toFloat()
            if (currentStep == OnboardingStep.REFLECTIONS && allQuestions.isNotEmpty()) {
                val sub = currentReflectionIndex.toFloat() / allQuestions.size.toFloat()
                return (currentStep.ordinal + sub) / total
            }
            return currentStep.ordinal / total
        }
}

/** Mirrors Harvest/ViewModels/OnboardingViewModel.swift. */
@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val valuesService: ValuesService,
    private val questionsService: QuestionsService,
    private val geocoding: Geocoding
) : ViewModel() {

    private val _state = MutableStateFlow(OnboardingUiState())
    val state: StateFlow<OnboardingUiState> = _state.asStateFlow()

    // MARK: - Navigation

    fun nextStep() = _state.update { s ->
        val next = OnboardingStep.entries.getOrNull(s.currentStep.ordinal + 1) ?: return@update s
        s.copy(currentStep = next)
    }

    fun previousStep() = _state.update { s ->
        val prev = OnboardingStep.entries.getOrNull(s.currentStep.ordinal - 1) ?: return@update s
        s.copy(currentStep = prev)
    }

    // MARK: - Draft setters

    fun setBirthDate(date: LocalDate) = _state.update { it.copy(birthDate = date) }
    fun setNickname(value: String) = _state.update { it.copy(nickname = value) }
    fun setGender(value: String) = _state.update { it.copy(gender = value) }
    fun setRelationshipStatus(value: String) = _state.update { it.copy(relationshipStatus = value) }
    fun setTermsAccepted(value: Boolean) = _state.update { it.copy(termsAccepted = value) }

    fun toggleGoal(goal: String) = _state.update {
        it.copy(selectedGoals = it.selectedGoals.toggled(goal))
    }

    fun toggleInterestedIn(option: String) = _state.update {
        it.copy(interestedIn = it.interestedIn.toggled(option))
    }

    fun toggleValueBrought(valueId: String) = _state.update {
        it.copy(selectedValuesBrought = it.selectedValuesBrought.toggled(valueId))
    }

    fun toggleValueSought(valueId: String) = _state.update {
        it.copy(selectedValuesSought = it.selectedValuesSought.toggled(valueId))
    }

    fun answerReflection(questionId: String, optionId: String) = _state.update {
        it.copy(reflectionAnswers = it.reflectionAnswers + (questionId to optionId))
    }

    fun setReflectionIndex(index: Int) = _state.update { it.copy(currentReflectionIndex = index) }

    fun setLocationQuery(value: String) = _state.update {
        // Typing invalidates a previously resolved place, or the user could
        // edit the text after resolving and still pass the step.
        it.copy(location = value, resolvedLocation = null)
    }

    fun clearError() = _state.update { it.copy(error = null) }

    private fun <T> Set<T>.toggled(item: T): Set<T> =
        if (contains(item)) this - item else this + item

    // MARK: - Loading

    fun loadValuesIfNeeded() = viewModelScope.launch {
        if (_state.value.allValues.isNotEmpty() || _state.value.isLoadingValues) return@launch
        _state.update { it.copy(isLoadingValues = true) }
        try {
            val values = valuesService.getAllValues()
            _state.update { it.copy(allValues = values) }
        } catch (e: Exception) {
            _state.update { it.copy(error = "Failed to load values: ${e.message}") }
        } finally {
            _state.update { it.copy(isLoadingValues = false) }
        }
    }

    fun loadQuestionsIfNeeded() = viewModelScope.launch {
        if (_state.value.allQuestions.isNotEmpty() || _state.value.isLoadingQuestions) return@launch
        _state.update { it.copy(isLoadingQuestions = true) }
        try {
            // Onboarding only presents the first 10 questions; the Q11-Q35
            // deep dive is reached from the Values tab.
            val questions = questionsService.getAllQuestions()
                .sortedBy { it.displayOrder }
                .take(ONBOARDING_QUESTION_COUNT)
            _state.update { it.copy(allQuestions = questions) }
        } catch (e: Exception) {
            _state.update { it.copy(error = "Failed to load questions: ${e.message}") }
        } finally {
            _state.update { it.copy(isLoadingQuestions = false) }
        }
    }

    // MARK: - Photos

    fun uploadPhoto(userId: String, imageData: ByteArray) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null) }
        try {
            val url = profileService.uploadPhoto(
                userId = userId,
                imageData = imageData,
                photoIndex = _state.value.photoUrls.size
            )
            _state.update { it.copy(photoUrls = it.photoUrls + url) }
        } catch (e: Exception) {
            _state.update { it.copy(error = "Failed to upload photo: ${e.message}") }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun removePhoto(userId: String, index: Int) {
        val url = _state.value.photoUrls.getOrNull(index) ?: return
        _state.update { it.copy(photoUrls = it.photoUrls.filterIndexed { i, _ -> i != index }) }
        viewModelScope.launch {
            // Photo removed from the UI regardless; a storage failure leaves an
            // orphan rather than blocking the user, exactly as on iOS.
            runCatching { profileService.deletePhoto(userId, url) }
        }
    }

    // MARK: - Location

    fun validateLocation() = viewModelScope.launch {
        val query = _state.value.location.trim()
        if (query.isEmpty()) {
            _state.update { it.copy(resolvedLocation = null, locationSuggestions = emptyList()) }
            return@launch
        }

        _state.update { it.copy(isValidatingLocation = true) }
        try {
            val suggestions = geocoding.suggestions(query)
            _state.update {
                it.copy(
                    locationSuggestions = suggestions,
                    resolvedLocation = suggestions.firstOrNull()
                )
            }
        } finally {
            _state.update { it.copy(isValidatingLocation = false) }
        }
    }

    fun selectLocationSuggestion(suggestion: String) = _state.update {
        it.copy(
            location = suggestion,
            resolvedLocation = suggestion,
            locationSuggestions = listOf(suggestion)
        )
    }

    // MARK: - Completion

    suspend fun completeOnboarding(userId: String): UserProfile? {
        _state.update { it.copy(isLoading = true) }
        val s = _state.value

        val updates = buildJsonObject {
            put("nickname", s.nickname)
            put("age", s.age)
            put("bio", "I'm new here!")
            put("gender", s.gender)
            put("goals", s.selectedGoals.joinToString(","))
            put("photos", JsonArray(s.photoUrls.map { JsonPrimitive(it) }))
            put("location", s.resolvedLocation ?: s.location)
            put("interested_in", JsonArray(s.interestedIn.map { JsonPrimitive(it) }))
            put("relationship_status", s.relationshipStatus)
            put("onboarding_completed", true)
        }

        return try {
            val saved = profileService.updateProfile(userId, updates)
                // Profile row doesn't exist — create it via upsert.
                ?: profileService.upsertProfile(userId, updates)

            if (saved == null) {
                _state.update { it.copy(error = "Failed to save profile. Please try again.") }
                return null
            }

            // Best-effort: a failure here shouldn't strand the user at
            // onboarding — they can re-edit values later.
            runCatching {
                valuesService.saveUserValuesBrought(userId, s.selectedValuesBrought.toList())
                valuesService.saveUserValuesSought(userId, s.selectedValuesSought.toList())
            }
            runCatching { questionsService.saveAnswers(userId, s.reflectionAnswers) }

            saved
        } catch (e: Exception) {
            _state.update { it.copy(error = "Failed to save profile: ${e.message}") }
            null
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    companion object {
        const val ONBOARDING_QUESTION_COUNT = 10
    }
}
