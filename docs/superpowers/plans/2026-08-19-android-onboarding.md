# Harvest Android — Onboarding (P2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `OnboardingPlaceholderScreen` with the real 12-step onboarding wizard, so a new Android user can register, complete a profile, and reach the app without touching iOS.

**Architecture:** One `OnboardingViewModel` owning a step enum and all draft state (exactly as the Swift original), twelve stateless step composables, and a container that renders the current step with a progress bar and Back/Continue. This is the first flow with a real back stack, so it introduces Navigation Compose. Three new services (Profile, Values, Questions) and two new models (Value, Question) land here because onboarding is their first consumer.

**Tech Stack:** As established in P0/P1 — Kotlin 2.1.0, Compose BOM 2024.12.01, supabase-kt 3.0.3, Hilt, Coil. Adds: `androidx.navigation:navigation-compose` (already declared, unused until now) and Android's `Geocoder` in place of MapKit.

**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Scope Decision

The chosen P2 item was "Onboarding + Values (Soil)". That is **two** deliverables sharing one
foundation, ~3,300 lines of Swift together, so it is split:

- **This plan (P2a)** — models, the three services, and the onboarding wizard. Ships working
  software on its own: a new user can get into the app.
- **Next plan (P2b)** — the Soil tab: `ValuesView` (414 lines), the values radar, the
  deep-dive question sheet, `ValuesViewModel`. Consumes everything built here.

## Global Constraints

Everything from the P0/P1 plan still applies. Additionally:

- **Do not modify anything under `Harvest/`.**
- **Step order is fixed and must match `OnboardingStep` in `OnboardingViewModel.swift`:**
  age, nickname, photos, goals, values, reflections, genderIdentity, interestedIn,
  relationshipStatus, location, terms, complete.
- **`canProceed` per step is copied exactly** from the Swift `canProceed` switch. Getting a
  single branch wrong either traps a user or lets an incomplete profile through.
- **Onboarding presents only the FIRST 10 questions**, sorted by `displayOrder`. Q11–Q35 are
  reached later from the Values tab. Do not present all of them.
- **Value/Question saves are best-effort.** The Swift version logs and continues if values or
  answers fail to save — a failure there must never strand a user at onboarding.
- **All user-visible copy is verbatim** from the corresponding Swift view.
- **Geocoding:** iOS uses `MKGeocodingRequest`; Android uses `android.location.Geocoder`.
  It must be the async (API 33+) callback overload wrapped in a coroutine — the blocking
  overload is deprecated and will ANR. Keep the same behaviour: up to 5 unique suggestions,
  `resolvedLocation` = the first, and `canProceed` on the location step requires it non-null.

---

## File Structure

```
android/app/src/main/java/com/harvestglass/harvest/
  data/model/Value.kt              — Value, UserValue
  data/model/Question.kt           — ValueAxis, QuestionWeighting, QuestionOption,
                                     Question, UserQuestionAnswer, AxisScores,
                                     AxisScoring, ValuesTier
  data/service/ProfileService.kt   — mirrors Services/ProfileService.swift
  data/service/ValuesService.kt    — mirrors Services/ValuesService.swift
  data/service/QuestionsService.kt — mirrors Services/QuestionsService.swift
  util/Geocoding.kt                — suspend wrapper over android.location.Geocoder
  util/ObjectionableContent.kt     — port of MindfulMessagingService.containsObjectionableContent
                                     plus the KeywordMatcher helpers it needs
  ui/onboarding/OnboardingViewModel.kt
  ui/onboarding/OnboardingContainer.kt
  ui/onboarding/steps/AgeStep.kt … CompleteStep.kt   (12 files)
```

---

### Task 1: Value and Question models

**Files:**
- Create: `data/model/Value.kt`, `data/model/Question.kt`
- Test: `src/test/java/com/harvestglass/harvest/data/model/QuestionTest.kt`

**Interfaces:**
- Consumes: nothing.
- Produces: `@Serializable data class Value(id, name, category, displayOrder)`;
  `UserValue(id, userId, valueId, ranking)`;
  `enum class ValueAxis` with `EMOTIONAL_INTELLIGENCE("emotional_intelligence")`, `STABILITY`,
  `INTEGRITY`, `CONNECTION`, `GROWTH`, each with `displayName` and `serialName`;
  `enum class QuestionWeighting { NEED, BRING, BOTH }`;
  `QuestionOption(id, questionId, label, axis, displayOrder)`;
  `Question(id, prompt, weighting, displayOrder, options)`;
  `UserQuestionAnswer(userId, questionId, optionId)`;
  `data class AxisScores(...)` with `sum`, `isZero`, `value(axis)`, `add(delta, axis)`,
  `normalized()`, and `companion object { fun cosine(a, b): Double }`;
  `object AxisScoring` with `weights(weighting): Pair<Double, Double>`,
  `computeRawVectors(answers, questions)`, `computeVectors(answers, questions)`;
  `enum class ValuesTier` with `fromRawScore(Double)`, `displayName`, `levelLabel`,
  `rangeLabel`, `ringLabel`, `radiusFraction`.

