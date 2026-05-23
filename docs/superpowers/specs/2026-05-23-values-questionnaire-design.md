# Values Questionnaire & 5-Axis Radar — Design

**Date:** 2026-05-23
**Goal:** Replace the values-category-driven radar with a fixed 5-axis radar (Emotional Intelligence, Stability, Integrity, Connection, Growth) driven by a questionnaire. Add 10 questions to onboarding, surface the rest behind a button in the Values tab. Restructure the Values tab into Tips and Main sub-sections, with Main offering a Need-side and Bring-side view each showing the corresponding radar above an inline values picker. Replace name-intersection matching with cosine similarity between Need and Bring axis vectors.

## 1. Data Model

### 1.1 New tables

```sql
create table questions (
  id text primary key,                  -- e.g. "q1"
  prompt text not null,
  weighting text not null check (weighting in ('need','bring','both')),
  display_order int not null,
  created_at timestamptz default now()
);

create table question_options (
  id text primary key,                  -- e.g. "q1_a"
  question_id text not null references questions(id) on delete cascade,
  label text not null,
  axis text not null check (axis in
    ('emotional_intelligence','stability','integrity','connection','growth')),
  display_order int not null
);

create table user_question_answers (
  user_id uuid not null references users(id) on delete cascade,
  question_id text not null references questions(id) on delete cascade,
  option_id text not null references question_options(id),
  answered_at timestamptz default now(),
  primary key (user_id, question_id)
);
```

`user_question_answers` PK is `(user_id, question_id)` so re-answering replaces the previous answer via upsert.

### 1.2 `users` table addition

```sql
alter table users
  add column profile_graph_side text default 'bring'
    check (profile_graph_side in ('need','bring'));
```

The existing `show_values_graph` boolean is reused as the on/off gate; `profile_graph_side` picks which polygon shows when the gate is open.

### 1.3 RLS

```sql
alter table user_question_answers enable row level security;

create policy "answers_self_read" on user_question_answers
  for select using (auth.uid() = user_id);
create policy "answers_self_write" on user_question_answers
  for insert with check (auth.uid() = user_id);
create policy "answers_self_update" on user_question_answers
  for update using (auth.uid() = user_id);
```

`questions` and `question_options` are world-readable (no RLS or `for select using (true)` policy), matching the existing `values` table pattern.

### 1.4 Swift models — `Harvest/Models/Question.swift`

```swift
enum ValueAxis: String, Codable, CaseIterable, Sendable {
    case emotionalIntelligence = "emotional_intelligence"
    case stability
    case integrity
    case connection
    case growth

    var displayName: String { /* "Emotional Intelligence", etc. */ }
}

enum QuestionWeighting: String, Codable, Sendable {
    case need, bring, both
}

struct Question: Codable, Identifiable, Sendable {
    let id: String
    let prompt: String
    let weighting: QuestionWeighting
    let displayOrder: Int
    var options: [QuestionOption]  // populated by service join
}

struct QuestionOption: Codable, Identifiable, Sendable {
    let id: String
    let questionId: String
    let label: String
    let axis: ValueAxis
    let displayOrder: Int
}

struct UserQuestionAnswer: Codable, Sendable {
    let userId: String
    let questionId: String
    let optionId: String
}

struct AxisScores: Equatable, Sendable {
    var emotionalIntelligence: Double = 0
    var stability: Double = 0
    var integrity: Double = 0
    var connection: Double = 0
    var growth: Double = 0

    var sum: Double { emotionalIntelligence + stability + integrity + connection + growth }
    var isZero: Bool { sum == 0 }

    func normalized() -> AxisScores { /* divides each by sum if > 0 */ }
    func value(for axis: ValueAxis) -> Double { /* switch */ }
}
```

`UserProfile.swift` gains `var profileGraphSide: String?` with `CodingKeys` entry `profileGraphSide = "profile_graph_side"`. Reads default to `'bring'` when nil.

## 2. Scoring & Matching

### 2.1 Weight matrix

Per answered question, the option's axis receives weight on each side:

| Question weighting | NEED side | BRING side |
|---|---|---|
| `need` | 1.0 | 0.5 |
| `bring` | 0.5 | 1.0 |
| `both` | 1.0 | 1.0 |

### 2.2 Vectors

For each side (need, bring):
1. For each axis, sum the weights of every answer whose option's axis matches.
2. Normalize per side: `axis[i] = raw[i] / Σ raw` (skip normalization when total is 0; leave the vector zero).

