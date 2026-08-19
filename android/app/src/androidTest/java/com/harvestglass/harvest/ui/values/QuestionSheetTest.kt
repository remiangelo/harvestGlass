package com.harvestglass.harvest.ui.values

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.QuestionOption
import com.harvestglass.harvest.data.model.QuestionWeighting
import com.harvestglass.harvest.data.model.ValueAxis
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class QuestionSheetTest {
    @get:Rule val rule = createComposeRule()

    private fun sampleQuestion() = Question(
        id = "q1",
        prompt = "After a hard day, what would help you feel most cared for?",
        weighting = QuestionWeighting.NEED,
        displayOrder = 1,
        options = listOf(
            QuestionOption("q1_a", "q1", "They really listen before responding.", ValueAxis.EMOTIONAL_INTELLIGENCE, 0),
            QuestionOption("q1_b", "q1", "They stay calm and steady with me.", ValueAxis.STABILITY, 1)
        )
    )

    @Test
    fun answeringEmitsTheQuestionAndOptionIds() {
        var got: Pair<String, String>? = null
        rule.setContent {
            HarvestAppTheme {
                QuestionSheet(
                    unanswered = listOf(sampleQuestion()),
                    onAnswer = { q, o -> got = q to o },
                    onDismiss = {}
                )
            }
        }
        rule.onNodeWithText("They really listen before responding.").performClick()
        assertEquals("q1" to "q1_a", got)
    }

    @Test
    fun thePromptAndEveryOptionAreShown() {
        rule.setContent {
            HarvestAppTheme {
                QuestionSheet(listOf(sampleQuestion()), { _, _ -> }, {})
            }
        }
        rule.onNodeWithText("After a hard day, what would help you feel most cared for?")
            .assertIsDisplayed()
        rule.onNodeWithText("They stay calm and steady with me.").assertIsDisplayed()
    }

    @Test
    fun anEmptyQueueShowsTheAllAnsweredState() {
        rule.setContent { HarvestAppTheme { QuestionSheet(emptyList(), { _, _ -> }, {}) } }
        rule.onNodeWithText("You've answered everything for now.").assertIsDisplayed()
    }

    @Test
    fun doneDismissesFromTheEmptyState() {
        var dismissed = false
        rule.setContent {
            HarvestAppTheme { QuestionSheet(emptyList(), { _, _ -> }, { dismissed = true }) }
        }
        // "Done" appears in the bar and in the empty state; the bar one is first.
        rule.onAllNodesWithText("Done").onFirst().performClick()
        assertTrue(dismissed)
    }

    @Test
    fun onlyTheFirstUnansweredQuestionIsShown() {
        val second = sampleQuestion().copy(id = "q2", prompt = "Second prompt")
        rule.setContent {
            HarvestAppTheme {
                QuestionSheet(listOf(sampleQuestion(), second), { _, _ -> }, {})
            }
        }
        rule.onNodeWithText("Second prompt").assertDoesNotExist()
    }
}
