# Values Questionnaire & 5-Axis Radar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the values-category-driven radar with a fixed 5-axis radar (Emotional Intelligence, Stability, Integrity, Connection, Growth) driven by a question pool. Add 10 questions to onboarding, surface the rest behind a "More questions" button in the Values tab. Switch matching from value-name intersection to cosine similarity between Need and Bring axis vectors.

**Architecture:** Pure-function math layer (`AxisScores`, weight matrix, cosine similarity) is fully unit-tested. Above it, a `QuestionsService` loads pool + answers from Supabase with a hard-coded fallback. `ValuesService.calculateCompatibility` and `CompatibilityService.calculateValuesScore` switch to vector math. UI rewires onboarding (new `.reflections` step), Values tab (Tips/Main top segmented + Need/Bring inner segmented + inline value picker + question sheet), and the two profile views (single-polygon radar based on `profile_graph_side`).

**Tech Stack:** Swift / SwiftUI / `@Observable` view models / Supabase / XCTest.

**Spec:** [`docs/superpowers/specs/2026-05-23-values-questionnaire-design.md`](../specs/2026-05-23-values-questionnaire-design.md)

---

## File Inventory

**New files**
- `Harvest/Models/Question.swift`
- `Harvest/Services/QuestionsService.swift`
- `Harvest/Views/Onboarding/ReflectionsStepView.swift`
- `Harvest/Views/Values/QuestionSheetView.swift`
- `HarvestTests/Models/AxisScoresTests.swift`
- `HarvestTests/Models/QuestionScoringTests.swift`
- `supabase/migrations/20260523120000_values_questionnaire.sql`

**Modified**
- `Harvest/Models/UserProfile.swift`
- `Harvest/Services/ValuesService.swift`
- `Harvest/Services/CompatibilityService.swift`
- `Harvest/Services/SwipeService.swift`
- `Harvest/ViewModels/OnboardingViewModel.swift`
- `Harvest/ViewModels/ValuesViewModel.swift`
- `Harvest/ViewModels/ProfileViewModel.swift`
- `Harvest/Views/Onboarding/OnboardingContainerView.swift`
- `Harvest/Views/Components/ValuesRadarCard.swift`
- `Harvest/Views/Values/ValuesView.swift`
- `Harvest/Views/Profile/ProfileView.swift`
- `Harvest/Views/Discover/ProfileDetailView.swift`
- `HarvestTests/Services/CompatibilityServiceTests.swift`

**Deleted**
- `Harvest/Views/Gardener/ValuesQuestionnaireView.swift`

> **Convention for test runs:** Build/run via Xcode (Cmd+U) or `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`. The plan uses the latter in commands; if Xcode-only is preferred, run the same tests through Cmd+U.

---

## Task 1: Foundation — `Question.swift` types

**Files:**
- Create: `Harvest/Models/Question.swift`

- [ ] **Step 1.1: Create the model file**

```swift
import Foundation

enum ValueAxis: String, Codable, CaseIterable, Sendable {
    case emotionalIntelligence = "emotional_intelligence"
    case stability
    case integrity
    case connection
    case growth

    var displayName: String {
        switch self {
        case .emotionalIntelligence: return "Emotional Intelligence"
        case .stability:             return "Stability"
        case .integrity:             return "Integrity"
        case .connection:            return "Connection"
        case .growth:                return "Growth"
        }
    }
}

enum QuestionWeighting: String, Codable, Sendable {
    case need, bring, both
}

struct QuestionOption: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let questionId: String
    let label: String
    let axis: ValueAxis
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label, axis
        case questionId = "question_id"
        case displayOrder = "display_order"
    }
}

struct Question: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let prompt: String
    let weighting: QuestionWeighting
    let displayOrder: Int
    var options: [QuestionOption]

    enum CodingKeys: String, CodingKey {
        case id, prompt, weighting, options
        case displayOrder = "display_order"
    }
}

struct UserQuestionAnswer: Codable, Sendable, Equatable {
    let userId: String
    let questionId: String
    let optionId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionId = "question_id"
        case optionId = "option_id"
    }
}
```

- [ ] **Step 1.2: Verify the build still compiles**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 1.3: Commit**

```
git add Harvest/Models/Question.swift
git commit -m "feat(models): add Question, QuestionOption, ValueAxis types"
```

---

## Task 2: `AxisScores` struct + tests

**Files:**
- Modify: `Harvest/Models/Question.swift` (append `AxisScores`)
- Create: `HarvestTests/Models/AxisScoresTests.swift`

- [ ] **Step 2.1: Write the failing tests first**

Create `HarvestTests/Models/AxisScoresTests.swift`:

```swift
import XCTest
@testable import Harvest

final class AxisScoresTests: XCTestCase {
    func testIsZero_emptyScores() {
        let s = AxisScores()
        XCTAssertTrue(s.isZero)
        XCTAssertEqual(s.sum, 0)
    }

    func testIsZero_anyValueMakesItNonZero() {
        var s = AxisScores()
        s.connection = 0.1
        XCTAssertFalse(s.isZero)
    }

    func testNormalized_zeroVectorStaysZero() {
        let s = AxisScores().normalized()
        XCTAssertTrue(s.isZero)
    }

    func testNormalized_sumsToOne() {
        var s = AxisScores()
        s.emotionalIntelligence = 2
        s.stability = 1
        s.integrity = 1
        let n = s.normalized()
        XCTAssertEqual(n.sum, 1.0, accuracy: 0.0001)
    }

    func testNormalized_relativeShape() {
        var s = AxisScores()
        s.emotionalIntelligence = 4
        s.connection = 1
        let n = s.normalized()
        XCTAssertEqual(n.emotionalIntelligence, 0.8, accuracy: 0.0001)
        XCTAssertEqual(n.connection, 0.2, accuracy: 0.0001)
        XCTAssertEqual(n.stability, 0, accuracy: 0.0001)
    }

    func testValueFor_returnsTheRightAxis() {
        var s = AxisScores()
        s.growth = 0.5
        XCTAssertEqual(s.value(for: .growth), 0.5)
        XCTAssertEqual(s.value(for: .integrity), 0)
    }

    func testCosine_identicalVectorsIsOne() {
        var a = AxisScores()
        a.emotionalIntelligence = 0.4
        a.connection = 0.6
        let c = AxisScores.cosine(a, a)
        XCTAssertEqual(c, 1.0, accuracy: 0.0001)
    }

    func testCosine_zeroVectorIsZero() {
        var a = AxisScores()
        a.growth = 1
        let c = AxisScores.cosine(a, AxisScores())
        XCTAssertEqual(c, 0, accuracy: 0.0001)
    }

    func testCosine_orthogonalAxesIsZero() {
        var a = AxisScores(); a.emotionalIntelligence = 1
        var b = AxisScores(); b.growth = 1
        XCTAssertEqual(AxisScores.cosine(a, b), 0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2.2: Run tests to confirm they fail**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/AxisScoresTests`
Expected: FAIL — `AxisScores` is undefined.

- [ ] **Step 2.3: Append `AxisScores` to `Harvest/Models/Question.swift`**

```swift
struct AxisScores: Equatable, Sendable {
    var emotionalIntelligence: Double = 0
    var stability: Double = 0
    var integrity: Double = 0
    var connection: Double = 0
    var growth: Double = 0

    var sum: Double {
        emotionalIntelligence + stability + integrity + connection + growth
    }

    var isZero: Bool { sum == 0 }

    func value(for axis: ValueAxis) -> Double {
        switch axis {
        case .emotionalIntelligence: return emotionalIntelligence
        case .stability:             return stability
        case .integrity:             return integrity
        case .connection:            return connection
        case .growth:                return growth
        }
    }

    mutating func add(_ delta: Double, to axis: ValueAxis) {
        switch axis {
        case .emotionalIntelligence: emotionalIntelligence += delta
        case .stability:             stability += delta
        case .integrity:             integrity += delta
        case .connection:            connection += delta
        case .growth:                growth += delta
        }
    }

    func normalized() -> AxisScores {
        let total = sum
        guard total > 0 else { return self }
        var n = AxisScores()
        n.emotionalIntelligence = emotionalIntelligence / total
        n.stability             = stability / total
        n.integrity             = integrity / total
        n.connection            = connection / total
        n.growth                = growth / total
        return n
    }

    /// Standard cosine similarity in [-1, 1]; returns 0 when either is a zero vector.
    static func cosine(_ a: AxisScores, _ b: AxisScores) -> Double {
        let dot =
            a.emotionalIntelligence * b.emotionalIntelligence +
            a.stability * b.stability +
            a.integrity * b.integrity +
            a.connection * b.connection +
            a.growth * b.growth
        let magA = (a.emotionalIntelligence * a.emotionalIntelligence +
                    a.stability * a.stability +
                    a.integrity * a.integrity +
                    a.connection * a.connection +
                    a.growth * a.growth).squareRoot()
        let magB = (b.emotionalIntelligence * b.emotionalIntelligence +
                    b.stability * b.stability +
                    b.integrity * b.integrity +
                    b.connection * b.connection +
                    b.growth * b.growth).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}
```

- [ ] **Step 2.4: Run tests to confirm they pass**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/AxisScoresTests`
Expected: All 9 tests PASS.

- [ ] **Step 2.5: Commit**

```
git add Harvest/Models/Question.swift HarvestTests/Models/AxisScoresTests.swift
git commit -m "feat(models): AxisScores with normalize + cosine similarity"
```

---

## Task 3: Scoring math — answers → vectors

**Files:**
- Modify: `Harvest/Models/Question.swift` (append `AxisScoring` namespace)
- Create: `HarvestTests/Models/QuestionScoringTests.swift`

- [ ] **Step 3.1: Write the failing tests**

Create `HarvestTests/Models/QuestionScoringTests.swift`:

```swift
import XCTest
@testable import Harvest

