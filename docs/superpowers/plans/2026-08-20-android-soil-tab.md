# Harvest Android — Soil Tab (P2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Soil placeholder with the real Values tab: the values radar, need/bring side switching, chip editing, the deep-dive question sheet, and the profile display toggles.

**Architecture:** One `ValuesViewModel` holding profile, values, questions and answers, with all scores derived from `AxisScoring` (already ported in P2a). The radar is a Compose `Canvas` port of `ValuesRadarCard.swift`. Every mutation is optimistic with a revert on save failure, exactly as the Swift version does.

**Tech Stack:** As established. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Scope Decision

`ValuesView.swift` has two sections that reach outside this subsystem:

- **The AI blurb section** calls `BlurbService` → `OpenAIService`. That is the Gardener
  subsystem's surface (API key handling, chat transport). Porting it here would drag in
  Gardener's infrastructure to serve one button.
- **The Tips library** gates on `SubscriptionService.currentTier(userId).hasGrowthFeatures`.
  That is the Subscription subsystem.

Both are **deferred to their owning subsystems**. `hasGrowthFeatures` is hardcoded `false`
here — which is not a stub but the Swift's own documented fail-closed behaviour ("Defaults to
locked so a failed tier lookup can't hand it out"), so the Tips entry point renders locked
exactly as it does for a free user on iOS.

Everything else in the tab ports in full.

## Global Constraints

Everything from P0/P1/P2a still applies. Additionally:

- **Do not modify anything under `Harvest/`.**
- **The radar plots TIERS, not raw scores.** Each axis's raw score (0–28) is mapped through
  `ValuesTier.fromRawScore(...).radiusFraction` before it becomes a radius. Plotting raw
  scores directly would silently change what every user's profile looks like.
- **Side semantics are inverted between the two lists and must not be swapped:**
  `side == NEED` edits **`valuesSought`**, `side == BRING` edits **`valuesBrought`**.
  Getting this backwards writes users' values into the wrong column.
- **Value selection is capped at 3 per side**, same as onboarding.
- **All mutations are optimistic with revert on failure** — toggles, answers, and chips.
- **All user-visible copy is verbatim** from the corresponding Swift view.

---

### Task 1: Extend UserProfile and finish the question bank

**Files:**
- Modify: `data/model/UserProfile.kt`
- Modify: `data/service/QuestionsService.kt` — add Q11–Q35
- Test: `src/test/java/com/harvestglass/harvest/data/service/ValuesServiceTest.kt` (extend)

**Interfaces:**
- Produces: `UserProfile` gains `valuesBlurb`, `showValuesBrought`, `showValuesSought`,
  `showValuesBlurb`, `showValuesGraph`, `profileGraphSide`, all nullable.
  `QuestionsService.DEFAULT_QUESTIONS` grows to 35 entries.

- [ ] **Step 1: Extend the failing test**

```kotlin
    @Test
    fun `the fallback bank covers the full deep-dive pool`() {
        val bank = QuestionsService.DEFAULT_QUESTIONS
        assertEquals(35, bank.size)
        assertEquals((1..35).toList(), bank.map { it.displayOrder })
    }

    @Test
    fun `the deep dive is twelve need, twelve bring and one both`() {
        val deepDive = QuestionsService.DEFAULT_QUESTIONS.filter { it.displayOrder > 10 }
        assertEquals(25, deepDive.size)
        assertEquals(12, deepDive.count { it.weighting == QuestionWeighting.NEED })
        assertEquals(12, deepDive.count { it.weighting == QuestionWeighting.BRING })
        assertEquals(1, deepDive.count { it.weighting == QuestionWeighting.BOTH })
    }
```

The 12/12/1 split is asserted in the Swift source's own comment
(`// Deep-dive (Q11-Q35): 12 NEED, 12 BRING, 1 BOTH`), so it is a real invariant, not a
guess. If the transcription disagrees, the transcription is wrong.

- [ ] **Step 2: Run to verify failure**

Run: `./gradlew :app:testDebugUnitTest --tests "*ValuesServiceTest*"` — expect FAIL (10 != 35).

