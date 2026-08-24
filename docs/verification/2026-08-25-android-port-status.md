# Android Port — Status

**Branch:** `main`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

84 Kotlin files, ~12,900 lines, against 131 Swift files / ~19,600 lines.
**225 unit tests and 44 instrumented tests, 0 failures.**

## Shipped

All five tabs are real, and every screen the iOS app can reach has a counterpart.

| Area | State |
| --- | --- |
| Theme, shared components | Complete — tokens copied hex-for-hex |
| Auth, session restore, root gating | Complete |
| Onboarding (12 steps) | Complete |
| Soil / Values + radar + question sheet | Complete |
| The Field: rooms, chat, members roster | Complete |
| Seeds: requests, conversations, 1:1 chat | Complete |
| Gardener chat | Complete |
| Profile, edit, settings, legal, help, safety | Complete |
| Push: schema migration + send-push FCM branch | Server side complete; client needs Firebase |

## Deliberately not ported

**Discover, Compatibility and Filters.** Nothing in the iOS app references
`DiscoverView`, `CompatibilityView` or `FiltersView` — they are swipe-era
leftovers from before the Seeds pivot, reachable from no screen. ~960 lines of
Swift that would have become dead Kotlin.

**The mindful pre-send warning** and the **safety "ready to move" gate**. Both
need `MindfulMessagingService` / `SafetyAnalysisService`'s OpenAI paths. The
local keyword half IS ported and does real work: blur-on-receive in 1:1 chat,
the nickname gate in onboarding, and the masked preview in the conversation
list.

**The generated-blurb section** on Soil — iOS has it commented out
(`ValuesView.swift:92`), so its absence is parity, not a gap.

**The Tips library**, the **subscription screen**, and **inbound likes**. All
three gate on the tier lookup, which needs Play Billing. They render locked,
which is what a free user sees on iOS.

**The Gardener daily quiz and screenshot review.**

## What still needs you

1. **Play Console.** Create the subscription products; StoreKit's
   `com.harvestglass.harvest.grow.monthly` / `.gold.monthly` mean nothing to
   Google Play. Tier stays server-authoritative, so an iOS subscriber already
   reads correctly on Android — only purchasing is per-store.
2. **Firebase project.** Add `google-services.json`, the FCM SDK, and the
   `POST_NOTIFICATIONS` runtime prompt. The service that registers the token is
   written and the server accepts Android rows once the migration is applied.
3. **Apply the migration.** `20260825120000_android_push_support.sql` — until
   then every Android token registration fails the CHECK constraint.
4. **Set the FCM secrets** on `send-push`: `FCM_PROJECT_ID`,
   `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`. Without them the function reports
   `FCM_NOT_CONFIGURED` per Android device and still delivers to iOS.

## Known parity limits

**Liquid Glass cannot be reproduced.** iOS 26's `.glassEffect()` has no Android
equivalent. Buttons match in colour, geometry, padding and press spring, but not
translucency. This is the one place "exact same" was never achievable.

**Report has no category picker.** iOS opens `ReportUserView` with a reason
list; Android files a report with a fixed reason.

**Typing indicators** are implemented in `ChatService` but not surfaced in the
chat UI.

## Verification

Earlier per-phase checklists remain the record of what is unverified against
live data:

- `2026-08-16-android-slice-checklist.md` — foundation and The Field
- `2026-08-19-android-onboarding-checklist.md`
- `2026-08-20-android-soil-checklist.md`
- `2026-08-20-android-seeds-chat-checklist.md`

The Field has since been confirmed loading real rooms and images against the
live project. The rest of the manual items are still open, and Seeds/chat needs
two accounts to exercise properly.