final class QuestionScoringTests: XCTestCase {
    /// Helper: build a question with N options on N axes, given a weighting.
    private func makeQuestion(
        id: String,
        weighting: QuestionWeighting,
        optionAxes: [ValueAxis]
    ) -> Question {
        let options = optionAxes.enumerated().map { i, axis in
            QuestionOption(
                id: "\(id)_\(i)",
                questionId: id,
                label: "opt \(i)",
                axis: axis,
                displayOrder: i
            )
        }
        return Question(
            id: id,
            prompt: "prompt \(id)",
            weighting: weighting,
            displayOrder: 0,
            options: options
        )
    }

    func testWeightMatrix_needQuestion() {
        let (n, b) = AxisScoring.weights(for: .need)
        XCTAssertEqual(n, 1.0)
        XCTAssertEqual(b, 0.5)
    }

    func testWeightMatrix_bringQuestion() {
        let (n, b) = AxisScoring.weights(for: .bring)
        XCTAssertEqual(n, 0.5)
        XCTAssertEqual(b, 1.0)
    }

    func testWeightMatrix_bothQuestion() {
        let (n, b) = AxisScoring.weights(for: .both)
        XCTAssertEqual(n, 1.0)
        XCTAssertEqual(b, 1.0)
    }

    func testComputeVectors_emptyAnswers() {
        let result = AxisScoring.computeVectors(answers: [:], questions: [])
        XCTAssertTrue(result.need.isZero)
        XCTAssertTrue(result.bring.isZero)
    }

    func testComputeVectors_singleNeedAnswer() {
        let q = makeQuestion(
            id: "q1",
            weighting: .need,
            optionAxes: [.emotionalIntelligence, .stability, .integrity, .connection, .growth]
        )
        let answers = ["q1": "q1_0"]   // user picked Emotional Intelligence

        let result = AxisScoring.computeVectors(answers: answers, questions: [q])

        // need: 1.0 to EI; normalized => EI = 1.0
        XCTAssertEqual(result.need.emotionalIntelligence, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.need.sum, 1.0, accuracy: 0.0001)
        // bring: 0.5 to EI; normalized => EI = 1.0
        XCTAssertEqual(result.bring.emotionalIntelligence, 1.0, accuracy: 0.0001)
    }

    func testComputeVectors_mixedWeightings() {
        let qNeed = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let qBring = makeQuestion(id: "q2", weighting: .bring, optionAxes: [.growth])
        let qBoth = makeQuestion(id: "q3", weighting: .both, optionAxes: [.integrity])

        let answers = ["q1": "q1_0", "q2": "q2_0", "q3": "q3_0"]

        let result = AxisScoring.computeVectors(answers: answers, questions: [qNeed, qBring, qBoth])

        // need raw: connection=1.0, growth=0.5, integrity=1.0 -> total 2.5
        XCTAssertEqual(result.need.connection, 1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.growth,     0.5 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.integrity,  1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.sum, 1.0, accuracy: 0.0001)

        // bring raw: connection=0.5, growth=1.0, integrity=1.0 -> total 2.5
        XCTAssertEqual(result.bring.connection, 0.5 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.bring.growth,     1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.bring.integrity,  1.0 / 2.5, accuracy: 0.0001)
    }

    func testComputeVectors_answerForUnknownQuestionIsIgnored() {
        let q = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let answers = ["qX": "qX_0", "q1": "q1_0"]   // qX has no question
        let result = AxisScoring.computeVectors(answers: answers, questions: [q])
        XCTAssertEqual(result.need.connection, 1.0, accuracy: 0.0001)
    }

    func testComputeVectors_unknownOptionIsIgnored() {
        let q = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let answers = ["q1": "q1_99"]   // option id doesn't exist
        let result = AxisScoring.computeVectors(answers: answers, questions: [q])
        XCTAssertTrue(result.need.isZero)
    }
}
```

- [ ] **Step 3.2: Run tests to confirm they fail**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/QuestionScoringTests`
Expected: FAIL — `AxisScoring` is undefined.

- [ ] **Step 3.3: Append `AxisScoring` to `Harvest/Models/Question.swift`**

```swift
enum AxisScoring {
    /// Returns (needSideWeight, bringSideWeight) for a question with the given weighting.
    static func weights(for weighting: QuestionWeighting) -> (need: Double, bring: Double) {
        switch weighting {
        case .need:  return (1.0, 0.5)
        case .bring: return (0.5, 1.0)
        case .both:  return (1.0, 1.0)
        }
    }

    /// Build the user's normalized (need, bring) axis vectors from their answers.
    static func computeVectors(
        answers: [String: String],          // questionId -> optionId
        questions: [Question]
    ) -> (need: AxisScores, bring: AxisScores) {
        var rawNeed = AxisScores()
        var rawBring = AxisScores()

        let byId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })

        for (questionId, optionId) in answers {
            guard let q = byId[questionId] else { continue }
            guard let option = q.options.first(where: { $0.id == optionId }) else { continue }
            let (nW, bW) = weights(for: q.weighting)
            rawNeed.add(nW, to: option.axis)
            rawBring.add(bW, to: option.axis)
        }

        return (rawNeed.normalized(), rawBring.normalized())
    }
}
```

- [ ] **Step 3.4: Run tests to confirm they pass**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/QuestionScoringTests`
Expected: All 8 tests PASS.

- [ ] **Step 3.5: Commit**

```
git add Harvest/Models/Question.swift HarvestTests/Models/QuestionScoringTests.swift
git commit -m "feat(scoring): weight matrix + answer-to-vector computation"
```

---

## Task 4: `QuestionsService` with hard-coded fallback

**Files:**
- Create: `Harvest/Services/QuestionsService.swift`

- [ ] **Step 4.1: Create the service**

```swift
import Foundation
import Supabase

