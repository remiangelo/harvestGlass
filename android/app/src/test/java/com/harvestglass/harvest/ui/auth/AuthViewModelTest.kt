package com.harvestglass.harvest.ui.auth

import com.harvestglass.harvest.data.model.UserProfile
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * needsOnboarding gates the whole root navigation, so it is locked to the
 * iOS predicate from AuthViewModel.swift:
 *   onboardingCompleted != true && (age == nil || gender == nil || photos.isEmpty)
 */
class AuthViewModelTest {

    @Test
    fun `no profile needs onboarding`() {
        assertTrue(AuthUiState(profile = null).needsOnboarding)
    }

    @Test
    fun `completed flag alone satisfies onboarding`() {
        val p = UserProfile(id = "u1", onboardingCompleted = true)
        assertFalse(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `full profile without the flag does not need onboarding`() {
        val p = UserProfile(id = "u1", age = 33, gender = "female", photos = listOf("a.png"))
        assertFalse(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `missing age needs onboarding`() {
        val p = UserProfile(id = "u1", gender = "female", photos = listOf("a.png"))
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `missing gender needs onboarding`() {
        val p = UserProfile(id = "u1", age = 33, photos = listOf("a.png"))
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `empty photos needs onboarding`() {
        val p = UserProfile(id = "u1", age = 33, gender = "female", photos = emptyList())
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `null photos needs onboarding`() {
        val p = UserProfile(id = "u1", age = 33, gender = "female", photos = null)
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }
}
