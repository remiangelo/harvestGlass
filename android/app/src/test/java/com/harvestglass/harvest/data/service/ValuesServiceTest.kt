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
    fun `the fallback bank covers the full pool in display order`() {
        val bank = QuestionsService.DEFAULT_QUESTIONS
        assertEquals(35, bank.size)
        assertEquals((1..35).toList(), bank.map { it.displayOrder })
        assertEquals("q1", bank.first().id)
    }

    @Test
    fun `the ten onboarding questions split five need and five bring`() {
        val onboarding = QuestionsService.DEFAULT_QUESTIONS.filter { it.displayOrder <= 10 }
        assertEquals(10, onboarding.size)
        assertEquals(5, onboarding.count { it.weighting == QuestionWeighting.NEED })
        assertEquals(5, onboarding.count { it.weighting == QuestionWeighting.BRING })
    }

    @Test
    fun `the deep dive is twelve need, twelve bring and one both`() {
        // Asserted by the Swift source's own comment: Q11-Q35 = 12 NEED, 12 BRING, 1 BOTH.
        val deepDive = QuestionsService.DEFAULT_QUESTIONS.filter { it.displayOrder > 10 }
        assertEquals(25, deepDive.size)
        assertEquals(12, deepDive.count { it.weighting == QuestionWeighting.NEED })
        assertEquals(12, deepDive.count { it.weighting == QuestionWeighting.BRING })
        assertEquals(1, deepDive.count { it.weighting == QuestionWeighting.BOTH })
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