- [ ] **Step 3: Transcribe Q11–Q35**

Read `Harvest/Services/QuestionsService.swift` lines 185–463 and add each question with
`makeQuestion(...)`, preserving id, prompt, weighting, option labels, option order and axis
exactly. This is the pool the deep-dive sheet draws from.

- [ ] **Step 4: Extend `UserProfile`**

Add, with `@SerialName` matching `UserProfile.swift`:
`values_blurb`, `show_values_brought`, `show_values_sought`, `show_values_blurb`,
`show_values_graph`, `profile_graph_side`.

- [ ] **Step 5: Run tests, expect PASS. Commit**

```bash
git commit -m "feat(android): full question bank and values profile fields"
```

---

### Task 2: The values radar

**Files:**
- Create: `ui/components/ValuesRadarCard.kt`
- Test: `src/test/java/com/harvestglass/harvest/ui/components/RadarGeometryTest.kt`
- Test: `src/androidTest/java/com/harvestglass/harvest/ui/components/ValuesRadarCardTest.kt`

**Interfaces:**
- Produces: `@Composable fun ValuesRadarCard(primary: AxisScores, primaryLabel: String, modifier: Modifier = Modifier, title: String = "Your Values Map", subtitle: String? = null, primaryColor: Color = HarvestTheme.Colors.primary, secondary: AxisScores? = null, secondaryLabel: String? = null, secondaryColor: Color = HarvestTheme.Colors.accent, onEmptyTap: (() -> Unit)? = null)`
  and `internal fun radarAxisPoint(center: Offset, radius: Float, index: Int, axisCount: Int, magnitude: Float): Offset`.

- [ ] **Step 1: Write the failing geometry test**

The geometry is pure and is what makes the chart correct, so it is unit-tested rather than
eyeballed.

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.ui.geometry.Offset
import com.harvestglass.harvest.data.model.AxisScores
import com.harvestglass.harvest.data.model.ValueAxis
import com.harvestglass.harvest.data.model.ValuesTier
import org.junit.Assert.assertEquals
import org.junit.Test

class RadarGeometryTest {
    private val center = Offset(100f, 100f)

    @Test
    fun `the first axis points straight up`() {
        val p = radarAxisPoint(center, radius = 50f, index = 0, axisCount = 5, magnitude = 1f)
        assertEquals(100f, p.x, 0.01f)
        assertEquals(50f, p.y, 0.01f)   // -pi/2 start
    }

    @Test
    fun `a zero magnitude collapses to the centre`() {
        val p = radarAxisPoint(center, 50f, 2, 5, 0f)
        assertEquals(center.x, p.x, 0.01f)
        assertEquals(center.y, p.y, 0.01f)
    }

    @Test
    fun `magnitude is clamped into zero to one`() {
        val over = radarAxisPoint(center, 50f, 0, 5, 3f)
        val at = radarAxisPoint(center, 50f, 0, 5, 1f)
        assertEquals(at.y, over.y, 0.01f)

        val under = radarAxisPoint(center, 50f, 0, 5, -2f)
        assertEquals(center.y, under.y, 0.01f)
    }

    @Test
    fun `five axes are evenly spaced`() {
        val points = (0 until 5).map { radarAxisPoint(center, 50f, it, 5, 1f) }
        assertEquals(5, points.distinct().size)
    }

    @Test
    fun `the plotted radius comes from the tier, not the raw score`() {
        // Raw 22 is CORE_VALUE -> outer ring (4/4). Raw 3 is LOW_PRESENCE -> 1/4.
        assertEquals(1.0, ValuesTier.fromRawScore(22.0).radiusFraction, 0.0001)
        assertEquals(0.25, ValuesTier.fromRawScore(3.0).radiusFraction, 0.0001)
    }

