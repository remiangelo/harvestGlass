# Harvest for Android — Design

**Date:** 2026-08-16
**Status:** Approved, implementation starting
**Goal:** Ship an Android app at feature and visual parity with the existing SwiftUI iOS app.

## Context

`Harvest/` is a SwiftUI iOS app: 131 Swift files, ~19,600 lines, one third-party
dependency (`supabase-swift` 2.41.1). It talks to Supabase for Postgres, Auth,
Realtime and Storage, plus a set of Edge Functions. There is no Android code in
the repo today.

The backend needs no rewrite. Tables, RLS policies and Edge Functions are shared
verbatim; Android becomes a second client against the same project
(`jutzlxdboayvmcuqwodn.supabase.co`).

## Decisions

**Native Kotlin + Jetpack Compose.** Not KMP (would force a risky refactor of the
shipped iOS app before Android gained anything) and not Flutter/RN (would throw
away the working SwiftUI app). Cost accepted: two codebases to keep in step.

**Lives at `android/` in this repo.** Keeps `supabase/migrations`, the specs, and
the plans as one source of truth across both clients. `Harvest/` is not modified
by this work.

**Vertical slice before fan-out.** Prove the whole stack end to end on live data
with one real feature before porting the other ten.

## Architecture

The Android package structure deliberately mirrors the iOS folder structure, so
each Swift file has an obvious counterpart and future features port by analogy.

| iOS | Android |
| --- | --- |
| `Models/*.swift` (`Codable`) | `data/model/*.kt` (`@Serializable`) |
| `Services/*.swift` (22 files) | `data/service/*.kt` — same names, same method names |
| `ViewModels/*.swift` (`@Observable`) | `ui/<feature>/*ViewModel.kt` (`ViewModel` + `StateFlow`) |
| `Views/**/*.swift` | `ui/<feature>/*.kt` composables, same folder split |
| `Theme/HarvestTheme.swift` | `ui/theme/HarvestTheme.kt` |
| `Utilities/*.swift` | `util/*.kt` |
| `supabase-swift` | `supabase-kt` (postgrest, auth, realtime, storage) |

- **Shell:** single `MainActivity`, Navigation Compose, bottom bar mirroring
  `MainTabView` — Soil, The Field, Gardener, Seeds, Profile, defaulting to The
  Field (index 1) exactly as iOS does.
- **DI:** Hilt. 22 services sharing one client makes manual wiring unwieldy.
- **Images:** Coil, against Supabase Storage URLs (`profile-photos` bucket).
- **Root gating:** the `isLoading → LaunchScreen`, `needsOnboarding → Onboarding`,
  `isAuthenticated → MainTab`, else `Login` branch from `HarvestApp.swift` is
  reproduced as nav-graph start-destination logic, with the same
  `needsOnboarding` predicate (`onboardingCompleted != true && (age == null ||
  gender == null || photos.isEmpty)`).

## Visual parity

`HarvestTheme.swift` is fully tokenized — every color is a hex literal, and
spacing, radius and animation are plain numbers. `HarvestTheme.kt` carries the
identical token names and identical values, including the historical `wine*`
naming (which means "surface, deepest to most lifted" and denotes light tints,
not darks) and the comment explaining why.

Tokens are exposed through a `CompositionLocal`, **not** Material3's
`ColorScheme`, so names survive verbatim instead of being force-fit into
`primary`/`onPrimary`/`surfaceVariant`. Material3 is substrate only; its default
styling is overridden.

Typography in the iOS app resolves to system fonts — no `.ttf`/`.otf` is bundled
and no `UIAppFonts` key is declared, so the `Orange Squash` / `DM Serif Display`
name tokens are currently inert fallbacks. Compose therefore uses
`FontFamily.Serif` and `FontFamily.Default` at the same sizes and weights,
matching what actually ships rather than what the token names aspire to.

The app is light-only on iOS (`.preferredColorScheme(.light)`). Android forces
the light palette identically and does not follow system dark mode.

## Work that is not translation

Two areas need real changes rather than a Swift-to-Kotlin mapping.

### Push notifications are hard-blocked by the schema

`supabase/migrations/20260524120000_push_notifications.sql:6` declares:

```sql
platform text not null default 'ios' check (platform in ('ios'))
```

and the token column is named `apns_token`, with primary key
`(user_id, apns_token)`. Android rows will be **rejected** by that CHECK
constraint. Required:

1. An additive, backward-compatible migration widening the check to
   `('ios','android')`. The `apns_token` column is retained under its existing
   name to avoid breaking the shipped iOS client and `send-push`; it carries the
   FCM registration token for `platform = 'android'` rows.
2. `supabase/functions/send-push/index.ts` gains an FCM branch beside its APNs
   path, dispatching per row on `platform`.

Android-side, `NotificationService` mirrors the iOS one: FCM token retrieval,
upsert into `user_devices` on `(user_id, apns_token)` conflict, de-duplication
against the last token persisted this session, and row deletion on sign-out.
The iOS service caches that token in `UserDefaults`; Android uses DataStore.

### Billing does not cross platforms

StoreKit product IDs `com.harvestglass.harvest.grow.monthly` and
`...gold.monthly` mean nothing to Google Play. Equivalent subscription products
must be created in the Play Console — that is a manual step outside this work.

The client uses Play Billing 7. Tier state stays **server-authoritative**: the
purchase is verified and the resulting tier written to the existing
`subscription_tiers`-backed tables, exactly as `SubscriptionService.swift` does
on transaction update. Because tier is read from the database rather than from
the store, a user who subscribed on iOS sees their correct tier on Android; no
separate cross-platform entitlement mechanism is introduced. Purchasing and
restoring, however, are per-store.

## Phases

- **P0 — Foundation.** Gradle/Compose scaffold, `HarvestTheme.kt`, shared
  components (`GlassCard`, `GlassButton`, `ChipView`, `SectionHeader`, badges),
  nav shell. Builds and runs on the emulator.
- **P1 — Vertical slice.** Supabase client and session persistence, Auth
  (sign in / sign up / sign out / session restore), and **The Field** —
  community room list through to room chat with Realtime — against live data.
  Reviewed side by side with iOS before anything fans out.
- **P2+ — Fan-out**, each independently portable against the proven foundation:
  - Onboarding + Values (Soil)
  - Seeds, Discover, Compatibility, Filters
  - Chat / DM + mindful messaging
  - Gardener, including screenshot review
  - Profile, Settings, Help, Legal, Safety
  - Subscription (Play Billing) + Notifications (FCM) — carries the two
    non-translation items above

## Testing

`HarvestTests/` (Models, Services, Utilities, Views, Mocks) mirrors into the
Android source sets: JUnit + `kotlinx-coroutines-test` + MockK for models,
services and utilities; Compose UI tests for slice screens. Existing Swift test
cases are ported as the Kotlin equivalents rather than rewritten from scratch.

## Toolchain

Verified present on the development machine: Android SDK platform 35,
build-tools 35.0.0/35.0.1/36.0.0, an API 36 Google Play emulator image, and an
existing `Medium_Phone` AVD. JDK 21 is on `PATH`.

`JAVA_HOME` points at `jdk-11.0.2`, below AGP 8.x's minimum of 17. This is
pinned via `org.gradle.java.home` in `gradle.properties` rather than by changing
the machine's global environment.

Unlike the iOS app, which needs the Mac build loop, Android builds and runs
locally on this Windows machine.

## Out of scope

- Any change to `Harvest/` (the iOS app).
- Creating Play Console products or a Play Store listing.
- Cross-store purchase restoration or refund handling beyond what the shared
  tier tables already provide.
- The `admin/` surface.
