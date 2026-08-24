package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.util.KeywordMatcher

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
        assertFalse(MindfulMessagingService.containsObjectionableContent("Ada"))
        assertFalse(MindfulMessagingService.containsObjectionableContent("gardener_42"))
        assertFalse(MindfulMessagingService.containsObjectionableContent("Sunflower"))
    }

    @Test
    fun `blank input is allowed`() {
        assertFalse(MindfulMessagingService.containsObjectionableContent(""))
        assertFalse(MindfulMessagingService.containsObjectionableContent("   "))
    }

    @Test
    fun `a flagged standalone term is caught`() {
        assertTrue(MindfulMessagingService.containsObjectionableContent("moron"))
        assertTrue(MindfulMessagingService.containsObjectionableContent("wtf"))
    }

    @Test
    fun `a multi-word term is caught`() {
        assertTrue(MindfulMessagingService.containsObjectionableContent("shut up"))
        assertTrue(MindfulMessagingService.containsObjectionableContent("send nudes"))
    }

    @Test
    fun `matching is boundary-aware, not substring`() {
        // The whole point of KeywordMatcher: "hello" must not hit "hell".
        assertFalse(MindfulMessagingService.containsObjectionableContent("moronic"))
        assertFalse(MindfulMessagingService.containsObjectionableContent("Shitake"))
    }

    @Test
    fun `single-word terms still match simple inflections`() {
        // KeywordMatcher appends (?:s|es|ed|ing)? for single-word keywords.
        assertTrue(MindfulMessagingService.containsObjectionableContent("morons"))
    }

    @Test
    fun `matching ignores case`() {
        assertTrue(MindfulMessagingService.containsObjectionableContent("MORON"))
    }

    @Test
    fun `apostrophes are dropped before matching`() {
        // normalize() strips apostrophes so "can't" and "cant" are one keyword.
        assertEquals("cant stand you", KeywordMatcher.normalize("can't stand you"))
        assertTrue(MindfulMessagingService.containsObjectionableContent("can't stand you"))
    }

    @Test
    fun `punctuation collapses to single spaces`() {
        assertEquals("hello there", KeywordMatcher.normalize("hello... there!!"))
    }
}
