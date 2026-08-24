package com.harvestglass.harvest.ui.seeds

import com.harvestglass.harvest.data.model.Seed
import com.harvestglass.harvest.data.model.SeedStatus
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.SeedError
import com.harvestglass.harvest.data.service.SeedService
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SeedsViewModelTest {
    private val seedService: SeedService = mockk(relaxed = true)
    private val matchService: MatchService = mockk(relaxed = true)

    private fun vm() = SeedsViewModel(seedService, matchService)

    private val seed = Seed(
        id = "s1", senderId = "u2", recipientId = "u1",
        openingMessage = "hello", status = SeedStatus.PENDING
    )

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun stubLoad() {
        coEvery { seedService.receivedPending("u1") } returns listOf(seed)
        coEvery { seedService.sentPending("u1") } returns emptyList()
        coEvery { matchService.getConversations("u1") } returns emptyList()
    }

    @Test
    fun `accepting a seed removes it and routes into the conversation`() = runTest {
        stubLoad()
        coEvery { seedService.acceptSeed("s1") } returns "c9"
        val vm = vm(); vm.load("u1"); advanceUntilIdle()

        vm.accept(seed, "u1"); advanceUntilIdle()

        assertTrue(vm.state.value.received.isEmpty())
        assertEquals("c9", vm.state.value.openedConversationId)
        // The partner is the SENDER of the accepted seed, not the recipient.
        assertEquals("u2", vm.state.value.openedPartnerUserId)
    }

    @Test
    fun `declining removes the seed without opening anything`() = runTest {
        stubLoad()
        val vm = vm(); vm.load("u1"); advanceUntilIdle()

        vm.decline(seed, "u1"); advanceUntilIdle()

        assertTrue(vm.state.value.received.isEmpty())
        assertNull(vm.state.value.openedConversationId)
        coVerify(exactly = 1) { seedService.declineSeed("s1") }
    }

    @Test
    fun `a failed accept leaves the seed in place`() = runTest {
        stubLoad()
        coEvery { seedService.acceptSeed("s1") } throws RuntimeException("nope")
        val vm = vm(); vm.load("u1"); advanceUntilIdle()

        vm.accept(seed, "u1"); advanceUntilIdle()

        assertEquals(listOf("s1"), vm.state.value.received.map { it.id })
        assertNull(vm.state.value.openedConversationId)
        assertEquals("nope", vm.state.value.error)
    }

    @Test
    fun `the daily-limit error surfaces its copy`() = runTest {
        stubLoad()
        coEvery { seedService.acceptSeed(any()) } throws SeedError.DailyLimitReached()
        val vm = vm(); vm.load("u1"); advanceUntilIdle()

        vm.accept(seed, "u1"); advanceUntilIdle()

        assertEquals(
            "You've reached today's Seed limit. Upgrade or try again tomorrow.",
            vm.state.value.error
        )
    }

    @Test
    fun `a failing conversation list does not fail the whole tab`() = runTest {
        coEvery { seedService.receivedPending("u1") } returns listOf(seed)
        coEvery { seedService.sentPending("u1") } returns emptyList()
        coEvery { matchService.getConversations("u1") } throws RuntimeException("offline")
        val vm = vm()

        vm.load("u1"); advanceUntilIdle()

        assertEquals(listOf("s1"), vm.state.value.received.map { it.id })
        assertTrue(vm.state.value.conversations.isEmpty())
        assertNull(vm.state.value.error)
    }

    @Test
    fun `visible requests follow the selected kind`() {
        val sent = seed.copy(id = "s2", senderId = "u1", recipientId = "u3")
        val state = SeedsUiState(received = listOf(seed), sent = listOf(sent))
        assertEquals(listOf("s1"), state.visibleRequests.map { it.id })
        assertEquals(
            listOf("s2"),
            state.copy(requestKind = RequestKind.SENT).visibleRequests.map { it.id }
        )
    }

    @Test
    fun `clearing the opened conversation resets both fields`() = runTest {
        stubLoad()
        coEvery { seedService.acceptSeed("s1") } returns "c9"
        val vm = vm(); vm.load("u1"); advanceUntilIdle()
        vm.accept(seed, "u1"); advanceUntilIdle()

        vm.clearOpenedConversation()

        assertNull(vm.state.value.openedConversationId)
        assertNull(vm.state.value.openedPartnerUserId)
    }
}
