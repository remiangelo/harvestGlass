# Gardener Image Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach up to ten screenshots to the Gardener, ask a question about them, and get an answer to that question — with follow-ups that can still see the images.

**Architecture:** The screenshot call stops asking the model for a JSON verdict and asks for prose, with a single refusal sentinel (`REFUSE_EXPLICIT`) the client maps to its own copy. `sendScreenshot(imageDataUrl)` becomes `sendImages(imageDataUrls)` on both platforms. Encoded images are retained on the ViewModel for the session so follow-ups re-send them without spending another daily review. A tier column caps images per message.

**Tech Stack:** Kotlin + Jetpack Compose (Android), SwiftUI + supabase-swift 2.41.1 (iOS), Supabase Postgres, `gpt-4.1-mini` via the `openai-chat` Edge Function.

**Spec:** `docs/superpowers/specs/2026-09-02-gardener-image-review-design.md`

## Global Constraints

- The two platforms must stay behaviourally identical. Android files carry `Mirrors <SwiftFile>.swift` comments; keep them accurate.
- **`screenshotPlaceholder` output must match byte-for-byte across platforms** — both read each other's rows out of `gardener_chat_history`. Singular: `📷 Screenshot — <caption>`. Plural: `📷 3 screenshots — <caption>`. With an empty caption, the trailing ` — ` is dropped.
- **Refusal sentinel is exactly `REFUSE_EXPLICIT`**, compared against the trimmed reply.
- Images are never uploaded to storage and never written to `gardener_chat_history`. Only the placeholder is persisted.
- Tier caps: seed 3, green 6, gold 10 images per message. Default for an unknown tier is 1.
- `maxTokens` for the image call is 700. Temperature stays 0.4.
- Pure helpers live in the `companion object` (Android) or as `static` members (iOS) and are unit-tested without a network, matching `upsertPayload` / `photoObjectPath` / `storagePathFromUrl`.
- Android tests run with `cd android && ./gradlew :app:testDebugUnitTest`. iOS tests need a Mac — if unavailable, write them, say so, and leave them unrun rather than claiming they pass.

---

### Task 1: Tier column for images per message

**Files:**
- Create: `supabase/migrations/20260902130000_gardener_images_per_review.sql`
- Modify: `android/app/src/main/java/com/harvestglass/harvest/data/model/SubscriptionTier.kt:36`
- Modify: `Harvest/Models/SubscriptionTier.swift:63,92,110,126,148,168`
- Test: `HarvestTests/Models/SubscriptionTierTests.swift` (create if absent)

**Interfaces:**
- Consumes: nothing.
- Produces: `SubscriptionTier.gardenerImagesPerReview: Int` on both platforms, defaulting to `1` when the column is absent from a response.

- [ ] **Step 1: Write the migration**

```sql
-- Images per Gardener message, laddered by tier.
--
-- Separate from gardener_screenshots_per_day, which counts *messages*: a
-- message carrying six screenshots is still one review. This column caps how
-- much context one review may carry.

alter table public.subscription_tiers
  add column if not exists gardener_images_per_review int not null default 1;

comment on column public.subscription_tiers.gardener_images_per_review is
  'Max images attachable to one Gardener message. A message is one review however many it carries.';

update public.subscription_tiers set gardener_images_per_review = 3  where tier_key = 'seed';
update public.subscription_tiers set gardener_images_per_review = 6  where tier_key = 'green';
update public.subscription_tiers set gardener_images_per_review = 10 where tier_key = 'gold';
```

- [ ] **Step 2: Add the Android field**

In `SubscriptionTier.kt`, directly after the `gardener_screenshots_per_day` line:

```kotlin
    @SerialName("gardener_images_per_review") val gardenerImagesPerReview: Int = 1,
```

- [ ] **Step 3: Write the failing iOS decode test**

`HarvestTests/Models/SubscriptionTierTests.swift`:

