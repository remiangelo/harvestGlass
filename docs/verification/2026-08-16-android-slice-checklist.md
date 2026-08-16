# Android Foundation & Vertical Slice — Verification Checklist

**Branch:** `android-port`
**Plan:** `docs/superpowers/plans/2026-08-16-android-port-foundation.md`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Automated — verified

Run from `android/`:

```bash
./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

Last run on the `Medium_Phone_API_36.0` emulator (API 36):

- [x] **60 unit tests, 0 failures**
  - `HarvestThemeTest` (5) — every ported color token matches the iOS hex
  - `CommunityTest` (9) — snake_case column mapping, curated emoji, optional columns
  - `AuthViewModelTest` (7) — the `needsOnboarding` predicate in all its branches
  - `DeepLinkTest` (9) — deep-link routing, tab order, landing tab
  - `CommunityServiceTest` (3) — empty-list guard clauses
  - `FieldViewModelTest` (4) — load, join, leave, error handling
  - `CommunityChatViewModelTest` (8) — paging order, double-tap send guard, realtime echo
    de-duplication, failed-send text recovery, contact-block message, reaction toggle
  - `MessageGroupingTest` (10) — grouping window, date separators, microsecond timestamps
  - `DateSeparatorTest` (5) — Today / Yesterday / weekday / full-date labels
- [x] **20 instrumented tests, 0 failures**
  - `ComponentsTest` (5), `LoginScreenTest` (5), `FieldScreenTest` (7)
  - `SupabaseManagerTest` (2) — all four plugins installed
  - `SupabaseConnectivityTest` (1) — a real sign-in attempt against the live project is
    rejected by the **server**, proving DNS, TLS, the Ktor Android engine, and the auth
    endpoint all work on-device
- [x] App builds, installs, and launches with **no crash** (`AndroidRuntime:E` is clean)
- [x] Launch reaches the login screen — the session check completes against live Supabase
- [x] Login screen renders at visual parity with `LoginView.swift`: splash gradient, glow
      ring and rose leaf mark, serif "Harvest", tagline, glass form card, dimmed CTA while
      the form is invalid

## Manual — needs your account

I have no credentials for the live project, so everything below is unverified. Sign in on
the emulator (or a device) with a real account and work through it.

### Session and shell

- [ ] Sign in with a real account succeeds
- [ ] Force-quit and reopen — the session restores without a re-login
- [ ] Tab bar shows five tabs in order: Soil / The Field / Gardener / Seeds / Profile
- [ ] The app opens on **The Field**, not Soil
- [ ] Tab bar is the cream `wineBlack` surface with a rose selected item and muted
      `textTertiary` unselected items
- [ ] Sign Out (Profile tab) returns to the login screen

### The Field

- [ ] Lists the same rooms, in the same order, as the iOS app for the same account
- [ ] Member counts match iOS, and read "1 member" / "4 members" correctly
- [ ] Room banner images load; rooms without an image show the leaf placeholder
- [ ] Joining a room switches it to the joined treatment (green border, chevron,
      "Tap to open room")
- [ ] The join survives a re-entry to the tab, and shows as joined on iOS
- [ ] Leaving a room on iOS is reflected here after a reload
- [ ] With no eligible rooms, the empty state reads "No spaces yet"

### Room chat

- [ ] Opening a joined room loads history **oldest-first** and lands on the newest message
- [ ] Your own messages are green gradient bubbles on the right; others' are near-white
      cards on the left with avatar and nickname
- [ ] Consecutive messages from one sender within 5 minutes group (tightened corners)
- [ ] Date separators appear at the top and on each day change
- [ ] Sending shows the message immediately and does **not** duplicate when the realtime
      echo arrives
- [ ] A message sent from the iOS app appears live here without a refresh
- [ ] Double-tapping send inserts exactly one message
- [ ] With the keyboard open, the last message is fully visible above the composer
- [ ] Reactions add and remove, and reflect reaction changes made on iOS
- [ ] A quoted reply renders its original; an original that fell outside the loaded pages
      still resolves

### Side-by-side against iOS

Put the two apps next to each other on the same account and compare:

- [ ] Page background (`deepPlum` cream) and card surfaces (`wineCard`)
- [ ] Room name over the photo scrim stays white and legible
- [ ] Member-count metadata uses the red `accent`, not the green
- [ ] Field chat bubbles are green; nothing in The Field uses rose except metadata

## Known gaps in this phase

These are deliberate and tracked, not defects:

- **Soil, Gardener, Seeds, Profile** are placeholder screens — they port in P2.
- **Onboarding** is a labelled stub. An account whose profile is incomplete is told to
  finish setup on iOS rather than being let through.
- **Mindful messaging** (the pre-send warning in `CommunityChatViewModel.swift`) is not
  ported; `MindfulMessagingService` is P2 scope.
- **@mention autocomplete** logic is ported in the ViewModel but not yet surfaced in the
  composer UI.
- **Liquid Glass** cannot be reproduced on Android. Buttons match in color, geometry,
  padding, and press spring, but not in translucency.
- **Push and billing** are untouched here — they carry the `user_devices` platform CHECK
  migration and the Play Console work described in the spec.
