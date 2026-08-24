package com.harvestglass.harvest.ui.chat

import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.data.service.ChatService
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.MindfulMessagingService
import com.harvestglass.harvest.data.service.ProfileService
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
import org.junit.Before
import org.junit.Test

/**
 * Same hazards as the community-room transcript: double-tap send, realtime
 * echo duplication, and a failed send losing the user's text.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {
    private val chatService: ChatService = mockk(relaxed = true)
    private val profileService: ProfileService = mockk(relaxed = true)
    private val matchService: MatchService = mockk(relaxed = true)
    private val mindful: MindfulMessagingService = mockk(relaxed = true) {
        every { isEnabled } returns false
    }

    private lateinit var vm: ChatViewModel

    private fun msg(id: String, at: String, sender: String = "u1") = Message(
        id = id, conversationId = "c1", senderId = sender, content = "hi", createdAt = at
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        every { chatService.subscribeToMessages(any()) } returns emptyFlow()
        coEvery { profileService.getProfile(any()) } returns null
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `start loads the transcript`() = runTest {
        coEvery { chatService.getMessages("c1") } returns listOf(
            msg("m1", "2026-08-20T10:00:00.000001+00:00"),
            msg("m2", "2026-08-20T10:01:00.000001+00:00")
        )
        vm = ChatViewModel(chatService, profileService, matchService, mindful)

        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        assertEquals(listOf("m1", "m2"), vm.state.value.messages.map { it.id })
    }

    @Test
    fun `send is a no-op while a send is already in flight`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        coEvery { chatService.sendMessage(any(), any(), any()) } coAnswers {
            delay(1_000); msg("m9", "2026-08-20T10:02:00.000001+00:00")
        }
        vm = ChatViewModel(chatService, profileService, matchService, mindful)
        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        vm.send("hello")
        vm.send("hello")
        advanceUntilIdle()

        coVerify(exactly = 1) { chatService.sendMessage("c1", "u1", "hello") }
    }

    @Test
    fun `blank content is not sent`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        vm = ChatViewModel(chatService, profileService, matchService, mindful)
        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        vm.send("   "); advanceUntilIdle()

        coVerify(exactly = 0) { chatService.sendMessage(any(), any(), any()) }
    }

    @Test
    fun `a realtime echo does not duplicate the sent message`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        val posted = msg("m9", "2026-08-20T10:02:00.000001+00:00")
        coEvery { chatService.sendMessage(any(), any(), any()) } returns posted
        every { chatService.subscribeToMessages("c1") } returns flowOf(posted)
        vm = ChatViewModel(chatService, profileService, matchService, mindful)
        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        vm.send("hi"); advanceUntilIdle()

        assertEquals(1, vm.state.value.messages.count { it.id == "m9" })
    }

    @Test
    fun `a message from the partner arrives over realtime`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        val incoming = msg("m5", "2026-08-20T10:03:00.000001+00:00", sender = "u2")
        every { chatService.subscribeToMessages("c1") } returns flowOf(incoming)
        vm = ChatViewModel(chatService, profileService, matchService, mindful)

        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        assertEquals(listOf("m5"), vm.state.value.messages.map { it.id })
    }

    @Test
    fun `a failed send hands the text back rather than losing it`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        coEvery { chatService.sendMessage(any(), any(), any()) } throws RuntimeException("offline")
        vm = ChatViewModel(chatService, profileService, matchService, mindful)
        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        vm.send("a thought"); advanceUntilIdle()

        assertEquals("a thought", vm.state.value.draft)
        assertEquals("offline", vm.state.value.error)
    }

    @Test
    fun `blocking delegates to the match service`() = runTest {
        coEvery { chatService.getMessages(any()) } returns emptyList()
        vm = ChatViewModel(chatService, profileService, matchService, mindful)
        vm.start("c1", "u1", "u2"); advanceUntilIdle()

        vm.block("u2"); advanceUntilIdle()

        coVerify(exactly = 1) { matchService.blockUser("u1", "u2") }
    }

    @Test
    fun `the blur hint maps each category to its iOS copy`() {
        assertEquals("May contain hostile language", hintFor("aggressive"))
        assertEquals("May contain explicit content", hintFor("sexual_pressure"))
        assertEquals("May contain personal info", hintFor("phone_number"))
        assertEquals("Possibly sensitive content", hintFor(null))
        assertEquals("Possibly sensitive content", hintFor("something_new"))
    }
}