```swift
import XCTest
@testable import Harvest

final class SubscriptionTierTests: XCTestCase {
    /// The column arrives with migration 20260902130000. A client running
    /// against a database without it must still decode, and must not offer
    /// more images than the free tier allows.
    func testImagesPerReviewDefaultsToOneWhenAbsent() throws {
        let json = #"{"id":"1","name":"Seed","tier_key":"seed","gardener_screenshots_per_day":1}"#
        let tier = try JSONDecoder().decode(SubscriptionTier.self, from: Data(json.utf8))
        XCTAssertEqual(tier.gardenerImagesPerReview, 1)
    }

    func testImagesPerReviewDecodesWhenPresent() throws {
        let json = #"{"id":"3","name":"Gold","tier_key":"gold","gardener_images_per_review":10}"#
        let tier = try JSONDecoder().decode(SubscriptionTier.self, from: Data(json.utf8))
        XCTAssertEqual(tier.gardenerImagesPerReview, 10)
    }
}
```

- [ ] **Step 4: Run it and watch it fail**

Expected: compile failure, `value of type 'SubscriptionTier' has no member 'gardenerImagesPerReview'`.

- [ ] **Step 5: Add the iOS field**

Mirror `gardenerScreenshotsPerDay` in all six places: stored property, `CodingKeys` case (`case gardenerImagesPerReview = "gardener_images_per_review"`), memberwise-init parameter with default `1`, the assignment in that init, `decodeIfPresent(...) ?? 1` in `init(from:)`, and `try container.encode(...)` in `encode(to:)`.

- [ ] **Step 6: Run the tests**

Both pass. Android: `./gradlew :app:testDebugUnitTest` still green.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260902130000_gardener_images_per_review.sql android/app/src/main/java/com/harvestglass/harvest/data/model/SubscriptionTier.kt Harvest/Models/SubscriptionTier.swift HarvestTests/Models/SubscriptionTierTests.swift
git commit -m "feat(gardener): tier cap for images per message"
```

---

### Task 2: Android encoder — target dimension by image count

**Files:**
- Modify: `android/app/src/main/java/com/harvestglass/harvest/util/ScreenshotEncoder.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/util/ScreenshotEncoderTest.kt` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `ScreenshotEncoder.targetDimension(imageCount: Int): Int` and `ScreenshotEncoder.dataUrl(context: Context, uri: Uri, maxDimension: Int = 1400): String`.

- [ ] **Step 1: Write the failing test**

`ScreenshotEncoderTest.kt`:

```kotlin
package com.harvestglass.harvest.util

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Ten images at full size is several megabytes in one JSON body, and base64
 * inflates that by a third. The target shrinks as the count rises so total
 * payload stays bounded instead of growing linearly.
 */
class ScreenshotEncoderTest {

    @Test
    fun `one or two images keep the full target`() {
        assertEquals(1400, ScreenshotEncoder.targetDimension(1))
        assertEquals(1400, ScreenshotEncoder.targetDimension(2))
    }

    @Test
    fun `three to five images step down`() {
        assertEquals(1100, ScreenshotEncoder.targetDimension(3))
        assertEquals(1100, ScreenshotEncoder.targetDimension(5))
    }

    @Test
    fun `six or more step down again`() {
        assertEquals(900, ScreenshotEncoder.targetDimension(6))
        assertEquals(900, ScreenshotEncoder.targetDimension(10))
    }

