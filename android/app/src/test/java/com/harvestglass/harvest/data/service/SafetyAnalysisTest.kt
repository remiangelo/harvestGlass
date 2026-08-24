package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.RedFlagCategory
import com.harvestglass.harvest.data.model.SafetyAnalysis
import com.harvestglass.harvest.data.model.SafetyLevel
import java.time.Instant
import java.time.temporal.ChronoUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A red flag costs the other person 25-30 safety points and can gate contact
 * sharing, so a false positive is expensive. These lock both the detection bar
 * and the arithmetic on top of it.
 */
class SafetyAnalysisTest {

    private fun analysis(
        score: Int = 100,
        totalMessages: Int = 0,
        firstMessageAt: String? = null
    ) = SafetyAnalysis(
        id = "a1",
        conversationId = "c1",
        userId = "u1",
        matchId = "m1",
        safetyScore = score
    ).also {
        it.totalMessages = totalMessages
        it.firstMessageAt = firstMessageAt
    }

    @Test
    fun `an ordinary message trips nothing`() {
        assertTrue(
            SafetyAnalysisService.detectFlags("Hey! Want to grab coffee this weekend?").isEmpty()
        )
    }

    @Test
    fun `a financial ask is flagged critical`() {
        val flags = SafetyAnalysisService.detectFlags("could you send money for my flight?")

        assertEquals(1, flags.size)
        assertEquals(RedFlagCategory.FINANCIAL, flags[0].category)
        assertEquals(30, flags[0].severity.weight)
    }

    // Bare verbs used to fire on ordinary sentences, which is why the harassment
    // lexicon spells out its objects.
    @Test
    fun `a harassment term needs its object`() {
        assertTrue(SafetyAnalysisService.detectFlags("i will kill you").isNotEmpty())
        assertTrue(SafetyAnalysisService.detectFlags("i need to kill some time").isEmpty())
    }

    @Test
    fun `two phrases in one category are one flag`() {
        val flags = SafetyAnalysisService.detectFlags(
            "send money by wire transfer, or a gift card works"
        )

        assertEquals(1, flags.size)
    }

    @Test
    fun `different categories each flag separately`() {
        val flags = SafetyAnalysisService.detectFlags("send money and send nudes")

        assertEquals(2, flags.size)
        assertTrue(flags.map { it.category }.containsAll(
            listOf(RedFlagCategory.FINANCIAL, RedFlagCategory.INAPPROPRIATE)
        ))
    }

    @Test
    fun `a clean conversation scores one hundred`() {
        assertEquals(100, SafetyAnalysisService.computeSafetyScore(emptyList()))
    }

    @Test
    fun `flags subtract their severity weight`() {
        val flags = SafetyAnalysisService.detectFlags("send money and send nudes")

        // financial 30 + inappropriate 20
        assertEquals(50, SafetyAnalysisService.computeSafetyScore(flags))
    }

    // The penalty is capped at 90, so keywords alone can never zero a score.
    @Test
    fun `the penalty is capped at ninety`() {
        val many = (1..10).flatMap { SafetyAnalysisService.detectFlags("send money") }

        assertEquals(10, SafetyAnalysisService.computeSafetyScore(many))
    }

    @Test
    fun `safety levels bracket the score`() {
        assertEquals(SafetyLevel.BLOCK, analysis(score = 19).safetyLevel)
        assertEquals(SafetyLevel.WARNING, analysis(score = 49).safetyLevel)
        assertEquals(SafetyLevel.CAUTION, analysis(score = 69).safetyLevel)
        assertEquals(SafetyLevel.SAFE, analysis(score = 79).safetyLevel)
        assertEquals(SafetyLevel.VERIFIED, analysis(score = 80).safetyLevel)
    }

    // All three conditions have to hold; each one alone is not enough.
    @Test
    fun `contact sharing needs the score, the messages and the day`() {
        val yesterday = Instant.now().minus(25, ChronoUnit.HOURS).toString()

        assertTrue(
            SafetyAnalysisService.canShareContact(analysis(70, 20, yesterday))
        )
        assertFalse(
            SafetyAnalysisService.canShareContact(analysis(69, 20, yesterday))
        )
        assertFalse(
            SafetyAnalysisService.canShareContact(analysis(70, 19, yesterday))
        )
        assertFalse(
            SafetyAnalysisService.canShareContact(
                analysis(70, 20, Instant.now().minus(1, ChronoUnit.HOURS).toString())
            )
        )
    }

    @Test
    fun `a conversation with no timestamp has no 24 hour history`() {
        assertFalse(analysis(100, 50, null).has24HourHistory)
    }

    @Test
    fun `a clean, mature conversation gets the reassuring recommendation`() {
        val recs = SafetyAnalysisService.recommendations(score = 90, totalMessages = 40)

        assertEquals(1, recs.size)
        assertTrue(recs[0].startsWith("This conversation currently looks safe"))
    }

    @Test
    fun `a low score stacks all three warnings`() {
        val recs = SafetyAnalysisService.recommendations(score = 40, totalMessages = 5)

        assertEquals(3, recs.size)
    }
}
