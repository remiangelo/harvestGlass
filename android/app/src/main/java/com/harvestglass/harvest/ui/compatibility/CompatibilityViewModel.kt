package com.harvestglass.harvest.ui.compatibility

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.AxisScoring
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.CompatibilityService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.data.service.ValueOverlap
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
import javax.inject.Inject

/** Which side of the alignment the radar is showing. */
enum class Perspective { YOURS, THEIRS }

data class CompatibilityUiState(
    val otherProfile: UserProfile? = null,
    val perspective: Perspective = Perspective.YOURS,

    val myNeedScores: AxisScores = AxisScores(),
    val myBringScores: AxisScores = AxisScores(),
    val theirNeedScores: AxisScores = AxisScores(),
    val theirBringScores: AxisScores = AxisScores(),

    val myNeeds: List<Value> = emptyList(),
    val myBrings: List<Value> = emptyList(),
    val theirNeeds: List<Value> = emptyList(),
    val theirBrings: List<Value> = emptyList(),

    /**
     * The radar and the value chips are free. The interpretation on top of
     * them — overlap scoring and the written read — is the paid part.
     * Defaults to locked so a failed tier read can't hand it out.
     */
    val hasAdvancedInsights: Boolean = false,

    val isLoading: Boolean = true,
    val loadError: String? = null
) {
    val otherName: String get() = otherProfile?.displayName.orEmpty()

    val overlap: ValueOverlap
        get() = CompatibilityService.valueOverlap(myNeeds, myBrings, theirNeeds, theirBrings)

    /** The written read, composed from the same inputs iOS uses. */
    val blurb: String
        get() = CompatibilityService.compatibilityBlurb(
            otherName = otherName,
            bringCosine = AxisScores.cosine(myBringScores, theirBringScores),
            needCosine = AxisScores.cosine(myNeedScores, theirNeedScores),
            topSharedAxis = CompatibilityService.topSharedAxis(myBringScores, theirNeedScores),
            overlap = overlap,
            // A zero denominator would read as "0 of 0"; iOS floors it at 1.
            myNeedsCount = maxOf(1, myNeeds.size)
        )
}

/** Mirrors Harvest/Views/Compatibility/CompatibilityView.swift's own loading. */
@HiltViewModel
class CompatibilityViewModel @Inject constructor(
    private val profileService: ProfileService,
    private val valuesService: ValuesService,
    private val questionsService: QuestionsService,
    private val subscriptionService: SubscriptionService
) : ViewModel() {

    private val _state = MutableStateFlow(CompatibilityUiState())
    val state: StateFlow<CompatibilityUiState> = _state.asStateFlow()

    fun setPerspective(perspective: Perspective) =
        _state.update { it.copy(perspective = perspective) }

    fun load(viewerId: String, otherUserId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val other = async { profileService.getProfile(otherUserId) }
                val myAnswers = async {
                    runCatching { questionsService.getUserAnswers(viewerId) }.getOrNull()
                }
                val theirAnswers = async {
                    runCatching { questionsService.getUserAnswers(otherUserId) }.getOrNull()
                }
                val questions = async {
                    runCatching { questionsService.getAllQuestions() }.getOrNull()
                }
                val myBrought = async {
                    runCatching { valuesService.getUserValuesBrought(viewerId) }.getOrNull()
                }
                val mySought = async {
                    runCatching { valuesService.getUserValuesSought(viewerId) }.getOrNull()
                }
                val theirBrought = async {
                    runCatching { valuesService.getUserValuesBrought(otherUserId) }.getOrNull()
                }
                val theirSought = async {
                    runCatching { valuesService.getUserValuesSought(otherUserId) }.getOrNull()
                }
                val insights = async {
                    subscriptionService.currentTier(viewerId)?.hasDeepSoilInsights
                }

                val allQuestions = questions.await().orEmpty()

                // Raw per-category scores: the radar tiers them for display, and
                // cosine is scale-invariant, so raw is right for both.
                val mine = AxisScoring.computeRawVectors(myAnswers.await().orEmpty(), allQuestions)
                val theirs =
                    AxisScoring.computeRawVectors(theirAnswers.await().orEmpty(), allQuestions)

                _state.update {
                    it.copy(
                        otherProfile = other.await(),
                        myNeedScores = mine.first,
                        myBringScores = mine.second,
                        theirNeedScores = theirs.first,
                        theirBringScores = theirs.second,
                        myBrings = myBrought.await().orEmpty(),
                        myNeeds = mySought.await().orEmpty(),
                        theirBrings = theirBrought.await().orEmpty(),
                        theirNeeds = theirSought.await().orEmpty(),
                        hasAdvancedInsights = insights.await() ?: false,
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
}