    /** A count below one is a caller bug, not a reason to divide by zero. */
    @Test
    fun `a nonsense count falls back to the full target`() {
        assertEquals(1400, ScreenshotEncoder.targetDimension(0))
        assertEquals(1400, ScreenshotEncoder.targetDimension(-3))
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*ScreenshotEncoderTest*"`
Expected: FAIL, `Unresolved reference 'targetDimension'`.

- [ ] **Step 3: Implement**

In `ScreenshotEncoder`, change `private const val MAX_DIMENSION = 1400` to `const val MAX_DIMENSION = 1400`, then add:

```kotlin
    /**
     * Longest-edge target for a send of [imageCount] images. Text in a phone
     * screenshot stays legible at 900px, which is what makes the top of the
     * ladder affordable.
     */
    fun targetDimension(imageCount: Int): Int = when {
        imageCount <= 2 -> MAX_DIMENSION
        imageCount <= 5 -> 1100
        else -> 900
    }
```

Then thread the target through instead of using the constant directly:

```kotlin
    fun dataUrl(context: Context, uri: Uri, maxDimension: Int = MAX_DIMENSION): String {
        val bitmap = decodeDownsampled(context, uri, maxDimension)
            ?: throw EncodingException("That image couldn't be read. Try a different screenshot.")

        val scaled = downscale(bitmap, maxDimension)
        // ... rest unchanged
    }
```

Give `decodeDownsampled` and `downscale` a `maxDimension: Int` parameter and replace their uses of `MAX_DIMENSION` with it. Delete the empty `try { } finally { }` around the `downscale` call — the comment inside it explains why nothing is recycled, so move that comment onto `downscale` itself.

- [ ] **Step 4: Run the tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*ScreenshotEncoderTest*"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/util/ScreenshotEncoder.kt android/app/src/test/java/com/harvestglass/harvest/util/ScreenshotEncoderTest.kt
git commit -m "feat(gardener): scale encode target to image count"
```

---

### Task 3: Android service — sendImages, new prompt, sentinel refusal

**Files:**
- Modify: `android/app/src/main/java/com/harvestglass/harvest/data/service/GardenerService.kt:118-172,389-425,427-462`
- Modify: `android/app/src/test/java/com/harvestglass/harvest/data/service/GardenerScreenshotTest.kt` (replace contents)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `GardenerService.sendImages(userId: String, imageDataUrls: List<String>, caption: String, history: List<GardenerMessage>): String`
  - `GardenerService.imageParts(caption: String, imageDataUrls: List<String>): List<OpenAIService.ContentPart>`
  - `GardenerService.resolveReply(raw: String): String`
  - `GardenerService.screenshotPlaceholder(caption: String, imageCount: Int): String`
  - `GardenerService.REFUSE_SENTINEL: String`, `GardenerService.EXPLICIT_REFUSAL_REPLY: String`

- [ ] **Step 1: Replace the test file**

`GardenerScreenshotTest.kt` — delete the `parseVerdict` tests entirely (that function is going away) and write:

```kotlin
package com.harvestglass.harvest.data.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The image call returns prose, not JSON. The only structure is the refusal
 * sentinel — the previous JSON verdict was truncated by maxTokens on long
 * replies and surfaced as "The Gardener returned no verdict".
 */
class GardenerScreenshotTest {

    @Test
    fun `a caption becomes a text part before the images`() {
        val parts = GardenerService.imageParts("what do you think?", listOf("data:a", "data:b"))

        assertEquals(3, parts.size)
        assertEquals(OpenAIService.ContentPart.Text("what do you think?"), parts[0])
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:a"), parts[1])
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:b"), parts[2])
    }

    @Test
    fun `an empty caption contributes no text part`() {
        val parts = GardenerService.imageParts("   ", listOf("data:a"))

        assertEquals(1, parts.size)
        assertEquals(OpenAIService.ContentPart.ImageUrl("data:a"), parts[0])
    }

    @Test
    fun `image order is selection order`() {
        val urls = listOf("data:1", "data:2", "data:3")
        val parts = GardenerService.imageParts("", urls)

        assertEquals(urls, parts.map { (it as OpenAIService.ContentPart.ImageUrl).url })
    }

    @Test
    fun `the sentinel becomes the canned refusal`() {
        assertEquals(GardenerService.EXPLICIT_REFUSAL_REPLY, GardenerService.resolveReply("REFUSE_EXPLICIT"))
    }

    @Test
    fun `the sentinel is recognised with surrounding whitespace`() {
        assertEquals(
            GardenerService.EXPLICIT_REFUSAL_REPLY,
            GardenerService.resolveReply("  REFUSE_EXPLICIT\n\n")
        )
    }

    /** A reply that merely mentions the sentinel is a real reply. */
    @Test
    fun `prose containing the word is not a refusal`() {
        val raw = "I won't REFUSE_EXPLICIT anything here — the tone reads warm."
        assertTrue(GardenerService.resolveReply(raw).contains("tone reads warm"))
    }

    @Test
    fun `ordinary prose is formatted and returned`() {
        assertEquals("They're pulling back.", GardenerService.resolveReply("They're pulling back."))
    }

    @Test
    fun `the placeholder is singular for one image`() {
        assertEquals("📷 Screenshot — read this", GardenerService.screenshotPlaceholder("read this", 1))
    }

    @Test
    fun `the placeholder counts several images`() {
        assertEquals("📷 3 screenshots — read this", GardenerService.screenshotPlaceholder("read this", 3))
    }

    @Test
    fun `an empty caption drops the dash`() {
        assertEquals("📷 Screenshot", GardenerService.screenshotPlaceholder("", 1))
        assertEquals("📷 2 screenshots", GardenerService.screenshotPlaceholder("", 2))
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*GardenerScreenshotTest*"`
Expected: FAIL, unresolved references to `imageParts`, `resolveReply`, `EXPLICIT_REFUSAL_REPLY`, and the two-argument `screenshotPlaceholder`.

- [ ] **Step 3: Replace the companion members**

In `GardenerService`'s `companion object`, delete `data class ScreenshotVerdict`, `fun parseVerdict`, `private val JSON`, `NOT_A_SCREENSHOT_REPLY` and `SCREENSHOT_SYSTEM_PROMPT`. Replace the old one-argument `screenshotPlaceholder` too. Add:

```kotlin
        const val REFUSE_SENTINEL = "REFUSE_EXPLICIT"

        /**
         * Shown verbatim when the model refuses. Fixed in the app rather than
         * written by the model so the promise is worded identically every
         * time, and so it invites a retry — the judgement is the model's and
         * will occasionally be wrong.
         */
        val EXPLICIT_REFUSAL_REPLY = """
            I can't give you a read on that one — it looks explicit, and that's outside what I can coach on.

            Send me a conversation, a profile, or anything else you'd like a view on and I'll take a proper look.
        """.trimIndent()

        /** iOS composes the same placeholder, and both stores read it back. */
        fun screenshotPlaceholder(caption: String, imageCount: Int): String {
            val noun = if (imageCount > 1) "$imageCount screenshots" else "Screenshot"
            return if (caption.isEmpty()) "📷 $noun" else "📷 $noun — $caption"
        }

        /** The user turn: the question first, then every image in selection order. */
        fun imageParts(
            caption: String,
            imageDataUrls: List<String>
        ): List<OpenAIService.ContentPart> = buildList {
            val trimmed = caption.trim()
            if (trimmed.isNotEmpty()) add(OpenAIService.ContentPart.Text(trimmed))
            imageDataUrls.forEach { add(OpenAIService.ContentPart.ImageUrl(it)) }
        }

        /**
         * The model's reply, or our own copy when it refused. Compared against
         * the whole trimmed reply, not searched for: the sentinel appearing
         * inside a sentence is prose, not a refusal.
         */
        fun resolveReply(raw: String): String =
            if (raw.trim() == REFUSE_SENTINEL) EXPLICIT_REFUSAL_REPLY
            else GardenerFormatter.format(raw)

        private val IMAGE_SYSTEM_PROMPT = """
            You are The Gardener, a warm and insightful AI dating coach for the Harvest dating app.

            The user has attached one or more images and may have asked a question about them.

            If they asked a question, ANSWER THAT QUESTION. Ground every claim in what is
            actually visible in the images. Do not substitute general dating advice for the
            thing they asked.

            Several images are one continuous piece of context — usually consecutive
            screenshots of the same conversation, in the order given. Read them as a whole.

            If they asked nothing, give your read: what you notice, then what to do about it.

            Whatever you are looking at — a chat thread, a dating profile, a bio, a photo —
            respond to it as a coach would.

            - Never invent messages or details that aren't visible.
            - Be specific about tone and what the other person appears to be signalling.
            - Keep it concise: short paragraphs of 1-3 sentences, blank line between each.
            - Never give medical or legal advice. If it shows distress, abuse, or risk,
              name that clearly and encourage professional or trusted human support.

            If ANY image is sexually explicit or graphic, reply with exactly REFUSE_EXPLICIT
            and nothing else — no explanation, no other text.
        """.trimIndent()
```

- [ ] **Step 4: Replace `sendScreenshot` with `sendImages`**

```kotlin
    /**
     * Sends images for review. They are passed inline as data URLs and never
     * stored; only a placeholder is written to chat history.
     *
     * Throws on transport failure — a user must never be told their
     * screenshot was invalid because the network dropped.
     */
    suspend fun sendImages(
        userId: String,
        imageDataUrls: List<String>,
        caption: String,
        history: List<GardenerMessage>
    ): String {
        val trimmedCaption = caption.trim()

        val chatMessages = buildList {
            add(OpenAIService.ChatMessage("system", IMAGE_SYSTEM_PROMPT))
            history.takeLast(SCREENSHOT_HISTORY_WINDOW).forEach { msg ->
                add(
                    OpenAIService.ChatMessage(
                        role = if (msg.role == "assistant") "assistant" else "user",
                        content = msg.content
                    )
                )
            }
            add(OpenAIService.ChatMessage(role = "user", parts = imageParts(trimmedCaption, imageDataUrls)))
        }

        val raw = openAI.sendChat(messages = chatMessages, temperature = 0.4, maxTokens = 700)
        val response = resolveReply(raw)

        val placeholder = screenshotPlaceholder(trimmedCaption, imageDataUrls.size)
        val now = Instant.now().toString()
        runCatching { persist(userId, "user", placeholder, now) }
        runCatching { persist(userId, "gardener", response, now) }

        return response
    }
```

Remove the now-unused `kotlinx.serialization.json.Json`, `jsonObject`, `jsonPrimitive` and `booleanOrNull` imports if nothing else in the file uses them.

- [ ] **Step 5: Run the tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: PASS. `GardenerFormatTest` and `GardenerBudgetTest` must still be green — `resolveReply` routes through `GardenerFormatter.format`, so formatting behaviour is unchanged.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/data/service/GardenerService.kt android/app/src/test/java/com/harvestglass/harvest/data/service/GardenerScreenshotTest.kt
git commit -m "feat(gardener): answer the user's question about attached images"
```

---

### Task 4: Android ViewModel — multi-selection, retention, follow-up routing

**Files:**
- Modify: `android/app/src/main/java/com/harvestglass/harvest/ui/gardener/GardenerViewModel.kt:35,182-250`
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/gardener/GardenerSelectionTest.kt` (create)

**Interfaces:**
- Consumes: `GardenerService.sendImages`, `GardenerService.screenshotPlaceholder`, `ScreenshotEncoder.targetDimension`, `SubscriptionTier.gardenerImagesPerReview`.
- Produces: `GardenerViewModel.clampSelection(picked: List<Uri>, cap: Int): List<Uri>` (pure, in the companion), state fields `pendingScreenshots: List<Uri>`, `retainedImageUrls: List<String>`, `imageCap: Int`.

- [ ] **Step 1: Write the failing test**

`GardenerSelectionTest.kt`:

```kotlin
package com.harvestglass.harvest.ui.gardener

import android.net.Uri
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The picker is opened with the tier's cap, but the cap is applied again here:
 * a picker limit is a UI affordance, not a guarantee, and a 20-image request
 * is several megabytes.
 */
class GardenerSelectionTest {

    private fun uris(n: Int): List<Uri> = List(n) { i ->
        mockk<Uri>().also { every { it.toString() } returns "uri-$i" }
    }

    @Test
    fun `a selection within the cap is untouched`() {
        val picked = uris(3)
        assertEquals(picked, GardenerViewModel.clampSelection(picked, cap = 6))
    }

    @Test
    fun `an over-long selection keeps the first cap images`() {
        val picked = uris(9)
        val clamped = GardenerViewModel.clampSelection(picked, cap = 6)

        assertEquals(6, clamped.size)
        assertEquals(picked.take(6), clamped)
    }

    /** An unknown tier decodes as 1, and must not become "unlimited". */
    @Test
    fun `a cap of one keeps a single image`() {
        assertEquals(1, GardenerViewModel.clampSelection(uris(5), cap = 1).size)
    }

    @Test
    fun `a nonsense cap still sends one image rather than none`() {
        assertEquals(1, GardenerViewModel.clampSelection(uris(5), cap = 0).size)
    }

    @Test
    fun `an empty selection stays empty`() {
        assertEquals(emptyList<Uri>(), GardenerViewModel.clampSelection(emptyList(), cap = 6))
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*GardenerSelectionTest*"`
Expected: FAIL, `Unresolved reference 'clampSelection'`.

- [ ] **Step 3: Add the pure helper**

In `GardenerViewModel`'s `companion object`:

```kotlin
        /**
         * The images actually sent. The picker is opened with the cap, but a
         * picker limit is an affordance rather than a guarantee — and a cap of
         * zero from a malformed tier row must still let one image through.
         */
        fun clampSelection(picked: List<Uri>, cap: Int): List<Uri> =
            picked.take(cap.coerceAtLeast(1))
```

- [ ] **Step 4: Widen the state**

In the UI state class, replace `pendingScreenshot: Uri?` with:

```kotlin
    /** Images staged in the composer, awaiting send. Never persisted. */
    val pendingScreenshots: List<Uri> = emptyList(),
    /**
     * Encoded images from the last send, kept so a follow-up in the same
     * sitting can be answered by looking again. Dies with the process; never
     * uploaded, never written to chat history.
     */
    val retainedImageUrls: List<String> = emptyList(),
    /** Images allowed per message on the current tier. */
    val imageCap: Int = 1,
```

Update `hasPendingScreenshot` to `pendingScreenshots.isNotEmpty()`. Change `stageScreenshot(uri: Uri)` to `stageScreenshots(uris: List<Uri>)`, storing `clampSelection(uris, _state.value.imageCap)`. Add `unstageScreenshot(index: Int)` removing one entry. Set `imageCap` from `currentTier.gardenerImagesPerReview` wherever `currentTier` is loaded.

- [ ] **Step 5: Rewrite the send path**

Rename `sendScreenshot` to `sendImages` and change its body so that:

- it reads `val uris = _state.value.pendingScreenshots`, returning early when empty;
- the tier and `checkScreenshotLimit` guards are unchanged;
- encoding maps over the selection with the count-aware target:

```kotlin
        val target = ScreenshotEncoder.targetDimension(uris.size)
        val dataUrls = try {
            withContext(Dispatchers.IO) { uris.map { ScreenshotEncoder.dataUrl(context, it, target) } }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
            return@launch
        }
```

- the optimistic placeholder uses `GardenerService.screenshotPlaceholder(caption, uris.size)`;
- state clears `pendingScreenshots` and sets `retainedImageUrls = dataUrls`;
- the service call becomes `service.sendImages(userId, dataUrls, caption, _state.value.messages.dropLast(1))`.

- [ ] **Step 6: Guard the total payload**

Per-image scaling bounds each image, not the sum. Add the pure helper beside
`clampSelection`:

```kotlin
        /** Total encoded budget for one request, in characters of base64. */
        const val PAYLOAD_BUDGET_CHARS = 6_000_000

        /**
         * Null when the encoded selection fits, otherwise the message to show.
         * Scaling bounds each image; nothing bounds the sum, and a transport
         * error tells the user nothing about what to do differently.
         */
        fun payloadRejection(dataUrls: List<String>): String? {
            val total = dataUrls.sumOf { it.length }
            if (total <= PAYLOAD_BUDGET_CHARS) return null
            return "Those ${dataUrls.size} images are too large to send together. " +
                "Try sending fewer at a time."
        }
```

and its tests in `GardenerSelectionTest`:

```kotlin
    @Test
    fun `a selection within budget is accepted`() {
        assertNull(GardenerViewModel.payloadRejection(listOf("a".repeat(1000), "b".repeat(1000))))
    }

    @Test
    fun `an oversized selection is refused by count, not by bytes`() {
        val huge = List(3) { "x".repeat(3_000_000) }
        val message = GardenerViewModel.payloadRejection(huge)

        assertNotNull(message)
        assertTrue(message!!.contains("3 images"))
    }
```

(add `import org.junit.Assert.assertNull`, `assertNotNull` and `assertTrue`).

Call it in `sendImages` immediately after encoding, before any state mutation:

```kotlin
        payloadRejection(dataUrls)?.let { message ->
            _state.update { it.copy(error = message) }
            return@launch
        }
```

- [ ] **Step 7: Route follow-ups**

At the top of the existing text-send function `send(userId)`, before its character-limit path:

```kotlin
        // A follow-up while images are still in hand goes back through the
        // image call so the Gardener can look again rather than guess. It is
        // not a new review: trackScreenshotReview is deliberately not called.
        val retained = _state.value.retainedImageUrls
        if (retained.isNotEmpty()) {
            sendRetained(userId, retained)
            return@launch
        }
```

`sendRetained` mirrors the tail of `sendImages` — optimistic user message with the raw draft text (not a placeholder; the user typed a real message), `service.sendImages(userId, retained, draft, history)`, append the reply — and calls neither `checkScreenshotLimit` nor `trackScreenshotReview`.

- [ ] **Step 8: Run the whole suite**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: PASS, including the new `GardenerSelectionTest`.

- [ ] **Step 9: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/gardener/GardenerViewModel.kt android/app/src/test/java/com/harvestglass/harvest/ui/gardener/GardenerSelectionTest.kt
git commit -m "feat(gardener): stage several images and reuse them for follow-ups"
```

---

### Task 5: Android composer UI

**Files:**
- Modify: `android/app/src/main/java/com/harvestglass/harvest/ui/gardener/GardenerScreen.kt:66-69,184,204-208,213-216`

**Interfaces:**
- Consumes: `state.pendingScreenshots`, `state.imageCap`, `viewModel.stageScreenshots`, `viewModel.unstageScreenshot`, `viewModel.sendImages`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Swap the picker contract**

```kotlin
    // ImageOnly, not a screenshots-only filter: a screenshot someone was *sent*
    // isn't tagged as one.
    val pickImages = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(state.imageCap.coerceAtLeast(1))
    ) { uris: List<Uri> -> if (uris.isNotEmpty()) viewModel.stageScreenshots(uris) }
```

`PickMultipleVisualMedia` requires `maxItems >= 2`; when `imageCap` is 1, use `ActivityResultContracts.PickVisualMedia()` instead and wrap the single result in a list. Branch on the cap at the call site rather than inside the contract.

- [ ] **Step 2: Add the thumbnail strip**

Above the input row, when `state.pendingScreenshots.isNotEmpty()`, a `LazyRow` of 56.dp `AsyncImage` thumbnails with an 8.dp gap, each with a small close affordance in its top-right corner calling `viewModel.unstageScreenshot(index)`. Use Coil's `AsyncImage` (`io.coil-kt:coil-compose`, already a dependency at `libs.versions.toml:47`) with `contentScale = ContentScale.Crop` and a 8.dp rounded clip.

- [ ] **Step 3: Add the retained-images chip**

While `state.retainedImageUrls` is non-empty AND `state.pendingScreenshots` is
empty, show a small dismissible chip above the input reading
`Following up on 3 images` (singular: `Following up on 1 image`), with a close
control calling `viewModel.clearRetainedImages()`.

Without this the user cannot tell that their next message will re-send images,
and cannot stop it — the ViewModel is Activity-scoped, so retention lasts until
the process dies. Added 2026-09-02 by ruling during implementation; see the
ledger and spec §6.

- [ ] **Step 4: Update the counter and send**

The `sendFooter` currently reads `"${state.remainingScreenshots}📷"`. When images are staged, show `"${state.pendingScreenshots.size} / ${state.imageCap} 📷"`; otherwise leave the existing remaining-reviews text. Change the `onSend` branch to call `viewModel.sendImages(context, userId)`.

- [ ] **Step 5: Build and check by hand**

Run: `cd android && ./gradlew :app:assembleDebug`
Then on a device: stage three images, confirm the strip and the `3 / N` counter, remove the middle one, send, and confirm the reply answers the typed question rather than describing the images generically. Then confirm the chip appears, that a follow-up without attaching anything is answered from the images, and that dismissing the chip stops that.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/gardener/GardenerScreen.kt
git commit -m "feat(gardener): multi-image composer"
```

---

### Task 6: Measure the payload ceiling, settle the dimensions

**Files:**
- Modify: `android/app/src/main/java/com/harvestglass/harvest/util/ScreenshotEncoder.kt` (constants only, if the measurement demands it)
- Modify: `docs/superpowers/specs/2026-09-02-gardener-image-review-design.md` §3

**Interfaces:**
- Consumes: Task 5's working build.
- Produces: confirmed constants for Task 7 to mirror on iOS.

This is the open question the spec flagged: the ladder in §3 is conservative, not measured.

- [ ] **Step 1: Measure a real ten-image send**

On a device with a gold-tier account, stage ten real phone screenshots and send. Log the summed length of the encoded data URLs before the request goes out.

- [ ] **Step 2: Record the result**

If the request succeeds, note the total size in the spec and leave the constants alone. If it fails, note the failing size and the error, then lower the `>= 6` rung until a ten-image send succeeds with at least 30% headroom.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/util/ScreenshotEncoder.kt docs/superpowers/specs/2026-09-02-gardener-image-review-design.md
git commit -m "docs(gardener): record the measured payload ceiling"
```

---

### Task 7: iOS service — mirror Task 3

**Files:**
- Modify: `Harvest/Services/GardenerService.swift:48-135`
- Test: `HarvestTests/Services/ScreenshotReviewTests.swift`

**Interfaces:**
- Consumes: the constants confirmed in Task 6.
- Produces: `GardenerService.sendImages(userId:imageDataURLs:caption:history:)`, and statics `imageParts(caption:imageDataURLs:)`, `resolveReply(_:)`, `screenshotPlaceholder(caption:imageCount:)`, `explicitRefusalReply`, `refuseSentinel`.

- [ ] **Step 1: Write the failing tests**

Append to `ScreenshotReviewTests.swift` a `GardenerImageReviewTests` class covering exactly the cases in Task 3's Kotlin tests — caption becomes a leading text part, blank caption contributes none, selection order preserved, sentinel alone maps to the refusal, sentinel with whitespace maps to the refusal, sentinel inside prose does not, singular/plural placeholder, and empty-caption placeholder.

**The placeholder assertions must use the same literal strings as the Kotlin tests** — `"📷 Screenshot — read this"` and `"📷 3 screenshots — read this"` — since both platforms read each other's rows.

- [ ] **Step 2: Run and watch them fail**

On a Mac: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: compile failure on the new members.

- [ ] **Step 3: Mirror the implementation**

Delete `parseVerdict`, `ScreenshotVerdict`, `notAScreenshotReply` and `screenshotSystemPrompt`. Add the Swift equivalents of Task 3's members, with `imageSystemPrompt` carrying **the identical prompt text** — copy it across verbatim so the two platforms cannot drift.

Replace `sendScreenshot(userId:imageDataURL:caption:history:)` with `sendImages(userId:imageDataURLs:caption:history:)`, `maxTokens: 700`.

- [ ] **Step 4: Run the tests**

Expected: PASS. If no Mac is available, say so plainly and leave this unrun — do not report it as passing.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Services/GardenerService.swift HarvestTests/Services/ScreenshotReviewTests.swift
git commit -m "feat(gardener): mirror image review on iOS"
```

---

### Task 8: iOS ViewModel and composer — mirror Tasks 4 and 5

**Files:**
- Modify: `Harvest/ViewModels/GardenerViewModel.swift:62-130` (`sendScreenshot`, and the `dataURL` encode at :93)
- Modify: `Harvest/Views/Gardener/GardenerChatView.swift:227` (the send branch and the picker above it)
- Modify: `Harvest/Utilities/ScreenshotEncoder.swift` (`ScreenshotEncoder.dataURL(from:)`)

**Interfaces:**
- Consumes: `GardenerService.sendImages`, `SubscriptionTier.gardenerImagesPerReview`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Mirror the encoder ladder**

Add `static func targetDimension(imageCount: Int) -> Int` with the same rungs as Task 2 and thread it through the Swift encoder. Add the matching tests to the iOS suite.

- [ ] **Step 2: Mirror the view model**

Staged selection becomes an array, encoded URLs are retained after send, and a text follow-up while retained images exist routes to `sendImages` without touching the review counter — the same rule as Task 4 Step 6.

- [ ] **Step 3: Mirror the composer**

`PhotosPicker(selection:maxSelectionCount:)` with the tier's cap, a thumbnail strip with per-item removal, and a `3 / 6` counter.

- [ ] **Step 4: Build, test, check by hand**

Same manual check as Task 5 Step 4, on a device.

- [ ] **Step 5: Commit**

```bash
git add Harvest HarvestTests
git commit -m "feat(gardener): multi-image composer on iOS"
```

---

### Task 9: Apply the migration and verify end to end

- [ ] **Step 1: Apply**

Paste `supabase/migrations/20260902130000_gardener_images_per_review.sql` into the Supabase SQL editor for `jutzlxdboayvmcuqwodn`. Do **not** use `supabase db push` — remote migration history is out of sync with this directory.

- [ ] **Step 2: Verify the tiers**

```sql
select tier_key, gardener_screenshots_per_day, gardener_images_per_review
from public.subscription_tiers order by price_cents;
```

Expect 1/3, 5/6, 20/10 for seed, green, gold.

- [ ] **Step 3: Check the three reported bugs by hand**

1. Attach a screenshot of a conversation, ask a specific question about it ("what's the tone of the last message?"). The reply must answer that question.
2. Attach a **dating profile** screenshot and ask about it. It must be answered, not refused — this is what the old gate rejected.
3. Ask a follow-up without attaching anything ("what did the second message say?"). The reply must reference the actual content, and the daily review count must not have moved.

- [ ] **Step 4: Confirm the review counter**

```sql
select gardener_screenshots_today from public.user_usage where user_id = '<your id>';
```

One send with six images plus two follow-ups increments this by exactly 1.
