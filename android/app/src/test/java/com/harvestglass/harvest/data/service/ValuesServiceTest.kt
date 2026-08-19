package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.QuestionWeighting
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The built-in catalogues are what keep onboarding completable when the DB is
 * empty or unreachable, so their shape is worth pinning down.
 */
class ValuesServiceTest {

    @Test
    fun `the default catalogue covers every category in order`() {
        val categories = ValuesService.DEFAULT_VALUES.map { it.category }.distinct()
        assertEquals(
            listOf(
                "communication", "relationship", "lifestyle",
                "personal growth", "social", "core beliefs"
            ),
            categories
        )
    }

    @Test
    fun `default ids are category-indexed and unique`() {
        val ids = ValuesService.DEFAULT_VALUES.map { it.id }
        assertEquals(ids.size, ids.distinct().size)
        assertTrue(ValuesService.DEFAULT_VALUES.first().id.startsWith("communication-"))
    }

    @Test
    fun `display order restarts within each category`() {
        ValuesService.DEFAULT_VALUES.groupBy { it.category }.forEach { (_, values) ->
            assertEquals(values.indices.toList(), values.map { it.displayOrder })
        }
    }

    @Test
    fun `the fallback question bank covers the ten onboarding questions`() {
        val bank = QuestionsService.DEFAULT_QUESTIONS
        assertEquals(10, bank.size)
        assertEquals((1..10).toList(), bank.map { it.displayOrder })
        assertEquals("q1", bank.first().id)
    }

    @Test
    fun `onboarding questions split five need and five bring`() {
        val bank = QuestionsService.DEFAULT_QUESTIONS
        assertEquals(5, bank.count { it.weighting == QuestionWeighting.NEED })
        assertEquals(5, bank.count { it.weighting == QuestionWeighting.BRING })
    }

    @Test
    fun `every fallback question offers four distinctly-identified options`() {
        QuestionsService.DEFAULT_QUESTIONS.forEach { q ->
            assertEquals("${q.id} option count", 4, q.options.size)
            assertEquals(q.options.map { it.id }.distinct().size, q.options.size)
            assertTrue(q.options.all { it.questionId == q.id })
            assertEquals(listOf(0, 1, 2, 3), q.options.map { it.displayOrder })
        }
    }

    @Test
    fun `option ids are question-scoped`() {
        assertEquals("q1_a", QuestionsService.DEFAULT_QUESTIONS.first().options.first().id)
    }
}
