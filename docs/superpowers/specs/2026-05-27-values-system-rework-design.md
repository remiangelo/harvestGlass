# Values System Rework — Two-Tier Values, Compat Screen, Rebalanced Questionnaire — Design

**Date:** 2026-05-27
**Goal:** Split the values system into two complementary layers:

1. **Inferred 5-axis radar** (Emotional Intelligence / Stability / Integrity / Connection / Growth) derived from a rebalanced questionnaire — produces separate Need and Bring vectors.
2. **User-selected Top 3 Bring + Top 3 Need** chosen from a flat list of 20 specific values, decoupled from the 5 axes.

Add a new Compatibility screen that overlays the radars and reports value-pick overlap. Reorder the profile so a user's Bring chips appear publicly under name/age while Need is hidden from public view. Rewrite all 10 onboarding questions, add 25 deep-dive questions, and change scoring weights to pure 2/0 (or 1/1 for BOTH).

## 1. Overview of deltas vs. what ships today

| Area | Today | After this rework |
|---|---|---|
| Question count | 10 onboarding | 10 onboarding + 25 deep-dive (35 total) |
| Options per question | 5 | 4 |
| Weighting balance (onboarding) | 6 NEED / 1 BRING / 3 BOTH | 5 NEED / 5 BRING / 0 BOTH |
| Per-side weight | NEED Q → (1.0 need, 0.5 bring) | NEED Q → (2.0 need, 0 bring) |
| BOTH weight | (0.75, 0.75) | (1.0, 1.0) |
| Specific values | 6 categories × ~50 values, ≤5 picks per side | Flat 20 values, exactly Top 3 per side |
| Values↔axes mapping | Values nested under categories shown on radar | 20 values fully decoupled from 5 axes |
| Profile display | Bring + Need chips both gated by toggles | Bring chips public under name/age; Need hidden publicly |
| Compatibility view | None — score computed silently during ranking | New full-screen view with dual radar overlap + value-pick overlap + blurb |
| Existing user data | — | Clear `user_question_answers` and `user_values`; show retake banner |

## 2. Data model changes

### 2.1 Migration `20260527120000_values_system_rework.sql`

```sql
-- ============================================================
-- 1. Reseed values table to flat 20-value list
-- ============================================================
truncate table user_values;
delete from values;

insert into values (id, label, category) values
  ('val_empathetic',         'Empathetic',           null),
  ('val_compassionate',      'Compassionate',        null),
  ('val_active_listener',    'Active Listener',      null),
  ('val_supportive',         'Supportive',           null),
  ('val_reliable',           'Reliable',             null),
  ('val_consistent',         'Consistent',           null),
  ('val_grounded',           'Grounded',             null),
  ('val_responsible',        'Responsible',          null),
  ('val_honest_transparent', 'Honest & Transparent', null),
  ('val_accountable',        'Accountable',          null),
  ('val_respectful',         'Respectful',           null),
  ('val_loyal',              'Loyal',                null),
  ('val_affectionate',       'Affectionate',         null),
  ('val_passionate',         'Passionate',           null),
  ('val_quality_time',       'Quality Time',         null),
  ('val_playful',            'Playful',              null),
  ('val_ambitious',          'Ambitious',            null),
  ('val_optimistic',         'Optimistic',           null),
  ('val_independent',        'Independent',          null),
  ('val_intentional',        'Intentional',          null);

-- ============================================================
-- 2. Reseed questions: rewrite Q1-Q10, add Q11-Q35
-- ============================================================
truncate table user_question_answers;
delete from question_options;
delete from questions;

-- (insert all 35 questions and 140 options — see §6 for full content)

-- ============================================================
-- 3. Add cap-3 constraint on user_values picks
-- ============================================================
-- Existing schema: user_values(user_id, value_id, side) with side in ('need','bring').
-- Enforce at app layer (DiscoverViewModel/ValuesViewModel) — no DB constraint needed
-- because the 3-cap is a UX rule, not a data integrity rule (we may relax it later).
```

The `values.category` column stays in the schema but is `null` for all rows. Keeping the column avoids a destructive schema change; nullable category means the picker no longer renders a category-segmented control.

