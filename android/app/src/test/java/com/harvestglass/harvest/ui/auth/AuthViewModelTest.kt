package com.harvestglass.harvest.ui.auth

import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.ProfileService
import com.harvestglass.harvest.data.service.SubscriptionService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * needsOnboarding gates the whole root navigation, so it is locked to the
 * iOS predicate from AuthViewModel.swift:
 *   onboardingCompleted != true && (age == nil || gender == nil || photos.isEmpty)
 */
class NeedsOnboardingTest {

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

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {
    private val authService: AuthService = mockk(relaxed = true)
    private val profileService: ProfileService = mockk(relaxed = true)
    private val subscriptionService: SubscriptionService = mockk(relaxed = true)

    private fun vm() = AuthViewModel(authService, profileService, subscriptionService)

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        coEvery { authService.signUp(any(), any()) } returns "u1"
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `signing up creates the profile row and the free subscription`() = runTest {
        val vm = vm()

        vm.register("a@b.co", "pw"); advanceUntilIdle()

        coVerify { profileService.createProfile("u1", "a@b.co") }
        coVerify { subscriptionService.initializeUserSubscription("u1") }
        assertTrue(vm.state.value.isAuthenticated)
        assertNull(vm.state.value.error)
    }

    // Everything downstream reads the profile row, so signup can't quietly
    // succeed without one.
    @Test
    fun `a failed profile row fails the signup`() = runTest {
        coEvery { profileService.createProfile(any(), any()) } throws
            IllegalStateException("duplicate key")
        val vm = vm()

        vm.register("a@b.co", "pw"); advanceUntilIdle()

        assertFalse(vm.state.value.isAuthenticated)
        assertEquals("duplicate key", vm.state.value.error)
    }

    // A missing tier row reads as free, which is what a new account gets — not
    // worth failing a signup over.
    @Test
    fun `a failed subscription row does not fail the signup`() = runTest {
        coEvery { subscriptionService.initializeUserSubscription(any()) } throws
            IllegalStateException("network")
        val vm = vm()

        vm.register("a@b.co", "pw"); advanceUntilIdle()

        assertTrue(vm.state.value.isAuthenticated)
        assertNull(vm.state.value.error)
    }

    @Test
    fun `a rejected signup writes no profile row`() = runTest {
        coEvery { authService.signUp(any(), any()) } throws
            IllegalStateException("User already registered")
        val vm = vm()

        vm.register("a@b.co", "pw"); advanceUntilIdle()

        coVerify(exactly = 0) { profileService.createProfile(any(), any()) }
        assertFalse(vm.state.value.isAuthenticated)
        assertEquals("User already registered", vm.state.value.error)
    }

    // supabase-kt's signUpWith returns null whenever sign-up establishes the
    // session directly, which is every sign-up on this project. AuthService now
    // falls back to that session, but if an id still can't be resolved the
    // screen has to say so: silently leaving isAuthenticated false looked like
    // a dead button, and the account was left with no profile row to onboard
    // into.
    @Test
    fun `a signup that yields no user id reports an error instead of doing nothing`() = runTest {
        coEvery { authService.signUp(any(), any()) } returns null
        val vm = vm()

        vm.register("a@b.co", "pw"); advanceUntilIdle()

        coVerify(exactly = 0) { profileService.createProfile(any(), any()) }
        assertFalse(vm.state.value.isAuthenticated)
        assertNotNull(vm.state.value.error)
    }
}