    @Test
    fun `a scores vector reads back per axis`() {
        val s = AxisScores(connection = 22.0)
        assertEquals(22.0, s.value(ValueAxis.CONNECTION), 0.0001)
        assertEquals(0.0, s.value(ValueAxis.GROWTH), 0.0001)
    }
}
```

- [ ] **Step 2: Run to verify failure.** Expect unresolved `radarAxisPoint`.

- [ ] **Step 3: Implement**

Port `ValuesRadarCard.swift`. Carry over exactly:
- Axis order: emotional intelligence, stability, integrity, connection, growth.
- Angle: `2*PI*index/axisCount - PI/2`, so index 0 is straight up.
- Four grid rings at 0.25 / 0.5 / 0.75 / 1.0, plus a spoke per axis, stroked
  `textSecondary` at 25% alpha, width 0.5.
- Polygons filled at 30% alpha and stroked at width 1.5; secondary drawn first so primary
  sits on top.
- Ring numbers 1–4 drawn **last**, 12dp left of centre, so they stay legible over the
  polygons — keep that comment.
- Axis labels at `radius + 22`.
- Chart height 280dp; radius `min(w,h)/2 - 32`.
- Empty state when primary and secondary are both zero: a 32dp accent glyph,
  "Answer a few questions to map your values.", and an optional "Start" button, min height 240.
- Legend: one dot per non-zero series.

Text inside a Compose `Canvas` needs `drawText` with a `TextMeasurer` (`rememberTextMeasurer()`),
which SwiftUI's `context.draw(Text…)` hides. Measure each string and offset by half its size
to reproduce `anchor: .center`.

- [ ] **Step 4: Write the UI test**

```kotlin
class ValuesRadarCardTest {
    @get:Rule val rule = createComposeRule()

    @Test fun emptyScoresShowThePrompt() {
        rule.setContent { HarvestAppTheme { ValuesRadarCard(AxisScores(), "I Need") } }
        rule.onNodeWithText("Answer a few questions to map your values.").assertIsDisplayed()
    }

    @Test fun emptyStateStartButtonFires() {
        var tapped = false
        rule.setContent {
            HarvestAppTheme { ValuesRadarCard(AxisScores(), "I Need", onEmptyTap = { tapped = true }) }
        }
        rule.onNodeWithText("Start").performClick()
        assertTrue(tapped)
    }