A side's vector is therefore either all-zero (no contributing answers) or sums to exactly 1.0 across the 5 axes.

### 2.3 Compatibility — two call sites

There are two `calculateCompatibility` functions in the codebase today. Both change.

**`ValuesService.calculateCompatibility`** — rewritten:

```swift
// Returns 0...100 if both users have ≥ 5 total answers each, else nil.
func calculateCompatibility(
    userId: String,
    otherUserId: String
) async throws -> (score: Double, sharedTopAxes: [ValueAxis])?
```

Internals:
- Fetch both users' answers and the question pool in parallel.
- If either user has fewer than 5 total answers (across all questions, not per side), return `nil`.
- Compute each user's need + bring vector.
- `score = (cosine(A.need, B.bring) + cosine(A.bring, B.need)) / 2 * 100`
- `sharedTopAxes` = axes that are in the top 2 by score on both sides of the pairing — used to drive copy on the swipe card (e.g. "You both value Connection"). Optional, may be empty.

**`CompatibilityService` — values sub-score swap:**

`CompatibilityService` keeps its 5-factor structure (interests 40 / values 30 / goals 15 / age 10 / distance 5). Only the values sub-score changes:

```swift
private func calculateValuesScore(
    currentUserAxisScores: (need: AxisScores, bring: AxisScores)?,
    otherUserAxisScores: (need: AxisScores, bring: AxisScores)?
) -> Double {
    guard let me = currentUserAxisScores, let them = otherUserAxisScores,
          !me.need.isZero, !me.bring.isZero,
          !them.need.isZero, !them.bring.isZero else {
        return 15.0 // Neutral score if either side has no answers — preserves today's behavior
    }
    let avgCosine =
        (cosine(me.need, them.bring) + cosine(me.bring, them.need)) / 2.0
    return avgCosine * 30.0
}
```

The old `calculateValuesScore` (value-name intersection) is deleted. `rankProfiles` and the public `calculateCompatibility` signature gain `currentUserAxisScores` and `otherUsersAxisScores: [String: (need: AxisScores, bring: AxisScores)]` parameters, mirroring how it already accepts other-users-values today. The old `currentUserValuesBrought/Sought` and `otherUsersValues` parameters are removed (they are no longer used anywhere).

**Call sites to update**

| File | Change |
|---|---|
| `Harvest/Services/SwipeService.swift` (one call to `compatibilityService.calculateCompatibility`) | Switch to new parameters: pass axis scores instead of value lists. Where the score would have come from value lists, pass `nil`/empty axis scores to keep the neutral-15 fallback. |
| `Harvest/Services/CompatibilityService.swift` (one internal call in `rankProfiles`) | Same parameter swap. |
| `HarvestTests/Services/CompatibilityServiceTests.swift` | All tests rewritten to seed axis scores instead of value lists. The interests/goals/age/distance test branches are unchanged. |
| Any UI that displays the `ValuesService.calculateCompatibility` tuple's `matchingValues` (grep currently finds none in app code outside tests) | If a call site is discovered during implementation, it must handle the new `sharedTopAxes` shape or the `nil` ("not enough answers yet") return. |

### 2.4 Value picks no longer affect matching

`user_values_brought` and `user_values_sought` stay in the schema and continue to display on profile and in the Values-tab Main section as chips. They are no longer read by `calculateCompatibility`. The `Values` table and `ValuesService` get/save methods are unchanged.

## 3. Onboarding

### 3.1 New step `.reflections`

`OnboardingStep` enum gains one case, inserted after `.values`:

```swift
enum OnboardingStep: Int, CaseIterable {
    case age, nickname, photos, goals, values
    case reflections                 // NEW
    case genderIdentity, interestedIn, location, terms, complete
}
```

### 3.2 `ReflectionsStepView`

New file: `Harvest/Views/Onboarding/ReflectionsStepView.swift`.

