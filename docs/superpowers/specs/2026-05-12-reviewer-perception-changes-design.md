# Reviewer-Perception Changes — Design

**Date:** 2026-05-12
**Goal:** Six high-impact changes that shift a reviewer's perception of the app within the first 60 seconds toward values-first dating, AI coaching, reflection, and safety.

## 1.1 Tab Hierarchy

Reorder `MainTabView.swift` to: **Gardener → Discover → Matches → Chat → Profile**.

- Convert `TabView` to a selection-bound form using `@State private var selection: Int`.
- Tag each tab and default `selection` to the Gardener tag, so the app lands on Gardener at launch.
- Exposed via `Binding<Int>` so the differentiation card (1.2) can switch the user to Gardener on dismiss.

## 1.2 Differentiation Screen

A single-screen onboarding card shown the first time a user reaches `MainTabView`.

- New view: `DifferentiationView` with three bullets — **AI Coach**, **Values Matching**, **Red-Flag Detection** — and a "Get Started" button.
- Presented from `MainTabView` via `.fullScreenCover`, gated by `UserDefaults.standard.bool(forKey: "hasSeenDifferentiation")`.
- On dismiss: set `hasSeenDifferentiation = true` and set the active tab to Gardener.

## 1.3 Values Integration

Make the values questionnaire a mandatory onboarding step.

- Add `.values` case to `OnboardingStep` between `.goals` and `.genderIdentity`.
- New view: `ValuesStepView` — two segmented sections ("What I Bring" / "What I Seek"), each backed by `ValuesService.getAllValues()`.
- `OnboardingViewModel` adds `selectedBrought: Set<String>` and `selectedSought: Set<String>`. `canProceed` for `.values` requires `≥1` in each set.
- `completeOnboarding` calls `saveUserValuesBrought` and `saveUserValuesSought` after profile upsert succeeds.

## 1.4 Safety Badge in Chat

Surface the existing `SafetyLevel` enum in `ChatDetailView`.

- Add a small badge (icon + level name) anchored above the messages or in the navigation bar trailing area.
- Show only when `viewModel.safetyAnalysis` is non-nil; uses `SafetyLevel.color`, `.icon`, `.displayName`.
- Read-only — no tap interaction in this pass.

## 1.5 Copy Alignment

Replace generic dating language with values-first / AI coaching framing.

| File | Before | After |
|---|---|---|
| `LoginView.swift` | "Grow meaningful connections" | "Values-first dating, with an AI coach in your corner" |
| `CompleteView.swift` | "Time to start discovering amazing people" | "Meet your AI coach — let's find values-aligned matches" |
| `DiscoverView.swift` (empty state title) | "No more profiles" | "No more values-aligned matches right now" |
| `DiscoverView.swift` (empty state subtitle) | "Check back later for new people" | "Check back soon — we're finding people who share your values" |
| `GardenerChatView.swift` (empty state subtitle) | "I'm your AI dating coach. Ask me anything about dating, relationships, or personal growth!" | "I'm your AI coach. Ask me about values, red flags, communication, or anything on your mind." |

## 1.6 First-Time UX Audit

Composite outcome of 1.1–1.5. No new code: default landing on Gardener, mandatory values, differentiation card, safety badge, and copy together emphasize coaching, reflection, safety, and values up-front.

## Assumptions

- Differentiation card shows once per device; no server-side tracking needed.
- Values step minimum: 1 brought + 1 sought (lower bar than the in-app questionnaire's 5-each, to avoid blocking onboarding).
- Safety badge is read-only.
- No backend/schema changes — existing `values`, `user_values_brought`, `user_values_sought` tables and existing `safety_analysis` are reused.

## Non-Goals

- No new safety analysis logic, model changes, or onboarding step reorders beyond inserting `.values`.
- No A/B testing infrastructure.
- No analytics events for the differentiation card.