### 2.2 Swift model changes

**`Harvest/Models/Question.swift`** — `AxisScoring` namespace constants:

```swift
enum AxisScoring {
    static let weightPrimary: Double = 2.0    // was 1.0
    static let weightSecondary: Double = 0.0  // was 0.5
    static let weightBoth: Double = 1.0       // was 0.75 — equal on both sides for BOTH-weighted Qs
}
```

Update `AxisScores.add(option:weighting:)` to apply these new constants.

**`Harvest/Models/UserProfile.swift`** — no schema changes needed for the profile reorder; existing fields `valuesBrought`/`valuesSought` remain. The `showValuesSought` toggle becomes dead (defaulted off, hidden from Settings).

## 3. Scoring math

For each answered question with chosen option mapping to axis `a`:

| Question weighting | Need vector gets | Bring vector gets |
|---|---|---|
| `need` | +2.0 at axis `a` | +0 |
| `bring` | +0 | +2.0 at axis `a` |
| `both` | +1.0 at axis `a` | +1.0 at axis `a` |

After summing across all answered questions, each vector is normalized so its 5 axis values sum to 1.0 (existing `AxisScores.normalized()` unchanged). The normalized vectors feed:

- **Radar rendering** in `ValuesRadarCard` (existing code reused — accepts `AxisScores` directly)
- **Cosine similarity** in `CompatibilityService` for the global match score (existing code reused)
- **New compatibility view's dual-polygon overlap** (see §5.4)

With the new balance (10 onboarding = 5 NEED + 5 BRING, ~12 NEED + 12 BRING + 1 BOTH in deep-dive), users who answer only onboarding get equal weight on both vectors. Users who go through all 35 get richer, more differentiated vectors.

## 4. Values picker rewrite

### 4.1 ValuesView — visible state

**Today:** segmented control [Main | Tips] outer, [Need | Bring] inner, then a values picker rendered as a 6-category × ~50-value list with category headers.

**After:** segmented control [Main | Tips] outer. On Main: top-of-tab retake banner (if `answeredCount < 10`), the radar for the active side, segmented [Need | Bring] toggle, and a flat 20-chip grid below the toggle.

### 4.2 Chip grid

`Harvest/Views/Components/ValueChipGrid.swift` (new) — a `LazyVGrid` of 2-3 columns with one `Chip` per value. Each chip:

- Tap to toggle selected state on the active side
- If selected, fill = primary accent; if not, fill = glass surface
- If the user already has 3 selected and they tap an unselected chip, the chip gives a haptic tap and a brief shake animation (no state change). Toast: "You can pick 3 — tap one to swap."

### 4.3 Retake banner

`ValuesView` top-section: shown if `viewModel.answeredQuestionCount < 10`. Copy:

> **Your values questionnaire has been updated**
> Answer 10 quick questions so we can find new matches for you.
> [Get started →]

Tap → opens a sheet containing the existing `ReflectionsStepView` flow, but configured to drive through all 10 onboarding questions (Q1–Q10) then dismiss. On dismiss, refresh the radar.

### 4.4 "More questions" button

Below the chip grid. Label: "More questions (`{35 - answeredCount}` left)" while ≤25 remain unanswered; "All caught up ✓" when answered ≥ 35.

Tap → opens `QuestionSheetView` (existing) listing all unanswered Q11–Q35 as cards. User can answer any subset, any order. Each answer hot-refreshes the radar.

## 5. Compatibility screen

### 5.1 Entry point

