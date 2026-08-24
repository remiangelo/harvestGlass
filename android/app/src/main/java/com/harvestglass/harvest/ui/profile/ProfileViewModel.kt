package com.harvestglass.harvest.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.AxisScoring
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
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
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

/** The editable copy of a profile, held separately so Cancel can discard it. */
data class ProfileDraft(
    val nickname: String = "",
    val bio: String = "",
    val location: String = "",
    val photoUrls: List<String> = emptyList(),
    val hobbies: List<String> = emptyList(),
    val age: Int = 18,
    val lookingFor: String = "",
    val heightCm: Int = 170,
    val smoking: String = "",
    val drinking: String = "",
    val cannabis: String = "",
    val spiritualOrientation: String = "",
    val childrenStatus: String = "",
    val relationshipStatus: String = "",
    val interestedIn: List<String> = emptyList()
) {
    companion object {
        fun from(profile: UserProfile) = ProfileDraft(
            nickname = profile.nickname.orEmpty(),
            bio = profile.bio.orEmpty(),
            location = profile.location.orEmpty(),
            photoUrls = profile.photos.orEmpty(),
            hobbies = profile.hobbies.orEmpty(),
            age = profile.age ?: 18,
            lookingFor = profile.lookingFor.orEmpty(),
            heightCm = profile.heightCm ?: 170,
            smoking = profile.smoking.orEmpty(),
            drinking = profile.drinking.orEmpty(),
            cannabis = profile.cannabis.orEmpty(),
            spiritualOrientation = profile.spiritualOrientation.orEmpty(),
            childrenStatus = profile.childrenStatus.orEmpty(),
            relationshipStatus = profile.relationshipStatus.orEmpty(),
            interestedIn = profile.interestedIn.orEmpty()
        )
    }
}

data class ProfileUiState(
    val profile: UserProfile? = null,
    val draft: ProfileDraft = ProfileDraft(),
    val valuesBrought: List<Value> = emptyList(),
    val valuesSought: List<Value> = emptyList(),
    val allQuestions: List<Question> = emptyList(),
    val answers: Map<String, String> = emptyMap(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
) {
    val needScores: AxisScores
        get() = AxisScoring.computeRawVectors(answers, allQuestions).first

    val bringScores: AxisScores
        get() = AxisScoring.computeRawVectors(answers, allQuestions).second

    /** The side the profile card shows; iOS defaults to "bring". */
    val graphIsNeed: Boolean get() = profile?.profileGraphSide == "need"

    val graphScores: AxisScores get() = if (graphIsNeed) needScores else bringScores
}

/** Mirrors Harvest/ViewModels/ProfileViewModel.swift. */
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val valuesService: ValuesService,
    private val questionsService: QuestionsService
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val profile = async { profileService.getProfile(userId) }
                val brought = async { runCatching { valuesService.getUserValuesBrought(userId) }.getOrNull() }
                val sought = async { runCatching { valuesService.getUserValuesSought(userId) }.getOrNull() }
                val questions = async { runCatching { questionsService.getAllQuestions() }.getOrNull() }
                val answers = async { runCatching { questionsService.getUserAnswers(userId) }.getOrNull() }

                val loaded = profile.await()
                _state.update {
                    it.copy(
                        profile = loaded,
                        draft = loaded?.let { p -> ProfileDraft.from(p) } ?: it.draft,
                        valuesBrought = brought.await().orEmpty(),
                        valuesSought = sought.await().orEmpty(),
                        allQuestions = questions.await().orEmpty(),
                        answers = answers.await().orEmpty(),
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

    fun updateDraft(draft: ProfileDraft) = _state.update { it.copy(draft = draft) }

    /** Throws away edits by re-seeding the draft from the loaded profile. */
    fun cancelEditing() = _state.update {
        it.copy(draft = it.profile?.let { p -> ProfileDraft.from(p) } ?: ProfileDraft())
    }

    suspend fun save(userId: String): Boolean {
        _state.update { it.copy(isSaving = true) }
        val d = _state.value.draft
        return try {
            val updates = buildJsonObject {
                put("nickname", d.nickname)
                put("bio", d.bio)
                put("location", d.location)
                put("age", d.age)
                put("looking_for", d.lookingFor)
                put("height_cm", d.heightCm)
                put("smoking", d.smoking)
                put("drinking", d.drinking)
                put("cannabis", d.cannabis)
                put("spiritual_orientation", d.spiritualOrientation)
                put("children_status", d.childrenStatus)
                put("relationship_status", d.relationshipStatus)
                put("photos", JsonArray(d.photoUrls.map { JsonPrimitive(it) }))
                put("hobbies", JsonArray(d.hobbies.map { JsonPrimitive(it) }))
                put("interested_in", JsonArray(d.interestedIn.map { JsonPrimitive(it) }))
            }
            val saved = profileService.updateProfile(userId, updates)
            if (saved != null) {
                _state.update { it.copy(profile = saved, error = null) }
                true
            } else {
                _state.update { it.copy(error = "Failed to save profile. Please try again.") }
                false
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
            false
        } finally {
            _state.update { it.copy(isSaving = false) }
        }
    }

    fun uploadPhoto(userId: String, imageData: ByteArray) = viewModelScope.launch {
        try {
            val url = profileService.uploadPhoto(userId, imageData, _state.value.draft.photoUrls.size)
            _state.update { it.copy(draft = it.draft.copy(photoUrls = it.draft.photoUrls + url)) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    fun removePhoto(userId: String, index: Int) {
        val url = _state.value.draft.photoUrls.getOrNull(index) ?: return
        _state.update {
            it.copy(draft = it.draft.copy(
                photoUrls = it.draft.photoUrls.filterIndexed { i, _ -> i != index }
            ))
        }
        viewModelScope.launch { runCatching { profileService.deletePhoto(userId, url) } }
    }
}
