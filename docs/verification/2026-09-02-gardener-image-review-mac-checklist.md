# Gardener image review — Mac checklist (2026-09-02)

The Android half of `feat/gardener-image-review` is built and tested: 326 unit
tests green, `assembleDebug` succeeds. **The iOS half has never been compiled and
its tests have never been run** — there was no Mac. Nothing about the Swift is
verified beyond reading.

Behavioural parity was checked by review rather than by execution. The three
strings both platforms must agree on — the system prompt, the refusal copy, and
`screenshotPlaceholder`'s output — were diffed byte-for-byte against the Kotlin
and are identical.

Plan: `docs/superpowers/plans/2026-09-02-gardener-image-review.md`
Spec: `docs/superpowers/specs/2026-09-02-gardener-image-review-design.md`

## 1. Build it, in this order

Compile first. If it fails, these are the lines to suspect, ranked by how likely
they were judged to break:

1. **`GardenerViewModel.swift` — `Task.detached` capturing `[UIImage]`.** The
   closure is `@Sendable`, so this needs `UIImage: Sendable`. Recent SDKs declare
   that conformance and Swift 5 language mode demotes a miss to a warning, but
   the SDK could not be checked without a Mac. If it errors: box the array in an
   `@unchecked Sendable` wrapper, or hop through an `actor`.
2. **`GardenerChatView.swift:21,30` — `ForEach(images, id: \.self)` and
   `images.firstIndex(of:)`.** Both assume `UIImage` equality is `NSObject`
   identity, not pixel comparison. If it is content comparison, two identical
   staged images collide on id. Fix is a small `Identifiable` wrapper holding a
   `UUID`.
3. **`ScreenshotEncoder.swift:25-27` — `nonisolated static let`.** Valid from
   Swift 5.5. It replaced a type-level `nonisolated`, which is SE-0449 and needs
   Swift 6.1 — this target is `SWIFT_VERSION = 5.0`, so the type-level form would
   have been a hard failure. The annotation is load-bearing, not decorative:
   without it the `= maxDimension` default arguments would read MainActor state
   from a nonisolated function.
4. **`ScreenshotReviewTests.swift` — `GardenerRetentionTests` constructing
   `GardenerViewModel()`.** Depends on the `@Observable` macro leaving the
   synthesized `init()` visible through `@testable import`. `GardenerChatView`
   constructs it identically, so probably fine.
5. Judged likely-to-compile on review but never compiled: the
   `PhotosPicker(selection:maxSelectionCount:matching:)` labels,
   `.onChange(of: pickedPhotos)` needing `[PhotosPickerItem]: Equatable`, the
   generic `static func clampSelection<Item>`, the `target: CGFloat = maxDimension`
   default argument, `resolveReply` calling `formatResponse` unqualified, and
   `XCTAssertEqual` on `CGFloat` against integer literals.

One project-level question that a single compile settles: the app target sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `HarvestTests` does not, which
makes app declarations implicitly MainActor while test code is nonisolated. The
new test classes carry `@MainActor` defensively. `KeywordMatcherTests.swift:9`
has the same shape and presumably compiles today, so this may never have been a
problem.

## 2. Apply the migration

`supabase/migrations/20260902130000_gardener_images_per_review.sql` — paste into
the SQL editor for `jutzlxdboayvmcuqwodn`. Do **not** use `supabase db push`;
remote migration history is out of sync with this directory.

```sql
select tier_key, gardener_screenshots_per_day, gardener_images_per_review
from public.subscription_tiers order by price_cents;
```

Expect 1/3, 5/6, 20/10 for seed, green, gold.

## 3. Measure the payload ceiling — the one thing nobody could do

The encoder's dimension ladder (1400px for 1–2 images, 1100 for 3–5, 900 for 6+)
and the 6,000,000-character total budget are **conservative guesses, not
measurements**. The real Supabase Edge Function request ceiling was never
established.

On a gold-tier account, stage ten real screenshots and send. Log the summed
length of the encoded data URLs first. If it succeeds, record the size and leave
the constants alone. If it fails, lower the 6+ rung until a ten-image send
succeeds with at least 30% headroom, and mirror the change to both platforms.

This matters more on iOS than the spec assumed: iOS's encoder cap was 1024px, and
it was raised to 1400 for parity, so existing single-image sends there now carry
roughly 1.9× the pixels.

## 4. Check the three reported bugs by hand

On a device, for each platform:

1. Attach a conversation screenshot and ask something specific about it — "what's
   the tone of the last message?". The reply must answer *that*, not describe the
   conversation generically.
2. Attach a **dating profile** screenshot and ask about it. It must be answered.
   The old gate refused this outright, and it is the case most likely to regress
   if the prompt drifts.
3. Ask a follow-up with nothing attached — "what did the second message say?".
   The reply must reference real content from the images.

Then confirm the accounting:

```sql
select gardener_screenshots_today from public.user_usage where user_id = '<id>';
```

One send with six images plus two follow-ups must increment this by exactly **1**.
The follow-ups should spend chat characters but not a review.

Also worth watching on a device: stage several large screenshots and confirm the
composer stays responsive with the spinner up *during* encoding, and that a
double-tap on send cannot spend two reviews. Both were bugs found in review; both
are fixed but neither was exercised on hardware.

## 5. Cross-platform check

Send a screenshot from iOS and one from Android, then read both rows:

```sql
select role, content from public.gardener_chat_history
where user_id = '<id>' order by created_at desc limit 6;
```

The placeholders must match byte for byte — `📷 Screenshot — <caption>` for one
image, `📷 3 screenshots — <caption>` for several. Both platforms read each
other's rows back, so a divergence here is a real defect.

## Known and deliberately left alone

- `clearScreenshot()` (Kotlin) and `clearScreenshots()` (Swift) are dead code.
- iOS's plain-text `sendMessage` failure path does not restore the draft or remove
  its bubble, where Android's does. Pre-existing.
- JPEG quality differs — Android 80, iOS 0.7 — and iOS enforces a 4MB per-image
  cap Android has no counterpart for. Pre-existing, now more visible with ten
  images in play.
- `GardenerRetentionTest.kt` seeds state by reflecting into the private `_state`
  flow. The alternatives were adding Robolectric or making `ScreenshotEncoder`
  injectable, both larger than the problem.
- No test covers the *fresh* send path incrementing the review count, because
  `trackScreenshotReview` sits behind a `BitmapFactory`/`ContentResolver` encode.
  The retained half — that a follow-up spends no review — is covered.