- [ ] **Step 1: Write the failing test**

`AxisScoring` and `ValuesTier` are pure maths the matching algorithm depends on, so they get
real coverage. Expected values are read off `Harvest/Models/Question.swift`.

```kotlin
package com.harvestglass.harvest.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class QuestionTest {

    private fun option(id: String, axis: ValueAxis) =
        QuestionOption(id = id, questionId = "q1", label = "L", axis = axis, displayOrder = 0)

    private fun question(id: String, weighting: QuestionWeighting, axis: ValueAxis) =
        Question(
            id = id, prompt = "P", weighting = weighting, displayOrder = 0,
            options = listOf(option("$id-a", axis))
        )

    @Test
    fun `need questions score the need side only`() {
        assertEquals(2.0 to 0.0, AxisScoring.weights(QuestionWeighting.NEED))
    }

    @Test
    fun `bring questions score the bring side only`() {
        assertEquals(0.0 to 2.0, AxisScoring.weights(QuestionWeighting.BRING))
    }

    @Test
    fun `both questions split evenly`() {
        assertEquals(1.0 to 1.0, AxisScoring.weights(QuestionWeighting.BOTH))
    }

    @Test
    fun `raw vectors accumulate per axis`() {
        val qs = listOf(
            question("q1", QuestionWeighting.NEED, ValueAxis.STABILITY),
            question("q2", QuestionWeighting.BOTH, ValueAxis.STABILITY),
            question("q3", QuestionWeighting.BRING, ValueAxis.GROWTH)
        )
        val answers = mapOf("q1" to "q1-a", "q2" to "q2-a", "q3" to "q3-a")
        val (need, bring) = AxisScoring.computeRawVectors(answers, qs)

        assertEquals(3.0, need.stability, 0.0001)   // 2.0 + 1.0
        assertEquals(1.0, bring.stability, 0.0001)  // 0.0 + 1.0
        assertEquals(2.0, bring.growth, 0.0001)
        assertEquals(0.0, need.growth, 0.0001)
    }

    @Test
    fun `an answer to an unknown question is ignored`() {
        val qs = listOf(question("q1", QuestionWeighting.NEED, ValueAxis.INTEGRITY))
        val (need, _) = AxisScoring.computeRawVectors(mapOf("nope" to "x"), qs)
        assertTrue(need.isZero)
    }

    @Test
    fun `an unknown option id is ignored`() {
        val qs = listOf(question("q1", QuestionWeighting.NEED, ValueAxis.INTEGRITY))
        val (need, _) = AxisScoring.computeRawVectors(mapOf("q1" to "wrong"), qs)
        assertTrue(need.isZero)
    }

    @Test
    fun `normalized vectors sum to one`() {
        val s = AxisScores(stability = 3.0, growth = 1.0)
        assertEquals(1.0, s.normalized().sum, 0.0001)
    }

    @Test
    fun `normalizing a zero vector leaves it alone`() {
        assertTrue(AxisScores().normalized().isZero)
    }

    @Test
    fun `cosine of identical vectors is one`() {
        val a = AxisScores(stability = 2.0, growth = 1.0)
        assertEquals(1.0, AxisScores.cosine(a, a), 0.0001)
    }

    @Test
    fun `cosine with a zero vector is zero`() {
        assertEquals(0.0, AxisScores.cosine(AxisScores(stability = 1.0), AxisScores()), 0.0001)
    }

    @Test
    fun `tier boundaries match the radar mapping`() {
        assertEquals(ValuesTier.LOW_PRESENCE, ValuesTier.fromRawScore(0.0))
        assertEquals(ValuesTier.LOW_PRESENCE, ValuesTier.fromRawScore(5.9))
        assertEquals(ValuesTier.GROWING_PRESENCE, ValuesTier.fromRawScore(6.0))
        assertEquals(ValuesTier.GROWING_PRESENCE, ValuesTier.fromRawScore(10.9))
        assertEquals(ValuesTier.STRONG_PRESENCE, ValuesTier.fromRawScore(11.0))
        assertEquals(ValuesTier.STRONG_PRESENCE, ValuesTier.fromRawScore(17.9))
        assertEquals(ValuesTier.CORE_VALUE, ValuesTier.fromRawScore(18.0))
        assertEquals(ValuesTier.CORE_VALUE, ValuesTier.fromRawScore(28.0))
    }

    @Test
    fun `axis serial names match the database`() {
        assertEquals("emotional_intelligence", ValueAxis.EMOTIONAL_INTELLIGENCE.serialName)
        assertEquals("stability", ValueAxis.STABILITY.serialName)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*QuestionTest*"`
Expected: FAIL — unresolved references.

