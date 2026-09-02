package com.harvestglass.harvest.ui.gardener

import android.content.Context
import android.net.Uri
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.service.GardenerLimitCheck
import com.harvestglass.harvest.data.service.GardenerService
import com.harvestglass.harvest.data.service.OpenAIService
import com.harvestglass.harvest.data.service.RateLimitService
import com.harvestglass.harvest.data.service.ScreenshotLimitCheck
import com.harvestglass.harvest.data.service.SubscriptionService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Retained images are Activity-scoped, in-memory state (see the ViewModel's
 * `retainedImageUrls` doc). There is no public setter for them other than a
 * successful [GardenerViewModel.sendImages] send, which needs a real
 * [android.content.Context] plus Android's BitmapFactory/ContentResolver —
 * unreachable from a plain JVM unit test, and this module has no Robolectric
 * dependency to fake them. These tests seed the precondition by reflecting
 * into the private `_state` flow, then call the real, unmodified production
 * methods and observe the result through the public `state` flow — nothing
 * about what's being asserted is mocked away, only the starting point is
 * injected.
 *
 * A test that instead drove this through [GardenerViewModel.sendImages]
 * end-to-end would need either Robolectric (to fake `ContentResolver` and
 * `BitmapFactory`) or `ScreenshotEncoder` made injectable so a fake encoder
 * could stand in for it. That is why the two review-accounting tests below
 * cover the retained path in full and the fresh path only up to the encode.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class GardenerRetentionTest {

    private val service: GardenerService = mockk(relaxed = true)
    private val subscriptionService: SubscriptionService = mockk(relaxed = true)
    private val rateLimitService: RateLimitService = mockk(relaxed = true)
    private val openAI: OpenAIService = mockk(relaxed = true)

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun uri(id: String): Uri = mockk<Uri>().also { every { it.toString() } returns id }

    private fun newViewModel(): GardenerViewModel = GardenerViewModel(
        service = service,
        subscriptionService = subscriptionService,
        rateLimitService = rateLimitService,
        openAI = openAI
    )

    @Suppress("UNCHECKED_CAST")
    private fun seed(vm: GardenerViewModel, state: GardenerUiState) {
        val field = GardenerViewModel::class.java.getDeclaredField("_state")
        field.isAccessible = true
        (field.get(vm) as MutableStateFlow<GardenerUiState>).value = state
    }

    /**
     * `currentTier` is private and only set by `load()`, which would need the
     * whole Supabase stack. Both send paths bail early without it, so the tier
     * is injected the same way the state is.
     */
    private fun injectTier(vm: GardenerViewModel, tier: SubscriptionTier) {
        val field = GardenerViewModel::class.java.getDeclaredField("currentTier")
        field.isAccessible = true
        field.set(vm, tier)
    }

    private val seedTier = SubscriptionTier(
        id = "t-seed",
        name = TierName.SEED,
        displayName = "Seed",
        gardenerCharacterLimit = 2000,
        gardenerScreenshotsPerDay = 1,
        gardenerImagesPerReview = 3
    )

    @Test
    fun `staging a new selection clears any retained images`() {
        val vm = newViewModel()
        seed(
            vm,
            GardenerUiState(
                retainedImageUrls = listOf("data:image/jpeg;base64,AAA"),
                imageCap = 3
            )
        )

        vm.stageScreenshots(listOf(uri("new-1")))

        assertTrue(vm.state.value.retainedImageUrls.isEmpty())
        assertEquals(1, vm.state.value.pendingScreenshots.size)
    }

    @Test
    fun `clearRetainedImages empties the field`() {
        val vm = newViewModel()
        seed(
            vm,
            GardenerUiState(
                retainedImageUrls = listOf(
                    "data:image/jpeg;base64,AAA",
                    "data:image/jpeg;base64,BBB"
                )
            )
        )

        vm.clearRetainedImages()

        assertTrue(vm.state.value.retainedImageUrls.isEmpty())
    }

    /**
     * Spec §9: "a follow-up with retained images does not increment the review
     * count". A re-send is a second question about one review, so neither the
     * daily allowance check nor the counter may fire — only the chat character
     * budget, which the follow-up still spends.
     */
    @Test
    fun `a follow-up on retained images spends no daily review`() = runTest {
        val vm = newViewModel()
        injectTier(vm, seedTier)
        seed(
            vm,
            GardenerUiState(
                retainedImageUrls = listOf("data:image/jpeg;base64,AAA"),
                screenshotsUsedToday = 1,
                screenshotLimit = 1,
                imageCap = 3
            )
        )
        coEvery { rateLimitService.checkGardenerLimit(any(), any(), any()) } returns
            GardenerLimitCheck(canSend = true, reason = null, remainingCharacters = 2000, characterLimit = 2000)
        val userTurn = slot<String>()
        coEvery {
            service.sendImages(any(), any(), any(), capture(userTurn), any())
        } returns "The second message said hello."

        val question = "what did the second message say?"
        vm.send("u1", question).join()

        coVerify(exactly = 0) { rateLimitService.checkScreenshotLimit(any(), any()) }
        coVerify(exactly = 0) { rateLimitService.trackScreenshotReview(any()) }
        assertEquals(1, vm.state.value.screenshotsUsedToday)

        // The follow-up is metered as chat, and persisted as the plain
        // question — not re-filed as another camera-prefixed review.
        coVerify(exactly = 1) { rateLimitService.trackGardenerConversation("u1", question.length) }
        assertEquals(question, userTurn.captured)
    }

    /**
     * The other half of the same spec line — "and a fresh selection does" —
     * only as far as a JVM test can reach it. `checkScreenshotLimit` runs
     * before the encode and is observable. `trackScreenshotReview` runs after
     * it, on the far side of a `Dispatchers.IO` hop the test scheduler does
     * not control, and of a `ScreenshotEncoder.dataUrl` that needs a real
     * `ContentResolver` and `BitmapFactory`. Covering the increment itself
     * needs Robolectric or an injectable encoder — see this class's header.
     */
    @Test
    fun `a fresh selection consults the daily review budget`() = runTest {
        val vm = newViewModel()
        injectTier(vm, seedTier)
        val picked = uri("pick-1")
        seed(vm, GardenerUiState(pendingScreenshots = listOf(picked), imageCap = 3))
        coEvery { rateLimitService.checkScreenshotLimit(any(), any()) } returns
            ScreenshotLimitCheck(canSend = true, reason = null, remaining = 1, limit = 1)

        // Joined, not just advanced: the encode hops to Dispatchers.IO, which
        // the test scheduler does not drive, and letting it outlive the test
        // leaks an uncaught resumption into whatever runs next.
        vm.sendImages(mockk<Context>(relaxed = true), "u1").join()

        coVerify(exactly = 1) { rateLimitService.checkScreenshotLimit("u1", seedTier) }
        // …unlike the retained path above, which never asks. That contrast is
        // the whole point: a fresh selection is a review, a follow-up is not.
        coVerify(exactly = 0) { rateLimitService.checkGardenerLimit(any(), any(), any()) }

        // The encode then fails on the stubbed Context, which is as far as
        // this reaches — but the failure path is itself worth pinning: the
        // selection survives it (spec §7), and isThinking, raised before the
        // encode so a double tap can't spend a second review, comes back down.
        assertNotNull(vm.state.value.error)
        assertFalse(vm.state.value.isThinking)
        assertEquals(listOf(picked), vm.state.value.pendingScreenshots)
    }
}
