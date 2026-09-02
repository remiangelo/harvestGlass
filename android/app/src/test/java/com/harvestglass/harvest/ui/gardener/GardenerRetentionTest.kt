package com.harvestglass.harvest.ui.gardener

import android.net.Uri
import com.harvestglass.harvest.data.service.GardenerService
import com.harvestglass.harvest.data.service.OpenAIService
import com.harvestglass.harvest.data.service.RateLimitService
import com.harvestglass.harvest.data.service.SubscriptionService
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
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
 * could stand in for it.
 */
class GardenerRetentionTest {

    private fun uri(id: String): Uri = mockk<Uri>().also { every { it.toString() } returns id }

    private fun newViewModel(): GardenerViewModel = GardenerViewModel(
        service = mockk<GardenerService>(relaxed = true),
        subscriptionService = mockk<SubscriptionService>(relaxed = true),
        rateLimitService = mockk<RateLimitService>(relaxed = true),
        openAI = mockk<OpenAIService>(relaxed = true)
    )

    @Suppress("UNCHECKED_CAST")
    private fun seed(vm: GardenerViewModel, state: GardenerUiState) {
        val field = GardenerViewModel::class.java.getDeclaredField("_state")
        field.isAccessible = true
        (field.get(vm) as MutableStateFlow<GardenerUiState>).value = state
    }

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
}
