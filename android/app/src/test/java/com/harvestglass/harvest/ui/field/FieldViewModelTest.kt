package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.data.service.CommunityService
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FieldViewModelTest {
    private val service: CommunityService = mockk()
    private lateinit var vm: FieldViewModel

    private val room = Community(id = "c1", slug = "s", name = "Room", kind = "status")

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `load populates available rooms and joined ids`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns setOf("c1")
        vm = FieldViewModel(service)

        vm.load("u1")
        advanceUntilIdle()

        assertEquals(listOf(room), vm.state.value.available)
        assertTrue(vm.state.value.isJoined(room))
        assertFalse(vm.state.value.isLoading)
    }

    @Test
    fun `toggleJoin on a joined room leaves and drops the id`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns setOf("c1")
        coEvery { service.leave("c1", "u1") } returns Unit
        vm = FieldViewModel(service)
        vm.load("u1"); advanceUntilIdle()

        vm.toggleJoin(room, "u1"); advanceUntilIdle()

        coVerify(exactly = 1) { service.leave("c1", "u1") }
        assertFalse(vm.state.value.isJoined(room))
    }

    @Test
    fun `toggleJoin on an unjoined room joins and adds the id`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns emptySet()
        coEvery { service.join("c1", "u1") } returns Unit
        vm = FieldViewModel(service)
        vm.load("u1"); advanceUntilIdle()

        vm.toggleJoin(room, "u1"); advanceUntilIdle()

        coVerify(exactly = 1) { service.join("c1", "u1") }
        assertTrue(vm.state.value.isJoined(room))
    }

    @Test
    fun `load surfaces the error message and clears loading`() = runTest {
        coEvery { service.availableCommunities("u1") } throws RuntimeException("boom")
        coEvery { service.joinedCommunityIds("u1") } returns emptySet()
        vm = FieldViewModel(service)

        vm.load("u1"); advanceUntilIdle()

        assertEquals("boom", vm.state.value.error)
        // iOS uses `defer { isLoading = false }` — it clears on failure too.
        assertFalse(vm.state.value.isLoading)
    }
}
