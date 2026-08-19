package com.harvestglass.harvest.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * AxisScoring and ValuesTier are pure maths the matching algorithm depends on.
 * Expected values are read off Harvest/Models/Question.swift.
 */
class QuestionTest {

    private fun option(id: String, axis: ValueAxis) =
        QuestionOption(id = id, questionId = "q1", label = "L", axis = axis, displayOrder = 0)

    private fun question(id: String, weighting: QuestionWeighting, axis: ValueAxis) =
        Question(
            id = id, prompt = "P", weighting = weighting, displayOrder = 0,
            options = listOf(option("$id-a", axis))
        )

    @Test
    fun `need questions score the need side only`() {
        assertEquals(2.0 to 0.0, AxisScoring.weights(QuestionWeighting.NEED))
    }

    @Test
    fun `bring questions score the bring side only`() {
        assertEquals(0.0 to 2.0, AxisScoring.weights(QuestionWeighting.BRING))
    }

    @Test
    fun `both questions split evenly`() {
        assertEquals(1.0 to 1.0, AxisScoring.weights(QuestionWeighting.BOTH))
    }

    @Test
    fun `raw vectors accumulate per axis`() {
        val qs = listOf(
            question("q1", QuestionWeighting.NEED, ValueAxis.STABILITY),
            question("q2", QuestionWeighting.BOTH, ValueAxis.STABILITY),
            question("q3", QuestionWeighting.BRING, ValueAxis.GROWTH)
        )
        val answers = mapOf("q1" to "q1-a", "q2" to "q2-a", "q3" to "q3-a")
        val (need, bring) = AxisScoring.computeRawVectors(answers, qs)

        assertEquals(3.0, need.stability, 0.0001)   // 2.0 + 1.0
        assertEquals(1.0, bring.stability, 0.0001)  // 0.0 + 1.0
        assertEquals(2.0, bring.growth, 0.0001)
        assertEquals(0.0, need.growth, 0.0001)
    }

    @Test
    fun `an answer to an unknown question is ignored`() {
        val qs = listOf(question("q1", QuestionWeighting.NEED, ValueAxis.INTEGRITY))
        val (need, _) = AxisScoring.computeRawVectors(mapOf("nope" to "x"), qs)
        assertTrue(need.isZero)
    }

    @Test
    fun `an unknown option id is ignored`() {
        val qs = listOf(question("q1", QuestionWeighting.NEED, ValueAxis.INTEGRITY))
        val (need, _) = AxisScoring.computeRawVectors(mapOf("q1" to "wrong"), qs)
        assertTrue(need.isZero)
    }

    @Test
    fun `normalized vectors sum to one`() {
        val s = AxisScores(stability = 3.0, growth = 1.0)
        assertEquals(1.0, s.normalized().sum, 0.0001)
    }

    @Test
    fun `normalizing a zero vector leaves it alone`() {
        assertTrue(AxisScores().normalized().isZero)
    }

    @Test
    fun `cosine of identical vectors is one`() {
        val a = AxisScores(stability = 2.0, growth = 1.0)
        assertEquals(1.0, AxisScores.cosine(a, a), 0.0001)
    }

    @Test
    fun `cosine with a zero vector is zero`() {
        assertEquals(0.0, AxisScores.cosine(AxisScores(stability = 1.0), AxisScores()), 0.0001)
    }

    @Test
    fun `tier boundaries match the radar mapping`() {
        assertEquals(ValuesTier.LOW_PRESENCE, ValuesTier.fromRawScore(0.0))
        assertEquals(ValuesTier.LOW_PRESENCE, ValuesTier.fromRawScore(5.9))
        assertEquals(ValuesTier.GROWING_PRESENCE, ValuesTier.fromRawScore(6.0))
        assertEquals(ValuesTier.GROWING_PRESENCE, ValuesTier.fromRawScore(10.9))
        assertEquals(ValuesTier.STRONG_PRESENCE, ValuesTier.fromRawScore(11.0))
        assertEquals(ValuesTier.STRONG_PRESENCE, ValuesTier.fromRawScore(17.9))
        assertEquals(ValuesTier.CORE_VALUE, ValuesTier.fromRawScore(18.0))
        assertEquals(ValuesTier.CORE_VALUE, ValuesTier.fromRawScore(28.0))
    }

    @Test
    fun `axis serial names match the database`() {
        assertEquals("emotional_intelligence", ValueAxis.EMOTIONAL_INTELLIGENCE.serialName)
        assertEquals("stability", ValueAxis.STABILITY.serialName)
    }
}
