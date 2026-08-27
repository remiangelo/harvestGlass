# Android Port — Status

**Branch:** `main`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

116 Kotlin files, ~22,100 lines, against 131 Swift files.
**304 unit tests and 44 instrumented tests, 0 failures.**

## Shipped

Every screen the iOS app can reach has a counterpart.

| Area | State |
| --- | --- |
| Theme, shared components | Complete — tokens copied hex-for-hex |
| Auth, signup, session restore, root gating | Complete |
| First-run intro (Differentiation) | Complete |
| Onboarding (12 steps) | Complete |
| Soil / Values + radar + question sheet + Tips | Complete |
| The Field: rooms, chat, members roster | Complete |
| Member profiles, Send a Seed, Compatibility | Complete |
| Seeds: requests, inbox, Likes You, 1:1 chat | Complete |
| Gardener: chat, daily quiz, screenshot review | Complete |
| Mindful messaging (pre-send + blur-on-receive) | Complete |
| Safety analysis, dashboard, ready-to-move gate | Complete |
| Subscriptions (Play Billing 7, server-verified) | Complete — needs Play Console products |
| Profile, edit, settings, legal, help | Complete |
| Push | Client complete — needs a Firebase project |

## Corrections to the earlier status

Two calls in the previous version of this document were wrong, and both
were fixed:

**ProfileDetailView is not dead code.** It lives under `Views/Discover/`,
which is why I filed it with the swipe-era leftovers, but it is reached from
the room roster, community chat and the inbound-likes list — and it is the
only place a Seed can be sent from. Android had no way to send a Seed at all
until it was ported. CompatibilityView, reached from it, was live for the same
reason.

**"Likes You" is live too.** It lists historical inbound swipes, and answering
one writes an outgoing swipe that can create a match. Nothing creates a *new*
swipe any more, but the list and its reply path still work.

## Deliberately not ported

**DiscoverView, FiltersView and TipsView.swift.** Nothing in the iOS app
references any of them — genuinely unreachable, verified by grep for each
symbol across the Swift sources.

**The generated-blurb section** on Soil — iOS has it commented out
(`ValuesView.swift:92`), so its absence is parity, not a gap.

## What still needs you

1. **Firebase project.** Add `google-services.json` to `android/app/`. The app
   builds and runs without it; push registration is simply inert.
2. **Apply the migration.** `20260825120000_android_push_support.sql` — until
   then every Android token registration fails the CHECK constraint.
3. **Set the FCM secrets** on `send-push`: `FCM_PROJECT_ID`,
   `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`. Without them the function reports
   `FCM_NOT_CONFIGURED` per Android device and still delivers to iOS.
4. **Play Console.** Create four subscription products with the ids in
   `PlayBilling.Product` — they match StoreKit's exactly.
5. **Set the Play secrets** on `verify-play-purchase`: `PLAY_PACKAGE_NAME`,
   `PLAY_CLIENT_EMAIL`, `PLAY_PRIVATE_KEY`, and deploy the function.

See `docs/setup/2026-08-25-android-launch-setup.md` for the step-by-step.

## Open defect: system back exits the app

Found 2026-08-27 while moving to targetSdk 36. Screens are routed by setting a
state flag and early-returning, and each takes an `onBack`/`onDismiss` the
chrome calls — but only `OnboardingContainer` registers a `BackHandler`. On
every other pushed screen the system back gesture is unhandled, so it finishes
the Activity instead of going back: Settings, Subscription, member profile,
Compatibility, room members, both chats, the report sheet, Send a Seed, the
interest picker, the quiz, and the safety screens.

Pre-existing, and it survived because the on-screen back affordances all work.
Predictive back is on by default at targetSdk 36, so it is now visible as an
app-exit animation the moment someone swipes back.

The fix is contained — a `BackHandler` inside each screen that already has the
callback — but it is a behaviour change across ~14 files and wants testing per
screen, so it is written down rather than slipped into the compliance bump.

## Known parity limits

**Liquid Glass cannot be reproduced.** iOS 26's `.glassEffect()` has no Android
equivalent. Buttons match in colour, geometry, padding and press spring, but not
translucency. This is the one place "exact same" was never achievable.

**Answering an inbound like is one tap, not three.** iOS opens the full profile
sheet to take the answer; the Android row carries Like back / Pass directly. The
profile is still one tap away on the row itself.

**Two Edge Functions are untypechecked locally.** `verify-play-purchase` and the
FCM branch of `send-push` were written without Deno installed here. They deploy
and run like any other function, but they have not been compiled.

## Verification

Earlier per-phase checklists remain the record of what is unverified against
live data:

- `2026-08-16-android-slice-checklist.md` — foundation and The Field
- `2026-08-19-android-onboarding-checklist.md`
- `2026-08-20-android-soil-checklist.md`
- `2026-08-20-android-seeds-chat-checklist.md`

The Field has been confirmed loading real rooms and images against the live
project, and the whole app has been confirmed launching without crashing after
every phase. The rest of the manual items are still open, and Seeds/chat needs
two accounts to exercise properly.
