# Values Tab + Mindful Messages — Design

**Date:** 2026-05-18
**Goal:** Replace the Matches tab with a new Values tab that houses values questionnaires, a values radar graph, an AI-generated blurb, profile-display toggles, and values-based dating tips. Merge active matches and conversations into a renamed Mindful Messages tab. Simplify the Gardener tab to pure AI chat.

## 1. Tab Structure

`MainTabView.swift` — five tabs, in left-to-right order:

| Tag | Label | Icon | View |
|---|---|---|---|
| 0 | Mindful Messages | `bubble.left.fill` | `MindfulMessagesView` (new) |
| 1 | The Gardener | `leaf.fill` | `GardenerChatView` (simplified) |
| 2 | Values | `heart.text.square.fill` | `ValuesView` (new) |
| 3 | Profile | `person.fill` | `ProfileView` (updated) |
| 4 | Swipe | `safari` | `DiscoverView` (label change only) |

- Remove the Matches tab entry.
- Default landing tab remains the Gardener (consistent with the existing reviewer-perception spec). Set `@State private var selection = 1` in `MainTabView`.
- Rename the Discover tab label to **Swipe**; the in-screen title in `DiscoverView` is unchanged.

## 2. Mindful Messages Tab

New view: `MindfulMessagesView.swift` replacing both `MatchesView` and `ChatListView`. Rename `MatchesViewModel` → `MindfulMessagesViewModel`. `MindfulMessagesViewModel` already loads `inboundLikes`, `matchThreads`, and `conversations` — no new view model logic needed.

Top-to-bottom layout, single scrolling screen:

1. **Search bar** — same shape as today's `ChatListView`. Filters only the Messages list (section 4 below).
2. **Likes You** — only shown when `inboundLikes` is non-empty. Same `inboundLikeRow` UI as today's `MatchesView`, including the Gold `PremiumGateView` when ungated.
3. **New Matches** — horizontal `ScrollView` of ~70pt avatar bubbles with name underneath, one per `matchThread` where `thread.conversation == nil`. Tapping opens the chat via the existing `openMatch` flow. Section hidden when empty.
4. **Messages** — vertical list combining `matchThreads` (where a conversation exists) with standalone `conversations`, deduplicated by `conversationId` and sorted by `lastMessageAt` desc. Row uses the existing `ChatListView.chatRow` styling. Pull-to-refresh and `NavigationLink` to `ChatDetailView` are preserved.

Empty state for Messages: today's "No messages yet / Start swiping to find your match" copy.

Navigation title: **Mindful Messages**.

Files touched: new `MindfulMessagesView.swift`; delete `MatchesView.swift` and `ChatListView.swift`; rename `MatchesViewModel.swift` → `MindfulMessagesViewModel.swift`; update `MainTabView.swift`.

## 3. Gardener Tab Simplification

`GardenerChatView.swift`:

- Remove `selectedTab` state, the `gardenerSegmentButton` helper, and the segmented control container.
- Body collapses to the existing `chatView` plus the existing `DailyQuizPopup` sheet.
- Keep navigation title "The Gardener" and the toolbar leaf icon.
- No changes to `GardenerViewModel`.

`TipsView.swift` and `TipsViewModel.swift` are not deleted — they move with the Values tab (section 4).

## 4. Values Tab

New view: `ValuesView.swift` under `Harvest/Views/Values/`. Single `ScrollView` with a `VStack` of sections, top-to-bottom:

1. **Values Graph (hero)** — `ValuesRadarCard` (section 5). Empty-state placeholder card when the user has zero selections in both sets: copy "Take the questionnaire to see your values map" and a button that pushes `ValuesQuestionnaireView`.
2. **Your Blurb** — saved blurb if present, else placeholder copy. "Generate" / "Regenerate" button (section 6).
3. **What I Bring** — chip row of selected values + an `Edit` button that pushes `ValuesQuestionnaireView(authViewModel:, initialTab: 0)`.
4. **What I Seek** — same shape, pushes `initialTab: 1`.
5. **Show on Profile** — four `Toggle`s (section 7): Values I Bring, Values I Seek, Generated Blurb, Values Graph.
6. **Values-Based Dating Tips** — the content of today's `TipsView` (category chips + tip cards + Quick Advice FAQ), embedded inline. Section header retitled. Tip copy edited (section 4.1).