`ProfileDetailView` (the screen reached by tapping a chat partner's header or a Discover card): add a new full-width button below the bio section, above the existing photo grid:

```swift
GlassButton(title: "See Compatibility", icon: "chart.dots.scatter", style: .secondary) {
    showCompatibility = true
}
```

`.sheet(isPresented: $showCompatibility)` presents `CompatibilityView(currentProfile:, otherProfile:)`.

### 5.2 CompatibilityView layout

```
┌─────────────────────────────────────────────┐
│  ← Compatibility with Christy               │
├─────────────────────────────────────────────┤
│                                             │
│       [Bring radar — dual polygon]          │
│                                             │
│   You bring     ┊     Christy brings        │
│  (chip row)     ┊      (chip row)           │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│       [Need radar — dual polygon]           │
│                                             │
│   You need      ┊     Christy needs         │
│  (chip row)     ┊      (chip row)           │
│                                             │
├─────────────────────────────────────────────┤
│  Value overlap                              │
│  • Christy brings 2 of your 3 needs:        │
│    [Honest & Transparent] [Consistent]      │
│  • You bring 1 of Christy's 3 needs:        │
│    [Playful]                                │
│                                             │
├─────────────────────────────────────────────┤
│  "You and Christy share a strong            │
│   foundation around Stability and Integrity│
│   — and what you bring lines up with two    │
│   of her three needs."                      │
│                                             │
└─────────────────────────────────────────────┘
```

Each radar uses the existing `ValuesRadarCard` with a new `secondary: AxisScores?` argument. Two semi-transparent polygons overlay; primary in accent color, secondary in `HarvestTheme.Colors.secondary` accent.

### 5.3 CompatibilityService additions

```swift
extension CompatibilityService {
    struct ValueOverlap {
        let theyBringForMyNeeds: [Value]   // intersection of their bring picks ∩ my need picks
        let iBringForTheirNeeds: [Value]   // intersection of my bring picks ∩ their need picks
    }

    func valueOverlap(
        myNeeds: [String], myBrings: [String],
        theirNeeds: [String], theirBrings: [String],
        allValues: [Value]
    ) -> ValueOverlap

    func compatibilityBlurb(
        bringCosine: Double,
        needCosine: Double,
        topSharedAxis: ValueAxis?,
        valueOverlap: ValueOverlap
    ) -> String
}
```

**Blurb template** (no LLM):

- Pick top-shared axis = axis where `min(myBringVector[i], theirNeedVector[i])` is highest
- Compute share = "{X} of your {N} needs" and reciprocal
- Template: `"You and {name} share a strong foundation around {topAxis} — and what they bring lines up with {X} of your {N} needs."`
- Fall back to generic line if no value-pick overlap and cosine < 0.5

### 5.4 Dual-polygon radar

`ValuesRadarCard` already accepts `secondary: AxisScores?`. No changes needed beyond verifying both polygons render with distinguishable fills.

## 6. Question content

### 6.1 Onboarding (Q1–Q10)

All 10 questions and their 4 options are replaced verbatim with the rewritten set provided in the source spec. Each question targets one of the 5 axes with `weighting in ('need','bring','both')` and each option maps to a single axis. Per-question construct-omission is documented inline.

**Balance:** 5 questions weighted 100% NEED, 5 weighted 100% BRING, 0 BOTH. Each construct (axis) appears in 8 of 40 onboarding options and is omitted exactly twice across the 10 questions. Full text:

<details>
<summary>Full Q1–Q10 text (click to expand)</summary>

**Q1 (NEED, omits Growth)** — After a hard day, what would help you feel most cared for?
- A. They really listen before responding. → Emotional Intelligence
- B. They stay calm and steady with me. → Stability
- C. They are honest, respectful, and present with what I'm feeling. → Integrity
- D. They pull me close and make time for me. → Connection

**Q2 (NEED, omits Connection)** — Someone disappoints you. What helps repair the moment most?
- A. They understand why it hurt. → Emotional Intelligence
- B. They show up more consistently afterward. → Stability
- C. They own their part clearly. → Integrity
- D. They reflect on what happened and try to grow from it. → Growth

**Q3 (BRING, omits Integrity)** — Someone you care about is stressed. What feels most natural for you to offer?
- A. I help them feel understood. → Emotional Intelligence
- B. I help steady the situation. → Stability
- C. I offer warmth, affection, or closeness. → Connection
- D. I encourage their next step forward. → Growth

**Q4 (BRING, omits Stability)** — When conflict happens, what do you naturally try to bring into the moment?
- A. I try to understand what the other person is really feeling. → Emotional Intelligence
- B. I try to own my part honestly. → Integrity
- C. I try to protect the bond and come back toward closeness. → Connection
- D. I try to learn from it and find a better way forward. → Growth

**Q5 (NEED, omits Emotional Intelligence)** — You are starting to trust someone. What makes that trust grow most for you?
- A. Their energy stays steady over time. → Stability
- B. Their actions match their words. → Integrity
- C. You feel wanted and close. → Connection
- D. You can see shared direction and growth. → Growth

**Q6 (BRING, omits Growth)** — When you picture what you bring to long-term love, what feels most true?
- A. I bring emotional care and understanding. → Emotional Intelligence
- B. I bring steadiness and dependability. → Stability
- C. I bring honesty, loyalty, and respect. → Integrity
- D. I bring warmth, affection, and connection. → Connection

**Q7 (NEED, omits Connection)** — You are nervous before something important. What kind of support would help most?
- A. They notice how I'm feeling and comfort me. → Emotional Intelligence
- B. They help me feel grounded and steady. → Stability
- C. They help me face the situation honestly. → Integrity
- D. They remind me what I'm capable of. → Growth

**Q8 (BRING, omits Integrity)** — When you realize you may have hurt or disappointed someone, what do you most want to do?
- A. I want to understand how it affected them. → Emotional Intelligence
- B. I want to show up better and be more consistent. → Stability
- C. I want to reconnect and help them feel cared for. → Connection
- D. I want to reflect, adjust, and grow from it. → Growth

**Q9 (NEED, omits Stability)** — What makes you feel respected in a relationship?
- A. They consider my feelings. → Emotional Intelligence
- B. They honor my boundaries. → Integrity
- C. They make space for me in their life. → Connection
- D. They take my goals seriously. → Growth

**Q10 (BRING, omits Emotional Intelligence)** — During a quiet evening together, what do you most naturally hope to bring?
- A. A peaceful, steady presence. → Stability
- B. A space where honesty feels safe. → Integrity
- C. Warmth, closeness, or playfulness. → Connection
- D. Meaningful conversation about dreams, purpose, or direction. → Growth

</details>

### 6.2 Deep-dive (Q11–Q35)

25 questions: 12 NEED, 12 BRING, 1 BOTH. Each construct (axis) appears in 20 of 100 options and is omitted exactly 5 times across the 25 questions. Full text:

<details>
<summary>Full Q11–Q35 text (click to expand)</summary>

**Q11 (BRING, omits Growth)** — Someone shares something vulnerable with you. What do you naturally try to offer?
- A. I try to understand what they are feeling. → Emotional Intelligence
- B. I stay steady and present with them. → Stability
- C. I treat their honesty with respect. → Integrity
- D. I move closer emotionally so they do not feel alone. → Connection

**Q12 (NEED, omits Connection)** — Plans change at the last minute. What matters most to you?
- A. They care how the change affects me. → Emotional Intelligence
- B. They communicate early and follow through later. → Stability
- C. They handle the change with respect. → Integrity
- D. They try to handle it better next time. → Growth

**Q13 (NEED, omits Growth)** — You feel misunderstood. What helps most?
- A. They ask questions before assuming. → Emotional Intelligence
- B. They keep the conversation calm. → Stability
- C. They speak plainly and fairly. → Integrity
- D. They reassure me through closeness. → Connection

**Q14 (BRING, omits Connection)** — When you make a mistake, what do you naturally try to do afterward?
- A. I try to understand the impact. → Emotional Intelligence
- B. I try to show steadier behavior over time. → Stability
- C. I own my part clearly. → Integrity
- D. I reflect on what I can learn from it. → Growth

**Q15 (NEED, omits Emotional Intelligence)** — When you imagine building a life with someone, what do you most need to feel secure?
- A. They are dependable in daily life. → Stability
- B. They live by strong character. → Integrity
- C. They keep closeness active. → Connection
- D. They move toward purpose with me. → Growth

**Q16 (BRING, omits Stability)** — Someone you love is nervous before something important. What feels most natural for you to offer?
- A. I notice what they are feeling and try to comfort them. → Emotional Intelligence
- B. I help them face the moment honestly. → Integrity
- C. I stay close and present. → Connection
- D. I remind them what they are capable of. → Growth

**Q17 (NEED, omits Connection)** — What makes you feel respected?
- A. They consider my feelings. → Emotional Intelligence
- B. They treat my time with care. → Stability
- C. They honor my boundaries. → Integrity
- D. They take my goals seriously. → Growth

**Q18 (BRING, omits Growth)** — When life gets stressful, what do you hope someone can count on you for?
- A. I try to be emotionally aware and caring. → Emotional Intelligence
- B. I try to stay steady under pressure. → Stability
- C. I try to act with character even when it is hard. → Integrity
- D. I try to keep warmth alive between us. → Connection

**Q19 (NEED, omits Integrity)** — You are excited about a personal goal. What response would mean the most?
- A. They understand why it matters to me. → Emotional Intelligence
- B. They help me stay grounded. → Stability
- C. They celebrate with me. → Connection
- D. They encourage me toward my potential. → Growth

**Q20 (BRING, omits Stability)** — When attraction starts feeling more serious, what do you most want to bring into the connection?
- A. I want to be emotionally present and aware. → Emotional Intelligence
- B. I want my actions to reflect my character. → Integrity
- C. I want the spark to feel mutual and alive. → Connection
- D. I want to build toward something meaningful. → Growth

**Q21 (NEED, omits Growth)** — A conversation gets tense. What do you need most from the other person?
- A. They listen beneath the words. → Emotional Intelligence
- B. They keep the tone steady. → Stability
- C. They stay fair and truthful. → Integrity
- D. They reach for closeness after. → Connection

**Q22 (BRING, omits Integrity)** — What do you most naturally do to help someone feel chosen?
- A. I remember what matters to them. → Emotional Intelligence
- B. I try to show up consistently over time. → Stability
- C. I make real time for them. → Connection
- D. I build toward the future with them. → Growth

**Q23 (NEED, omits Stability)** — You share a concern. What response builds the most confidence?
- A. They receive it with care. → Emotional Intelligence
- B. They answer honestly. → Integrity
- C. They soften toward me. → Connection
- D. They look for a better way forward. → Growth

**Q24 (BRING, omits Emotional Intelligence)** — What do you most want to be dependable for in a relationship?
- A. Doing what I said I would do. → Stability
- B. Handling responsibility with character. → Integrity
- C. Continuing to invest in closeness. → Connection
- D. Learning how to show up better over time. → Growth

**Q25 (NEED, omits Growth)** — You are spending a quiet evening together. What feels most meaningful to you?
- A. The conversation feels emotionally real. → Emotional Intelligence
- B. The peace feels easy and steady. → Stability
- C. I feel safe being truthful. → Integrity
- D. The closeness feels warm and natural. → Connection

**Q26 (BRING, omits Connection)** — When you are under pressure, what do you hope your character shows?
- A. I still care about people's feelings. → Emotional Intelligence
- B. I can remain steady. → Stability
- C. My values hold even when it is hard. → Integrity
- D. I can respond, reflect, and grow. → Growth

**Q27 (NEED, omits Stability)** — What kind of apology means the most to you?
- A. One that shows they understand my heart. → Emotional Intelligence
- B. One that takes full ownership. → Integrity
- C. One that brings us close again. → Connection
- D. One that leads to new growth. → Growth

**Q28 (BRING, omits Stability)** — What do you most want to offer so someone feels free to be themselves?
- A. I try to understand their emotions. → Emotional Intelligence
- B. I treat their truth with respect. → Integrity
- C. I enjoy their personality. → Connection
- D. I give them room to become more fully themselves. → Growth

**Q29 (NEED, omits Emotional Intelligence)** — What makes love feel alive to you?
- A. Feeling safe in the rhythm. → Stability
- B. Feeling secure in trust. → Integrity
- C. Feeling wanted, playful, and close. → Connection
- D. Feeling inspired together. → Growth

**Q30 (BRING, omits Stability)** — When you disagree about something important, what do you naturally try to bring?
- A. I try to care about their perspective. → Emotional Intelligence
- B. I try to handle the disagreement with respect. → Integrity
- C. I try to protect the bond while talking. → Connection
- D. I try to search for a wiser path forward. → Growth

**Q31 (NEED, omits Growth)** — What makes someone feel like a safe long-term choice?
- A. Their emotional care feels real. → Emotional Intelligence
- B. Their patterns are dependable. → Stability
- C. Their character is clear. → Integrity
- D. Their love feels warm and active. → Connection

**Q32 (BOTH, omits Emotional Intelligence)** — Shared spiritual or philosophical values feel meaningful when they shape what?
- A. The way we make life decisions. → Stability
- B. The way we treat people. → Integrity
- C. The depth of closeness between us. → Connection
- D. The meaning we build together. → Growth

**Q33 (BRING, omits Stability)** — What makes you feel supportive in a relationship?
- A. I can sense what someone may need emotionally. → Emotional Intelligence
- B. I protect their dignity. → Integrity
- C. I make them feel loved in real time. → Connection
- D. I believe in where they are going. → Growth

**Q34 (BRING, omits Connection)** — What do you hope someone notices about what you bring?
- A. How deeply I care. → Emotional Intelligence
- B. How steady I try to be. → Stability
- C. How seriously I take trust. → Integrity
- D. How much I am growing. → Growth

**Q35 (NEED, omits Integrity)** — When you imagine healthy love, what feels most like home?
- A. Being understood with care. → Emotional Intelligence
- B. Feeling steady and safe. → Stability
- C. Feeling close, wanted, and joyful. → Connection
- D. Growing into something meaningful together. → Growth

</details>

## 7. Profile reorder

### 7.1 ProfileView (current user's own profile)

Move the Bring chips to a new section directly under the name/age block (above the bio). Need chips removed from the public view entirely — they still exist in the data model and remain editable via the Values tab.

### 7.2 ProfileDetailView (another user's profile)

Same reorder: Bring chips under name/age. Need is not shown anywhere on this screen. The new "See Compatibility" button is the only path to view need overlap.

### 7.3 Settings cleanup

Hide the `showValuesSought` toggle from `SettingsView` (the row is removed from the form; the underlying field stays in the schema for future use). The `showValuesBrought` toggle remains.

## 8. Migration & rollout

### 8.1 Data clear

The migration runs `truncate table user_question_answers; truncate table user_values;`. Every existing user starts fresh.

### 8.2 Retake banner

`ValuesView` shows the retake banner when `viewModel.answeredQuestionCount < 10`. Banner persists until 10 questions answered. New users hit onboarding which captures these 10 inline; existing users see the banner.

### 8.3 No backward-compatibility shims

Old value IDs (e.g., `val_communication_empathy`) are gone. Any cached profile data in Swift in-memory state will be replaced on next refresh. No Swift code paths reference removed IDs by name (all references are dynamic).

## 9. Task breakdown

Each task = one commit. Trunk-based on `main`. Each task is independently buildable.

1. **Migration + seed** — `supabase/migrations/20260527120000_values_system_rework.sql` with all 35 questions + 140 options + 20 values.
2. **Question fallback in `QuestionsService.swift`** — update the in-Swift fallback list to match the new seed (35 questions, 4 options each, new weightings).
3. **Scoring math** — update `AxisScoring.weight*` constants in `Question.swift` to 2.0/0.0/1.0.
4. **Values picker rewrite** — replace 6-category list with flat 20-chip grid; enforce Top-3 cap; retake banner; "More questions" counter update.
5. **`ValueChipGrid.swift`** — new component.
6. **ProfileView + ProfileDetailView reorder** — Bring chips under name/age, remove Need chips from both views.
7. **CompatibilityService additions** — `ValueOverlap` struct, `valueOverlap()`, `compatibilityBlurb()`.
8. **`CompatibilityView.swift`** — new screen; "See Compatibility" button on `ProfileDetailView`.
9. **SettingsView cleanup** — hide `showValuesSought` toggle.
10. **Smoke test** — verify build, run `swift build` analog (Xcode build via project run), exercise paths in simulator if available.

## 10. Out of scope

- Personalization of blurbs via LLM (template-driven only — could swap to Gardener in a future iteration)
- Re-running the questionnaire to refresh stale answers (no expiration; retake is user-initiated via the banner or by navigating into the deep-dive)
- Adding/removing values from the 20-value list at runtime (admin tooling out of scope)
- Ordered Top-3 (deferred per design decision; could add `priority int` to `user_values` later without migration loss)
