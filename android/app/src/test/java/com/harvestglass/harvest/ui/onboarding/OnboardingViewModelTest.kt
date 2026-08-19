package com.harvestglass.harvest.ui.onboarding

import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.QuestionWeighting
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * canProceed and progress are where a mistake either traps a user at a step or
 * lets an incomplete profile through, so every branch of the Swift switch in
 * OnboardingViewModel.swift is covered here.
 */
class OnboardingViewModelTest {

    private fun state(
        step: OnboardingStep,
        block: OnboardingUiState.() -> OnboardingUiState = { this }
    ) = OnboardingUiState(currentStep = step).block()

    private fun question(id: String) = Question(
        id = id, prompt = "P", weighting = QuestionWeighting.BOTH,
        displayOrder = 0, options = emptyList()
    )

    @Test
    fun `age under eighteen cannot proceed`() {
        assertFalse(state(OnboardingStep.AGE) { copy(birthDate = LocalDate.now().minusYears(17)) }.canProceed)
    }

    @Test
    fun `age eighteen or over can proceed`() {
        assertTrue(state(OnboardingStep.AGE) { copy(birthDate = LocalDate.now().minusYears(18)) }.canProceed)
    }

    @Test
    fun `age is whole years, so a day short of eighteen is still refused`() {
        val almost = LocalDate.now().minusYears(18).plusDays(1)
        assertFalse(state(OnboardingStep.AGE) { copy(birthDate = almost) }.canProceed)
    }

    @Test
    fun `a blank nickname cannot proceed`() {
        assertFalse(state(OnboardingStep.NICKNAME) { copy(nickname = "   ") }.canProceed)
    }

    @Test
    fun `an ordinary nickname can proceed`() {
        assertTrue(state(OnboardingStep.NICKNAME) { copy(nickname = "Ada") }.canProceed)
    }

    @Test
    fun `an objectionable nickname cannot proceed`() {
        assertFalse(state(OnboardingStep.NICKNAME) { copy(nickname = "moron") }.canProceed)
    }

    @Test
    fun `photos step requires an uploaded url, not a picked file`() {
        assertFalse(state(OnboardingStep.PHOTOS).canProceed)
        assertTrue(state(OnboardingStep.PHOTOS) { copy(photoUrls = listOf("a.jpg")) }.canProceed)
    }

    @Test
    fun `goals step requires at least one`() {
        assertFalse(state(OnboardingStep.GOALS).canProceed)
        assertTrue(state(OnboardingStep.GOALS) { copy(selectedGoals = setOf("g")) }.canProceed)
    }

    @Test
    fun `values step requires both brought and sought`() {
        assertFalse(state(OnboardingStep.VALUES) { copy(selectedValuesBrought = setOf("a")) }.canProceed)
        assertFalse(state(OnboardingStep.VALUES) { copy(selectedValuesSought = setOf("b")) }.canProceed)
        assertTrue(
            state(OnboardingStep.VALUES) {
                copy(selectedValuesBrought = setOf("a"), selectedValuesSought = setOf("b"))
            }.canProceed
        )
    }

    @Test
    fun `reflections require an answer to every loaded question`() {
        val qs = listOf(question("q1"), question("q2"))
        assertFalse(state(OnboardingStep.REFLECTIONS) { copy(allQuestions = qs) }.canProceed)
        assertFalse(
            state(OnboardingStep.REFLECTIONS) {
                copy(allQuestions = qs, reflectionAnswers = mapOf("q1" to "a"))
            }.canProceed
        )
        assertTrue(
            state(OnboardingStep.REFLECTIONS) {
                copy(allQuestions = qs, reflectionAnswers = mapOf("q1" to "a", "q2" to "b"))
            }.canProceed
        )
    }

    @Test
    fun `reflections with no questions loaded cannot proceed`() {
        // Guards against an empty question bank silently waving the user through.
        assertFalse(state(OnboardingStep.REFLECTIONS).canProceed)
    }

    @Test
    fun `location requires a resolved place, not just typed text`() {
        assertFalse(state(OnboardingStep.LOCATION) { copy(location = "Lond") }.canProceed)
        assertTrue(state(OnboardingStep.LOCATION) { copy(resolvedLocation = "London") }.canProceed)
    }

    @Test
    fun `terms must be accepted`() {
        assertFalse(state(OnboardingStep.TERMS).canProceed)
        assertTrue(state(OnboardingStep.TERMS) { copy(termsAccepted = true) }.canProceed)
    }

    @Test
    fun `gender, interestedIn and relationshipStatus each require a value`() {
        assertFalse(state(OnboardingStep.GENDER_IDENTITY).canProceed)
        assertTrue(state(OnboardingStep.GENDER_IDENTITY) { copy(gender = "female") }.canProceed)
        assertFalse(state(OnboardingStep.INTERESTED_IN).canProceed)
        assertTrue(state(OnboardingStep.INTERESTED_IN) { copy(interestedIn = setOf("men")) }.canProceed)
        assertFalse(state(OnboardingStep.RELATIONSHIP_STATUS).canProceed)
        assertTrue(state(OnboardingStep.RELATIONSHIP_STATUS) { copy(relationshipStatus = "single") }.canProceed)
    }

    @Test
    fun `the complete step always proceeds`() {
        assertTrue(state(OnboardingStep.COMPLETE).canProceed)
    }

    @Test
    fun `step order matches the iOS enum`() {
        assertEquals(
            listOf(
                "AGE", "NICKNAME", "PHOTOS", "GOALS", "VALUES", "REFLECTIONS",
                "GENDER_IDENTITY", "INTERESTED_IN", "RELATIONSHIP_STATUS",
                "LOCATION", "TERMS", "COMPLETE"
            ),
            OnboardingStep.entries.map { it.name }
        )
    }

    @Test
    fun `progress advances with the step index`() {
        val total = (OnboardingStep.entries.size - 1).toFloat()
        assertEquals(0f, state(OnboardingStep.AGE).progress, 0.0001f)
        assertEquals(1f / total, state(OnboardingStep.NICKNAME).progress, 0.0001f)
        assertEquals(1f, state(OnboardingStep.COMPLETE).progress, 0.0001f)
    }

    @Test
    fun `reflections progress interpolates across the question sub-steps`() {
        val qs = listOf(question("q1"), question("q2"), question("q3"), question("q4"))
        val total = (OnboardingStep.entries.size - 1).toFloat()
        val s = state(OnboardingStep.REFLECTIONS) {
            copy(allQuestions = qs, currentReflectionIndex = 2)
        }
        assertEquals((OnboardingStep.REFLECTIONS.ordinal + 0.5f) / total, s.progress, 0.0001f)
    }

    @Test
    fun `reflections progress does not divide by zero before questions load`() {
        val total = (OnboardingStep.entries.size - 1).toFloat()
        val s = state(OnboardingStep.REFLECTIONS)
        assertEquals(OnboardingStep.REFLECTIONS.ordinal / total, s.progress, 0.0001f)
    }
}
