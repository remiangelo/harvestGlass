package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.util.KeywordMatcher
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The directed-lexicon rules are the whole reason this isn't a substring
 * scan: "I need to kill some time" and "I'll kill you" must not read the same,
 * and a gardening app must not flag "my new hoe".
 */
class MindfulKeywordTest {

    private fun directed(keyword: String, text: String): Boolean =
        KeywordMatcher.containsDirected(keyword, KeywordMatcher.clauses(text))

    @Test
    fun `a directed term aimed at someone matches`() {
        assertTrue(directed("kill", "I'll kill you"))
        assertTrue(directed("stupid", "you are being stupid"))
    }

    @Test
    fun `the same term with no target does not match`() {
        assertFalse(directed("kill", "I need to kill some time"))
        assertFalse(directed("hoe", "I bought a new hoe for the garden"))
    }

    // The clause split is what keeps "you know" from making the rest of the
    // sentence read as directed.
    @Test
    fun `a second-person word in another clause does not direct the term`() {
        assertFalse(directed("stupid", "you know, that plan was stupid"))
    }

    @Test
    fun `clause splitting happens before normalising`() {
        val clauses = KeywordMatcher.clauses("you know. that was stupid!")

        assertTrue(clauses.contains("you know"))
        assertTrue(clauses.contains("that was stupid"))
    }

    @Test
    fun `word boundaries stop the classic substring false positives`() {
        val normalized = KeywordMatcher.normalize("hello there, one of us had breakfast")

        assertFalse(KeywordMatcher.contains("hell", normalized))
        assertFalse(KeywordMatcher.contains("f u", normalized))
        assertFalse(KeywordMatcher.contains("break", normalized))
    }

    @Test
    fun `single-word keywords match simple inflections but not longer stems`() {
        assertTrue(KeywordMatcher.contains("stalk", KeywordMatcher.normalize("he stalked me")))
        assertTrue(KeywordMatcher.contains("stalk", KeywordMatcher.normalize("stop stalking me")))
        assertFalse(KeywordMatcher.contains("hell", KeywordMatcher.normalize("hello")))
    }

    @Test
    fun `apostrophe variants normalise to one keyword`() {
        val curly = KeywordMatcher.normalize("I can’t stand you")
        val plain = KeywordMatcher.normalize("I can't stand you")

        assertTrue(KeywordMatcher.contains("can't stand you", curly))
        assertTrue(KeywordMatcher.contains("cant stand you", plain))
    }

    // Profile fields have no one to direct an insult at, so only the
    // standalone terms apply — otherwise "trash" would block an innocent bio.
    @Test
    fun `the profile-field gate ignores directed-only terms`() {
        assertFalse(MindfulMessagingService.containsObjectionableContent("I love trash TV"))
        assertTrue(MindfulMessagingService.containsObjectionableContent("moron"))
    }

    @Test
    fun `an ordinary bio passes the profile-field gate`() {
        assertFalse(
            MindfulMessagingService.containsObjectionableContent(
                "Gardener, hiker, and a truly terrible cook."
            )
        )
    }
}