struct QuestionsService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Returns the full question pool, options included. Falls back to the
    /// hard-coded defaults below on DB error / empty result (mirrors ValuesService).
    func getAllQuestions() async throws -> [Question] {
        do {
            let questions: [Question] = try await client
                .from("questions")
                .select("id, prompt, weighting, display_order, options:question_options(*)")
                .order("display_order", ascending: true)
                .execute()
                .value

            if !questions.isEmpty { return questions.map(Self.sortingOptions) }
        } catch {
            // DB unavailable or decode error — fall through to defaults
        }

        return Self.defaultQuestions
    }

    /// Returns a map of questionId -> optionId for the given user.
    func getUserAnswers(userId: String) async throws -> [String: String] {
        let rows: [UserQuestionAnswer] = try await client
            .from("user_question_answers")
            .select("user_id, question_id, option_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.questionId, $0.optionId) })
    }

    func saveAnswer(userId: String, questionId: String, optionId: String) async throws {
        let row: [String: AnyJSON] = [
            "user_id":     .string(userId),
            "question_id": .string(questionId),
            "option_id":   .string(optionId)
        ]
        try await client
            .from("user_question_answers")
            .upsert(row, onConflict: "user_id,question_id")
            .execute()
    }

    func saveAnswers(userId: String, answers: [String: String]) async throws {
        guard !answers.isEmpty else { return }
        let rows: [[String: AnyJSON]] = answers.map { (questionId, optionId) in
            [
                "user_id":     .string(userId),
                "question_id": .string(questionId),
                "option_id":   .string(optionId)
            ]
        }
        try await client
            .from("user_question_answers")
            .upsert(rows, onConflict: "user_id,question_id")
            .execute()
    }

    private static func sortingOptions(_ q: Question) -> Question {
        var copy = q
        copy.options.sort { $0.displayOrder < $1.displayOrder }
        return copy
    }

    // MARK: - Hard-coded defaults (mirrors values seed)

    static let defaultQuestions: [Question] = [
        Self.makeQuestion(
            id: "q1",
            prompt: "After a hard day, what would help you feel most cared for?",
            weighting: .need,
            options: [
                ("a", "They really listen before responding.",          .emotionalIntelligence),
                ("b", "They stay calm and steady with me.",             .stability),
                ("c", "They make it feel safe to be fully myself.",     .integrity),
                ("d", "They pull me close and make time for me.",       .connection),
                ("e", "They help me see a way forward.",                .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q2",
            prompt: "Someone disappoints you. What helps repair the moment most?",
            weighting: .need,
            options: [
                ("a", "They understand why it hurt.",     .emotionalIntelligence),
                ("b", "They show up better next time.",   .stability),
                ("c", "They own their part clearly.",     .integrity),
                ("d", "They make time to reconnect.",     .connection),
                ("e", "They want to learn from it.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q3",
            prompt: "You are starting to trust someone. What makes that trust grow?",
            weighting: .both,
            options: [
                ("a", "They notice what you feel.",       .emotionalIntelligence),
                ("b", "Their energy stays steady.",       .stability),
                ("c", "Their actions match their words.", .integrity),
                ("d", "You feel close and wanted.",       .connection),
                ("e", "They keep growing through life.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q4",
            prompt: "During conflict, what matters most to you?",
            weighting: .need,
            options: [
                ("a", "They try to understand you.",                     .emotionalIntelligence),
                ("b", "They slow the moment down.",                      .stability),
                ("c", "They take ownership.",                            .integrity),
                ("d", "They come back toward you emotionally.",          .connection),
                ("e", "They care more about growing than winning.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q5",
            prompt: "When you picture long-term love, what feels most important?",
            weighting: .need,
            options: [
                ("a", "Feeling emotionally known.",                       .emotionalIntelligence),
                ("b", "Knowing I can count on how they show up.",         .stability),
                ("c", "Feeling secure in their character.",               .integrity),
                ("d", "Feeling wanted and close.",                        .connection),
                ("e", "Feeling like you are building something meaningful.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q6",
            prompt: "Someone you care about is stressed. What feels most natural to you?",
            weighting: .bring,
            options: [
                ("a", "Help them feel understood.",            .emotionalIntelligence),
                ("b", "Help steady the situation.",            .stability),
                ("c", "Help them face the situation honestly.",.integrity),
                ("d", "Offer warmth and closeness.",           .connection),
                ("e", "Encourage their next step.",            .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q7",
            prompt: "What makes someone feel emotionally mature to you?",
            weighting: .both,
            options: [
                ("a", "They can read the room emotionally.",                .emotionalIntelligence),
                ("b", "They stay steady under pressure.",                   .stability),
                ("c", "They admit when they were wrong.",                   .integrity),
                ("d", "They keep reaching toward the people they love.",    .connection),
                ("e", "They reflect and adjust.",                           .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q8",
            prompt: "What keeps you invested when dating gets real?",
            weighting: .need,
            options: [
                ("a", "They care about your inner world.",            .emotionalIntelligence),
                ("b", "Their effort stays steady.",                   .stability),
                ("c", "The way they handle people feels trustworthy.",.integrity),
                ("d", "The bond feels alive.",                        .connection),
                ("e", "You see shared direction.",                    .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q9",
            prompt: "What makes a relationship feel safe enough to deepen?",
            weighting: .need,
            options: [
                ("a", "You feel emotionally understood.",             .emotionalIntelligence),
                ("b", "Their presence feels steady over time.",       .stability),
                ("c", "You trust how they handle hard things.",       .integrity),
                ("d", "You feel wanted in their life.",               .connection),
                ("e", "You feel like the relationship has purpose.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q10",
            prompt: "What would make you feel proud to choose someone?",
            weighting: .both,
            options: [
                ("a", "Their care for people is genuine.",                          .emotionalIntelligence),
                ("b", "Their life feels steady and dependable.",                    .stability),
                ("c", "Their character shows when things are hard.",                .integrity),
                ("d", "They make love feel warm and alive.",                        .connection),
                ("e", "They keep becoming a better version of themselves.",         .growth)
            ]
        )
    ]

    private static func makeQuestion(
        id: String,
        prompt: String,
        weighting: QuestionWeighting,
        options: [(String, String, ValueAxis)]
    ) -> Question {
        let opts = options.enumerated().map { i, t in
            QuestionOption(
                id: "\(id)_\(t.0)",
                questionId: id,
                label: t.1,
                axis: t.2,
                displayOrder: i
            )
        }
        return Question(
            id: id,
            prompt: prompt,
            weighting: weighting,
            displayOrder: Int(id.dropFirst()) ?? 0,    // "q3" -> 3
            options: opts
        )
    }
}
```

- [ ] **Step 4.2: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4.3: Commit**

```
git add Harvest/Services/QuestionsService.swift
git commit -m "feat(services): QuestionsService with hard-coded fallback pool"
```

---

## Task 5: `UserProfile` — add `profileGraphSide`

**Files:**
- Modify: `Harvest/Models/UserProfile.swift`

- [ ] **Step 5.1: Add the property**

In `Harvest/Models/UserProfile.swift`, add after `var showValuesGraph: Bool?` (currently line 31):

```swift
    var profileGraphSide: String?
```

- [ ] **Step 5.2: Add the coding key**

In the `CodingKeys` enum, add after `case showValuesGraph = "show_values_graph"`:

```swift
        case profileGraphSide = "profile_graph_side"
```

- [ ] **Step 5.3: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5.4: Commit**

```
git add Harvest/Models/UserProfile.swift
git commit -m "feat(profile): add profile_graph_side field"
```

---

## Task 6: Rewrite `ValuesService.calculateCompatibility`

**Files:**
- Modify: `Harvest/Services/ValuesService.swift`

- [ ] **Step 6.1: Replace the method**

In `Harvest/Services/ValuesService.swift`, replace the existing method (currently lines 161–171):

```swift
    /// New signature: returns nil if either user has fewer than 5 total answers.
    /// On success, returns radar-based score and the axes that are in the top 2
    /// on both sides of the pairing (may be empty).
    func calculateCompatibility(
        userId: String,
        otherUserId: String
    ) async throws -> (score: Double, sharedTopAxes: [ValueAxis])? {
        let questionsService = QuestionsService()

        async let myAnswersTask = questionsService.getUserAnswers(userId: userId)
        async let theirAnswersTask = questionsService.getUserAnswers(userId: otherUserId)
        async let questionsTask = questionsService.getAllQuestions()

        let myAnswers = try await myAnswersTask
        let theirAnswers = try await theirAnswersTask
        let questions = try await questionsTask

        let minAnswers = 5
        guard myAnswers.count >= minAnswers, theirAnswers.count >= minAnswers else {
            return nil
        }

        let mine = AxisScoring.computeVectors(answers: myAnswers, questions: questions)
        let theirs = AxisScoring.computeVectors(answers: theirAnswers, questions: questions)

        let needMatch = AxisScores.cosine(mine.need, theirs.bring)
        let bringMatch = AxisScores.cosine(mine.bring, theirs.need)
        let score = (needMatch + bringMatch) / 2.0 * 100

        let myNeedTop = Self.topAxes(in: mine.need, count: 2)
        let theirBringTop = Self.topAxes(in: theirs.bring, count: 2)
        let myBringTop = Self.topAxes(in: mine.bring, count: 2)
        let theirNeedTop = Self.topAxes(in: theirs.need, count: 2)

        let shared = Set(myNeedTop).intersection(theirBringTop)
            .union(Set(myBringTop).intersection(theirNeedTop))

        return (score, Array(shared))
    }

    private static func topAxes(in scores: AxisScores, count: Int) -> [ValueAxis] {
        ValueAxis.allCases
            .sorted { scores.value(for: $0) > scores.value(for: $1) }
            .prefix(count)
            .map { $0 }
    }
```

- [ ] **Step 6.2: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED. (No other call sites use this function — `CompatibilityService` has its own.)

- [ ] **Step 6.3: Commit**

```
git add Harvest/Services/ValuesService.swift
git commit -m "feat(values): rewrite calculateCompatibility with axis vector math"
```

---

## Task 7: Rewrite `CompatibilityService.calculateValuesScore`

**Files:**
- Modify: `Harvest/Services/CompatibilityService.swift`

- [ ] **Step 7.1: Change the public signature and the `rankProfiles` signature**

Replace the public `calculateCompatibility` (lines 6–63) and `rankProfiles` (lines 170–196) with:

```swift
    /// Calculate compatibility score between two users
    /// Returns a score from 0-100 based on multiple factors
    func calculateCompatibility(
        currentUser: UserProfile,
        otherUser: UserProfile,
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)? = nil,
        otherUserAxisScores: (need: AxisScores, bring: AxisScores)? = nil
    ) -> CompatibilityScore {
        var totalScore = 0.0
        var breakdown: [String: Double] = [:]

        let interestsScore = calculateInterestsScore(
            userHobbies: currentUser.hobbies ?? [],
            otherHobbies: otherUser.hobbies ?? []
        )
        breakdown["interests"] = interestsScore
        totalScore += interestsScore

        let valuesScore = calculateValuesScore(
            currentUserAxisScores: currentUserAxisScores,
            otherUserAxisScores: otherUserAxisScores
        )
        breakdown["values"] = valuesScore
        totalScore += valuesScore

        let goalsScore = calculateGoalsScore(
            userGoals: currentUser.goalsList,
            otherGoals: otherUser.goalsList
        )
        breakdown["goals"] = goalsScore
        totalScore += goalsScore

        let ageScore: Double
        if let userAge = currentUser.age, let otherAge = otherUser.age {
            ageScore = calculateAgeScore(userAge: userAge, otherAge: otherAge)
        } else {
            ageScore = 5.0
        }
        breakdown["age"] = ageScore
        totalScore += ageScore

        breakdown["distance"] = 5.0
        totalScore += 5.0

        return CompatibilityScore(
            total: Int(min(100, totalScore)),
            breakdown: breakdown
        )
    }

    /// Sort profiles by compatibility score (highest first)
    func rankProfiles(
        currentUser: UserProfile,
        profiles: [UserProfile],
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)?,
        otherUsersAxisScores: [String: (need: AxisScores, bring: AxisScores)]
    ) -> [(profile: UserProfile, score: CompatibilityScore)] {
        var scoredProfiles: [(profile: UserProfile, score: CompatibilityScore)] = []

        for profile in profiles {
            let otherAxis = otherUsersAxisScores[profile.id]
            let score = calculateCompatibility(
                currentUser: currentUser,
                otherUser: profile,
                currentUserAxisScores: currentUserAxisScores,
                otherUserAxisScores: otherAxis
            )
            scoredProfiles.append((profile: profile, score: score))
        }

        return scoredProfiles.sorted { $0.score.total > $1.score.total }
    }
```

- [ ] **Step 7.2: Replace `calculateValuesScore`**

Replace the existing private `calculateValuesScore` (lines 91–119) with:

```swift
    // MARK: - Values Scoring

    private func calculateValuesScore(
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)?,
        otherUserAxisScores: (need: AxisScores, bring: AxisScores)?
    ) -> Double {
        guard let me = currentUserAxisScores,
              let them = otherUserAxisScores,
              !me.need.isZero, !me.bring.isZero,
              !them.need.isZero, !them.bring.isZero else {
            return 15.0
        }
        let avgCosine =
            (AxisScores.cosine(me.need, them.bring) + AxisScores.cosine(me.bring, them.need)) / 2.0
        // Cosine on non-negative vectors is in [0, 1] -> scale to 0...30
        return max(0, avgCosine) * 30.0
    }
```

- [ ] **Step 7.3: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: build will FAIL — `SwipeService` and `CompatibilityServiceTests` still pass the old parameters. That's fine; tasks 8 and 9 fix them.

- [ ] **Step 7.4: Don't commit yet — proceed to task 8**

The next two tasks fix the callers; commit them together with this change.

---

## Task 8: Update `SwipeService.getCompatibilityScore`

**Files:**
- Modify: `Harvest/Services/SwipeService.swift`

- [ ] **Step 8.1: Replace the method**

Replace `getCompatibilityScore` (lines 142–164) with:

```swift
    /// Get compatibility score between current user and another user
    func getCompatibilityScore(currentUserId: String, otherUserId: String) async throws -> CompatibilityScore {
        guard let currentUser = try await profileService.getProfile(userId: currentUserId) else {
            throw NSError(domain: "SwipeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Current user profile not found"])
        }
        guard let otherUser = try await profileService.getProfile(userId: otherUserId) else {
            throw NSError(domain: "SwipeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Other user profile not found"])
        }

        let questionsService = QuestionsService()
        let questions = (try? await questionsService.getAllQuestions()) ?? []
        let myAnswers = (try? await questionsService.getUserAnswers(userId: currentUserId)) ?? [:]
        let theirAnswers = (try? await questionsService.getUserAnswers(userId: otherUserId)) ?? [:]

        let mine = AxisScoring.computeVectors(answers: myAnswers, questions: questions)
        let theirs = AxisScoring.computeVectors(answers: theirAnswers, questions: questions)

        return compatibilityService.calculateCompatibility(
            currentUser: currentUser,
            otherUser: otherUser,
            currentUserAxisScores: mine,
            otherUserAxisScores: theirs
        )
    }
```

- [ ] **Step 8.2: Don't commit yet — proceed to task 9**

---

## Task 9: Update `CompatibilityServiceTests`

**Files:**
- Modify: `HarvestTests/Services/CompatibilityServiceTests.swift`

- [ ] **Step 9.1: Survey existing tests**

The existing tests call `service.calculateCompatibility(currentUser:, otherUser:, currentUserValuesBrought:, ...)`. The new signature uses `currentUserAxisScores:` and `otherUserAxisScores:`. The interests/goals/age/distance tests don't pass any values args today (they rely on the defaults) — they only need the parameter name dropped, not real axis scores.

The "Values Scoring" tests (search for `testValuesScore` or similar in the file) need axis scores instead of value lists.

- [ ] **Step 9.2: Update non-values tests**

Search the file for `currentUserValuesBrought` and `currentUserValuesSought`. Anywhere they appear in test calls, remove those arguments — `calculateCompatibility(currentUser:, otherUser:)` continues to work because the new params default to `nil`.

For example, this call:

```swift
let score = service.calculateCompatibility(
    currentUser: user1,
    otherUser: user2
)
```

stays exactly as-is. Calls that previously included `currentUserValuesBrought: ...` etc. lose those arguments.

- [ ] **Step 9.3: Replace the values-scoring tests**

Locate the section "MARK: - Values Scoring" (or any test using the `Value` type in the args) and replace it with:

```swift
    // MARK: - Values Scoring (axis-vector based)

    private func balancedScores() -> (need: AxisScores, bring: AxisScores) {
        var s = AxisScores()
        s.emotionalIntelligence = 0.2
        s.stability             = 0.2
        s.integrity             = 0.2
        s.connection            = 0.2
        s.growth                = 0.2
        return (s, s)
    }

    private func connectionFocused() -> (need: AxisScores, bring: AxisScores) {
        var s = AxisScores()
        s.connection = 1.0
        return (s, s)
    }

    private func growthFocused() -> (need: AxisScores, bring: AxisScores) {
        var s = AxisScores()
        s.growth = 1.0
        return (s, s)
    }

    func testValuesScore_neutralWhenMissing() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")
        let score = service.calculateCompatibility(currentUser: user1, otherUser: user2)
        // 15 = neutral fallback for the 30-point values sub-score
        XCTAssertEqual(score.valuesScore, 15)
    }

    func testValuesScore_identicalVectorsIsMax() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")
        let axis = connectionFocused()
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserAxisScores: axis,
            otherUserAxisScores: axis
        )
        XCTAssertEqual(score.valuesScore, 30)
    }

    func testValuesScore_orthogonalVectorsIsZero() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserAxisScores: connectionFocused(),
            otherUserAxisScores: growthFocused()
        )
        XCTAssertEqual(score.valuesScore, 0)
    }

    func testValuesScore_balancedVsBalancedIsMax() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserAxisScores: balancedScores(),
            otherUserAxisScores: balancedScores()
        )
        // Identical balanced vectors -> cosine = 1 -> 30
        XCTAssertEqual(score.valuesScore, 30)
    }
```

If any other test file refers to `calculateValuesScore` directly (it's private now), remove that test.

- [ ] **Step 9.4: Run the test target**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/CompatibilityServiceTests`
Expected: All tests PASS.

- [ ] **Step 9.5: Commit tasks 7, 8, 9 together**

```
git add Harvest/Services/CompatibilityService.swift Harvest/Services/SwipeService.swift HarvestTests/Services/CompatibilityServiceTests.swift
git commit -m "feat(matching): axis-vector cosine values score in CompatibilityService"
```

---

## Task 10: Rewrite `ValuesRadarCard` for 5 fixed axes

**Files:**
- Modify: `Harvest/Views/Components/ValuesRadarCard.swift`

- [ ] **Step 10.1: Replace the entire file**

```swift
import SwiftUI

struct ValuesRadarCard: View {
    let primary: AxisScores
    let primaryLabel: String
    let secondary: AxisScores?
    let secondaryLabel: String?
    let onEmptyTap: (() -> Void)?

    init(
        primary: AxisScores,
        primaryLabel: String,
        secondary: AxisScores? = nil,
        secondaryLabel: String? = nil,
        onEmptyTap: (() -> Void)? = nil
    ) {
        self.primary = primary
        self.primaryLabel = primaryLabel
        self.secondary = secondary
        self.secondaryLabel = secondaryLabel
        self.onEmptyTap = onEmptyTap
    }

    private let axes: [ValueAxis] = [
        .emotionalIntelligence,
        .stability,
        .integrity,
        .connection,
        .growth
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Your Values Map")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if primary.isZero && (secondary?.isZero ?? true) {
                    emptyState
                } else {
                    chart
                    legend
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 32))
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text("Answer a few questions to map your values.")
                .font(HarvestTheme.Typography.bodyRegular)
                .multilineTextAlignment(.center)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            if let onEmptyTap {
                Button(action: onEmptyTap) {
                    Text("Start")
                        .font(HarvestTheme.Typography.buttonText)
                        .foregroundStyle(HarvestTheme.Colors.textOnCream)
                        .padding(.horizontal, HarvestTheme.Spacing.lg)
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var chart: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let radius = (size / 2) - 32

            Canvas { context, _ in
                drawGrid(context: context, center: center, radius: radius)
                drawAxisLabels(context: context, center: center, radius: radius)
                if let secondary, !secondary.isZero {
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        scores: secondary,
                        stroke: HarvestTheme.Colors.accent,
                        fill: HarvestTheme.Colors.accent.opacity(0.3)
                    )
                }
                if !primary.isZero {
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        scores: primary,
                        stroke: HarvestTheme.Colors.primary,
                        fill: HarvestTheme.Colors.primary.opacity(0.3)
                    )
                }
            }
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private var legend: some View {
        if let secondary, !secondary.isZero, let secondaryLabel {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: HarvestTheme.Colors.primary, label: primaryLabel)
                legendDot(color: HarvestTheme.Colors.accent, label: secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: HarvestTheme.Colors.primary, label: primaryLabel)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
    }

    // MARK: - Geometry

    private func axisPoint(center: CGPoint, radius: Double, index: Int, magnitude: Double) -> CGPoint {
        let angle = (2 * .pi * Double(index) / Double(axes.count)) - .pi / 2
        // primary/secondary are normalized to sum ~1.0; clamp the radial range to [0, 1].
        let clamped = min(max(magnitude, 0), 1)
        let r = radius * clamped
        return CGPoint(
            x: center.x + CGFloat(r * cos(angle)),
            y: center.y + CGFloat(r * sin(angle))
        )
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: Double) {
        let gridColor = HarvestTheme.Colors.textSecondary.opacity(0.25)
        let rings = [0.2, 0.4, 0.6, 0.8, 1.0]
        for ring in rings {
            var path = Path()
            for i in 0..<axes.count {
                let p = axisPoint(center: center, radius: radius, index: i, magnitude: ring)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
        for i in 0..<axes.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: axisPoint(center: center, radius: radius, index: i, magnitude: 1.0))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawAxisLabels(context: GraphicsContext, center: CGPoint, radius: Double) {
        for (i, axis) in axes.enumerated() {
            let labelPoint = axisPoint(center: center, radius: radius + 22, index: i, magnitude: 1.0)
            let text = Text(axis.displayName)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            context.draw(text, at: labelPoint, anchor: .center)
        }
    }

    private func drawPolygon(
        context: GraphicsContext,
        center: CGPoint,
        radius: Double,
        scores: AxisScores,
        stroke: Color,
        fill: Color
    ) {
        var path = Path()
        for (i, axis) in axes.enumerated() {
            let p = axisPoint(
                center: center,
                radius: radius,
                index: i,
                magnitude: scores.value(for: axis)
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: 1.5)
    }
}

#Preview("Radar — needle on connection") {
    var s = AxisScores(); s.connection = 1.0
    return ValuesRadarCard(primary: s, primaryLabel: "I Need")
        .padding()
        .background(HarvestTheme.Colors.background)
}

#Preview("Radar — balanced") {
    var s = AxisScores()
    s.emotionalIntelligence = 0.2; s.stability = 0.2; s.integrity = 0.2
    s.connection = 0.2; s.growth = 0.2
    return ValuesRadarCard(primary: s, primaryLabel: "I Bring")
        .padding()
        .background(HarvestTheme.Colors.background)
}

#Preview("Radar — empty with action") {
    ValuesRadarCard(
        primary: AxisScores(),
        primaryLabel: "I Need",
        onEmptyTap: { print("start tapped") }
    )
    .padding()
    .background(HarvestTheme.Colors.background)
}
```

- [ ] **Step 10.2: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: build will fail at the existing `ValuesRadarCard(brought:sought:)` call sites in `ValuesView`, `ProfileView`, `ProfileDetailView` — they pass the old initializer args. Those are fixed in later tasks.

- [ ] **Step 10.3: Don't commit yet — call sites are fixed in tasks 17, 21, 22**

Hold this change in the working tree.

---

## Task 11: Onboarding — add `.reflections` step + view model state

**Files:**
- Modify: `Harvest/ViewModels/OnboardingViewModel.swift`

- [ ] **Step 11.1: Add the enum case**

Replace the enum (lines 7–18) with:

```swift
enum OnboardingStep: Int, CaseIterable {
    case age
    case nickname
    case photos
    case goals
    case values
    case reflections
    case genderIdentity
    case interestedIn
    case location
    case terms
    case complete
}
```

- [ ] **Step 11.2: Add state properties**

After `var isLoadingValues = false` (line 31), add:

```swift
    var allQuestions: [Question] = []
    var reflectionAnswers: [String: String] = [:]   // questionId -> optionId
    var currentReflectionIndex: Int = 0
    var isLoadingQuestions = false
```

After `private let valuesService = ValuesService()`, add:

```swift
    private let questionsService = QuestionsService()
```

- [ ] **Step 11.3: Add load + canProceed clause**

After `func loadValuesIfNeeded()` (around line 77), add:

```swift
    func loadQuestionsIfNeeded() async {
        guard allQuestions.isEmpty, !isLoadingQuestions else { return }
        isLoadingQuestions = true
        defer { isLoadingQuestions = false }
        do {
            allQuestions = try await questionsService.getAllQuestions()
        } catch {
            self.error = "Failed to load questions: \(error.localizedDescription)"
        }
    }
```

In `canProceed`, insert before `case .genderIdentity`:

```swift
        case .reflections:
            return !allQuestions.isEmpty && reflectionAnswers.count >= allQuestions.count
```

- [ ] **Step 11.4: Update progress formula**

Replace the existing `progress` getter (lines 79–82) with:

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

- [ ] **Step 11.5: Persist answers in `completeOnboarding`**

In `completeOnboarding`, find the existing `do { try await valuesService.saveUserValuesBrought ... }` block (around line 201–206). After it, add:

```swift
            do {
                try await questionsService.saveAnswers(
                    userId: userId,
                    answers: reflectionAnswers
                )
            } catch {
                print("Warning: Failed to save reflection answers during onboarding: \(error)")
            }
```

- [ ] **Step 11.6: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: build will fail — `OnboardingContainerView` does not yet handle the new `.reflections` enum case. Fixed in Task 13.

- [ ] **Step 11.7: Don't commit yet — proceed to task 12**

---

## Task 12: `ReflectionsStepView`

**Files:**
- Create: `Harvest/Views/Onboarding/ReflectionsStepView.swift`

- [ ] **Step 12.1: Create the view**

```swift
import SwiftUI

struct ReflectionsStepView: View {
    let viewModel: OnboardingViewModel

    private var currentQuestion: Question? {
        guard viewModel.currentReflectionIndex < viewModel.allQuestions.count else { return nil }
        return viewModel.allQuestions[viewModel.currentReflectionIndex]
    }

    private var selectedOptionId: String? {
        guard let q = currentQuestion else { return nil }
        return viewModel.reflectionAnswers[q.id]
    }

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            header

            if viewModel.isLoadingQuestions {
                Spacer()
                ProgressView().tint(HarvestTheme.Colors.primary)
                Spacer()
            } else if let q = currentQuestion {
                questionCard(q)
                Spacer()
                footer
            } else {
                Text("No questions available.")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.lg)
        .padding(.bottom, HarvestTheme.Spacing.lg)
        .task {
            await viewModel.loadQuestionsIfNeeded()
        }
    }

    private var header: some View {
        VStack(spacing: HarvestTheme.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.primary)
            Text("A few reflections")
                .font(HarvestTheme.Typography.h2)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            if !viewModel.allQuestions.isEmpty {
                Text("Question \(viewModel.currentReflectionIndex + 1) of \(viewModel.allQuestions.count)")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
        .padding(.top, HarvestTheme.Spacing.md)
    }

    private func questionCard(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text(q.prompt)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .padding(.bottom, HarvestTheme.Spacing.xs)

                VStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(q.options) { option in
                        optionRow(option: option, isSelected: selectedOptionId == option.id)
                    }
                }
            }
        }
    }

    private func optionRow(option: QuestionOption, isSelected: Bool) -> some View {
        Button {
            viewModel.reflectionAnswers[option.questionId] = option.id
        } label: {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textSecondary)
                Text(option.label)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(HarvestTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                    .fill(isSelected
                          ? HarvestTheme.Colors.primary.opacity(0.15)
                          : HarvestTheme.Colors.formBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                            .stroke(
                                isSelected ? HarvestTheme.Colors.primary : HarvestTheme.Colors.divider,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: HarvestTheme.Spacing.md) {
            if viewModel.currentReflectionIndex > 0 {
                GlassButton(title: "Back", icon: "chevron.left", style: .primary) {
                    withAnimation { viewModel.currentReflectionIndex -= 1 }
                }
            }

            GlassButton(title: "Continue", icon: "chevron.right", style: .primary) {
                let isLast = viewModel.currentReflectionIndex >= viewModel.allQuestions.count - 1
                withAnimation {
                    if isLast {
                        viewModel.nextStep()
                    } else {
                        viewModel.currentReflectionIndex += 1
                    }
                }
            }
            .disabled(selectedOptionId == nil)
            .opacity(selectedOptionId == nil ? 0.5 : 1)
        }
    }
}
```

- [ ] **Step 12.2: Don't commit yet — proceed to task 13**

---

## Task 13: Wire `.reflections` into `OnboardingContainerView`

**Files:**
- Modify: `Harvest/Views/Onboarding/OnboardingContainerView.swift`

- [ ] **Step 13.1: Add the switch case**

In the `Group { switch ... }` block (lines 17–37), insert this case before `case .genderIdentity`:

```swift
                    case .reflections:
                        ReflectionsStepView(viewModel: viewModel)
```

- [ ] **Step 13.2: Hide the outer navigation buttons while on `.reflections`**

Replace the existing outer Continue/Back block (lines 43–63) with:

```swift
                if viewModel.currentStep != .complete && viewModel.currentStep != .reflections {
                    HStack(spacing: HarvestTheme.Spacing.md) {
                        if viewModel.currentStep != .age {
                            GlassButton(title: "Back", icon: "chevron.left", style: .primary) {
                                withAnimation { viewModel.previousStep() }
                            }
                        }

                        GlassButton(
                            title: "Continue",
                            icon: "chevron.right",
                            style: .primary
                        ) {
                            withAnimation { viewModel.nextStep() }
                        }
                        .disabled(!viewModel.canProceed)
                        .opacity(viewModel.canProceed ? 1 : 0.5)
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.bottom, HarvestTheme.Spacing.lg)
                }
```

- [ ] **Step 13.3: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED for the onboarding parts. Other parts may still fail (Values tab, profile views — fixed later).

- [ ] **Step 13.4: Commit tasks 11–13 together**

```
git add Harvest/ViewModels/OnboardingViewModel.swift Harvest/Views/Onboarding/ReflectionsStepView.swift Harvest/Views/Onboarding/OnboardingContainerView.swift
git commit -m "feat(onboarding): add reflections step with 10 questions and sub-step progress"
```

---

## Task 14: `ValuesViewModel` — Mode/Side, questions, scores

**Files:**
- Modify: `Harvest/ViewModels/ValuesViewModel.swift`

- [ ] **Step 14.1: Replace the file**

```swift
import Foundation
import Observation
import Supabase

@Observable
final class ValuesViewModel {
    enum Mode { case main, tips }
    enum Side: String { case need, bring }

    var profile: UserProfile?
    var valuesBrought: [Value] = []
    var valuesSought: [Value] = []

    var allValues: [Value] = []
    var allQuestions: [Question] = []
    var answers: [String: String] = [:]            // questionId -> optionId

    var mode: Mode = .main
    var side: Side = .need

    var isLoading = false
    var isGeneratingBlurb = false
    var loadError: String?
    var blurbError: String?
    var toggleError: String?
    var saveError: String?

    private let valuesService = ValuesService()
    private let questionsService = QuestionsService()
    private let profileService = ProfileService()
    private let blurbService = BlurbService()

    // MARK: - Derived state

    var needScores: AxisScores {
        AxisScoring.computeVectors(answers: answers, questions: allQuestions).need
    }

    var bringScores: AxisScores {
        AxisScoring.computeVectors(answers: answers, questions: allQuestions).bring
    }

    var activeScores: AxisScores {
        side == .need ? needScores : bringScores
    }

    var activeValueIds: Set<String> {
        Set((side == .need ? valuesSought : valuesBrought).map(\.id))
    }

    private let maxValueSelections = 5

    // MARK: - Load

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = profileService.getProfile(userId: userId)
            async let broughtTask = valuesService.getUserValuesBrought(userId: userId)
            async let soughtTask = valuesService.getUserValuesSought(userId: userId)
            async let allValuesTask = valuesService.getAllValues()
            async let allQuestionsTask = questionsService.getAllQuestions()
            async let answersTask = questionsService.getUserAnswers(userId: userId)

            profile = try await profileTask
            valuesBrought = (try? await broughtTask) ?? []
            valuesSought = (try? await soughtTask) ?? []
            allValues = (try? await allValuesTask) ?? []
            allQuestions = (try? await allQuestionsTask) ?? []
            answers = (try? await answersTask) ?? [:]
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Values (chip) editing

    /// Toggles the given value on the active side. Optimistic; reverts on save failure.
    func toggleValue(userId: String, valueId: String) async {
        var brought = valuesBrought
        var sought = valuesSought

        switch side {
        case .need:
            if let idx = sought.firstIndex(where: { $0.id == valueId }) {
                sought.remove(at: idx)
            } else if sought.count < maxValueSelections,
                      let v = allValues.first(where: { $0.id == valueId }) {
                sought.append(v)
            } else {
                return
            }
        case .bring:
            if let idx = brought.firstIndex(where: { $0.id == valueId }) {
                brought.remove(at: idx)
            } else if brought.count < maxValueSelections,
                      let v = allValues.first(where: { $0.id == valueId }) {
                brought.append(v)
            } else {
                return
            }
        }

        let previousBrought = valuesBrought
        let previousSought = valuesSought
        valuesBrought = brought
        valuesSought = sought

        do {
            switch side {
            case .need:
                try await valuesService.saveUserValuesSought(userId: userId, valueIds: sought.map(\.id))
            case .bring:
                try await valuesService.saveUserValuesBrought(userId: userId, valueIds: brought.map(\.id))
            }
            saveError = nil
        } catch {
            valuesBrought = previousBrought
            valuesSought = previousSought
            saveError = error.localizedDescription
        }
    }

    // MARK: - Questions (answer editing)

    func saveAnswer(userId: String, questionId: String, optionId: String) async {
        let previous = answers[questionId]
        answers[questionId] = optionId

        do {
            try await questionsService.saveAnswer(
                userId: userId,
                questionId: questionId,
                optionId: optionId
            )
            saveError = nil
        } catch {
            if let previous {
                answers[questionId] = previous
            } else {
                answers.removeValue(forKey: questionId)
            }
            saveError = error.localizedDescription
        }
    }

    var unansweredQuestionsForActiveSide: [Question] {
        let relevant = allQuestions.filter { q in
            switch side {
            case .need:  return q.weighting == .need  || q.weighting == .both
            case .bring: return q.weighting == .bring || q.weighting == .both
            }
        }
        return relevant
            .filter { answers[$0.id] == nil }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Blurb

    func generateBlurb(userId: String) async {
        guard !valuesBrought.isEmpty || !valuesSought.isEmpty else {
            blurbError = "Pick at least one value first."
            return
        }

        isGeneratingBlurb = true
        defer { isGeneratingBlurb = false }
        blurbError = nil

        do {
            let blurb = try await blurbService.generateBlurb(brought: valuesBrought, sought: valuesSought)
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: ["values_blurb": .string(blurb)]
            )
            if let updated {
                profile = updated
            } else {
                profile?.valuesBlurb = blurb
            }
        } catch {
            blurbError = error.localizedDescription
        }
    }

    // MARK: - Display toggles

    enum DisplayToggle {
        case brought, sought, blurb, graph

        var column: String {
            switch self {
            case .brought: return "show_values_brought"
            case .sought:  return "show_values_sought"
            case .blurb:   return "show_values_blurb"
            case .graph:   return "show_values_graph"
            }
        }
    }

    func setDisplayToggle(userId: String, key: DisplayToggle, isOn: Bool) async {
        let previous = profile
        applyToggleLocally(key: key, isOn: isOn)

        do {
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: [key.column: .bool(isOn)]
            )
            if let updated { profile = updated }
            toggleError = nil
        } catch {
            profile = previous
            toggleError = error.localizedDescription
        }
    }

    private func applyToggleLocally(key: DisplayToggle, isOn: Bool) {
        switch key {
        case .brought: profile?.showValuesBrought = isOn
        case .sought:  profile?.showValuesSought = isOn
        case .blurb:   profile?.showValuesBlurb = isOn
        case .graph:   profile?.showValuesGraph = isOn
        }
    }

    // MARK: - Graph side picker

    func setGraphSide(userId: String, side: Side) async {
        let previous = profile?.profileGraphSide
        profile?.profileGraphSide = side.rawValue

        do {
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: ["profile_graph_side": .string(side.rawValue)]
            )
            if let updated { profile = updated }
            toggleError = nil
        } catch {
            profile?.profileGraphSide = previous
            toggleError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 14.2: Don't commit yet — proceed to task 15**

The view that imports this file will be replaced next.

---

## Task 15: `QuestionSheetView`

**Files:**
- Create: `Harvest/Views/Values/QuestionSheetView.swift`

- [ ] **Step 15.1: Create the view**

```swift
import SwiftUI

struct QuestionSheetView: View {
    let authViewModel: AuthViewModel
    let viewModel: ValuesViewModel

    @Environment(\.dismiss) private var dismiss

    private var queue: [Question] { viewModel.unansweredQuestionsForActiveSide }
    private var current: Question? { queue.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: HarvestTheme.Spacing.md) {
                if let q = current {
                    questionView(q)
                } else {
                    emptyView
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)
            .padding(.vertical, HarvestTheme.Spacing.lg)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(viewModel.side == .need ? "More about what you need" : "More about what you bring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
        }
    }

    private func questionView(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text(q.prompt)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                ForEach(q.options) { option in
                    Button {
                        guard let userId = authViewModel.currentUserId else { return }
                        Task {
                            await viewModel.saveAnswer(
                                userId: userId,
                                questionId: q.id,
                                optionId: option.id
                            )
                        }
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: "circle")
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            Text(option.label)
                                .font(HarvestTheme.Typography.bodyRegular)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(HarvestTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .fill(HarvestTheme.Colors.formBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(HarvestTheme.Colors.divider, lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text("You've answered everything for now.")
                .font(HarvestTheme.Typography.h4)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("New questions will appear here as they're added.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(HarvestTheme.Typography.buttonText)
                    .foregroundStyle(HarvestTheme.Colors.textOnCream)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 15.2: Don't commit yet — proceed to task 16**

---

## Task 16: Replace `ValuesView` body

**Files:**
- Modify: `Harvest/Views/Values/ValuesView.swift`

- [ ] **Step 16.1: Replace the whole file**

```swift
import SwiftUI

struct ValuesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = ValuesViewModel()
    @State private var tipsViewModel = TipsViewModel()
    @State private var showQuestionSheet = false

    private let chipSurface = Color(hex: "5F2039")
    private let chipSelected = Color(hex: "C67E95")
    private let chipBorder = HarvestTheme.Colors.harvestCream.opacity(0.2)
    private let cardSurface = Color(hex: "5A1B33")
    private let cardBorder = HarvestTheme.Colors.harvestCream.opacity(0.16)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    topModePicker

                    switch viewModel.mode {
                    case .main:
                        mainContent
                    case .tips:
                        tipsSection
                    }
                }
                .padding(.vertical)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(HarvestTheme.Colors.accent)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.load(userId: userId)
                }
            }
            .sheet(isPresented: $showQuestionSheet) {
                QuestionSheetView(authViewModel: authViewModel, viewModel: viewModel)
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Mode + Side pickers

    private var topModePicker: some View {
        Picker("", selection: $viewModel.mode) {
            Text("Main").tag(ValuesViewModel.Mode.main)
            Text("Tips").tag(ValuesViewModel.Mode.tips)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var sidePicker: some View {
        Picker("", selection: $viewModel.side) {
            Text("I Need").tag(ValuesViewModel.Side.need)
            Text("I Bring").tag(ValuesViewModel.Side.bring)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: HarvestTheme.Spacing.lg) {
            sidePicker
            radarCard
            moreQuestionsButton
            valuesPicker
            blurbSection
            displayTogglesSection
        }
    }

    private var radarCard: some View {
        ValuesRadarCard(
            primary: viewModel.activeScores,
            primaryLabel: viewModel.side == .need ? "I Need" : "I Bring",
            onEmptyTap: { showQuestionSheet = true }
        )
        .padding(.horizontal)
    }

    private var moreQuestionsButton: some View {
        Button {
            showQuestionSheet = true
        } label: {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                Text("More questions")
            }
            .font(HarvestTheme.Typography.buttonText)
            .foregroundStyle(HarvestTheme.Colors.textOnCream)
            .padding(.horizontal, HarvestTheme.Spacing.lg)
            .padding(.vertical, HarvestTheme.Spacing.sm)
            .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
        }
    }

    private var valuesPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text(viewModel.side == .need ? "Values I Need" : "Values I Bring")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                Text("Pick up to 5.")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)

                let grouped = Dictionary(grouping: viewModel.allValues) { $0.category }
                let sortedCategories = grouped.keys.sorted()

                ForEach(sortedCategories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                        Text(category.capitalized)
                            .font(HarvestTheme.Typography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                            ForEach(grouped[category] ?? [], id: \.id) { value in
                                ChipView(
                                    title: value.name,
                                    isSelected: viewModel.activeValueIds.contains(value.id)
                                ) {
                                    if let userId = authViewModel.currentUserId {
                                        Task { await viewModel.toggleValue(userId: userId, valueId: value.id) }
                                    }
                                }
                            }
                        }
                    }
                }

                if let err = viewModel.saveError {
                    Text(err)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private var blurbSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Your Blurb")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if let blurb = viewModel.profile?.valuesBlurb, !blurb.isEmpty {
                    Text(blurb)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                } else {
                    Text("Generate a blurb that describes the values you bring and seek.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }

                HStack {
                    Spacer()
                    if viewModel.isGeneratingBlurb {
                        ProgressView().tint(HarvestTheme.Colors.accent)
                    } else {
                        Button {
                            if let userId = authViewModel.currentUserId {
                                Task { await viewModel.generateBlurb(userId: userId) }
                            }
                        } label: {
                            Text(viewModel.profile?.valuesBlurb?.isEmpty == false ? "Regenerate" : "Generate")
                                .font(HarvestTheme.Typography.buttonText)
                                .foregroundStyle(HarvestTheme.Colors.textOnCream)
                                .padding(.horizontal, HarvestTheme.Spacing.md)
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                                .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
                        }
                        .disabled(viewModel.valuesBrought.isEmpty && viewModel.valuesSought.isEmpty)
                    }
                }

                if let error = viewModel.blurbError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private var displayTogglesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Show on Profile")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                toggleRow(label: "Values I Bring",
                          isOn: Binding(get: { viewModel.profile?.showValuesBrought ?? true },
                                        set: { setToggle(.brought, $0) }))
                toggleRow(label: "Values I Seek",
                          isOn: Binding(get: { viewModel.profile?.showValuesSought ?? true },
                                        set: { setToggle(.sought, $0) }))
                toggleRow(label: "Generated Blurb",
                          isOn: Binding(get: { viewModel.profile?.showValuesBlurb ?? true },
                                        set: { setToggle(.blurb, $0) }))
                toggleRow(label: "Values Graph",
                          isOn: Binding(get: { viewModel.profile?.showValuesGraph ?? true },
                                        set: { setToggle(.graph, $0) }))

                if viewModel.profile?.showValuesGraph ?? true {
                    HStack {
                        Text("Graph side")
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        Spacer()
                        Picker("", selection: graphSideBinding) {
                            Text("Need").tag(ValuesViewModel.Side.need)
                            Text("Bring").tag(ValuesViewModel.Side.bring)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                    }
                }

                if let error = viewModel.toggleError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private var graphSideBinding: Binding<ValuesViewModel.Side> {
        Binding(
            get: {
                ValuesViewModel.Side(rawValue: viewModel.profile?.profileGraphSide ?? "bring") ?? .bring
            },
            set: { newSide in
                guard let userId = authViewModel.currentUserId else { return }
                Task { await viewModel.setGraphSide(userId: userId, side: newSide) }
            }
        )
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
        }
        .tint(HarvestTheme.Colors.accent)
    }

    private func setToggle(_ key: ValuesViewModel.DisplayToggle, _ value: Bool) {
        guard let userId = authViewModel.currentUserId else { return }
        Task { await viewModel.setDisplayToggle(userId: userId, key: key, isOn: value) }
    }

    // MARK: - Tips (embedded)

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
            Text("Values-Based Dating Tips")
                .font(HarvestTheme.Typography.h3)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    tipsChip(title: "All", isSelected: tipsViewModel.selectedCategory == nil) {
                        tipsViewModel.selectedCategory = nil
                    }
                    ForEach(TipsViewModel.TipCategory.allCases, id: \.rawValue) { category in
                        tipsChip(title: category.rawValue, isSelected: tipsViewModel.selectedCategory == category) {
                            tipsViewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }

            VStack(spacing: HarvestTheme.Spacing.md) {
                ForEach(tipsViewModel.filteredTips) { tip in
                    tipsCard {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                            HStack(spacing: HarvestTheme.Spacing.sm) {
                                Image(systemName: tip.icon)
                                    .font(.title3)
                                    .foregroundStyle(HarvestTheme.Colors.harvestCream)
                                Text(tip.title)
                                    .font(HarvestTheme.Typography.h4)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                Spacer()
                                Text(tip.category.rawValue)
                                    .font(HarvestTheme.Typography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(HarvestTheme.Colors.textOnCream)
                                    .padding(.horizontal, HarvestTheme.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
                            }
                            Text(tip.body)
                                .font(HarvestTheme.Typography.bodySmall)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary.opacity(0.92))
                        }
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Quick Advice")
                    .font(HarvestTheme.Typography.h3)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal)
                ForEach(TipsViewModel.faqs) { faq in
                    tipsCard(padding: HarvestTheme.Spacing.sm) {
                        DisclosureGroup {
                            Text(faq.answer)
                                .font(HarvestTheme.Typography.bodySmall)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                .padding(.top, HarvestTheme.Spacing.sm)
                        } label: {
                            Text(faq.question)
                                .font(HarvestTheme.Typography.bodyRegular)
                                .fontWeight(.medium)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        }
                        .tint(HarvestTheme.Colors.harvestCream)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func tipsChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? HarvestTheme.Colors.textOnCream : HarvestTheme.Colors.harvestCream)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    Capsule()
                        .fill(isSelected ? chipSelected : chipSurface)
                        .overlay { Capsule().stroke(chipBorder, lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
    }

    private func tipsCard<Content: View>(padding: CGFloat = HarvestTheme.Spacing.md, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                    .fill(cardSurface)
                    .overlay { RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg).stroke(cardBorder, lineWidth: 1) }
            }
    }
}
```

- [ ] **Step 16.2: Delete the old ValuesQuestionnaireView**

```
git rm Harvest/Views/Gardener/ValuesQuestionnaireView.swift
```

- [ ] **Step 16.3: Verify build**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: build will FAIL only because of `ProfileView` and `ProfileDetailView` still using the old `ValuesRadarCard(brought:sought:)` initializer. Fixed in tasks 17 and 18.

- [ ] **Step 16.4: Don't commit yet — proceed to task 17**

---

## Task 17: Update `ProfileViewModel` to load axis data

**Files:**
- Modify: `Harvest/ViewModels/ProfileViewModel.swift`

- [ ] **Step 17.1: Add new properties**

In `Harvest/ViewModels/ProfileViewModel.swift`, immediately after the existing line 32 (`var valuesSought: [Value]?`), add:

```swift
    var allQuestions: [Question] = []
    var answers: [String: String] = [:]
```

And immediately after line 35 (`private let valuesService = ValuesService()`), add:

```swift
    private let questionsService = QuestionsService()

    var axisScores: (need: AxisScores, bring: AxisScores) {
        AxisScoring.computeVectors(answers: answers, questions: allQuestions)
    }
```

- [ ] **Step 17.2: Load questions + answers in `loadProfile`**

Inside `loadProfile(userId:)`, immediately after the `valuesSought` load block (currently ends at line 59 with `valuesSought = []`), insert:

```swift
            do {
                allQuestions = try await questionsService.getAllQuestions()
            } catch {
                print("Warning: Failed to load questions: \(error)")
                allQuestions = []
            }

            do {
                answers = try await questionsService.getUserAnswers(userId: userId)
            } catch {
                print("Warning: Failed to load answers: \(error)")
                answers = [:]
            }
```

- [ ] **Step 17.3: Verify build of the scheme**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: still failing on `ProfileView` and `ProfileDetailView` radar call sites — those are fixed in tasks 18 and 19.

- [ ] **Step 17.4: Don't commit yet — proceed to task 18**

---

## Task 18: Update `ProfileView` radar call site

**Files:**
- Modify: `Harvest/Views/Profile/ProfileView.swift`

- [ ] **Step 18.1: Replace the radar block**

Find lines around 157–162 where `ValuesRadarCard(brought:sought:)` is constructed and replace with:

```swift
                    if (viewModel.profile?.showValuesGraph ?? true) {
                        let side = ValuesViewModel.Side(
                            rawValue: viewModel.profile?.profileGraphSide ?? "bring"
                        ) ?? .bring
                        let scores = (side == .need)
                            ? viewModel.axisScores.need
                            : viewModel.axisScores.bring
                        if !scores.isZero {
                            ValuesRadarCard(
                                primary: scores,
                                primaryLabel: side == .need ? "I Need" : "I Bring"
                            )
                            .padding(.horizontal)
                        }
                    }
```

Remove any other reference to the previous `ValuesRadarCard(brought:sought:)` initializer in this file. Keep the chip rows for `valuesBrought` / `valuesSought` as-is.

- [ ] **Step 18.2: Don't commit yet — proceed to task 19**

---

## Task 19: Update `ProfileDetailView` radar call site

**Files:**
- Modify: `Harvest/Views/Discover/ProfileDetailView.swift`

- [ ] **Step 19.1: Add question + answer state to the view**

Near the existing `@State private var valuesBrought: [Value] = []` / `valuesSought: [Value] = []` (lines 6–7), add:

```swift
    @State private var allQuestions: [Question] = []
    @State private var otherAnswers: [String: String] = [:]

    private let questionsService = QuestionsService()
```

- [ ] **Step 19.2: Load them in the existing `.task` block**

Find the `.task` modifier where `valuesService.getUserValuesBrought` is called (around line 166). After those lines, append:

```swift
                allQuestions = (try? await questionsService.getAllQuestions()) ?? []
                otherAnswers = (try? await questionsService.getUserAnswers(userId: profile.id)) ?? [:]
```

- [ ] **Step 19.3: Replace the radar block**

Find lines 152–155 where `ValuesRadarCard(brought:sought:)` is constructed and replace with:

```swift
                        if (profile.showValuesGraph ?? true) {
                            let side = ValuesViewModel.Side(
                                rawValue: profile.profileGraphSide ?? "bring"
                            ) ?? .bring
                            let vectors = AxisScoring.computeVectors(
                                answers: otherAnswers,
                                questions: allQuestions
                            )
                            let scores = (side == .need) ? vectors.need : vectors.bring
                            if !scores.isZero {
                                ValuesRadarCard(
                                    primary: scores,
                                    primaryLabel: side == .need ? "I Need" : "I Bring"
                                )
                            }
                        }
```

- [ ] **Step 19.4: Verify the whole build now**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 19.5: Commit tasks 10, 14, 15, 16, 17, 18, 19 together**

```
git add Harvest/Views/Components/ValuesRadarCard.swift \
        Harvest/ViewModels/ValuesViewModel.swift \
        Harvest/Views/Values/QuestionSheetView.swift \
        Harvest/Views/Values/ValuesView.swift \
        Harvest/ViewModels/ProfileViewModel.swift \
        Harvest/Views/Profile/ProfileView.swift \
        Harvest/Views/Discover/ProfileDetailView.swift
git rm Harvest/Views/Gardener/ValuesQuestionnaireView.swift
git commit -m "feat(values): 5-axis radar across Values tab and profile views

- Rewrite ValuesRadarCard with 5 fixed axes and single-polygon default
- Add ValuesViewModel mode/side state, questions + answers loading
- Tips/Main top segmented + Need/Bring inner segmented in ValuesView
- QuestionSheetView for 'More questions' flow
- Profile and ProfileDetail render the chosen-side polygon via profile_graph_side
- Drop the old ValuesQuestionnaireView (replaced by inline picker)"
```

---

## Task 20: Run the test suite end-to-end

**Files:** none

- [ ] **Step 20.1: Run all tests**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: All tests PASS, including `AxisScoresTests`, `QuestionScoringTests`, and `CompatibilityServiceTests`.

- [ ] **Step 20.2: If any tests fail**

Fix the failures by re-reading the relevant task. Do not move on with a red suite.

- [ ] **Step 20.3: No commit (tests only)**

---

## Task 21: SQL migration + seed

**Files:**
- Create: `supabase/migrations/20260523120000_values_questionnaire.sql`

- [ ] **Step 21.1: Write the migration**

```sql
-- 1. Schema

create table questions (
  id text primary key,
  prompt text not null,
  weighting text not null check (weighting in ('need','bring','both')),
  display_order int not null,
  created_at timestamptz default now()
);

create table question_options (
  id text primary key,
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

alter table users
  add column profile_graph_side text default 'bring'
    check (profile_graph_side in ('need','bring'));

-- 2. RLS

alter table user_question_answers enable row level security;

create policy "answers_self_read" on user_question_answers
  for select using (auth.uid() = user_id);
create policy "answers_self_write" on user_question_answers
  for insert with check (auth.uid() = user_id);
create policy "answers_self_update" on user_question_answers
  for update using (auth.uid() = user_id);

-- 3. Seed: 10 questions + 50 options

insert into questions (id, prompt, weighting, display_order) values
  ('q1',  'After a hard day, what would help you feel most cared for?',                   'need',  1),
  ('q2',  'Someone disappoints you. What helps repair the moment most?',                  'need',  2),
  ('q3',  'You are starting to trust someone. What makes that trust grow?',               'both',  3),
  ('q4',  'During conflict, what matters most to you?',                                    'need',  4),
  ('q5',  'When you picture long-term love, what feels most important?',                  'need',  5),
  ('q6',  'Someone you care about is stressed. What feels most natural to you?',          'bring', 6),
  ('q7',  'What makes someone feel emotionally mature to you?',                            'both',  7),
  ('q8',  'What keeps you invested when dating gets real?',                                'need',  8),
  ('q9',  'What makes a relationship feel safe enough to deepen?',                         'need',  9),
  ('q10', 'What would make you feel proud to choose someone?',                             'both',  10);

insert into question_options (id, question_id, label, axis, display_order) values
  ('q1_a','q1','They really listen before responding.',                'emotional_intelligence', 1),
  ('q1_b','q1','They stay calm and steady with me.',                   'stability',              2),
  ('q1_c','q1','They make it feel safe to be fully myself.',           'integrity',              3),
  ('q1_d','q1','They pull me close and make time for me.',             'connection',             4),
  ('q1_e','q1','They help me see a way forward.',                      'growth',                 5),

  ('q2_a','q2','They understand why it hurt.',                         'emotional_intelligence', 1),
  ('q2_b','q2','They show up better next time.',                       'stability',              2),
  ('q2_c','q2','They own their part clearly.',                         'integrity',              3),
  ('q2_d','q2','They make time to reconnect.',                         'connection',             4),
  ('q2_e','q2','They want to learn from it.',                          'growth',                 5),

  ('q3_a','q3','They notice what you feel.',                           'emotional_intelligence', 1),
  ('q3_b','q3','Their energy stays steady.',                           'stability',              2),
  ('q3_c','q3','Their actions match their words.',                     'integrity',              3),
  ('q3_d','q3','You feel close and wanted.',                           'connection',             4),
  ('q3_e','q3','They keep growing through life.',                      'growth',                 5),

  ('q4_a','q4','They try to understand you.',                          'emotional_intelligence', 1),
  ('q4_b','q4','They slow the moment down.',                           'stability',              2),
  ('q4_c','q4','They take ownership.',                                 'integrity',              3),
  ('q4_d','q4','They come back toward you emotionally.',               'connection',             4),
  ('q4_e','q4','They care more about growing than winning.',           'growth',                 5),

  ('q5_a','q5','Feeling emotionally known.',                           'emotional_intelligence', 1),
  ('q5_b','q5','Knowing I can count on how they show up.',             'stability',              2),
  ('q5_c','q5','Feeling secure in their character.',                   'integrity',              3),
  ('q5_d','q5','Feeling wanted and close.',                            'connection',             4),
  ('q5_e','q5','Feeling like you are building something meaningful.',  'growth',                 5),

  ('q6_a','q6','Help them feel understood.',                           'emotional_intelligence', 1),
  ('q6_b','q6','Help steady the situation.',                           'stability',              2),
  ('q6_c','q6','Help them face the situation honestly.',               'integrity',              3),
  ('q6_d','q6','Offer warmth and closeness.',                          'connection',             4),
  ('q6_e','q6','Encourage their next step.',                           'growth',                 5),

  ('q7_a','q7','They can read the room emotionally.',                  'emotional_intelligence', 1),
  ('q7_b','q7','They stay steady under pressure.',                     'stability',              2),
  ('q7_c','q7','They admit when they were wrong.',                     'integrity',              3),
  ('q7_d','q7','They keep reaching toward the people they love.',      'connection',             4),
  ('q7_e','q7','They reflect and adjust.',                             'growth',                 5),

  ('q8_a','q8','They care about your inner world.',                    'emotional_intelligence', 1),
  ('q8_b','q8','Their effort stays steady.',                           'stability',              2),
  ('q8_c','q8','The way they handle people feels trustworthy.',        'integrity',              3),
  ('q8_d','q8','The bond feels alive.',                                'connection',             4),
  ('q8_e','q8','You see shared direction.',                            'growth',                 5),

  ('q9_a','q9','You feel emotionally understood.',                     'emotional_intelligence', 1),
  ('q9_b','q9','Their presence feels steady over time.',               'stability',              2),
  ('q9_c','q9','You trust how they handle hard things.',               'integrity',              3),
  ('q9_d','q9','You feel wanted in their life.',                       'connection',             4),
  ('q9_e','q9','You feel like the relationship has purpose.',          'growth',                 5),

  ('q10_a','q10','Their care for people is genuine.',                  'emotional_intelligence', 1),
  ('q10_b','q10','Their life feels steady and dependable.',            'stability',              2),
  ('q10_c','q10','Their character shows when things are hard.',        'integrity',              3),
  ('q10_d','q10','They make love feel warm and alive.',                'connection',             4),
  ('q10_e','q10','They keep becoming a better version of themselves.', 'growth',                 5);
```

- [ ] **Step 21.2: Apply the migration**

Apply via the Supabase CLI (`supabase db push`) or by pasting the SQL into the Supabase dashboard SQL editor. The migration file in git is a record; running the file is a separate step.

- [ ] **Step 21.3: Smoke test against the live DB**

In the running app on the simulator:
1. Sign up as a new user, complete onboarding through the reflections step.
2. After onboarding, open the Values tab. Verify the radar shows a polygon (not the empty state).
3. Tap "More questions". Verify the sheet shows the empty "You've answered everything for now" state (because onboarding covered all 10).
4. Open Profile. Verify the single-polygon radar matches the Values tab.
5. Toggle "Values Graph" off — radar card disappears.
6. Toggle it back on; switch graph side; verify the Profile radar updates.
7. As an existing user (one without `user_question_answers` rows) — open Values tab. Verify the radar shows the empty "Answer a few questions..." state with a Start button. Tap Start; sheet opens with the 10 questions queued.

- [ ] **Step 21.4: Commit**

```
git add supabase/migrations/20260523120000_values_questionnaire.sql
git commit -m "db(migration): values questionnaire tables, RLS, and seed"
```

---

## Self-Review Checklist (run after writing the plan)

- [x] **Spec coverage:** Each spec section maps to one or more tasks: §1 → T1, T5, T21; §2 → T2, T3, T6, T7; §3 → T11–T13; §4 → T14, T16; §5 → T15; §6 → T10; §7 → T17–T19; §8 → T4, T6, T7; §9 → T21; §10 → empty-state handling in T10, T16; §11/§12 reflected throughout; §13 → T2, T3, T9.
- [x] **No placeholders:** Each code block is complete; no "TODO" / "fill in" remains.
- [x] **Type consistency:** `AxisScores`, `AxisScoring.computeVectors`, `ValueAxis`, `QuestionWeighting`, `ValuesViewModel.Side`, `ValuesViewModel.Mode` are named identically wherever referenced.
- [x] **Test fail-first:** Tasks 2, 3 write failing tests before implementation. Task 9 updates tests in the same commit as the rewrite (which is acceptable since they're a single behavior change verified by the existing test names).
