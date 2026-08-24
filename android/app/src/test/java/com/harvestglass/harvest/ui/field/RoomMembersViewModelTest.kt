package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.data.model.FieldFilterLevel
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.service.CommunityService
import com.harvestglass.harvest.data.service.SubscriptionService
import io.mockk.coEvery
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
class RoomMembersViewModelTest {
    private val service: CommunityService = mockk(relaxed = true)
    private val subscriptionService: SubscriptionService = mockk(relaxed = true)

    private fun vm() = RoomMembersViewModel(service, subscriptionService)

    private fun tier(name: TierName, level: String?) =
        SubscriptionTier(id = "t-${name.raw}", name = name, fieldFilterLevelRaw = level)

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        coEvery { subscriptionService.currentTier(any()) } returns tier(TierName.SEED, null)
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `the free tier unlocks no paid filters`() = runTest {
        val vm = vm()

        vm.load("c1", "u1"); advanceUntilIdle()

        assertEquals(FieldFilterLevel.NONE, vm.state.value.filterLevel)
        assertFalse(vm.state.value.canAccessAdvanced)
        assertFalse(vm.state.value.canAccessFull)
    }

    @Test
    fun `Gold unlocks the full filter set`() = runTest {
        coEvery { subscriptionService.currentTier("u1") } returns tier(TierName.GOLD, "full")
        val vm = vm()

        vm.load("c1", "u1"); advanceUntilIdle()

        assertTrue(vm.state.value.canAccessFull)
        assertTrue(vm.state.value.canAccessAdvanced)
    }

    // A tier lookup that fails must lock the paid filters, never open them.
    @Test
    fun `an unreadable tier fails closed`() = runTest {
        coEvery { subscriptionService.currentTier("u1") } returns null
        val vm = vm()

        vm.load("c1", "u1"); advanceUntilIdle()

        assertEquals(FieldFilterLevel.NONE, vm.state.value.filterLevel)
    }

    // The roster still loads for a paying user even when the tier read fails;
    // only the filters lock.
    @Test
    fun `a failed tier read does not block the member list`() = runTest {
        coEvery { subscriptionService.currentTier("u1") } returns null
        val vm = vm()

        vm.load("c1", "u1"); advanceUntilIdle()

        assertFalse(vm.state.value.isLoading)
        assertEquals(null, vm.state.value.error)
    }
}