- [ ] **Step 3: Implement the two model files**

Port from `Harvest/Models/Value.swift` and `Harvest/Models/Question.swift`. Notes:

- `ValueAxis` needs both a kotlinx `@SerialName` for decoding and a plain `serialName`
  property for the assertion above; declare the enum with a constructor parameter and
  annotate each entry.
- `AxisScores` is a `data class` with five `Double` fields defaulting to `0.0`. Swift's
  `mutating add` becomes a `copy`-returning `add(delta, axis): AxisScores` — keep it pure
  rather than making the fields `var`, and have `computeRawVectors` reassign.
- `ValuesTier` uses `companion object { fun fromRawScore(raw: Double): ValuesTier }`
  reproducing the Swift `init(rawScore:)` ranges exactly: `<6`, `<11`, `<18`, else.
- `iconName` in Swift returns SF Symbol names. Drop that property — the Android radar picks
  its own icons in P2b. Everything else on the tier carries over.

- [ ] **Step 4: Run test to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "*QuestionTest*"`
Expected: PASS, 11 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/data/model android/app/src/test
git commit -m "feat(android): port Value and Question models with axis scoring"
```

---

### Task 2: Objectionable-content check

**Files:**
- Create: `util/ObjectionableContent.kt`
- Test: `src/test/java/com/harvestglass/harvest/util/ObjectionableContentTest.kt`

**Interfaces:**
- Consumes: nothing.
- Produces: `object ObjectionableContent { fun contains(text: String): Boolean }` plus the
  internal `normalize`/`containsToken` helpers it needs, and an `internal` test accessor
  `firstAggressiveTermForTest(): String`.

The nickname step gates on this (`canProceed` for `.nickname` calls
`MindfulMessagingService.containsObjectionableContent`), so it must exist before the wizard.
Port only the static path — `aggressiveStandalone`, `sexualPressureStandalone`, and
`KeywordMatcher.normalize`/`contains` from `Harvest/Utilities/KeywordMatcher.swift`. The
OpenAI-backed `analyzeMessage` is P2 chat scope and is NOT ported here.

- [ ] **Step 1: Read the Swift source**

Read `Harvest/Utilities/KeywordMatcher.swift` in full and the `aggressiveStandalone` /
`sexualPressureStandalone` sets in `Harvest/Services/MindfulMessagingService.swift`. Copy the
term lists verbatim — this gates what users may name themselves, so an invented list is a
behaviour change.

- [ ] **Step 2: Write the failing test**

```kotlin
package com.harvestglass.harvest.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ObjectionableContentTest {

    @Test
    fun `an ordinary nickname is allowed`() {
        assertFalse(ObjectionableContent.contains("Ada"))
        assertFalse(ObjectionableContent.contains("gardener_42"))
    }

    @Test
    fun `blank input is allowed`() {
        assertFalse(ObjectionableContent.contains(""))
        assertFalse(ObjectionableContent.contains("   "))
    }

    @Test
    fun `a flagged standalone term is caught`() {
        assertTrue(ObjectionableContent.contains(ObjectionableContent.firstAggressiveTermForTest()))
    }

    @Test
    fun `matching is boundary-aware, not substring`() {
        val term = ObjectionableContent.firstAggressiveTermForTest()
        assertFalse(ObjectionableContent.contains(term + "xyzq"))
    }

    @Test
    fun `matching ignores case the way normalize does`() {
        val term = ObjectionableContent.firstAggressiveTermForTest()
        assertTrue(ObjectionableContent.contains(term.uppercase()))
    }
}
```

`firstAggressiveTermForTest()` exists solely so the test does not hardcode a slur in the
repo. If `KeywordMatcher.contains` turns out NOT to be boundary-aware when read in Step 1,
delete the boundary test rather than assert behaviour the iOS app does not have — and say so
in the commit message.

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*ObjectionableContentTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement and re-run**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/util android/app/src/test
git commit -m "feat(android): port the objectionable-content nickname check"
```

---

### Task 3: ProfileService

**Files:**
- Create: `data/service/ProfileService.kt`
- Modify: `di/AppModule.kt` — add the provider
- Test: `src/test/java/com/harvestglass/harvest/data/service/ProfileServiceTest.kt`

**Interfaces:**
- Consumes: `SupabaseClient`, `UserProfile`, `Config`.
- Produces: `class ProfileService(client: SupabaseClient)` with
  `suspend fun getProfile(userId: String): UserProfile?`,
  `createProfile(userId: String, email: String): UserProfile?`,
  `upsertProfile(userId: String, updates: JsonObject): UserProfile?`,
  `updateProfile(userId: String, updates: JsonObject): UserProfile?`,
  `uploadPhoto(userId: String, imageData: ByteArray, photoIndex: Int): String`,
  `deletePhoto(userId: String, photoUrl: String)`,
  and `internal fun storagePathFromUrl(photoUrl: String): String?`.

- [ ] **Step 1: Write the failing test**

The URL round-trip is the part worth testing without a network: `uploadPhoto` builds a public
URL and `deletePhoto` must parse the storage path back out of it. A mismatch silently leaks
orphaned photos.

```kotlin
package com.harvestglass.harvest.data.service