Navigation title: **Values**. Toolbar leading icon: `heart.fill` in `HarvestTheme.Colors.accent`.

New `ValuesViewModel` (lightweight, `@State`-owned) holds:
- `allValues: [Value]`, `valuesBrought: [Value]`, `valuesSought: [Value]`
- `profile: UserProfile?` (for blurb + display toggles)
- `isGeneratingBlurb: Bool`, `blurbError: String?`
- `displayPrefs` are read directly from `profile`; mutations go through `ProfileService.updateProfile`.

It owns calls to `ValuesService`, `BlurbService`, and `ProfileService`. `TipsViewModel` stays separate and is instantiated inside the Tips subsection unchanged.

### 4.1 Tip copy curation

Edit `TipsViewModel.swift` in place. Two passes:

- Existing tips: rewrite each tip's `body` (and `title` where natural) to lead with values language. Example: a "Red Flags" tip should call out value misalignment, not just generic warning signs.
- FAQs: rewrite questions and answers similarly.

No structural changes — same `TipCategory` enum, same number of tips. Concrete tip text is left to the implementation plan; this spec only declares the rewrite is in scope.

## 5. Values Radar Chart

New component: `Harvest/Views/Components/ValuesRadarCard.swift`.

- Six axes for the six categories returned by `ValuesService`: `communication`, `relationship`, `lifestyle`, `personal growth`, `social`, `core beliefs`. Sort alphabetically for stable axis order.
- Each axis is scaled 0–5 (the questionnaire caps each set at 5 picks).
- Two overlaid polygons:
  - **Bring** — fill `HarvestTheme.Colors.primary` at ~30% opacity, stroke at full opacity.
  - **Seek** — fill `HarvestTheme.Colors.accent` at ~30% opacity, stroke at full opacity.
- Legend below the chart: two color dots labeled "I Bring" and "I Seek".
- Rendered with SwiftUI `Canvas` (Swift Charts has no first-class radar; Canvas keeps this to one focused view).
- Card chrome matches `GlassCard`.
- Inputs: two `[Value]` arrays. No async work inside the component.
- Pure SwiftUI; no new package dependencies.

If `ValuesService` returns more than six categories at runtime, the component derives axes dynamically from the union of categories present in the two input arrays, alphabetized.

## 6. Generated Blurb

### 6.1 Service

New file: `Harvest/Services/BlurbService.swift`. One method:

```swift
func generateBlurb(brought: [Value], sought: [Value]) async throws -> String
```

- Calls `OpenAIService` with a single template prompt that takes the two value lists and returns a 2–3 sentence first-person blurb, no preamble.
- Output is trimmed and length-capped at 280 characters before return.
- Errors bubble up; the view shows a non-blocking inline error.

Prompt template lives as a private constant in `BlurbService.swift`. No new prompt-engineering infrastructure.

### 6.2 Storage

Add `values_blurb text` (nullable) to the `users` table. Update `UserProfile.swift` with `var valuesBlurb: String?` and matching `CodingKeys` (`valuesBlurb = "values_blurb"`). Add the field to `ProfileService` select projection and upsert payloads.

The project has no existing `supabase/migrations/` directory (only Edge Functions live under `supabase/`); the plan creates the directory and adds the file using the Supabase CLI naming convention (`YYYYMMDDHHMMSS_description.sql`). The SQL must also be applied via the Supabase dashboard or CLI — committing the file does not run it.

### 6.3 UI

Blurb card inside `ValuesView`:
- Show `viewModel.profile?.valuesBlurb` if non-empty; otherwise placeholder copy "Generate a blurb that describes the values you bring and seek."
- Button label: "Generate" when blurb is empty, "Regenerate" otherwise.
- Tap → inline `ProgressView`, button hidden during the call. On success, persist via `ProfileService.updateProfile` and update `viewModel.profile`.
- Disabled with helper text "Pick some values first" when both `brought` and `sought` are empty.

## 7. Profile Display Toggles

### 7.1 Storage

