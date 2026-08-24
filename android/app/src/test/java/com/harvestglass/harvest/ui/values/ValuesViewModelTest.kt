package com.harvestglass.harvest.ui.values

import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.QuestionWeighting
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.QuestionsService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.data.service.ValuesService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ValuesViewModelTest {
    private val profileService: ProfileService = mockk(relaxed = true)
    private val valuesService: ValuesService = mockk(relaxed = true)
    private val questionsService: QuestionsService = mockk(relaxed = true)
    private val subscriptionService: SubscriptionService = mockk(relaxed = true)

    private fun vm() =
        ValuesViewModel(profileService, valuesService, questionsService, subscriptionService)

    private fun tier(name: TierName, growth: Boolean) =
        SubscriptionTier(id = "t-${name.raw}", name = name, hasGrowthFeatures = growth)

    private val calm = Value(id = "v1", name = "Calm", category = "lifestyle")
    private val trust = Value(id = "v2", name = "Trust", category = "relationship")

    private fun q(id: String, order: Int) = Question(
        id = id, prompt = "P", weighting = QuestionWeighting.BOTH,
        displayOrder = order, options = emptyList()
    )

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        // Free tier unless a test says otherwise.
        coEvery { subscriptionService.currentTier(any()) } returns tier(TierName.SEED, growth = false)
    }
    @After fun tearDown() { Dispatchers.resetMain() }

    // The single easiest thing to get backwards in this whole subsystem.
    @Test
    fun `the NEED side edits values SOUGHT`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm, trust)
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()
        vm.setSide(ValuesSide.NEED)

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertEquals(listOf("v1"), vm.state.value.valuesSought.map { it.id })
        assertTrue(vm.state.value.valuesBrought.isEmpty())
        coVerify { valuesService.saveUserValuesSought("u1", listOf("v1")) }
    }

    @Test
    fun `the BRING side edits values BROUGHT`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm, trust)
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()
        vm.setSide(ValuesSide.BRING)

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertEquals(listOf("v1"), vm.state.value.valuesBrought.map { it.id })
        assertTrue(vm.state.value.valuesSought.isEmpty())
        coVerify { valuesService.saveUserValuesBrought("u1", listOf("v1")) }
    }

    @Test
    fun `a failed value save reverts the optimistic edit`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm)
        coEvery { valuesService.saveUserValuesSought(any(), any()) } throws RuntimeException("nope")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertTrue(vm.state.value.valuesSought.isEmpty())
        assertEquals("nope", vm.state.value.saveError)
    }

    @Test
    fun `value selection is capped at three per side`() = runTest {
        val values = (1..4).map { Value(id = "v$it", name = "V$it", category = "c") }
        coEvery { valuesService.getAllValues() } returns values
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        values.forEach { vm.toggleValue("u1", it.id); advanceUntilIdle() }

        assertEquals(3, vm.state.value.valuesSought.size)
    }

    @Test
    fun `toggling an already-selected value removes it`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm)
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.toggleValue("u1", "v1"); advanceUntilIdle()
        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertTrue(vm.state.value.valuesSought.isEmpty())
    }

    @Test
    fun `a failed answer save reverts to the previous answer`() = runTest {
        coEvery { questionsService.getUserAnswers(any()) } returns mapOf("q1" to "a")
        coEvery { questionsService.saveAnswer(any(), any(), any()) } throws RuntimeException("x")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.saveAnswer("u1", "q1", "b"); advanceUntilIdle()

        assertEquals("a", vm.state.value.answers["q1"])
    }

    @Test
    fun `an answer that had no previous value is removed on failure`() = runTest {
        coEvery { questionsService.getUserAnswers(any()) } returns emptyMap()
        coEvery { questionsService.saveAnswer(any(), any(), any()) } throws RuntimeException("x")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.saveAnswer("u1", "q9", "opt"); advanceUntilIdle()

        assertFalse(vm.state.value.answers.containsKey("q9"))
    }

    @Test
    fun `a successful answer save sticks`() = runTest {
        coEvery { questionsService.getUserAnswers(any()) } returns emptyMap()
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.saveAnswer("u1", "q9", "opt"); advanceUntilIdle()

        assertEquals("opt", vm.state.value.answers["q9"])
    }

    @Test
    fun `the retake banner shows below ten answers and hides at ten`() {
        assertTrue(ValuesUiState(answers = (1..9).associate { "q$it" to "a" }).showRetakeBanner)
        assertFalse(ValuesUiState(answers = (1..10).associate { "q$it" to "a" }).showRetakeBanner)
    }

    @Test
    fun `remaining question count never goes negative`() {
        val state = ValuesUiState(
            allQuestions = listOf(q("q1", 1)),
            answers = mapOf("q1" to "a", "stale" to "b")
        )
        assertEquals(0, state.remainingQuestionCount)
    }

    @Test
    fun `unanswered questions come back in display order`() {
        val qs = listOf(q("q2", 2), q("q1", 1), q("q3", 3))
        val state = ValuesUiState(allQuestions = qs, answers = mapOf("q1" to "a"))
        assertEquals(listOf("q2", "q3"), state.unansweredQuestions.map { it.id })
    }

    @Test
    fun `active scores follow the selected side`() {
        val state = ValuesUiState(side = ValuesSide.NEED)
        assertEquals(state.needScores, state.activeScores)
        assertEquals(state.bringScores, state.copy(side = ValuesSide.BRING).activeScores)
    }

    @Test
    fun `active value ids follow the selected side`() {
        val state = ValuesUiState(
            valuesBrought = listOf(calm),
            valuesSought = listOf(trust),
            side = ValuesSide.NEED
        )
        assertEquals(setOf("v2"), state.activeValueIds)
        assertEquals(setOf("v1"), state.copy(side = ValuesSide.BRING).activeValueIds)
    }

    @Test
    fun `growth features default to locked`() {
        // Swift: "Defaults to locked so a failed tier lookup can't hand it out."
        assertFalse(ValuesUiState().hasGrowthFeatures)
    }

    @Test
    fun `display toggle columns match the database`() {
        assertEquals("show_values_brought", DisplayToggle.BROUGHT.column)
        assertEquals("show_values_blurb", DisplayToggle.BLURB.column)
        assertEquals("show_values_graph", DisplayToggle.GRAPH.column)
    }

    @Test
    fun `Gold unlocks the growth features`() = runTest {
        coEvery { subscriptionService.currentTier("u1") } returns tier(TierName.GOLD, growth = true)
        val vm = vm()

        vm.load("u1"); advanceUntilIdle()

        assertTrue(vm.state.value.hasGrowthFeatures)
    }

    @Test
    fun `the free tier leaves the growth features locked`() = runTest {
        val vm = vm()

        vm.load("u1"); advanceUntilIdle()

        assertFalse(vm.state.value.hasGrowthFeatures)
    }

    // A tier lookup that fails must lock the paid features, never hand them out.
    @Test
    fun `an unreadable tier fails closed`() = runTest {
        coEvery { subscriptionService.currentTier("u1") } returns null
        val vm = vm()

        vm.load("u1"); advanceUntilIdle()

        assertFalse(vm.state.value.hasGrowthFeatures)
    }
}