    @Test fun nonEmptyScoresShowTheLegendNotThePrompt() {
        rule.setContent {
            HarvestAppTheme { ValuesRadarCard(AxisScores(connection = 22.0), "I Need") }
        }
        rule.onNodeWithText("I Need").assertIsDisplayed()
    }
}
```

- [ ] **Step 5: Run both suites, expect PASS. Commit**

```bash
git commit -m "feat(android): port the values radar"
```

---

### Task 3: ValuesViewModel

**Files:**
- Create: `ui/values/ValuesViewModel.kt`
- Test: `src/test/java/com/harvestglass/harvest/ui/values/ValuesViewModelTest.kt`

**Interfaces:**
- Consumes: `ProfileService`, `ValuesService`, `QuestionsService`.
- Produces: `enum class ValuesSide { NEED, BRING }`;
  `enum class DisplayToggle(val column: String) { BROUGHT("show_values_brought"), BLURB("show_values_blurb"), GRAPH("show_values_graph") }`;
  `data class ValuesUiState(profile, valuesBrought, valuesSought, allValues, allQuestions, answers, side, isLoading, loadError, saveError, toggleError, hasGrowthFeatures)`
  with derived `needScores`, `bringScores`, `activeScores`, `activeValueIds`,
  `answeredQuestionCount`, `totalQuestionCount`, `remainingQuestionCount`,
  `showRetakeBanner`, `unansweredQuestions`;
  `@HiltViewModel class ValuesViewModel` with `load(userId)`, `setSide(side)`,
  `toggleValue(userId, valueId)`, `saveAnswer(userId, questionId, optionId)`,
  `setDisplayToggle(userId, key, isOn)`, `setGraphSide(userId, side)`.

- [ ] **Step 1: Write the failing test**

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class ValuesViewModelTest {
    private val profileService: ProfileService = mockk(relaxed = true)
    private val valuesService: ValuesService = mockk(relaxed = true)
    private val questionsService: QuestionsService = mockk(relaxed = true)

    private fun vm() = ValuesViewModel(profileService, valuesService, questionsService)

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private val calm = Value(id = "v1", name = "Calm", category = "lifestyle")
    private val trust = Value(id = "v2", name = "Trust", category = "relationship")

    @Test
    fun `the NEED side edits values SOUGHT`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm, trust)
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()
        vm.setSide(ValuesSide.NEED)

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertEquals(listOf("v1"), vm.state.value.valuesSought.map { it.id })
        assertTrue(vm.state.value.valuesBrought.isEmpty())
        coVerify { valuesService.saveUserValuesSought("u1", listOf("v1")) }
    }

    @Test
    fun `the BRING side edits values BROUGHT`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm, trust)
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()
        vm.setSide(ValuesSide.BRING)

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertEquals(listOf("v1"), vm.state.value.valuesBrought.map { it.id })
        coVerify { valuesService.saveUserValuesBrought("u1", listOf("v1")) }
    }

    @Test
    fun `a failed value save reverts the optimistic edit`() = runTest {
        coEvery { valuesService.getAllValues() } returns listOf(calm)
        coEvery { valuesService.saveUserValuesSought(any(), any()) } throws RuntimeException("nope")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.toggleValue("u1", "v1"); advanceUntilIdle()

        assertTrue(vm.state.value.valuesSought.isEmpty())
        assertEquals("nope", vm.state.value.saveError)
    }

    @Test
    fun `value selection is capped at three per side`() = runTest {
        val values = (1..4).map { Value(id = "v$it", name = "V$it", category = "c") }
        coEvery { valuesService.getAllValues() } returns values
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        values.forEach { vm.toggleValue("u1", it.id); advanceUntilIdle() }

        assertEquals(3, vm.state.value.valuesSought.size)
    }

    @Test
    fun `a failed answer save reverts to the previous answer`() = runTest {
        coEvery { questionsService.getUserAnswers(any()) } returns mapOf("q1" to "a")
        coEvery { questionsService.saveAnswer(any(), any(), any()) } throws RuntimeException("x")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.saveAnswer("u1", "q1", "b"); advanceUntilIdle()

        assertEquals("a", vm.state.value.answers["q1"])
    }

    @Test
    fun `an answer that had no previous value is removed on failure`() = runTest {
        coEvery { questionsService.getUserAnswers(any()) } returns emptyMap()
        coEvery { questionsService.saveAnswer(any(), any(), any()) } throws RuntimeException("x")
        val vm = vm()
        vm.load("u1"); advanceUntilIdle()

        vm.saveAnswer("u1", "q9", "opt"); advanceUntilIdle()

        assertFalse(vm.state.value.answers.containsKey("q9"))
    }

    @Test
    fun `the retake banner shows below ten answers and hides at ten`() {
        assertTrue(ValuesUiState(answers = (1..9).associate { "q$it" to "a" }).showRetakeBanner)
        assertFalse(ValuesUiState(answers = (1..10).associate { "q$it" to "a" }).showRetakeBanner)
    }

    @Test
    fun `unanswered questions come back in display order`() {
        val qs = listOf(q("q2", 2), q("q1", 1), q("q3", 3))
        val state = ValuesUiState(allQuestions = qs, answers = mapOf("q1" to "a"))
        assertEquals(listOf("q2", "q3"), state.unansweredQuestions.map { it.id })
    }

    @Test
    fun `growth features default to locked`() {
        assertFalse(ValuesUiState().hasGrowthFeatures)
    }
}
```

- [ ] **Step 2: Run to verify failure. Step 3: Implement.**

Mirror `ValuesViewModel.swift`. `load` runs its six fetches concurrently with `async`;
the profile fetch is the only one whose failure sets `loadError` — the rest degrade to
empty, exactly as the Swift `(try? await …) ?? []` does. `hasGrowthFeatures` stays `false`
(see Scope Decision).

- [ ] **Step 4: Run tests, expect PASS. Commit**

```bash
git commit -m "feat(android): port ValuesViewModel"
```

---

### Task 4: Question sheet and value chip grid