import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProfileServiceTest {
    private val service = ProfileService(mockk(relaxed = true))

    @Test
    fun `a public storage url yields the object path`() {
        val url = "https://jutzlxdboayvmcuqwodn.supabase.co/storage/v1/object/public/" +
            "profile-photos/u1/photo_0_1755300000000.jpg"
        assertEquals("u1/photo_0_1755300000000.jpg", service.storagePathFromUrl(url))
    }

    @Test
    fun `a url from another bucket is not treated as ours`() {
        val url = "https://x.supabase.co/storage/v1/object/public/other-bucket/u1/p.jpg"
        assertNull(service.storagePathFromUrl(url))
    }

    @Test
    fun `a non-storage url yields nothing`() {
        assertNull(service.storagePathFromUrl("https://example.com/photo.jpg"))
    }

    @Test
    fun `garbage input yields nothing rather than throwing`() {
        assertNull(service.storagePathFromUrl("not a url"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*ProfileServiceTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 3: Implement**

Port from `ProfileService.swift`. Details that must carry over:

- `createProfile` derives the default nickname as the part of the email before `@`,
  defaulting to `"User"`, and sets `bio` to `"I'm new here!"`.
- `upsertProfile` injects `id` and `updated_at`; `updateProfile` injects only `updated_at`.
  Both use an ISO-8601 UTC instant (`java.time.Instant.now().toString()`).
- `uploadPhoto` file name is `"$userId/photo_${photoIndex}_${epochMillis}.jpg"`, uploaded to
  `Config.STORAGE_BUCKET` with `upsert = true` and content type `image/jpeg`, returning
  `"${Config.SUPABASE_URL}/storage/v1/object/public/$fullPath"`.
- `deletePhoto` parses via `storagePathFromUrl` and returns silently when it is null — the
  Swift version does the same rather than throwing.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS, 4 tests.

- [ ] **Step 5: Add the Hilt provider and build**

```kotlin
@Provides @Singleton fun provideProfileService(client: SupabaseClient) = ProfileService(client)
```

Run: `./gradlew :app:assembleDebug` — expect BUILD SUCCESSFUL.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main android/app/src/test
git commit -m "feat(android): port ProfileService"
```

---

### Task 4: ValuesService and QuestionsService

**Files:**
- Create: `data/service/ValuesService.kt`, `data/service/QuestionsService.kt`
- Modify: `di/AppModule.kt`
- Test: `src/test/java/com/harvestglass/harvest/data/service/ValuesServiceTest.kt`

**Interfaces:**
- Consumes: `SupabaseClient`, `Value`, `Question`.
- Produces:
  - `class ValuesService(client)` with `suspend fun getAllValues(): List<Value>`,
    `getUserValuesBrought(userId): List<Value>`, `getUserValuesSought(userId): List<Value>`,
    `saveUserValuesBrought(userId, valueIds: List<String>)`,
    `saveUserValuesSought(userId, valueIds: List<String>)`, and
    `companion object { val DEFAULT_VALUES: List<Value> }`.
  - `class QuestionsService(client)` with `suspend fun getAllQuestions(): List<Question>`,
    `getUserAnswers(userId): Map<String, String>`,
    `saveAnswer(userId, questionId, optionId)`,
    `saveAnswers(userId, answers: Map<String, String>)`.

- [ ] **Step 1: Read both Swift services in full**

`ValuesService.swift` (207 lines) and `QuestionsService.swift` (487 lines). The latter is
mostly a large hardcoded fallback question bank built by `makeQuestion(...)` — read how
`getAllQuestions` chooses between DB rows and that fallback before porting.

- [ ] **Step 2: Write the failing test**

`getAllValues` falling back to a built-in catalogue when the DB is empty or unreachable is
real, testable behaviour, and the catalogue's shape is easy to get wrong.

```kotlin
package com.harvestglass.harvest.data.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ValuesServiceTest {

    @Test
    fun `the default catalogue covers every category in order`() {
        val categories = ValuesService.DEFAULT_VALUES.map { it.category }.distinct()
        assertEquals(
            listOf(
                "communication", "relationship", "lifestyle",
                "personal growth", "social", "core beliefs"
            ),
            categories
        )
    }

    @Test
    fun `default ids are category-indexed and unique`() {
        val ids = ValuesService.DEFAULT_VALUES.map { it.id }
        assertEquals(ids.size, ids.distinct().size)
        assertTrue(ValuesService.DEFAULT_VALUES.first().id.startsWith("communication-"))
    }

    @Test
    fun `display order restarts within each category`() {
        ValuesService.DEFAULT_VALUES.groupBy { it.category }.forEach { (_, values) ->
            assertEquals(values.indices.toList(), values.map { it.displayOrder })
        }
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*ValuesServiceTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement both services**

Carry over exactly:

- `getAllValues` queries `values` ordered by `category` then `name`; on an empty result **or
  any thrown error** it returns `DEFAULT_VALUES`. The Swift version swallows the error
  deliberately — preserve that and keep the comment explaining why.
- `getUserValuesBrought`/`Sought` select the nested `value_id, values(*)` shape from
  `user_values_brought` / `user_values_sought` and map out the nested object.
- `saveUserValuesBrought`/`Sought` replace the user's rows. Read lines 113–160 of the Swift
  file and match the ordering exactly, including what happens when `valueIds` is empty.
- `getAllQuestions` sorts each question's options by `displayOrder` before returning.
- `saveAnswers` upserts on the `(user_id, question_id)` conflict target.

- [ ] **Step 5: Run test to verify it passes**

Expected: PASS, 3 tests.

- [ ] **Step 6: Add both Hilt providers, build, commit**

```bash
./gradlew :app:assembleDebug
git add android/app/src/main android/app/src/test
git commit -m "feat(android): port ValuesService and QuestionsService"
```

---

### Task 5: Geocoding helper

**Files:**
- Create: `util/Geocoding.kt`
- Test: `src/androidTest/java/com/harvestglass/harvest/util/GeocodingTest.kt`

**Interfaces:**
- Consumes: Android `Context`.
- Produces: `class Geocoding(context: Context)` with
  `suspend fun suggestions(query: String, limit: Int = 5): List<String>`.

- [ ] **Step 1: Write the failing instrumented test**

Geocoder needs a real device, so this is instrumented. The emulator may have no geocoding
backend, so assert the **contract**, not real place names: a blank query returns empty, and a
lookup never throws or hangs.

```kotlin
package com.harvestglass.harvest.util

import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertTrue
import org.junit.Test

class GeocodingTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun blankQueryReturnsNothing() = runBlocking {
        assertTrue(Geocoding(context).suggestions("   ").isEmpty())
    }

    @Test
    fun aLookupCompletesWithoutThrowingOrHanging() = runBlocking {
        withTimeout(10_000) {
            val results = Geocoding(context).suggestions("London")
            assertTrue(results.size <= 5)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*GeocodingTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 3: Implement**

Use `Geocoder.getFromLocationName(query, limit, listener)` (API 33+) bridged with
`suspendCancellableCoroutine`, guarding on `Geocoder.isPresent()`. Build each suggestion from
the `Address` as locality + admin area + country, skipping nulls, then de-duplicate
preserving order and take `limit`. Return an empty list on any failure — the Swift version
clears `resolvedLocation` and `locationSuggestions` rather than surfacing a geocoding error.

`minSdk` is 26 but the async overload is 33+; branch on `Build.VERSION.SDK_INT` and fall back
to the deprecated blocking call **on `Dispatchers.IO`** below 33.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/util android/app/src/androidTest
git commit -m "feat(android): geocoding suggestions via android.location.Geocoder"
```

---

### Task 6: OnboardingViewModel

**Files:**
- Create: `ui/onboarding/OnboardingViewModel.kt`
- Test: `src/test/java/com/harvestglass/harvest/ui/onboarding/OnboardingViewModelTest.kt`

**Interfaces:**
- Consumes: `ProfileService`, `ValuesService`, `QuestionsService`, `Geocoding`,
  `ObjectionableContent`, models from Task 1.
- Produces:
  - `enum class OnboardingStep { AGE, NICKNAME, PHOTOS, GOALS, VALUES, REFLECTIONS,
    GENDER_IDENTITY, INTERESTED_IN, RELATIONSHIP_STATUS, LOCATION, TERMS, COMPLETE }`
  - `data class OnboardingUiState(...)` holding `currentStep`, `birthDate: LocalDate`,
    `nickname`, `photoUrls: List<String>`, `selectedGoals: Set<String>`, `allValues`,
    `selectedValuesBrought`, `selectedValuesSought`, `allQuestions`,
    `reflectionAnswers: Map<String, String>`, `currentReflectionIndex`, `gender`,
    `interestedIn: Set<String>`, `relationshipStatus`, `location`, `resolvedLocation`,
    `locationSuggestions`, `termsAccepted`, `isLoading`, `isValidatingLocation`,
    `isLoadingValues`, `isLoadingQuestions`, `error`;
    with computed `age: Int`, `isAgeValid: Boolean`, `canProceed: Boolean`, `progress: Float`.
  - `@HiltViewModel class OnboardingViewModel` exposing `state: StateFlow<OnboardingUiState>`
    and `nextStep()`, `previousStep()`, `loadValuesIfNeeded()`, `loadQuestionsIfNeeded()`,
    `uploadPhoto(userId, bytes)`, `removePhoto(userId, index)`, `validateLocation()`,
    `selectLocationSuggestion(s)`, `completeOnboarding(userId): UserProfile?`, plus a setter
    per draft field.

- [ ] **Step 1: Write the failing test**

`canProceed` and `progress` are where a mistake traps or leaks a user, so they get exhaustive
coverage.

```kotlin
package com.harvestglass.harvest.ui.onboarding

import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.data.model.QuestionWeighting
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class OnboardingViewModelTest {

    private fun state(
        step: OnboardingStep,
        block: OnboardingUiState.() -> OnboardingUiState = { this }
    ) = OnboardingUiState(currentStep = step).block()

    private fun question(id: String) = Question(
        id = id, prompt = "P", weighting = QuestionWeighting.BOTH,
        displayOrder = 0, options = emptyList()
    )

    @Test
    fun `age under eighteen cannot proceed`() {
        assertFalse(state(OnboardingStep.AGE) { copy(birthDate = LocalDate.now().minusYears(17)) }.canProceed)
    }

    @Test
    fun `age eighteen or over can proceed`() {
        assertTrue(state(OnboardingStep.AGE) { copy(birthDate = LocalDate.now().minusYears(18)) }.canProceed)
    }

    @Test
    fun `a blank nickname cannot proceed`() {
        assertFalse(state(OnboardingStep.NICKNAME) { copy(nickname = "   ") }.canProceed)
    }

    @Test
    fun `an ordinary nickname can proceed`() {
        assertTrue(state(OnboardingStep.NICKNAME) { copy(nickname = "Ada") }.canProceed)
    }

    @Test
    fun `photos step requires an uploaded url, not a picked file`() {
        assertFalse(state(OnboardingStep.PHOTOS).canProceed)
        assertTrue(state(OnboardingStep.PHOTOS) { copy(photoUrls = listOf("a.jpg")) }.canProceed)
    }

    @Test
    fun `goals step requires at least one`() {
        assertFalse(state(OnboardingStep.GOALS).canProceed)
        assertTrue(state(OnboardingStep.GOALS) { copy(selectedGoals = setOf("g")) }.canProceed)
    }

    @Test
    fun `values step requires both brought and sought`() {
        assertFalse(state(OnboardingStep.VALUES) { copy(selectedValuesBrought = setOf("a")) }.canProceed)
        assertFalse(state(OnboardingStep.VALUES) { copy(selectedValuesSought = setOf("b")) }.canProceed)
        assertTrue(
            state(OnboardingStep.VALUES) {
                copy(selectedValuesBrought = setOf("a"), selectedValuesSought = setOf("b"))
            }.canProceed
        )
    }

    @Test
    fun `reflections require an answer to every loaded question`() {
        val qs = listOf(question("q1"), question("q2"))
        assertFalse(state(OnboardingStep.REFLECTIONS) { copy(allQuestions = qs) }.canProceed)
        assertFalse(
            state(OnboardingStep.REFLECTIONS) {
                copy(allQuestions = qs, reflectionAnswers = mapOf("q1" to "a"))
            }.canProceed
        )
        assertTrue(
            state(OnboardingStep.REFLECTIONS) {
                copy(allQuestions = qs, reflectionAnswers = mapOf("q1" to "a", "q2" to "b"))
            }.canProceed
        )
    }

    @Test
    fun `reflections with no questions loaded cannot proceed`() {
        // Guards against an empty question bank silently waving the user through.
        assertFalse(state(OnboardingStep.REFLECTIONS).canProceed)
    }

    @Test
    fun `location requires a resolved place, not just typed text`() {
        assertFalse(state(OnboardingStep.LOCATION) { copy(location = "Lond") }.canProceed)
        assertTrue(state(OnboardingStep.LOCATION) { copy(resolvedLocation = "London") }.canProceed)
    }

    @Test
    fun `terms must be accepted`() {
        assertFalse(state(OnboardingStep.TERMS).canProceed)
        assertTrue(state(OnboardingStep.TERMS) { copy(termsAccepted = true) }.canProceed)
    }

    @Test
    fun `gender, interestedIn and relationshipStatus each require a value`() {
        assertFalse(state(OnboardingStep.GENDER_IDENTITY).canProceed)
        assertTrue(state(OnboardingStep.GENDER_IDENTITY) { copy(gender = "female") }.canProceed)
        assertFalse(state(OnboardingStep.INTERESTED_IN).canProceed)
        assertTrue(state(OnboardingStep.INTERESTED_IN) { copy(interestedIn = setOf("men")) }.canProceed)
        assertFalse(state(OnboardingStep.RELATIONSHIP_STATUS).canProceed)
        assertTrue(state(OnboardingStep.RELATIONSHIP_STATUS) { copy(relationshipStatus = "single") }.canProceed)
    }

    @Test
    fun `the complete step always proceeds`() {
        assertTrue(state(OnboardingStep.COMPLETE).canProceed)
    }

    @Test
    fun `progress advances with the step index`() {
        val total = (OnboardingStep.entries.size - 1).toFloat()
        assertEquals(0f, state(OnboardingStep.AGE).progress, 0.0001f)
        assertEquals(1f / total, state(OnboardingStep.NICKNAME).progress, 0.0001f)
    }

    @Test
    fun `reflections progress interpolates across the question sub-steps`() {
        val qs = listOf(question("q1"), question("q2"), question("q3"), question("q4"))
        val total = (OnboardingStep.entries.size - 1).toFloat()
        val s = state(OnboardingStep.REFLECTIONS) {
            copy(allQuestions = qs, currentReflectionIndex = 2)
        }
        assertEquals((OnboardingStep.REFLECTIONS.ordinal + 0.5f) / total, s.progress, 0.0001f)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*OnboardingViewModelTest*"`
Expected: FAIL — unresolved references.

- [ ] **Step 3: Implement**

Port from `OnboardingViewModel.swift`. Points that must be exact:

- `age` = whole years between `birthDate` and today (`java.time.Period.between(...).years`).
- `canProceed` reproduces the Swift switch branch for branch, including the nickname's
  `ObjectionableContent.contains` check and reflections' `allQuestions.isNotEmpty()` guard.
- `progress` divides by `entries.size - 1`, and on the reflections step adds
  `currentReflectionIndex / allQuestions.size` to the step ordinal before dividing.
- `loadQuestionsIfNeeded` sorts by `displayOrder` and takes **only the first 10**.
- `loadValuesIfNeeded`/`loadQuestionsIfNeeded` are idempotent: they no-op when already loaded
  or already loading.
- `removePhoto` drops the URL from state immediately and deletes from storage in the
  background, swallowing any delete failure (the Swift version leaves a possible orphan rather
  than blocking the user — keep the comment).
- `completeOnboarding` builds the same update map (note `bio` is hardcoded `"I'm new here!"`
  and `goals` is the selected set **comma-joined into a single string**), tries `updateProfile`
  then falls back to `upsertProfile`, and saves values and answers **best-effort** inside their
  own try/catch so a failure still returns the profile.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS, 15 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/onboarding android/app/src/test
git commit -m "feat(android): port OnboardingViewModel"
```

---

### Task 7: Step composables

**Files:**
- Create: `ui/onboarding/steps/` — `AgeStep.kt`, `NicknameStep.kt`, `PhotosStep.kt`,
  `GoalsStep.kt`, `ValuesStep.kt`, `ReflectionsStep.kt`, `GenderStep.kt`,
  `InterestedInStep.kt`, `RelationshipStatusStep.kt`, `LocationStep.kt`, `TermsStep.kt`,
  `CompleteStep.kt`
- Test: `src/androidTest/java/com/harvestglass/harvest/ui/onboarding/OnboardingStepsTest.kt`

**Interfaces:**
- Consumes: `OnboardingUiState` and the setter callbacks from Task 6, shared components.
- Produces: one stateless `@Composable fun <Name>Step(state: OnboardingUiState, on…: …)` per
  file. None own a ViewModel — the container passes state down and callbacks up.

- [ ] **Step 1: Read every Swift step view**

Read all 12 files in `Harvest/Views/Onboarding/`. Every heading, prompt, option label and
helper string is verbatim — do not paraphrase. Note in particular that `GoalsStepView`,
`GenderStepView`, `InterestedInStepView` and `RelationshipStatusStepView` each carry a
hardcoded option list whose **stored** values (e.g.
`single|dating|in_relationship|engaged|married`) must match the database exactly, not just the
display labels.

- [ ] **Step 2: Write the failing UI test**

```kotlin
package com.harvestglass.harvest.ui.onboarding

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.ui.onboarding.steps.RelationshipStatusStep
import com.harvestglass.harvest.ui.onboarding.steps.TermsStep
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class OnboardingStepsTest {
    @get:Rule val rule = createComposeRule()

    @Test
    fun relationshipStatusEmitsTheStoredValueNotTheLabel() {
        var picked: String? = null
        rule.setContent {
            HarvestAppTheme {
                RelationshipStatusStep(
                    state = OnboardingUiState(currentStep = OnboardingStep.RELATIONSHIP_STATUS),
                    onSelect = { picked = it }
                )
            }
        }
        // Label reads "In a relationship"; the column stores "in_relationship".
        rule.onNodeWithText("In a relationship").performClick()
        assertEquals("in_relationship", picked)
    }

    @Test
    fun termsToggleFlipsAcceptance() {
        var accepted = false
        rule.setContent {
            HarvestAppTheme {
                TermsStep(
                    state = OnboardingUiState(currentStep = OnboardingStep.TERMS),
                    onAcceptedChange = { accepted = it },
                    onOpenTerms = {}, onOpenPrivacy = {}
                )
            }
        }
        rule.onNodeWithText("I agree", substring = true).performClick()
        assertEquals(true, accepted)
    }
}
```

Adjust the asserted labels to whatever the Swift files actually use — read them first, then
write the assertion against the real copy.

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*OnboardingStepsTest*"`
Expected: FAIL — unresolved references.

- [ ] **Step 4: Implement the twelve steps**

Build them on the existing shared components (`GlassCard`, `ChipView`, `GlassButton`,
`SectionHeader`) and `HarvestTheme` tokens. Specific notes:

- **AgeStep** — iOS uses a wheel `DatePicker`. Use a Compose date picker or three-field entry;
  whichever, the derived age and the 18+ gate must match.
- **PhotosStep** — `ActivityResultContracts.PickVisualMedia` in place of `PhotosUI`, reading
  bytes via `contentResolver.openInputStream` and handing them to `uploadPhoto`. Re-encode to
  JPEG at quality 80 to match the iOS `jpegData(compressionQuality: 0.8)`.
- **ReflectionsStep** — one question at a time, driven by `currentReflectionIndex`; the
  container hides its own Back/Continue on this step (iOS does), so the step owns its advance.
- **LocationStep** — debounce typing before calling `validateLocation()`, list the suggestions,
  and select one to set `resolvedLocation`.
- **CompleteStep** — calls `completeOnboarding(userId)` and, on a non-null profile, hands
  control back so the root gate re-evaluates.

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/onboarding android/app/src/androidTest
git commit -m "feat(android): port the twelve onboarding step screens"
```

---

### Task 8: Container, wiring, and end-to-end verification

**Files:**
- Create: `ui/onboarding/OnboardingContainer.kt`
- Modify: `ui/HarvestApp.kt` — replace `OnboardingPlaceholderScreen`
- Create: `docs/verification/2026-08-19-android-onboarding-checklist.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `@Composable fun OnboardingContainer(userId: String, onComplete: () -> Unit,
  onSignOut: () -> Unit, viewModel: OnboardingViewModel = hiltViewModel())`.

- [ ] **Step 1: Implement the container**

Port `OnboardingContainerView.swift`: a `LinearProgressIndicator` tinted
`HarvestTheme.Colors.primary`, the current step filling the body, and a Back/Continue row that
is **hidden on the reflections and complete steps**. Title "Set Up Profile", a "Sign Out"
action in the top bar, background `HarvestTheme.Colors.formBackground`. Continue is disabled
and at 0.5 alpha when `!canProceed`.

Wire Navigation Compose here — this is the flow the dependency was kept for. A `NavHost` with
one destination per step gives the system back button correct behaviour; `previousStep()` and
`popBackStack()` must stay in sync, so drive navigation from `currentStep` and let the back
handler call `previousStep()`.

- [ ] **Step 2: Replace the placeholder in `HarvestApp.kt`**

```kotlin
state.needsOnboarding -> OnboardingContainer(
    userId = state.currentUserId.orEmpty(),
    onComplete = { authViewModel.checkSession() },
    onSignOut = authViewModel::logout
)
```

Delete `OnboardingPlaceholderScreen` entirely — leaving it would be dead code.

- [ ] **Step 3: Run the whole suite**

```bash
cd android && ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

Expected: all green, including the 80 tests already passing from P0/P1. Record actual counts.

- [ ] **Step 4: Run it on the emulator**

```bash
./gradlew :app:installDebug
```

Register a brand-new account and walk all twelve steps through to the tab shell.

- [ ] **Step 5: Write the verification checklist**

Create `docs/verification/2026-08-19-android-onboarding-checklist.md` with a box for each:
every step advances only when its rule is satisfied; under-18 is refused; an objectionable
nickname is refused; a photo uploads and appears in Supabase Storage; removing a photo removes
it; exactly 10 reflection questions appear; the progress bar advances within reflections;
location suggestions resolve and Continue stays disabled until one is chosen; terms must be
ticked; completion writes `onboarding_completed = true` and lands on The Field; the resulting
profile is visible and correct in the iOS app; values and answers are persisted; and a failure
to save values still lets the user through.

- [ ] **Step 6: Commit**

```bash
git add android docs/verification
git commit -m "feat(android): wire onboarding into the root gate"
```

---

## What this plan deliberately does not cover

- **The Soil tab (P2b)** — `ValuesView`, the values radar, the deep-dive question sheet,
  `ValuesViewModel`. Next plan; consumes the models and services built here.
- **`DifferentiationView`** — the one-time intro shown by `MainTabView` after onboarding,
  gated on a `hasSeenDifferentiation` flag. Ports with the tab shell, not the wizard.
- **The remaining P2 subsystems** — Seeds/Discover/Compatibility/Filters, Chat DM + mindful,
  Gardener, Profile/Settings/Help/Safety, Subscription + Notifications.
