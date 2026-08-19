package com.harvestglass.harvest.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Gates what a user may name themselves, so the rules must match
 * KeywordMatcher.swift + MindfulMessagingService.containsObjectionableContent.
 */
class ObjectionableContentTest {

    @Test
    fun `an ordinary nickname is allowed`() {
        assertFalse(ObjectionableContent.contains("Ada"))
        assertFalse(ObjectionableContent.contains("gardener_42"))
        assertFalse(ObjectionableContent.contains("Sunflower"))
    }

    @Test
    fun `blank input is allowed`() {
        assertFalse(ObjectionableContent.contains(""))
        assertFalse(ObjectionableContent.contains("   "))
    }

    @Test
    fun `a flagged standalone term is caught`() {
        assertTrue(ObjectionableContent.contains("moron"))
        assertTrue(ObjectionableContent.contains("wtf"))
    }

    @Test
    fun `a multi-word term is caught`() {
        assertTrue(ObjectionableContent.contains("shut up"))
        assertTrue(ObjectionableContent.contains("send nudes"))
    }

    @Test
    fun `matching is boundary-aware, not substring`() {
        // The whole point of KeywordMatcher: "hello" must not hit "hell".
        assertFalse(ObjectionableContent.contains("moronic"))
        assertFalse(ObjectionableContent.contains("Shitake"))
    }

    @Test
    fun `single-word terms still match simple inflections`() {
        // KeywordMatcher appends (?:s|es|ed|ing)? for single-word keywords.
        assertTrue(ObjectionableContent.contains("morons"))
    }

    @Test
    fun `matching ignores case`() {
        assertTrue(ObjectionableContent.contains("MORON"))
    }

    @Test
    fun `apostrophes are dropped before matching`() {
        // normalize() strips apostrophes so "can't" and "cant" are one keyword.
        assertEquals("cant stand you", ObjectionableContent.normalize("can't stand you"))
        assertTrue(ObjectionableContent.contains("can't stand you"))
    }

    @Test
    fun `punctuation collapses to single spaces`() {
        assertEquals("hello there", ObjectionableContent.normalize("hello... there!!"))
    }
}