**Files:**
- Create: `ui/values/QuestionSheet.kt`, `ui/components/ValueChipGrid.kt`,
  `ui/components/ValuesPresenceGuide.kt`
- Test: `src/androidTest/java/com/harvestglass/harvest/ui/values/QuestionSheetTest.kt`

**Interfaces:**
- Produces: `@Composable fun QuestionSheet(questions: List<Question>, answers: Map<String,String>, onAnswer: (String, String) -> Unit, onDismiss: () -> Unit)`;
  `@Composable fun ValueChipGrid(values: List<Value>, selectedIds: Set<String>, onToggle: (String) -> Unit)`;
  `@Composable fun ValuesPresenceGuide()`.

- [ ] **Step 1: Read the Swift sources**

`Harvest/Views/Values/QuestionSheetView.swift` (97), `Components/ValueChipGrid.swift` (57),
`Components/ValuesPresenceGuide.swift` (65). Copy is verbatim; the presence guide explains
the four tiers and must keep `ValuesTier`'s own `displayName` / `rangeLabel` / `ringLabel`
strings rather than re-wording them.

- [ ] **Step 2: Write the failing UI test**

```kotlin
class QuestionSheetTest {
    @get:Rule val rule = createComposeRule()

    @Test fun answeringEmitsTheQuestionAndOptionIds() {
        var got: Pair<String, String>? = null
        rule.setContent {
            HarvestAppTheme {
                QuestionSheet(
                    questions = listOf(sampleQuestion()),
                    answers = emptyMap(),
                    onAnswer = { q, o -> got = q to o },
                    onDismiss = {}
                )
            }
        }
        rule.onNodeWithText("They really listen before responding.").performClick()
        assertEquals("q1" to "q1_a", got)
    }
}
```

- [ ] **Step 3: Implement. Step 4: Run tests, expect PASS. Commit**

```bash
git commit -m "feat(android): port the question sheet and value chip grid"
```

---

### Task 5: The Soil screen and wiring

**Files:**
- Create: `ui/values/ValuesScreen.kt`
- Modify: `ui/MainTabScreen.kt` — replace the SOIL placeholder
- Create: `docs/verification/2026-08-20-android-soil-checklist.md`

**Interfaces:**
- Produces: `@Composable fun ValuesScreen(userId: String, viewModel: ValuesViewModel = hiltViewModel())`
  and a stateless `ValuesContent(state, callbacks…)`.

- [ ] **Step 1: Read `ValuesView.swift` in full** (414 lines) before writing anything.

- [ ] **Step 2: Implement**, in the Swift's order: side picker (I Need / I Bring), retake
  banner when fewer than 10 answers, the radar card, the "More questions" button showing
  `remainingQuestionCount`, the values chip picker, and the display-toggles section
  (show brought / show blurb / show graph, plus the graph-side picker).

  The blurb section and the Tips section are **not** ported — see Scope Decision. Where the
  Tips entry point appears, render it in its locked state.

- [ ] **Step 3: Wire into `MainTabScreen`**, replacing the `SOIL` placeholder with
  `ValuesScreen(userId = state.currentUserId.orEmpty())`.

- [ ] **Step 4: Run the whole suite and the app on the emulator.** Record actual counts.

- [ ] **Step 5: Write the verification checklist** covering: the radar renders and matches
  iOS for the same account; switching side swaps the polygon and the chip selection;
  chips cap at 3 and persist; a question answered in the sheet updates the radar; the
  retake banner disappears at 10 answers; display toggles persist and are reflected on iOS;
  and the blurb/Tips omissions are visible-but-expected.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(android): port the Soil tab"
```

---

## What this plan deliberately does not cover

- **The AI blurb section** — needs `OpenAIService`; ports with Gardener.
- **The Tips library** — gates on `SubscriptionService.currentTier`; ports with Subscription.
  Renders locked here, which is the Swift's own fail-closed default.
- **The remaining P2 subsystems** — Seeds/Discover/Compatibility/Filters, Chat DM + mindful,
  Gardener, Profile/Settings/Help/Safety, Subscription + Notifications.
