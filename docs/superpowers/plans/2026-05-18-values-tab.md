# Values Tab + Mindful Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Matches tab with a new Values tab (questionnaire, radar graph, AI blurb, profile display toggles, values-based tips). Merge the old Matches and Chat tabs into a single Mindful Messages tab. Simplify the Gardener tab to pure AI chat.

**Architecture:** Pure SwiftUI on top of existing `ValuesService`, `ProfileService`, and `OpenAIService`. One new view (`ValuesView`) + one new component (`ValuesRadarCard`) + one new service (`BlurbService`) + one merged inbox view (`MindfulMessagesView`). Five new columns on the `users` table.

**Tech Stack:** Swift 5.9+, SwiftUI, Supabase Swift SDK, XCTest, Supabase Postgres.

**Spec:** `docs/superpowers/specs/2026-05-18-values-tab-design.md`.

---

## File Map

**New files:**
- `supabase/migrations/<timestamp>_values_blurb_and_display_toggles.sql`
- `Harvest/Services/BlurbService.swift`
- `Harvest/Views/Components/ValuesRadarCard.swift`
- `Harvest/ViewModels/ValuesViewModel.swift`
- `Harvest/Views/Values/ValuesView.swift`
- `Harvest/ViewModels/MindfulMessagesViewModel.swift` (renamed from `MatchesViewModel.swift`)
- `Harvest/Views/Chat/MindfulMessagesView.swift`
- `HarvestTests/Services/BlurbServiceTests.swift`

**Modified files:**
- `Harvest/Models/UserProfile.swift` (5 new fields)
- `Harvest/Views/MainTabView.swift` (tab restructure)
- `Harvest/Views/Gardener/GardenerChatView.swift` (drop segments)
- `Harvest/Views/Profile/ProfileView.swift` (blurb + radar + gates)
- `Harvest/Views/Discover/ProfileDetailView.swift` (same gates)
- `Harvest/ViewModels/TipsViewModel.swift` (copy edits)

**Deleted files:**
- `Harvest/Views/Matches/MatchesView.swift`
- `Harvest/Views/Chat/ChatListView.swift`

---

## Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/20260518120000_values_blurb_and_display_toggles.sql`

- [ ] **Step 1: Create the migrations directory and SQL file**

```bash
mkdir -p supabase/migrations
```

Write `supabase/migrations/20260518120000_values_blurb_and_display_toggles.sql`:

```sql
alter table users
  add column values_blurb text,
  add column show_values_brought boolean default true,
  add column show_values_sought boolean default true,
  add column show_values_blurb boolean default true,
  add column show_values_graph boolean default true;
```

- [ ] **Step 2: Apply the migration to Supabase**

This file is reference; it does not auto-run. Apply via one of:

- **Dashboard:** Open the Supabase SQL editor and run the file's contents against the project's database.
- **CLI (if configured):** `supabase db push` from the repo root.

After applying, verify in the SQL editor:

```sql
select column_name, data_type, column_default
from information_schema.columns
where table_name = 'users'
  and column_name in (
    'values_blurb',
    'show_values_brought',
    'show_values_sought',
    'show_values_blurb',
    'show_values_graph'
  );
```

Expected: five rows, four booleans with `true` default and one `text` with no default.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260518120000_values_blurb_and_display_toggles.sql
git commit -m "feat(db): add values_blurb and four display-toggle columns to users"
```

---

## Task 2: Extend `UserProfile`

**Files:**
- Modify: `Harvest/Models/UserProfile.swift`

- [ ] **Step 1: Add the five fields and CodingKeys**

In `UserProfile.swift`, after the existing `var updatedAt: String?` line, add:

```swift
    var valuesBlurb: String?
    var showValuesBrought: Bool?
    var showValuesSought: Bool?
    var showValuesBlurb: Bool?
    var showValuesGraph: Bool?
```

In the same struct, extend `CodingKeys` (replace the existing enum block) with:

```swift
    enum CodingKeys: String, CodingKey {
        case id, email, nickname, age, bio, location, gender, preferences, goals, hobbies, photos
        case distancePreference = "distance_preference"
        case interestedIn = "interested_in"
        case lookingFor = "looking_for"
        case heightCm = "height_cm"
        case smoking
        case drinking
        case cannabis
        case spiritualOrientation = "spiritual_orientation"
        case childrenStatus = "children_status"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case valuesBlurb = "values_blurb"
        case showValuesBrought = "show_values_brought"
        case showValuesSought = "show_values_sought"
        case showValuesBlurb = "show_values_blurb"
        case showValuesGraph = "show_values_graph"
    }
```

- [ ] **Step 2: Build to verify the model compiles**

In Xcode: `Product → Build` (or `xcodebuild -scheme Harvest build`). Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Models/UserProfile.swift
git commit -m "feat: add values blurb and display-toggle fields to UserProfile"
```

---

## Task 3: `BlurbService`

**Files:**
- Create: `Harvest/Services/BlurbService.swift`
- Create: `HarvestTests/Services/BlurbServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `HarvestTests/Services/BlurbServiceTests.swift`:

```swift
import XCTest
@testable import Harvest

final class BlurbServiceTests: XCTestCase {
    func testGenerateBlurb_TrimsWhitespace() async throws {
        let service = BlurbService(chat: { _ in
            "   I value honesty.\n\n"
        })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]
        let sought: [Value] = []

