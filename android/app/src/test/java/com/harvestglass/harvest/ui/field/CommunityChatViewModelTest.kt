package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.model.CommunityReaction
import com.harvestglass.harvest.data.service.CommunityService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CommunityChatViewModelTest {
    private val service: CommunityService = mockk(relaxed = true)
    private lateinit var vm: CommunityChatViewModel

    private fun msg(id: String, at: String, sender: String = "u1") = CommunityMessage(
        id = id, communityId = "c1", senderId = sender, content = "hi", createdAt = at
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        every { service.subscribeMessages(any()) } returns emptyFlow()
        every { service.subscribeReactions(any()) } returns emptyFlow()
        coEvery { service.senderProfiles(any()) } returns emptyList()
        coEvery { service.reactions(any()) } returns emptyList()
        coEvery { service.members(any()) } returns emptyList()
        coEvery { service.prompts(any()) } returns emptyList()
        coEvery { service.messagesByIds(any()) } returns emptyList()
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `start loads the newest page and renders it oldest-first`() = runTest {
        // The service returns newest-first; the transcript renders oldest-first.
        coEvery { service.messagesPage("c1", null, any()) } returns listOf(
            msg("m2", "2026-08-16T10:01:00.000001+00:00"),
            msg("m1", "2026-08-16T10:00:00.000001+00:00")
        )
        vm = CommunityChatViewModel(service)

        vm.start("c1", "u1"); advanceUntilIdle()

        assertEquals(listOf("m1", "m2"), vm.state.value.messages.map { it.id })
    }

    @Test
    fun `send is a no-op while a send is already in flight`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.post(any(), any(), any(), any(), any()) } coAnswers {
            delay(1_000); msg("m9", "2026-08-16T10:02:00.000001+00:00")
        }
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        // Commit 72f4202: a double tap must not insert twice.
        vm.send("hello")
        vm.send("hello")
        advanceUntilIdle()

        coVerify(exactly = 1) { service.post("c1", "u1", "hello", null, emptyList()) }
    }

    @Test
    fun `blank content is not sent`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("   "); advanceUntilIdle()

        coVerify(exactly = 0) { service.post(any(), any(), any(), any(), any()) }
    }

    @Test
    fun `a realtime echo of an already-inserted message does not duplicate it`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        val posted = msg("m9", "2026-08-16T10:02:00.000001+00:00")
        coEvery { service.post(any(), any(), any(), any(), any()) } returns posted
        every { service.subscribeMessages("c1") } returns flowOf(posted)
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("hi"); advanceUntilIdle()

        assertEquals(1, vm.state.value.messages.count { it.id == "m9" })
    }

    @Test
    fun `a failed send hands the text back rather than losing it`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.post(any(), any(), any(), any(), any()) } throws RuntimeException("offline")
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("a thought"); advanceUntilIdle()

        assertEquals("a thought", vm.state.value.draft)
    }

    @Test
    fun `a blocked contact-info send surfaces the friendly nudge`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.post(any(), any(), any(), any(), any()) } throws
            RuntimeException("CONTACT_INFO_BLOCKED")
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("call me on 555"); advanceUntilIdle()

        assertEquals(
            "Keep contact sharing to private Seed conversations 🌱",
            vm.state.value.error
        )
    }

    @Test
    fun `toggleReaction adds mine then removes it`() = runTest {
        val m = msg("m1", "2026-08-16T10:00:00.000001+00:00")
        coEvery { service.messagesPage(any(), any(), any()) } returns listOf(m)
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.toggleReaction("m1", "🌱"); advanceUntilIdle()
        assertTrue(vm.state.value.reactions["m1"].orEmpty().any { it.userId == "u1" })
        coVerify(exactly = 1) { service.addReaction("m1", "u1", "🌱") }

        vm.toggleReaction("m1", "🌱"); advanceUntilIdle()
        assertTrue(vm.state.value.reactions["m1"].orEmpty().none { it.userId == "u1" })
        coVerify(exactly = 1) { service.removeReaction("m1", "u1", "🌱") }
    }

    @Test
    fun `a duplicate reaction from realtime is not applied twice`() = runTest {
        val m = msg("m1", "2026-08-16T10:00:00.000001+00:00")
        coEvery { service.messagesPage(any(), any(), any()) } returns listOf(m)
        val r = CommunityReaction(messageId = "m1", userId = "u2", emoji = "💚", communityId = "c1")
        every { service.subscribeReactions("c1") } returns flowOf(
            com.harvestglass.harvest.data.service.ReactionEvent.Added(r),
            com.harvestglass.harvest.data.service.ReactionEvent.Added(r)
        )
        vm = CommunityChatViewModel(service)

        vm.start("c1", "u1"); advanceUntilIdle()

        assertEquals(1, vm.state.value.reactions["m1"].orEmpty().count { it.userId == "u2" })
    }
}