Add four boolean columns to `users`, all default `true`:

| Column | Controls |
|---|---|
| `show_values_brought` | "Values I Bring" chip row on profile |
| `show_values_sought` | "Values I Seek" chip row on profile |
| `show_values_blurb` | Generated blurb on profile |
| `show_values_graph` | `ValuesRadarCard` on profile |

Update `UserProfile.swift` with four `Bool?` fields. Read sites use `?? true` so older rows behave as "all toggles on." Update `ProfileService` select and upsert.

### 7.2 UI

"Show on Profile" card inside `ValuesView` is a `VStack` of four `Toggle`s. Each toggle's `onChange` writes a single field via `ProfileService.updateProfile`. Optimistic local update; on failure, revert local state and show an inline error message under the toggle row.

## 8. Profile View Updates

`ProfileView.swift`:

- Insert a **Generated Blurb** display below the info card and above "Values I Bring": gated on `profile.showValuesBlurb ?? true`, requires non-empty `valuesBlurb`. Same `GlassCard` styling as siblings.
- Gate the existing "Values I Bring" section on `profile.showValuesBrought ?? true`.
- Gate the existing "Values I Seek" section on `profile.showValuesSought ?? true`.
- Add a **Values Graph card** (`ValuesRadarCard`) below the values-sought section, gated on `profile.showValuesGraph ?? true` and requiring at least one value in either set.

`ProfileDetailView.swift` (viewing other users' profiles) gets the same four gated sections so the toggles affect outbound and inbound views consistently. Default `?? true` keeps existing users showing today's content.

`ProfileViewModel` already loads `valuesBrought` and `valuesSought`; no changes there.

## 9. Data & Migration

Single SQL migration under `supabase/migrations/` (directory does not yet exist; the plan creates it):

```sql
alter table users
  add column values_blurb text,
  add column show_values_brought boolean default true,
  add column show_values_sought boolean default true,
  add column show_values_blurb boolean default true,
  add column show_values_graph boolean default true;
```

`UserProfile.swift` additions:

```swift
var valuesBlurb: String?
var showValuesBrought: Bool?
var showValuesSought: Bool?
var showValuesBlurb: Bool?
var showValuesGraph: Bool?
```

with `CodingKeys`: `values_blurb`, `show_values_brought`, `show_values_sought`, `show_values_blurb`, `show_values_graph`.

`ProfileService` — add the five fields to select projection and upsert payloads. No new endpoints.

No data migration beyond schema; existing users keep their `valuesBrought` / `valuesSought` selections untouched.

## 10. Assumptions

- Matches tab is removed outright; no in-app redirect or "Matches has moved" toast — the merged Mindful Messages inbox makes the destination obvious.
- "New Matches" carousel scrolls horizontally; no "See all" link in this pass.
- Blurb generation is allowed for free tier; if rate-limiting is desired it can be added via the existing `RateLimitService` in a follow-up.
- Tip copy edits are content-only — no new categories, no new FAQ entries.
- Radar axes are derived from category names present in the data, sorted alphabetically. Six categories today; the component must still render correctly if `ValuesService` adds or removes categories.
- The reviewer-perception `DifferentiationView` copy referencing "Matches" is updated to "Mindful Messages" wherever it appears; no other UX is added.

## 11. Non-Goals

- No analytics / experiments around the change.
- No deep-linking between Gardener and Values (e.g. "ask the Gardener about your values") in this pass.
- No share-the-graph-as-image feature.
- No per-value display toggles, no multi-blurb selection, no separate Likert questionnaire.
- No changes to compatibility scoring (`ValuesService.calculateCompatibility`) or the swipe deck.
- No reordering of onboarding steps.

## 12. Testing Notes

- Unit test `BlurbService.generateBlurb` with a mocked `OpenAIService` round-trip (success + thrown-error paths).
- Snapshot or visual smoke test `ValuesRadarCard` at: empty, one-side-only, full-on-both-sides, and asymmetric data.
- Manually verify `MindfulMessagesView` with: no likes / no matches / matches-without-conversation only / conversations only / all three together.
- Verify `ProfileView` and `ProfileDetailView` honor all four toggles independently for self and for other-user contexts.