        let result = try await service.generateBlurb(brought: brought, sought: sought)

        XCTAssertEqual(result, "I value honesty.")
    }

    func testGenerateBlurb_CapsAtLengthLimit() async throws {
        let longResponse = String(repeating: "a", count: 500)
        let service = BlurbService(chat: { _ in longResponse })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]

        let result = try await service.generateBlurb(brought: brought, sought: [])

        XCTAssertEqual(result.count, 280)
    }

    func testGenerateBlurb_PropagatesErrors() async {
        struct StubError: Error {}
        let service = BlurbService(chat: { _ in throw StubError() })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]

        do {
            _ = try await service.generateBlurb(brought: brought, sought: [])
            XCTFail("Expected error")
        } catch is StubError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateBlurb_IncludesValueNamesInPrompt() async throws {
        var capturedMessages: [OpenAIService.ChatMessage] = []
        let service = BlurbService(chat: { messages in
            capturedMessages = messages
            return "ok"
        })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]
        let sought = [Value(id: "2", name: "Curiosity", category: "personal growth", displayOrder: 0)]

        _ = try await service.generateBlurb(brought: brought, sought: sought)

        let combined = capturedMessages.map(\.content).joined(separator: "\n")
        XCTAssertTrue(combined.contains("Honesty"))
        XCTAssertTrue(combined.contains("Curiosity"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/BlurbServiceTests`

Expected: compilation failure — `BlurbService` does not exist.

- [ ] **Step 3: Implement `BlurbService`**

Create `Harvest/Services/BlurbService.swift`:

```swift
import Foundation

struct BlurbService {
    typealias ChatProvider = (_ messages: [OpenAIService.ChatMessage]) async throws -> String

    private static let maxLength = 280
    private static let systemPrompt = """
    You write short, warm, first-person dating-profile blurbs based on the values someone brings and the values they seek.

    Rules:
    - 2 to 3 sentences, max 280 characters total.
    - First person ("I bring...", "I'm drawn to...").
    - No preamble, no quotes, no markdown. Plain prose only.
    - Reference the values naturally — do not list them like a bullet list.
    """

    private let chat: ChatProvider

    init(chat: @escaping ChatProvider = { messages in
        try await OpenAIService().sendChat(messages: messages)
    }) {
        self.chat = chat
    }

    func generateBlurb(brought: [Value], sought: [Value]) async throws -> String {
        let broughtList = brought.map(\.name).joined(separator: ", ")
        let soughtList = sought.map(\.name).joined(separator: ", ")

        let userPrompt = """
        Values I bring: \(broughtList.isEmpty ? "(none selected)" : broughtList)
        Values I seek: \(soughtList.isEmpty ? "(none selected)" : soughtList)

        Write the blurb now.
        """

        let messages: [OpenAIService.ChatMessage] = [
            .init(role: "system", content: Self.systemPrompt),
            .init(role: "user", content: userPrompt)
        ]

        let response = try await chat(messages)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= Self.maxLength {
            return trimmed
        }
        return String(trimmed.prefix(Self.maxLength))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HarvestTests/BlurbServiceTests`

Expected: all four tests pass.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Services/BlurbService.swift HarvestTests/Services/BlurbServiceTests.swift
git commit -m "feat: add BlurbService for AI-generated values blurbs"
```

---

## Task 4: `ValuesRadarCard` Component

**Files:**
- Create: `Harvest/Views/Components/ValuesRadarCard.swift`

- [ ] **Step 1: Implement the component**

Create `Harvest/Views/Components/ValuesRadarCard.swift`:

```swift
import SwiftUI

struct ValuesRadarCard: View {
    let brought: [Value]
    let sought: [Value]

    private var axes: [String] {
        let union = Set(brought.map(\.category)).union(sought.map(\.category))
        return union.sorted()
    }

    private func count(in values: [Value], category: String) -> Int {
        values.filter { $0.category == category }.count
    }

    private let maxPerAxis: Double = 5

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Your Values Map")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if axes.isEmpty {
                    Text("Pick a few values to see your map.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        let center = CGPoint(x: geo.size.width / 2, y: size / 2)
                        let radius = (size / 2) - 32

                        Canvas { context, _ in
                            drawGrid(context: context, center: center, radius: radius)
                            drawAxisLabels(context: context, center: center, radius: radius)
                            drawPolygon(
                                context: context,
                                center: center,
                                radius: radius,
                                counts: axes.map { count(in: sought, category: $0) },
                                stroke: HarvestTheme.Colors.accent,
                                fill: HarvestTheme.Colors.accent.opacity(0.3)
                            )
                            drawPolygon(
                                context: context,
                                center: center,
                                radius: radius,
                                counts: axes.map { count(in: brought, category: $0) },
                                stroke: HarvestTheme.Colors.primary,
                                fill: HarvestTheme.Colors.primary.opacity(0.3)
                            )
                        }
                    }
                    .frame(height: 280)

                    HStack(spacing: HarvestTheme.Spacing.lg) {
                        legendDot(color: HarvestTheme.Colors.primary, label: "I Bring")
                        legendDot(color: HarvestTheme.Colors.accent, label: "I Seek")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
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

    private func axisPoint(center: CGPoint, radius: Double, index: Int, magnitude: Double) -> CGPoint {
        let angle = (2 * .pi * Double(index) / Double(axes.count)) - .pi / 2
        let r = radius * (magnitude / maxPerAxis)
        return CGPoint(
            x: center.x + CGFloat(r * cos(angle)),
            y: center.y + CGFloat(r * sin(angle))
        )
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: Double) {
        let gridColor = HarvestTheme.Colors.textSecondary.opacity(0.25)

        for step in 1...5 {
            var path = Path()
            for i in 0..<axes.count {
                let p = axisPoint(center: center, radius: radius, index: i, magnitude: Double(step))
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        for i in 0..<axes.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: axisPoint(center: center, radius: radius, index: i, magnitude: maxPerAxis))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawAxisLabels(context: GraphicsContext, center: CGPoint, radius: Double) {
        for (i, axis) in axes.enumerated() {
            let labelPoint = axisPoint(center: center, radius: radius + 18, index: i, magnitude: maxPerAxis)
            let text = Text(axis.capitalized)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            context.draw(text, at: labelPoint, anchor: .center)
        }
    }

    private func drawPolygon(
        context: GraphicsContext,
        center: CGPoint,
        radius: Double,
        counts: [Int],
        stroke: Color,
        fill: Color
    ) {
        guard !counts.isEmpty else { return }
        var path = Path()
        for (i, count) in counts.enumerated() {
            let p = axisPoint(center: center, radius: radius, index: i, magnitude: Double(count))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: 1.5)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 3: Add a SwiftUI preview block (smoke test)**

Append to `ValuesRadarCard.swift`:

```swift
#Preview("Values Radar - mixed") {
    ValuesRadarCard(
        brought: [
            Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0),
            Value(id: "2", name: "Adventure", category: "lifestyle", displayOrder: 0),
            Value(id: "3", name: "Family", category: "social", displayOrder: 0)
        ],
        sought: [
            Value(id: "4", name: "Empathy", category: "communication", displayOrder: 0),
            Value(id: "5", name: "Ambition", category: "lifestyle", displayOrder: 0)
        ]
    )
    .padding()
    .background(HarvestTheme.Colors.background)
}

#Preview("Values Radar - empty") {
    ValuesRadarCard(brought: [], sought: [])
        .padding()
        .background(HarvestTheme.Colors.background)
}
```

Verify both previews render in Xcode's canvas (empty state shows the placeholder copy, mixed shows two polygons).

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Components/ValuesRadarCard.swift
git commit -m "feat: add ValuesRadarCard component with overlaid Bring/Seek polygons"
```

---

## Task 5: Tip Copy Curation

**Files:**
- Modify: `Harvest/ViewModels/TipsViewModel.swift`

- [ ] **Step 1: Rewrite tip and FAQ copy**

In `TipsViewModel.swift`, replace the `static let tips` array with:

```swift
    static let tips: [Tip] = [
        Tip(
            title: "Lead With Your Values",
            body: "Don't open with 'how was your day' — open with a question about something you actually value. 'What's a value you live by lately?' tells you more in one message than ten about logistics.",
            category: .conversation,
            icon: "bubble.left.and.bubble.right"
        ),
        Tip(
            title: "Show the Values You Bring",
            body: "Instead of saying 'I'm honest,' share a story that demonstrates the value. Your profile lands when your photos and bio together show what you stand for, not just what you do.",
            category: .profile,
            icon: "person.text.rectangle"
        ),
        Tip(
            title: "Trust Misalignment Signals",
            body: "When someone's actions don't match the values they claim, that's data. Slow down, ask one direct question, and trust what you hear back. Misalignment early is a gift.",
            category: .safety,
            icon: "shield.checkered"
        ),
        Tip(
            title: "Depth Over Volume",
            body: "Better to have one conversation rooted in shared values than five surface chats. Invest where the values overlap; let the rest fade without guilt.",
            category: .mindfulness,
            icon: "heart.text.clipboard"
        ),
        Tip(
            title: "Photos That Show Your Values",
            body: "One clear face shot, one full-body, and one photo of you doing something that reflects what matters to you — a meal you cooked, a place that grounds you, a project you finished.",
            category: .profile,
            icon: "photo.stack"
        ),
        Tip(
            title: "Meet in Public First",
            body: "First dates in public are about value alignment in low-stakes settings, and they're also about safety. Pick a place you'd happily go alone, and tell someone where you'll be.",
            category: .safety,
            icon: "mappin.and.ellipse"
        )
    ]
```

Replace the `static let faqs` array with:

```swift
    static let faqs: [FAQ] = [
        FAQ(
            question: "How do I lead with values without sounding stiff?",
            answer: "Anchor a value in a story or a small detail. 'I value honesty — last week I had to tell a friend a hard truth and we're closer for it' lands warmer than the abstract version."
        ),
        FAQ(
            question: "When should I suggest meeting in person?",
            answer: "Move to meeting once you've heard enough to know your values aren't going to actively clash. Usually 5–10 days of consistent messaging. Pick a low-pressure activity that lets you see who they are, not who they perform as."
        ),
        FAQ(
            question: "How do I handle rejection from someone whose values I liked?",
            answer: "Compatibility is more than overlap — it's also fit, timing, and a hundred things you can't control. Thank them, wish them well, and let the values you valued in them sharpen your sense of what's next."
        )
    ]
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Harvest/ViewModels/TipsViewModel.swift
git commit -m "feat(tips): rewrite tip and FAQ copy to lead with values-based dating"
```

---

## Task 6: Rename `MatchesViewModel` to `MindfulMessagesViewModel`

**Files:**
- Rename: `Harvest/ViewModels/MatchesViewModel.swift` → `Harvest/ViewModels/MindfulMessagesViewModel.swift`
- Modify: Every file referencing `MatchesViewModel`

- [ ] **Step 1: Find all references**

Run a project-wide search for `MatchesViewModel`. Expected callers (verify the list):

- `Harvest/Views/Matches/MatchesView.swift`
- `Harvest/Views/Chat/ChatListView.swift`

(Both views are about to be replaced anyway, but the rename should land first so the new view file can use the new name.)

- [ ] **Step 2: Rename the file via git**

```bash
git mv Harvest/ViewModels/MatchesViewModel.swift Harvest/ViewModels/MindfulMessagesViewModel.swift
```

- [ ] **Step 3: Rename the class inside**

In `Harvest/ViewModels/MindfulMessagesViewModel.swift`, replace every occurrence of `MatchesViewModel` (including the `@Observable final class MatchesViewModel { ... }` declaration) with `MindfulMessagesViewModel`. Update doc comments if they mention "matches view model" / similar.

Also add the file to the Xcode project file reference if your local Xcode project hasn't auto-detected the rename — open `Harvest.xcodeproj` in Xcode and confirm the new file is in the `ViewModels` group; if Xcode shows it red/missing, delete the missing reference and drag the renamed file back into the group.

- [ ] **Step 4: Update the two callers**

In `Harvest/Views/Matches/MatchesView.swift` line 5:

```swift
    @State private var viewModel = MindfulMessagesViewModel()
```

In `Harvest/Views/Chat/ChatListView.swift` line 5:

```swift
    @State private var viewModel = MindfulMessagesViewModel()
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Harvest/ViewModels/MindfulMessagesViewModel.swift Harvest/Views/Matches/MatchesView.swift Harvest/Views/Chat/ChatListView.swift
git commit -m "refactor: rename MatchesViewModel to MindfulMessagesViewModel"
```

---

## Task 7: `ValuesViewModel`

**Files:**
- Create: `Harvest/ViewModels/ValuesViewModel.swift`

- [ ] **Step 1: Implement the view model**

Create `Harvest/ViewModels/ValuesViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ValuesViewModel {
    var profile: UserProfile?
    var valuesBrought: [Value] = []
    var valuesSought: [Value] = []

    var isLoading = false
    var isGeneratingBlurb = false
    var loadError: String?
    var blurbError: String?
    var toggleError: String?

    private let valuesService = ValuesService()
    private let profileService = ProfileService()
    private let blurbService = BlurbService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = profileService.getProfile(userId: userId)
            async let broughtTask = valuesService.getUserValuesBrought(userId: userId)
            async let soughtTask = valuesService.getUserValuesSought(userId: userId)

            profile = try await profileTask
            valuesBrought = (try? await broughtTask) ?? []
            valuesSought = (try? await soughtTask) ?? []
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

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
        case .sought: profile?.showValuesSought = isOn
        case .blurb: profile?.showValuesBlurb = isOn
        case .graph: profile?.showValuesGraph = isOn
        }
    }

    enum DisplayToggle {
        case brought, sought, blurb, graph

        var column: String {
            switch self {
            case .brought: return "show_values_brought"
            case .sought: return "show_values_sought"
            case .blurb: return "show_values_blurb"
            case .graph: return "show_values_graph"
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Harvest/ViewModels/ValuesViewModel.swift
git commit -m "feat: add ValuesViewModel for the new Values tab"
```

---

## Task 8: `ValuesView`

**Files:**
- Create: `Harvest/Views/Values/ValuesView.swift`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p Harvest/Views/Values
```

- [ ] **Step 2: Implement the view**

Create `Harvest/Views/Values/ValuesView.swift`:

```swift
import SwiftUI

struct ValuesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = ValuesViewModel()
    @State private var tipsViewModel = TipsViewModel()

    private let chipSurface = Color(hex: "5F2039")
    private let chipSelected = Color(hex: "C67E95")
    private let chipBorder = HarvestTheme.Colors.harvestCream.opacity(0.2)
    private let cardSurface = Color(hex: "5A1B33")
    private let cardBorder = HarvestTheme.Colors.harvestCream.opacity(0.16)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    radarSection
                    blurbSection
                    bringSection
                    seekSection
                    displayTogglesSection
                    tipsSection
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
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var radarSection: some View {
        if viewModel.valuesBrought.isEmpty && viewModel.valuesSought.isEmpty {
            GlassCard {
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "chart.dots.scatter")
                        .font(.system(size: 32))
                        .foregroundStyle(HarvestTheme.Colors.accent)
                    Text("Take the questionnaire to see your values map.")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    NavigationLink {
                        ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: 0)
                    } label: {
                        Text("Start Questionnaire")
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.textOnCream)
                            .padding(.horizontal, HarvestTheme.Spacing.lg)
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                            .background {
                                Capsule().fill(HarvestTheme.Colors.harvestCream)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HarvestTheme.Spacing.md)
            }
            .padding(.horizontal)
        } else {
            ValuesRadarCard(brought: viewModel.valuesBrought, sought: viewModel.valuesSought)
                .padding(.horizontal)
        }
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
                                .background {
                                    Capsule().fill(HarvestTheme.Colors.harvestCream)
                                }
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

    private var bringSection: some View {
        valuesSection(
            title: "What I Bring",
            values: viewModel.valuesBrought,
            initialTab: 0
        )
    }

    private var seekSection: some View {
        valuesSection(
            title: "What I Seek",
            values: viewModel.valuesSought,
            initialTab: 1
        )
    }

    private func valuesSection(title: String, values: [Value], initialTab: Int) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                HStack {
                    Text(title)
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    Spacer()
                    NavigationLink {
                        ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: initialTab)
                    } label: {
                        Text("Edit")
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.accent)
                    }
                }

                if values.isEmpty {
                    Text("None selected yet.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                } else {
                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                        ForEach(values) { value in
                            ChipView(title: value.name)
                        }
                    }
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

                if let error = viewModel.toggleError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
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
                                    .background {
                                        Capsule().fill(HarvestTheme.Colors.harvestCream)
                                    }
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

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Values/ValuesView.swift
git commit -m "feat: add ValuesView with radar, blurb, edit links, display toggles, tips"
```

---

## Task 9: `MindfulMessagesView`

**Files:**
- Create: `Harvest/Views/Chat/MindfulMessagesView.swift`
- Delete: `Harvest/Views/Matches/MatchesView.swift`
- Delete: `Harvest/Views/Chat/ChatListView.swift`

- [ ] **Step 1: Implement the merged inbox**

Create `Harvest/Views/Chat/MindfulMessagesView.swift`:

```swift
import SwiftUI

struct MindfulMessagesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = MindfulMessagesViewModel()
    @State private var searchText = ""
    @State private var activeChatRoute: ChatRoute?
    @State private var selectedInboundLike: InboundLikeWithProfile?

    private var newMatches: [MatchThread] {
        viewModel.matchThreads.filter { $0.conversation == nil }
    }

    private var unifiedMessages: [InboxRow] {
        let conversationsFromMatches: [InboxRow] = viewModel.matchThreads
            .compactMap { thread in
                guard let convo = thread.conversation else { return nil }
                return InboxRow(
                    conversationId: convo.conversation.id,
                    profile: thread.match.profile,
                    matchId: thread.match.match.id,
                    lastMessagePreview: convo.conversation.lastMessagePreview,
                    lastMessageAt: convo.conversation.lastMessageAt,
                    hasReplyHighlight: convo.hasReplyHighlight
                )
            }

        let standaloneConversations: [InboxRow] = viewModel.conversations.map { convo in
            InboxRow(
                conversationId: convo.conversation.id,
                profile: convo.profile,
                matchId: convo.conversation.matchId,
                lastMessagePreview: convo.conversation.lastMessagePreview,
                lastMessageAt: convo.conversation.lastMessageAt,
                hasReplyHighlight: convo.hasReplyHighlight
            )
        }

        var seen = Set<String>()
        let merged = (conversationsFromMatches + standaloneConversations)
            .filter { row in
                guard !seen.contains(row.conversationId) else { return false }
                seen.insert(row.conversationId)
                return true
            }
            .sorted { (lhs, rhs) in
                (lhs.lastMessageAt ?? "") > (rhs.lastMessageAt ?? "")
            }

        guard !searchText.isEmpty else { return merged }
        return merged.filter { $0.profile.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    searchBar

                    if !viewModel.inboundLikes.isEmpty {
                        likesYouSection
                    }

                    if !newMatches.isEmpty {
                        newMatchesSection
                    }

                    messagesSection
                }
                .padding(.vertical, HarvestTheme.Spacing.sm)
            }
            .dismissKeyboardOnTap()
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Mindful Messages")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $activeChatRoute) { route in
                ChatDetailView(
                    authViewModel: authViewModel,
                    conversationId: route.conversationId,
                    partnerUserId: route.partnerUserId,
                    matchId: route.matchId,
                    onConversationRemoved: {
                        if let userId = authViewModel.currentUserId {
                            await viewModel.loadMatches(userId: userId)
                            await viewModel.loadConversations(userId: userId)
                        }
                    }
                )
            }
            .fullScreenCover(item: $selectedInboundLike) { inboundLike in
                ProfileDetailView(profile: inboundLike.profile) { action in
                    guard let currentUserId = authViewModel.currentUserId else { return }
                    Task {
                        await viewModel.respondToInboundLike(
                            currentUserId: currentUserId,
                            inboundLike: inboundLike,
                            action: action
                        )
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onAppear {
                Task { await refresh() }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search conversations").foregroundStyle(HarvestTheme.Colors.textTertiary)
            )
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                .tint(HarvestTheme.Colors.textOnBlack)
        }
        .padding(HarvestTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(HarvestTheme.Colors.blackSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var likesYouSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text("Likes You (\(viewModel.inboundLikes.count))")
                .font(HarvestTheme.Typography.h4)
                .padding(.horizontal)

            if viewModel.canSeeLikes {
                LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(viewModel.inboundLikes) { inboundLike in
                        Button {
                            selectedInboundLike = inboundLike
                        } label: {
                            inboundLikeRow(inboundLike)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            } else {
                PremiumGateView(
                    featureName: "See who likes you",
                    requiredTier: "Gold",
                    authViewModel: authViewModel
                )
                .frame(height: 220)
                .padding(.horizontal)
            }
        }
    }

    private var newMatchesSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text("New Matches")
                .font(HarvestTheme.Typography.h4)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HarvestTheme.Spacing.md) {
                    ForEach(newMatches) { thread in
                        Button {
                            openMatch(thread.match)
                        } label: {
                            newMatchBubble(thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text("Messages")
                .font(HarvestTheme.Typography.h4)
                .padding(.horizontal)

            if unifiedMessages.isEmpty {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 50))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    Text("No messages yet")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    Text("Start swiping to find your match")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HarvestTheme.Spacing.xl)
            } else {
                LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(unifiedMessages) { row in
                        Button {
                            openInboxRow(row)
                        } label: {
                            inboxRowView(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Row builders

    private func newMatchBubble(_ thread: MatchThread) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: thread.match.profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay { Circle().stroke(HarvestTheme.Colors.accent, lineWidth: 2) }

            Text(thread.match.profile.displayName)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
    }

    private func inboxRowView(_ row: InboxRow) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            AsyncImage(url: URL(string: row.profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Spacer()

                    if let time = row.lastMessageAt {
                        Text(formatTime(time))
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }

                Text(row.lastMessagePreview ?? "Tap to start chatting")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, HarvestTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(row.hasReplyHighlight
                      ? HarvestTheme.Colors.primary.opacity(0.12)
                      : HarvestTheme.Colors.glassFillStrong)
        }
    }

    private func inboundLikeRow(_ inboundLike: InboundLikeWithProfile) -> some View {
        GlassCard(padding: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                AsyncImage(url: URL(string: inboundLike.profile.primaryPhoto ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(HarvestTheme.Colors.divider)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(inboundLike.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text(inboundLike.swipe.action == .superLike ? "Super liked you" : "Liked you")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if inboundLike.swipe.action == .superLike {
                    GlassBadge(text: "Super Like", color: HarvestTheme.Colors.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func refresh() async {
        guard let userId = authViewModel.currentUserId else { return }
        await viewModel.loadMatches(userId: userId)
        await viewModel.loadConversations(userId: userId)
    }

    private func openMatch(_ matchWithProfile: MatchWithProfile) {
        guard let currentUserId = authViewModel.currentUserId else { return }
        Task {
            if let conversationId = await viewModel.startConversation(
                matchWithProfile: matchWithProfile,
                currentUserId: currentUserId
            ) {
                await MainActor.run {
                    activeChatRoute = ChatRoute(
                        conversationId: conversationId,
                        partnerUserId: matchWithProfile.profile.id,
                        matchId: matchWithProfile.match.id
                    )
                }
            }
        }
    }

    private func openInboxRow(_ row: InboxRow) {
        activeChatRoute = ChatRoute(
            conversationId: row.conversationId,
            partnerUserId: row.profile.id,
            matchId: row.matchId
        )
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

private struct ChatRoute: Identifiable, Hashable {
    let conversationId: String
    let partnerUserId: String
    let matchId: String?

    var id: String { conversationId }
}

private struct InboxRow: Identifiable, Hashable {
    let conversationId: String
    let profile: UserProfile
    let matchId: String?
    let lastMessagePreview: String?
    let lastMessageAt: String?
    let hasReplyHighlight: Bool

    var id: String { conversationId }

    static func == (lhs: InboxRow, rhs: InboxRow) -> Bool { lhs.conversationId == rhs.conversationId }
    func hash(into hasher: inout Hasher) { hasher.combine(conversationId) }
}
```

- [ ] **Step 2: Delete the old views**

```bash
git rm Harvest/Views/Matches/MatchesView.swift
git rm Harvest/Views/Chat/ChatListView.swift
```

If the `Harvest/Views/Matches/` directory is now empty, leave it for now; Xcode will need any remaining references cleaned up via the project file.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build fails because `MainTabView.swift` still references `MatchesView` and `ChatListView`. We fix this in Task 10.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Chat/MindfulMessagesView.swift
git commit -m "feat: add MindfulMessagesView replacing MatchesView and ChatListView"
```

---

## Task 10: Restructure `MainTabView`

**Files:**
- Modify: `Harvest/Views/MainTabView.swift`

- [ ] **Step 1: Replace the `TabView` body**

In `Harvest/Views/MainTabView.swift`, change `@State private var selection: Int = 0` to `@State private var selection: Int = 1` (Gardener at index 1 stays the default landing tab).

Replace the entire `TabView(selection: $selection) { ... }` block (lines 32–52 in the current file) with:

```swift
        TabView(selection: $selection) {
            Tab("Mindful Messages", systemImage: "bubble.left.fill", value: 0) {
                MindfulMessagesView(authViewModel: authViewModel)
            }

            Tab("The Gardener", systemImage: "leaf.fill", value: 1) {
                GardenerChatView(authViewModel: authViewModel)
            }

            Tab("Values", systemImage: "heart.text.square.fill", value: 2) {
                ValuesView(authViewModel: authViewModel)
            }

            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView(authViewModel: authViewModel)
            }

            Tab("Swipe", systemImage: "safari", value: 4) {
                DiscoverView(authViewModel: authViewModel)
            }
        }
```

Update the `DifferentiationView` `selection = 0` line in the `.fullScreenCover` block to `selection = 1` so the differentiation card still drops users onto the Gardener tab.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 3: Smoke test in simulator**

Launch the app. Verify the bottom nav shows five tabs in this order: Mindful Messages, The Gardener, Values, Profile, Swipe. The app should land on The Gardener.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/MainTabView.swift
git commit -m "feat(nav): restructure tabs — Mindful Messages, Gardener, Values, Profile, Swipe"
```

---

## Task 11: Simplify `GardenerChatView`

**Files:**
- Modify: `Harvest/Views/Gardener/GardenerChatView.swift`

- [ ] **Step 1: Remove the segmented control**

In `Harvest/Views/Gardener/GardenerChatView.swift`:

- Remove `@State private var selectedTab = 0` (line 6).
- Remove the three `private let previewSegment*` constants (lines 9–11) — they're only used by the segment control.
- Remove the `gardenerSegmentButton(_:tag:)` method entirely (lines 77–99).
- Replace the body's outer `VStack` content (the `HStack(spacing: 0) { gardenerSegmentButton... }` block and the `if selectedTab == 0 { chatView } else { TipsView() }` branch) with just `chatView`.

After edits, the body's `NavigationStack { ... }` should look like:

```swift
        NavigationStack {
            chatView
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .background(HarvestTheme.Colors.background.ignoresSafeArea())
                .navigationTitle("The Gardener")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(HarvestTheme.Colors.accent)
                    }
                }
                .task {
                    if let userId = authViewModel.currentUserId {
                        await viewModel.loadChat(userId: userId)
                        await viewModel.checkDailyQuiz(userId: userId)
                    }
                }
                .onAppear {
                    if let userId = authViewModel.currentUserId {
                        Task {
                            await viewModel.loadChat(userId: userId)
                        }
                    }
                }
                .sheet(isPresented: $viewModel.showDailyQuiz) {
                    if let quiz = viewModel.dailyQuiz {
                        DailyQuizPopup(quiz: quiz) { answer in
                            if let userId = authViewModel.currentUserId {
                                Task { await viewModel.submitQuizAnswer(userId: userId, answer: answer) }
                            }
                        }
                        .presentationDetents([.large])
                    }
                }
                .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
```

Keep the rest of the file (the `chatView` computed property, `gardenerBubble`, and the file-private `UIColor` extension) unchanged.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 3: Smoke test**

Open the Gardener tab in the simulator. Verify no segmented control appears; the screen is a single chat view. Type a message; verify the existing chat flow still works.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Gardener/GardenerChatView.swift
git commit -m "refactor(gardener): drop Chat/Tips segment, Gardener is pure AI chat"
```

---

## Task 12: Update `ProfileView`

**Files:**
- Modify: `Harvest/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add blurb display and gate sections**

In `ProfileView.swift`, inside the `GlassCard` (the info card starting at line 32), insert a new "Generated Blurb" block immediately after the `bio` block (after the `if let bio = viewModel.profile?.bio, !bio.isEmpty { ... }` block ending at line 61):

```swift
                            if (viewModel.profile?.showValuesBlurb ?? true),
                               let blurb = viewModel.profile?.valuesBlurb,
                               !blurb.isEmpty {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values Blurb")
                                        .font(HarvestTheme.Typography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                    Text(blurb)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }
```

Gate the existing "Values I Bring" block (starts at `if let values = viewModel.valuesBrought, !values.isEmpty { ... }`) by adding the toggle check. Change the conditional to:

```swift
                            if (viewModel.profile?.showValuesBrought ?? true),
                               let values = viewModel.valuesBrought, !values.isEmpty {
```

Gate the existing "Values I Seek" block the same way:

```swift
                            if (viewModel.profile?.showValuesSought ?? true),
                               let values = viewModel.valuesSought, !values.isEmpty {
```

- [ ] **Step 2: Add the radar card outside the info card**

Outside the `GlassCard` for the info card but inside the same outer `VStack`, immediately after the info card's `.padding(.horizontal)` (around line 139), insert:

```swift
                    if (viewModel.profile?.showValuesGraph ?? true),
                       (viewModel.valuesBrought?.isEmpty == false || viewModel.valuesSought?.isEmpty == false) {
                        ValuesRadarCard(
                            brought: viewModel.valuesBrought ?? [],
                            sought: viewModel.valuesSought ?? []
                        )
                        .padding(.horizontal)
                    }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 4: Smoke test**

Open the Profile tab. Verify (1) values blurb shows under the bio when present, (2) the radar card renders below the info card, (3) toggling sections off in the Values tab hides them on the Profile.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Views/Profile/ProfileView.swift
git commit -m "feat(profile): show values blurb + radar card, gate sections on toggles"
```

---

## Task 13: Update `ProfileDetailView`

**Files:**
- Modify: `Harvest/Views/Discover/ProfileDetailView.swift`

Note: `ProfileDetailView` currently does **not** render any values content. This task adds blurb, Values I Bring, Values I Seek, and the radar card — all gated on the four display toggles.

- [ ] **Step 1: Add `@State` storage for the partner's values**

In `ProfileDetailView.swift`, just below `let profile: UserProfile` and `let onSwipe: (SwipeAction) -> Void` (lines 4–5), add:

```swift
    @State private var valuesBrought: [Value] = []
    @State private var valuesSought: [Value] = []
    private let valuesService = ValuesService()
```

- [ ] **Step 2: Load values when the view appears**

Add a `.task` modifier on the outer `ZStack` (line 9). Place it immediately after the existing `.background(HarvestTheme.Colors.background.ignoresSafeArea())` call (line 115):

```swift
            .task {
                valuesBrought = (try? await valuesService.getUserValuesBrought(userId: profile.id)) ?? []
                valuesSought = (try? await valuesService.getUserValuesSought(userId: profile.id)) ?? []
            }
```

- [ ] **Step 3: Add blurb section after the "About" card**

In the inner `VStack(alignment: .leading, ...)` block (line 36), immediately after the bio `GlassCard` block (lines 64–74), add:

```swift
                        if (profile.showValuesBlurb ?? true),
                           let blurb = profile.valuesBlurb,
                           !blurb.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values Blurb")
                                        .font(HarvestTheme.Typography.h4)
                                    Text(blurb)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }
                        }
```

- [ ] **Step 4: Add Values I Bring and Values I Seek after Hobbies**

After the hobbies `GlassCard` block (lines 93–106), inside the same `VStack`, add:

```swift
                        if (profile.showValuesBrought ?? true), !valuesBrought.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values I Bring")
                                        .font(HarvestTheme.Typography.h4)
                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(valuesBrought) { value in
                                            ChipView(title: value.name)
                                        }
                                    }
                                }
                            }
                        }

                        if (profile.showValuesSought ?? true), !valuesSought.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values I Seek")
                                        .font(HarvestTheme.Typography.h4)
                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(valuesSought) { value in
                                            ChipView(title: value.name)
                                        }
                                    }
                                }
                            }
                        }
```

- [ ] **Step 5: Add the radar card after Values I Seek**

Immediately after the Values I Seek block from Step 4, still inside the same `VStack`:

```swift
                        if (profile.showValuesGraph ?? true),
                           !valuesBrought.isEmpty || !valuesSought.isEmpty {
                            ValuesRadarCard(brought: valuesBrought, sought: valuesSought)
                        }
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild build -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: build succeeds.

- [ ] **Step 7: Smoke test**

In the Swipe tab, tap a profile card to open `ProfileDetailView`. Verify (1) blurb shows when present, (2) Values I Bring / Seek chip rows show when present, (3) radar card renders when either set is non-empty, (4) toggling sections off in another user's account (test via two simulator accounts if available) hides them here.

- [ ] **Step 8: Commit**

```bash
git add Harvest/Views/Discover/ProfileDetailView.swift
git commit -m "feat(profile-detail): show blurb + values + radar card, gated on toggles"
```

---

## Task 14: Final Integration Smoke Test

**Files:** none (manual verification + cleanup)

- [ ] **Step 1: Full app smoke checklist**

In the simulator, verify each:

- Bottom nav shows: Mindful Messages, The Gardener, Values, Profile, Swipe (left-to-right).
- App lands on The Gardener on launch.
- **Gardener:** single chat surface, no segments. Daily-quiz popup still appears when due.
- **Values tab:**
  - Empty state shows the "Take the questionnaire" card when no values are selected.
  - Once values are selected, the radar renders with two overlaid polygons.
  - "Generate" creates a blurb (verify by toggling off a wifi-flaky path or stub if needed; primary verification is the success path).
  - "Edit" buttons push `ValuesQuestionnaireView` with the right initial tab.
  - All four display toggles flip and persist (kill the app, relaunch, verify state).
  - Tips chips filter; FAQ accordions expand.
- **Mindful Messages:**
  - Search bar filters Messages section.
  - "Likes You" appears at top when applicable (and Gold-gate shows when applicable).
  - "New Matches" carousel appears when there are matches without conversations.
  - Tapping a new-match bubble starts a conversation (calls existing `startConversation` flow).
  - Messages list shows merged conversations + match-thread conversations, deduplicated.
- **Profile:** values blurb + radar card show/hide per toggle settings; values chip rows show/hide per toggle.
- **ProfileDetailView (inside Swipe):** same gating as Profile.

- [ ] **Step 2: Remove the empty Matches directory (if applicable)**

If `Harvest/Views/Matches/` is now empty:

```bash
rmdir Harvest/Views/Matches 2>/dev/null || true
git add -A
```

Verify with `git status` that no unexpected file changes are staged.

- [ ] **Step 3: Run the test suite**

Run: `xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: all tests pass, including the new `BlurbServiceTests`.

- [ ] **Step 4: Commit (if anything to commit)**

```bash
git status
# If there are staged changes from Step 2:
git commit -m "chore: clean up empty Matches view directory"
```

---

## Notes for the Implementer

- **Xcode project file:** Renaming and adding Swift files via `git mv` and writing new files won't auto-add them to `Harvest.xcodeproj`. After each task that creates or renames files, open the project in Xcode and confirm the new files are members of the `Harvest` (or `HarvestTests`) target. If a file is missing or red, drag it back into its group with the correct target membership.
- **Existing patterns to follow:**
  - Use `HarvestTheme.*` for colors/spacing/typography.
  - Use `GlassCard` for card chrome.
  - Use `ChipView` for value chips.
  - Use `@Observable` view models with `@State` ownership in views.
  - Service methods take a `userId: String` and surface errors as thrown.
- **Don't introduce new packages.** Everything in this plan can be built with the existing dependency graph (SwiftUI, Supabase Swift SDK, OpenAI via existing `OpenAIService`).
- **Frequent commits.** Each task ends in a commit; that's the unit of revertability.