- Loads all questions via `QuestionsService.getAllQuestions()` on appear.
- Renders one question at a time using `viewModel.currentReflectionIndex`.
- Header: question N of M (M is the question count, today 10).
- Body: `Text(prompt)` + a vertical list of options. Tapping an option both records the answer in `viewModel.reflectionAnswers[questionId] = optionId` and animates to the next question (or no-op if it's the last).
- Footer "Back" button decrements the index (cannot go below 0); "Forward" arrow appears greyed unless an answer is recorded for the current question.
- When the user advances past the last question, `viewModel.nextStep()` is called automatically to leave the step.

### 3.3 `OnboardingContainerView` changes

- Switch adds `case .reflections: ReflectionsStepView(viewModel: viewModel)`.
- The outer Continue/Back bar is hidden when `currentStep == .reflections` (the in-step buttons handle nav).
- Progress bar formula updated:

```swift
var progress: Double {
    let total = Double(OnboardingStep.allCases.count - 1)
    if currentStep == .reflections, !allQuestions.isEmpty {
        let subProgress = Double(currentReflectionIndex) / Double(allQuestions.count)
        return (Double(currentStep.rawValue) + subProgress) / total
    }
    return Double(currentStep.rawValue) / total
}
```

### 3.4 `OnboardingViewModel` additions

```swift
var allQuestions: [Question] = []
var reflectionAnswers: [String: String] = [:]   // questionId -> optionId
var currentReflectionIndex: Int = 0
var isLoadingQuestions = false

func loadQuestionsIfNeeded() async { /* like loadValuesIfNeeded */ }
```

`canProceed` adds:
```swift
case .reflections:
    return reflectionAnswers.count >= allQuestions.count
```
This is only consulted if the outer Continue is ever visible inside `.reflections` (it isn't); kept for safety.

`completeOnboarding` saves answers alongside values, best-effort:

```swift
do {
    try await questionsService.saveAnswers(
        userId: userId,
        answers: reflectionAnswers
    )
} catch {
    print("Warning: Failed to save reflection answers: \(error)")
}
```

A failure here does not block onboarding completion — the user can re-answer from the Values tab.

## 4. Values Tab Structure

```
ValuesView
├─ Top segmented control:  [ Main | Tips ]
│
├─ if Main:
│   ├─ Inner segmented control:  [ I Need | I Bring ]
│   ├─ ValuesRadarCard (single polygon for the active side)
│   ├─ "More questions" button
│   ├─ Values picker — inline chips grouped by category
│   ├─ Blurb card (shared across sides)
│   └─ "Show on Profile" card (shared across sides)
│       ├─ Toggle: Values I Bring
│       ├─ Toggle: Values I Seek
│       ├─ Toggle: Generated Blurb
│       ├─ Toggle: Values Graph
│       └─ Segmented control: [ Need | Bring ]   (only when Values Graph is on)
│
└─ if Tips:
    └─ existing tips content (category chips, tip cards, FAQ)
```

### 4.1 State

`ValuesViewModel` gains:

```swift
enum Mode { case main, tips }
enum Side { case need, bring }

var mode: Mode = .main
var side: Side = .need
var allQuestions: [Question] = []
var answers: [String: String] = [:]             // questionId -> optionId

var needScores: AxisScores { /* computed from answers + questions */ }
var bringScores: AxisScores { /* computed from answers + questions */ }
var activeScores: AxisScores { side == .need ? needScores : bringScores }

func saveAnswer(questionId: String, optionId: String) async  // upserts; updates `answers`
```

### 4.2 Inline values picker

The picker replaces the navigation to `ValuesQuestionnaireView`. Behavior:

- Grouped by category, alphabetized, same `ChipView` styling as today.
- Max 5 selections per side; tapping a 6th is a no-op.
- Tapping a chip immediately saves via `ValuesService.saveUserValues{Brought,Sought}`. Optimistic local update; on failure, revert and show inline error.
- The active set (Need vs Bring) reads from the existing `valuesBrought` / `valuesSought` arrays in the view model. Side mapping: `I Need` → `valuesSought` (matches the existing "sought" column), `I Bring` → `valuesBrought`.

### 4.3 "More questions" button

A `GlassButton` labeled "More questions" sits between the radar and the values picker on both sides. Tap presents `QuestionSheetView` as a `.sheet`.

### 4.4 Blurb card

Unchanged from today's `ValuesView` blurb card — same Generate/Regenerate flow via `BlurbService`. Lives below the values picker, shown for both sides (no per-side blurb).

### 4.5 "Show on Profile" card

Same four toggles as today plus a new "Graph side" segmented control that is visible only when `showValuesGraph` is true:

```swift
if profile.showValuesGraph ?? true {
    Picker("Graph side", selection: graphSideBinding) {
        Text("Need").tag("need")
        Text("Bring").tag("bring")
    }
    .pickerStyle(.segmented)
}
```

`graphSideBinding` writes `profile_graph_side` via `ProfileService.updateProfile`.

## 5. Question Sheet

New file: `Harvest/Views/Values/QuestionSheetView.swift`.

- Initializer: `init(side: Side, viewModel: ValuesViewModel)`.
- On appear, computes the queue of unanswered questions for the active side:

```swift
let answered = Set(viewModel.answers.keys)
let pool = viewModel.allQuestions.filter { q in
    switch viewModel.side {
    case .need:  return q.weighting == .need  || q.weighting == .both
    case .bring: return q.weighting == .bring || q.weighting == .both
    }
}
let queue = pool.filter { !answered.contains($0.id) }
    .sorted { $0.displayOrder < $1.displayOrder }
```

- Renders one question at a time, identical layout to `ReflectionsStepView`'s question card.
- Tapping an option saves the answer immediately (`viewModel.saveAnswer`) and animates to the next item in the queue.
- When the queue empties, the sheet swaps to a "You've answered everything for now — new questions will appear here as they're added" state with a Done button.
- A queue that is empty on first open shows the same end-state directly. This is how existing users discover there's nothing to answer once we add more questions later.

The sheet does not refetch the question pool; it relies on `viewModel.allQuestions` already being loaded.

## 6. Radar Component

`Harvest/Views/Components/ValuesRadarCard.swift` is rewritten:

```swift
struct ValuesRadarCard: View {
    let primary: AxisScores            // required, drawn as the main polygon
    let secondary: AxisScores?         // optional second polygon
    let primaryLabel: String
    let secondaryLabel: String?
    let onEmptyTap: (() -> Void)?      // shown only when primary.isZero
}
```

- Axes are fixed and ordered clockwise from top: Emotional Intelligence → Stability → Integrity → Connection → Growth.
- Axis label drawing uses `ValueAxis.displayName`.
- Polygon plotting reads `primary.value(for: axis)` (range 0.0–1.0; a balanced user shows ~0.2 on every axis since the five axes sum to 1.0). The grid is drawn at 0.2, 0.4, 0.6, 0.8, 1.0. Polygon size is intentionally proportional to concentration — a perfectly balanced user shows a small even pentagon, a one-axis-focused user shows a needle reaching the edge.
- Single-polygon mode: only `primary` is drawn; no legend.
- Two-polygon mode (`secondary != nil`): both drawn with the existing Bring/Seek color split. Legend appears at the bottom.
- Empty state (when `primary.isZero` and no `secondary`): shows the existing empty placeholder + "Start" button wired to `onEmptyTap`.

Usage sites:
- **Values tab Main:** single-polygon, `primary = activeScores`, `primaryLabel = side == .need ? "I Need" : "I Bring"`, `onEmptyTap` opens `QuestionSheetView`.
- **Profile view (self) & Profile detail (other):** single-polygon, `primary = profileGraphSide == "need" ? needScores : bringScores`, `primaryLabel` matches. Tap on empty state is `nil` on the other-user profile.

The two-polygon mode is kept available for future use (e.g., a "see your full map" screen) but is not exercised by this pass.

## 7. Profile View Updates

`ProfileView.swift` and `ProfileDetailView.swift`:

- The Values Graph card is gated on `profile.showValuesGraph ?? true` (unchanged).
- When shown, it renders the single-polygon radar for the side specified by `profile.profileGraphSide ?? "bring"`.
- The "Values I Bring" and "Values I Seek" chip rows remain on profile, gated by their existing toggles. Their content is the user's selected values — purely visual.
- `ProfileViewModel` and `ProfileDetailViewModel` load `answers` and `allQuestions` (same as `ValuesViewModel`) so they can compute `AxisScores` for rendering. For other-user profiles, fetch only that user's answers.

## 8. Services

### 8.1 `QuestionsService.swift` (new)

```swift
struct QuestionsService {
    func getAllQuestions() async throws -> [Question]
    func getUserAnswers(userId: String) async throws -> [String: String]   // questionId -> optionId
    func saveAnswer(userId: String, questionId: String, optionId: String) async throws
    func saveAnswers(userId: String, answers: [String: String]) async throws
}
```

- `getAllQuestions` selects `questions` joined with `question_options(*)` and returns fully-populated `Question` values. On failure or empty result, falls back to a hard-coded default mirroring the 10 onboarding questions exactly as listed in the request — same defensive pattern as `ValuesService.defaultValues`.
- `saveAnswer` upserts on `(user_id, question_id)`.
- `saveAnswers` is a single upsert with multiple rows for the onboarding-completion path.

### 8.2 `ValuesService.calculateCompatibility`

Rewritten to use the new vector math (section 2.3). Other `ValuesService` methods are unchanged.

### 8.3 `ProfileService`

Add `profile_graph_side` to the select projection and to upsert payloads. No new endpoints.

## 9. Migration & Seeding

Single SQL file under `supabase/migrations/` (directory already exists at `supabase/migrations/`, with one prior file `20260518120000_values_blurb_and_display_toggles.sql`): `<timestamp>_values_questionnaire.sql`, where the timestamp is greater than the existing migration's.

Contents (in order):
1. `create table questions`, `question_options`, `user_question_answers` (section 1.1)
2. `alter table users add column profile_graph_side ...` (section 1.2)
3. RLS policies on `user_question_answers` (section 1.3)
4. Seed inserts: 10 rows into `questions`, 50 rows into `question_options`, with text matching the request exactly. IDs: `q1`..`q10` for questions, `q{n}_a`..`q{n}_e` for options. Display order is the request order.

The file must be applied via Supabase CLI or dashboard — committing does not run it.

Client-side fallback in `QuestionsService` carries the same seed content, so onboarding works in dev environments and during the seed-rollout window.

## 10. Existing User Handling

- No data migration on `user_question_answers` — they start with zero rows.
- Values tab Main radar shows the empty state ("Answer a few questions to map your values" + Start button) until the active side has at least one contributing answer.
- `ValuesService.calculateCompatibility` returns `nil` when either user has fewer than 5 total answers. Any UI that uses that helper directly renders a "—" or "Not enough answers yet" chip.
- `CompatibilityService.calculateValuesScore` falls back to its neutral 15.0 sub-score when either user has empty axis vectors — preserving today's behavior, so the swipe deck keeps producing a total score for everyone and is unaffected by the new feature on day 1.
- The "More questions" button is the only catch-up surface. Tapping it walks the existing user through all 10 onboarding questions in the sheet.
- Existing call sites that read a non-nil score: each must be updated to handle the optional. The implementation plan must enumerate them.

## 11. Non-Goals

- No tip-copy changes — the existing 2026-05-18 spec's tip rewrite already covers this.
- No analytics, no experiments, no rollout flag — the feature ships on first deploy.
- No animation of the radar between answer changes; the polygon snaps to its new shape.
- No deep-link from a profile to "see how we score on each axis" — score is a single number.
- No in-app question authoring; the pool is server-managed.
- No forced "catch-up" gate, no modal, no banner for existing users.
- No deletion of the existing `values`, `user_values_brought`, or `user_values_sought` data — chips stay on profile.
- No changes to the swipe deck mechanics, only to how its score is computed and displayed.
- No share-the-radar-as-image, no animations between sides, no haptics specific to this feature.

## 12. Assumptions

- The five axis names render fully at typical phone widths in the existing radar layout; no truncation logic added.
- "I Need" maps to the existing `user_values_sought` column. "I Bring" maps to `user_values_brought`. The spec uses "Need" in user-facing copy and "sought" in column references; both refer to the same data.
- The 5-answer threshold for showing compatibility is a starting heuristic. If tuning is needed it can be lifted into a constant in `ValuesService`.
- `ProfileDetailView` already fetches the other user's `UserProfile`; adding answer fetches alongside is consistent with how it fetches values today.
- The existing `valuesBlurb` field continues to be generated from value picks, not from axis scores — `BlurbService.generateBlurb(brought:sought:)` keeps its current signature.

## 13. Testing Notes

- Unit test `AxisScores.normalized()` — empty, single-axis-only, balanced, edge-case `sum == 0`.
- Unit test `ValuesService.calculateCompatibility` — both users with answers, one user below threshold (returns nil), perfect match (~100), opposite vectors (~0).
- Unit test the weight matrix application — verify that a `need`-weighted question contributes 1.0 to the need vector and 0.5 to the bring vector for the chosen axis.
- Snapshot/visual smoke test `ValuesRadarCard` at: empty, single dominant axis, balanced across 5, two-polygon mode (kept for future use).
- Manually walk onboarding through all 10 reflection questions: back navigation, progress bar advancing fractionally, completion saving correctly.
- Manually verify `QuestionSheetView` with: empty queue, full queue, single remaining question, all-Done state.
- Verify the Need/Bring segment control on Profile-Display correctly hides when the Values Graph toggle is off.
- Verify `ProfileView` and `ProfileDetailView` show the chosen-side polygon and respect `showValuesGraph`.
