package com.harvestglass.harvest.ui.subscription

import com.android.billingclient.api.Purchase
import com.harvestglass.harvest.billing.PlayBilling
import com.harvestglass.harvest.billing.PurchaseOutcome
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.model.UserSubscription
import com.harvestglass.harvest.data.service.SubscriptionService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
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
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SubscriptionViewModelTest {
    private val service: SubscriptionService = mockk(relaxed = true)
    private val billing: PlayBilling = mockk(relaxed = true)
    private val outcomes = MutableSharedFlow<PurchaseOutcome>(extraBufferCapacity = 4)

    private val seed = SubscriptionTier(
        id = "t-seed", name = TierName.SEED, displayName = "Seed", priceMonthly = 0.0
    )
    private val gold = SubscriptionTier(
        id = "t-gold", name = TierName.GOLD, displayName = "Gold", priceMonthly = 19.99
    )

    private fun vm() = SubscriptionViewModel(service, billing)

    private fun purchase(
        token: String = "tok",
        products: List<String> = listOf("com.harvestglass.harvest.gold.monthly")
    ): Purchase = mockk(relaxed = true) {
        every { purchaseToken } returns token
        every { this@mockk.products } returns products
        every { isAcknowledged } returns false
    }

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        every { billing.purchaseOutcomes } returns outcomes
        coEvery { service.getSubscriptionTiers() } returns listOf(seed, gold)
        coEvery { service.getUserSubscription(any()) } returns null
        coEvery { billing.activePurchases() } returns emptyList()
        coEvery { billing.products() } returns emptyList()
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `no subscription row falls back to the Seed tier`() = runTest {
        val vm = vm()

        vm.loadSubscriptionData("u1"); advanceUntilIdle()

        assertEquals(seed.id, vm.state.value.currentTier?.id)
        assertEquals("Seed", vm.state.value.currentTierName)
    }

    @Test
    fun `the subscription row selects its tier`() = runTest {
        coEvery { service.getUserSubscription("u1") } returns UserSubscription(
            id = "s1", userId = "u1", tierId = gold.id, status = "active"
        )
        val vm = vm()

        vm.loadSubscriptionData("u1"); advanceUntilIdle()

        assertEquals(gold.id, vm.state.value.currentTier?.id)
        assertEquals("Gold", vm.state.value.currentTierName)
    }

    // The Manage card is iOS's "paid plans only" affordance.
    @Test
    fun `the manage card is hidden on the free tier`() = runTest {
        val vm = vm()

        vm.loadSubscriptionData("u1"); advanceUntilIdle()

        assertFalse(vm.state.value.showsManageCard)
    }

    @Test
    fun `restoring with nothing to restore drops the user to Seed`() = runTest {
        val vm = vm()

        vm.restorePurchases("u1"); advanceUntilIdle()

        coVerify { service.syncToSeedTier("u1") }
        assertEquals("No previous purchases found to restore.", vm.state.value.error)
    }

    @Test
    fun `restoring verifies each live purchase and acknowledges it`() = runTest {
        val live = purchase()
        coEvery { billing.activePurchases() } returns listOf(live)
        val vm = vm()

        vm.restorePurchases("u1"); advanceUntilIdle()

        coVerify {
            service.verifyPlayPurchase("u1", "com.harvestglass.harvest.gold.monthly", "tok")
        }
        coVerify { billing.acknowledge(live) }
        coVerify(exactly = 0) { service.syncToSeedTier(any()) }
        assertNotNull(vm.state.value.successMessage)
    }

    // Acknowledging a purchase the server rejected would strand the user on a
    // tier they never got AND stop Google from refunding it.
    @Test
    fun `a purchase the server rejects is never acknowledged`() = runTest {
        val live = purchase()
        coEvery { billing.activePurchases() } returns listOf(live)
        coEvery { service.verifyPlayPurchase(any(), any(), any()) } throws
            IllegalStateException("Purchase verification failed (402)")
        val vm = vm()

        vm.restorePurchases("u1"); advanceUntilIdle()

        coVerify(exactly = 0) { billing.acknowledge(any()) }
        assertEquals("No previous purchases found to restore.", vm.state.value.error)
    }

    @Test
    fun `a completed purchase is verified, acknowledged and reported`() = runTest {
        val bought = purchase()
        val details: com.android.billingclient.api.ProductDetails = mockk(relaxed = true)
        every { billing.launchPurchase(any(), details) } returns null
        val vm = vm()
        advanceUntilIdle()

        vm.purchase(mockk(relaxed = true), details, "u1")
        outcomes.emit(PurchaseOutcome.Purchased(listOf(bought)))
        advanceUntilIdle()

        coVerify { service.verifyPlayPurchase("u1", any(), "tok") }
        coVerify { billing.acknowledge(bought) }
        assertEquals("Your subscription is now active.", vm.state.value.successMessage)
        assertFalse(vm.state.value.isPurchasing)
    }

    // Cancelling isn't an error on iOS and isn't one here.
    @Test
    fun `cancelling a purchase raises no error`() = runTest {
        val details: com.android.billingclient.api.ProductDetails = mockk(relaxed = true)
        every { billing.launchPurchase(any(), details) } returns null
        val vm = vm()
        advanceUntilIdle()

        vm.purchase(mockk(relaxed = true), details, "u1")
        outcomes.emit(PurchaseOutcome.Cancelled)
        advanceUntilIdle()

        assertNull(vm.state.value.error)
        assertFalse(vm.state.value.isPurchasing)
    }

    @Test
    fun `a sheet that never opens clears the purchasing flag`() = runTest {
        val details: com.android.billingclient.api.ProductDetails = mockk(relaxed = true)
        every { billing.launchPurchase(any(), details) } returns "Play is unavailable"
        val vm = vm()
        advanceUntilIdle()

        vm.purchase(mockk(relaxed = true), details, "u1")

        assertEquals("Play is unavailable", vm.state.value.error)
        assertFalse(vm.state.value.isPurchasing)
    }

    @Test
    fun `an empty product list is reported rather than shown as a blank sheet`() = runTest {
        val vm = vm()

        vm.loadProducts(); advanceUntilIdle()

        assertEquals(SubscriptionViewModel.PRODUCTS_UNAVAILABLE, vm.state.value.error)
    }
}
