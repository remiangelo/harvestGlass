# Chat Overhaul + Field Events Banner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild both chat surfaces on a shared set of visual components, add a static "community events coming soon" banner to The Field, and stop messages being sent twice.

**Architecture:** New `Harvest/Views/Components/Chat/` holds the pieces both chats need — grouping logic, bubble shape and fill, date separator, composer, backdrop. `CommunityChatView` and `ChatDetailView` become consumers of those pieces, each passing its own accent (green for Field rooms, rose for Seed chats). The double-send fix is an `isSending` flag on both view models that gates re-entry and drives the composer's third button state.

**Tech Stack:** SwiftUI, iOS 26 deployment target, Swift 5, XCTest, Supabase Realtime.

## Global Constraints

- Deployment target is **iOS 26.0**; Swift version **5.0**. `UnevenRoundedRectangle`, `.ultraThinMaterial`, and `@Observable` are all available.
- The project uses `PBXFileSystemSynchronizedRootGroup`. **Never edit `Harvest.xcodeproj/project.pbxproj`** — new files under `Harvest/` and `HarvestTests/` join their targets automatically.
- Tests use **XCTest** (`final class XTests: XCTestCase`), matching `HarvestTests/Models/AxisScoresTests.swift`. Do not use swift-testing.
- All colors, spacing, radii, and fonts come from `HarvestTheme`. No raw hex outside `HarvestTheme.swift`.
- Field rooms are **green** (`ChatAccent.field`), Seed chats are **rose** (`ChatAccent.rose`). Never mix.
- Commit after every task. Work directly on `main` (user's explicit instruction).
- The behaviours listed in §6 of the spec must survive unchanged. Re-read that list before each view task.

**Reference commands.** Pick a simulator once and reuse it:

```bash
xcrun simctl list devices available | grep iPhone   # pick one, e.g. "iPhone 17"
SIM="iPhone 17"

# Compile only (fast, no signing):
xcodebuild -project Harvest.xcodeproj -scheme Harvest \
  -destination 'generic/platform=iOS Simulator' build

# Run tests:
xcodebuild test -project Harvest.xcodeproj -scheme Harvest \
  -destination "platform=iOS Simulator,name=$SIM"
```

---

## File Structure

**Create:**
- `Harvest/Views/Components/Chat/MessageGrouping.swift` — pure grouping + timestamp parsing. No SwiftUI.
- `Harvest/Views/Components/Chat/ChatAccent.swift` — the three tints one chat surface needs.
- `Harvest/Views/Components/Chat/ChatBubbleShape.swift` — grouping-aware bubble outline.
- `Harvest/Views/Components/Chat/ChatBubbleBackground.swift` — outgoing gradient / incoming material fill.
- `Harvest/Views/Components/Chat/DateSeparator.swift` — "Today" / "Yesterday" / weekday pill.
- `Harvest/Views/Components/Chat/ChatBackdrop.swift` — plum base + two faint accent glows.
- `Harvest/Views/Components/Chat/ChatComposer.swift` — shared input with three send states.
- `Harvest/Views/Field/EventsComingSoonBanner.swift` — the Field banner.
- `HarvestTests/Views/MessageGroupingTests.swift`
- `HarvestTests/Views/DateSeparatorTests.swift`
- `docs/verification/2026-08-04-chat-overhaul-checklist.md`

**Modify:**
- `Harvest/Theme/HarvestTheme.swift` — add `fieldGreenDeep`.
- `Harvest/ViewModels/CommunityChatViewModel.swift` — `isSending`, draft lifecycle.
- `Harvest/ViewModels/ChatViewModel.swift` — `isSending`, draft lifecycle.
- `Harvest/Views/Field/CommunityChatView.swift` — adopt shared components.
- `Harvest/Views/Chat/ChatDetailView.swift` — adopt shared components.
- `Harvest/Views/Chat/MessageBubbleView.swift` — adopt shared components, grouped metadata.
- `Harvest/Views/Field/FieldView.swift` — insert the banner.

---

### Task 1: Message grouping logic

**Files:**
- Create: `Harvest/Views/Components/Chat/MessageGrouping.swift`
- Test: `HarvestTests/Views/MessageGroupingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct MessagePosition { let showsDateSeparator: Bool; let isFirstInGroup: Bool; let isLastInGroup: Bool }` and `enum MessageGrouping` with `static func date(from: String?) -> Date?`, `static func position(previousSender:previousDate:currentSender:currentDate:nextSender:nextDate:) -> MessagePosition`, and `static let groupWindow: TimeInterval`.

- [ ] **Step 1: Write the failing tests**

Create `HarvestTests/Views/MessageGroupingTests.swift`:

```swift
import XCTest
@testable import Harvest

final class MessageGroupingTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_754_000_000)  // fixed, no "now"

    private func position(
        prevSender: String?, prevOffset: TimeInterval?,
        sender: String, offset: TimeInterval?,
        nextSender: String? = nil, nextOffset: TimeInterval? = nil
    ) -> MessagePosition {
        MessageGrouping.position(
            previousSender: prevSender,
            previousDate: prevOffset.map { base.addingTimeInterval($0) },
            currentSender: sender,
            currentDate: offset.map { base.addingTimeInterval($0) },
            nextSender: nextSender,
            nextDate: nextOffset.map { base.addingTimeInterval($0) }
        )
    }

    func testGroupsWhenJustUnderFiveMinutes() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 299)
        XCTAssertFalse(p.isFirstInGroup)
    }

    func testDoesNotGroupWhenJustOverFiveMinutes() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 301)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testDoesNotGroupDifferentSenders() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "b", offset: 1)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testIsLastInGroupWhenNextIsDifferentSender() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 10,
                         nextSender: "b", nextOffset: 20)
        XCTAssertTrue(p.isLastInGroup)
    }

    func testIsNotLastInGroupWhenNextContinues() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 10,
                         nextSender: "a", nextOffset: 20)
        XCTAssertFalse(p.isLastInGroup)
    }

    func testFirstMessageInListShowsSeparator() {
        let p = position(prevSender: nil, prevOffset: nil, sender: "a", offset: 0)
        XCTAssertTrue(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testSeparatorAcrossMidnightAndNoGrouping() {
        // 23:59:30 and 00:00:30 local, one minute apart but different days.
        var cal = Calendar.current
        cal.timeZone = .current
        let midnight = cal.startOfDay(for: base.addingTimeInterval(86_400))
        let before = midnight.addingTimeInterval(-30)
        let after = midnight.addingTimeInterval(30)
        let p = MessageGrouping.position(
            previousSender: "a", previousDate: before,
            currentSender: "a", currentDate: after,
            nextSender: nil, nextDate: nil
        )
        XCTAssertTrue(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup, "a day break always starts a new group")
    }

    func testSameDayDoesNotShowSeparator() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "b", offset: 60)
        XCTAssertFalse(p.showsDateSeparator)
    }

    func testUnparseableCurrentDateStandsAlone() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: nil)
        XCTAssertTrue(p.isFirstInGroup)
        XCTAssertTrue(p.isLastInGroup)
        XCTAssertFalse(p.showsDateSeparator)
    }

    func testUnparseablePreviousDateDoesNotInventASeparator() {
        let p = position(prevSender: "a", prevOffset: nil, sender: "a", offset: 0)
        XCTAssertFalse(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testParsesTimestampWithFractionalSeconds() {
        XCTAssertNotNil(MessageGrouping.date(from: "2026-08-04T10:15:30.123456+00:00"))
    }

    func testParsesTimestampWithoutFractionalSeconds() {
        XCTAssertNotNil(MessageGrouping.date(from: "2026-08-04T10:15:30Z"))
    }

    func testReturnsNilForGarbageTimestamp() {
        XCTAssertNil(MessageGrouping.date(from: "not a date"))
        XCTAssertNil(MessageGrouping.date(from: nil))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Harvest.xcodeproj -scheme Harvest -destination "platform=iOS Simulator,name=$SIM"`
Expected: compile failure — `cannot find 'MessageGrouping' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Harvest/Views/Components/Chat/MessageGrouping.swift`:

```swift
import Foundation

/// Where a message sits within a run of consecutive messages from one sender.
struct MessagePosition: Equatable {
    let showsDateSeparator: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
}

/// Decides how messages clump together in a transcript. Pure and
/// synchronous so it can be unit tested without a view or a network.
enum MessageGrouping {
    /// Messages from one sender closer together than this, on the same day,
    /// render as a single group.
    static let groupWindow: TimeInterval = 5 * 60

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses a Supabase timestamp, which may or may not carry fractional
    /// seconds. Formatters are cached — the previous per-call
    /// `ISO8601DateFormatter()` ran once per bubble per redraw.
    static func date(from iso: String?) -> Date? {
        guard let iso else { return nil }
        return fractional.date(from: iso) ?? whole.date(from: iso)
    }

    static func position(
        previousSender: String?, previousDate: Date?,
        currentSender: String, currentDate: Date?,
        nextSender: String?, nextDate: Date?
    ) -> MessagePosition {
        // Without a usable timestamp a message can't be placed in a run,
        // so it stands alone rather than guessing.
        guard let currentDate else {
            return MessagePosition(
                showsDateSeparator: false,
                isFirstInGroup: true,
                isLastInGroup: true
            )
        }

        let showsDateSeparator: Bool = {
            guard previousSender != nil else { return true }   // top of the transcript
            guard let previousDate else { return false }       // unusable — don't invent a break
            return !Calendar.current.isDate(previousDate, inSameDayAs: currentDate)
        }()

        return MessagePosition(
            showsDateSeparator: showsDateSeparator,
            isFirstInGroup: !continues(
                fromSender: previousSender, fromDate: previousDate,
                toSender: currentSender, toDate: currentDate
            ),
            isLastInGroup: !continues(
                fromSender: currentSender, fromDate: currentDate,
                toSender: nextSender, toDate: nextDate
            )
        )
    }

    /// True when the second message continues the first: same sender, same
    /// calendar day, inside the window.
    private static func continues(
        fromSender: String?, fromDate: Date?,
        toSender: String?, toDate: Date?
    ) -> Bool {
        guard let fromSender, let toSender, fromSender == toSender,
              let fromDate, let toDate,
              Calendar.current.isDate(fromDate, inSameDayAs: toDate)
        else { return false }
        return toDate.timeIntervalSince(fromDate) < groupWindow
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Harvest.xcodeproj -scheme Harvest -destination "platform=iOS Simulator,name=$SIM"`
Expected: all 13 `MessageGroupingTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Views/Components/Chat/MessageGrouping.swift HarvestTests/Views/MessageGroupingTests.swift
git commit -m "feat(chat): message grouping logic with cached timestamp parsing"
```

---

### Task 2: Date separator

**Files:**
- Create: `Harvest/Views/Components/Chat/DateSeparator.swift`
- Test: `HarvestTests/Views/DateSeparatorTests.swift`

**Interfaces:**
- Consumes: `HarvestTheme`.
- Produces: `struct DateSeparator: View { let date: Date }` and `static func label(for date: Date, now: Date = Date()) -> String`.

- [ ] **Step 1: Write the failing tests**

Create `HarvestTests/Views/DateSeparatorTests.swift`:

```swift
import XCTest
@testable import Harvest

final class DateSeparatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_754_000_000)

    func testTodayLabel() {
        XCTAssertEqual(DateSeparator.label(for: now, now: now), "Today")
    }

    func testYesterdayLabel() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(DateSeparator.label(for: yesterday, now: now), "Yesterday")
    }

    func testWeekdayLabelWithinLastWeek() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let label = DateSeparator.label(for: threeDaysAgo, now: now)
        let weekdays = Calendar.current.weekdaySymbols
        XCTAssertTrue(weekdays.contains(label), "expected a weekday name, got \(label)")
    }

    func testOlderThanAWeekFallsBackToADate() {
        let longAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let label = DateSeparator.label(for: longAgo, now: now)
        XCTAssertFalse(Calendar.current.weekdaySymbols.contains(label))
        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Harvest.xcodeproj -scheme Harvest -destination "platform=iOS Simulator,name=$SIM"`
Expected: compile failure — `cannot find 'DateSeparator' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Harvest/Views/Components/Chat/DateSeparator.swift`:

```swift
import SwiftUI

/// A centred pill marking the day a run of messages belongs to.
struct DateSeparator: View {
    let date: Date

    var body: some View {
        Text(Self.label(for: date))
            .font(HarvestTheme.Typography.caption)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
            .padding(.horizontal, HarvestTheme.Spacing.md)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().stroke(HarvestTheme.Colors.border, lineWidth: 1) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    /// `now` is injectable so the label is testable without freezing the clock.
    static func label(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? Int.max

        if days < 7 {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Harvest.xcodeproj -scheme Harvest -destination "platform=iOS Simulator,name=$SIM"`
Expected: all 4 `DateSeparatorTests` pass, plus Task 1's still passing.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Views/Components/Chat/DateSeparator.swift HarvestTests/Views/DateSeparatorTests.swift
git commit -m "feat(chat): date separator pill"
```

---

### Task 3: Accent, bubble shape, bubble fill, backdrop

**Files:**
- Modify: `Harvest/Theme/HarvestTheme.swift:27` (add `fieldGreenDeep` after `fieldGreenSoft`)
- Create: `Harvest/Views/Components/Chat/ChatAccent.swift`
- Create: `Harvest/Views/Components/Chat/ChatBubbleShape.swift`
- Create: `Harvest/Views/Components/Chat/ChatBubbleBackground.swift`
- Create: `Harvest/Views/Components/Chat/ChatBackdrop.swift`

**Interfaces:**
- Consumes: `HarvestTheme.Colors`.
- Produces: `struct ChatAccent { let base, deep, light: Color; static let rose: ChatAccent; static let field: ChatAccent }`; `struct ChatBubbleShape: Shape { let isMine, isFirstInGroup, isLastInGroup: Bool }`; `View.chatBubble(accent:isMine:shape:) -> some View`; `struct ChatBackdrop: View { let accent: ChatAccent }`.

These are presentation-only — there is nothing meaningful to unit test, so this task's gate is "compiles cleanly and the preview renders".

- [ ] **Step 1: Add the missing theme token**

In `Harvest/Theme/HarvestTheme.swift`, immediately after the `fieldGreenSoft` line (currently line 27), add:

```swift
        static let fieldGreenDeep = Color(hex: "2F8C60")   // gradient end for Field bubbles
```

- [ ] **Step 2: Create the accent type**

Create `Harvest/Views/Components/Chat/ChatAccent.swift`:

```swift
import SwiftUI

/// The three tints one chat surface needs. Field rooms are green, Seed
/// conversations are rose; everything else about the two is identical, so
/// components take one of these rather than three loose colors.
struct ChatAccent {
    let base: Color     // outgoing bubble fill, send button
    let deep: Color     // outgoing gradient end
    let light: Color    // quotes, mentions, metadata

    static let rose = ChatAccent(
        base: HarvestTheme.Colors.rose,
        deep: HarvestTheme.Colors.roseDeep,
        light: HarvestTheme.Colors.roseLight
    )

    static let field = ChatAccent(
        base: HarvestTheme.Colors.fieldGreen,
        deep: HarvestTheme.Colors.fieldGreenDeep,
        light: HarvestTheme.Colors.fieldGreenLight
    )
}
```

- [ ] **Step 3: Create the bubble shape**

Create `Harvest/Views/Components/Chat/ChatBubbleShape.swift`:

```swift
import SwiftUI

/// A bubble outline that tightens the corners facing its neighbours, so a
/// run of messages reads as one column instead of a stack of separate pills.
struct ChatBubbleShape: Shape {
    let isMine: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool

    private let round: CGFloat = 20
    private let tight: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        // The "tail" side is the one nearest the sender: trailing for mine,
        // leading for theirs. Only that side tightens.
        let top = isFirstInGroup ? round : tight
        let bottom = isLastInGroup ? round : tight

        let radii = RectangleCornerRadii(
            topLeading: isMine ? round : top,
            bottomLeading: isMine ? round : bottom,
            bottomTrailing: isMine ? bottom : round,
            topTrailing: isMine ? top : round
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
            .path(in: rect)
    }
}
```

- [ ] **Step 4: Create the bubble fill**

Create `Harvest/Views/Components/Chat/ChatBubbleBackground.swift`:

```swift
import SwiftUI

/// Fills a bubble: an accent gradient when it's yours, material when it isn't.
struct ChatBubbleBackground: ViewModifier {
    let accent: ChatAccent
    let isMine: Bool
    let shape: ChatBubbleShape

    func body(content: Content) -> some View {
        content.background {
            if isMine {
                shape
                    .fill(
                        LinearGradient(
                            colors: [accent.base, accent.deep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay { shape.stroke(Color.white.opacity(0.14), lineWidth: 1) }
            } else {
                shape
                    .fill(HarvestTheme.Colors.wineCard)
                    .overlay { shape.fill(.ultraThinMaterial).opacity(0.45) }
                    .overlay { shape.stroke(HarvestTheme.Colors.border, lineWidth: 1) }
            }
        }
    }
}

extension View {
    func chatBubble(accent: ChatAccent, isMine: Bool, shape: ChatBubbleShape) -> some View {
        modifier(ChatBubbleBackground(accent: accent, isMine: isMine, shape: shape))
    }
}
```

- [ ] **Step 5: Create the backdrop**

Create `Harvest/Views/Components/Chat/ChatBackdrop.swift`:

```swift
import SwiftUI

/// The chat background: the app's plum base lifted by two faint accent
/// glows. Deliberately static — no animation, so it costs nothing per frame.
struct ChatBackdrop: View {
    let accent: ChatAccent

    var body: some View {
        ZStack {
            HarvestTheme.Colors.background
            RadialGradient(
                colors: [accent.base.opacity(0.10), .clear],
                center: UnitPoint(x: 0.08, y: 0.04),
                startRadius: 0,
                endRadius: 340
            )
            RadialGradient(
                colors: [accent.deep.opacity(0.12), .clear],
                center: UnitPoint(x: 0.96, y: 0.88),
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 6: Verify it compiles**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`, no new warnings.

- [ ] **Step 7: Commit**

```bash
git add Harvest/Theme/HarvestTheme.swift Harvest/Views/Components/Chat/
git commit -m "feat(chat): accent, grouping-aware bubble shape, fill, and backdrop"
```

---

### Task 4: Shared composer

**Files:**
- Create: `Harvest/Views/Components/Chat/ChatComposer.swift`

**Interfaces:**
- Consumes: `ChatAccent`, `HarvestTheme`.
- Produces: `ChatComposer<Accessory: View>` with init `(text: Binding<String>, focused: FocusState<Bool>.Binding, accent: ChatAccent, placeholder: String, isSending: Bool, onSend: @escaping () -> Void, @ViewBuilder accessory: () -> Accessory)`, plus an `Accessory == EmptyView` convenience init omitting `accessory`.

Focus is passed in rather than owned internally, because `ChatDetailView` already dismisses the keyboard by tapping the transcript (`ChatDetailView.swift:119-121`) and that must keep working. The room chat gains the same behaviour.

The composer owns the *disabled* half of the double-send fix; Task 5 owns the *re-entry* half. Both are needed — the button being disabled does not stop an in-flight second call.

- [ ] **Step 1: Write the composer**

Create `Harvest/Views/Components/Chat/ChatComposer.swift`:

```swift
import SwiftUI

/// The message input shared by both chats: a material capsule, an expanding
/// field, an optional leading accessory, and a send button with three states
/// — disabled, ready, and in-flight.
struct ChatComposer<Accessory: View>: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let accent: ChatAccent
    let placeholder: String
    let isSending: Bool
    let onSend: () -> Void
    @ViewBuilder let accessory: Accessory

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: HarvestTheme.Spacing.sm) {
            accessory

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .tint(accent.light)
                .focused(focused)
                .lineLimit(1...5)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay { Capsule().fill(HarvestTheme.Colors.wineCard.opacity(0.55)) }
                        .overlay { Capsule().stroke(HarvestTheme.Colors.border, lineWidth: 1) }
                }

            sendButton
        }
        .padding(.horizontal, HarvestTheme.Spacing.md)
        .padding(.vertical, HarvestTheme.Spacing.sm)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay { Rectangle().fill(HarvestTheme.Colors.wineBlack.opacity(0.55)) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                Circle()
                    .fill(canSend
                          ? AnyShapeStyle(LinearGradient(
                                colors: [accent.base, accent.deep],
                                startPoint: .top,
                                endPoint: .bottom))
                          : AnyShapeStyle(HarvestTheme.Colors.wineRaised))
                    .frame(width: 36, height: 36)

                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HarvestTheme.Colors.textPrimary)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend
                                         ? HarvestTheme.Colors.textPrimary
                                         : HarvestTheme.Colors.textTertiary)
                }
            }
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: HarvestTheme.Animation.fast), value: canSend)
        .padding(.bottom, 2)
    }
}

extension ChatComposer where Accessory == EmptyView {
    init(
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        accent: ChatAccent,
        placeholder: String,
        isSending: Bool,
        onSend: @escaping () -> Void
    ) {
        self.init(
            text: text,
            focused: focused,
            accent: accent,
            placeholder: placeholder,
            isSending: isSending,
            onSend: onSend,
            accessory: { EmptyView() }
        )
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Views/Components/Chat/ChatComposer.swift
git commit -m "feat(chat): shared composer with in-flight send state"
```

---

### Task 5: Stop double sends

**Files:**
- Modify: `Harvest/ViewModels/CommunityChatViewModel.swift:229-285`
- Modify: `Harvest/ViewModels/ChatViewModel.swift:108-167`

**Interfaces:**
- Consumes: nothing new.
- Produces: `CommunityChatViewModel.isSending: Bool` and `ChatViewModel.isSending: Bool`, both `private(set)`, read by the views in Tasks 6 and 7.

Neither view model takes an injectable service (`private let service = CommunityService()`), so there is no seam for a unit test here without a refactor this plan deliberately avoids. The gate is the manual double-tap check in Task 9, which must be confirmed **in the database**, not on screen.

Watch the interaction with the mindful-warning sheet. Clearing the draft up front means "Edit" would otherwise throw the user's text away, so dismissal has to put it back.

- [ ] **Step 1: Add the flag and rewrite the community send path**

In `Harvest/ViewModels/CommunityChatViewModel.swift`, add next to the other published state (after `var replyTarget: CommunityMessage?`, line 16):

```swift
    /// True from the moment send is tapped until the row is committed.
    /// Gates re-entry: the mindful check below can span an OpenAI round
    /// trip, and two taps inside that window used to insert two rows.
    private(set) var isSending = false
```

Replace `send`, `confirmSendDespiteWarning`, `dismissMindfulWarning`, and `performSend` (lines 229-285) with:

```swift
    func send(communityId: String, senderId: String) async {
        guard !isSending else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        // Clear up front. Leaving the text in place while the network call
        // runs is what made a second tap possible.
        draft = ""

        if mindfulService.isEnabled {
            let analysis = await mindfulService.analyzeMessage(text)
            if analysis.needsReview {
                mindfulAnalysis = analysis
                pendingDraft = text
                showMindfulWarning = true
                isSending = false   // the sheet owns the send from here
                return
            }
        }

        await performSend(communityId: communityId, senderId: senderId, text: text)
        isSending = false
    }

    func confirmSendDespiteWarning(communityId: String, senderId: String) async {
        guard !isSending else { return }
        showMindfulWarning = false
        mindfulAnalysis = nil
        let text = pendingDraft
        guard !text.isEmpty else { return }

        isSending = true
        await performSend(communityId: communityId, senderId: senderId, text: text)
        isSending = false
    }

    func dismissMindfulWarning() {
        showMindfulWarning = false
        mindfulAnalysis = nil
        // Put the text back, or "Edit" would silently discard it.
        if !pendingDraft.isEmpty {
            draft = pendingDraft
            pendingDraft = ""
        }
    }

    private func performSend(communityId: String, senderId: String, text: String) async {
        do {
            let sent = try await service.post(
                communityId: communityId,
                senderId: senderId,
                content: text,
                replyToId: replyTarget?.id,
                mentions: mentions(in: text)
            )
            draftMentions = [:]
            pendingDraft = ""
            replyTarget = nil
            if let sent, !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            await loadSenders(for: [senderId])
        } catch {
            // Hand the text back so a failed send isn't a lost message.
            draft = text
            pendingDraft = ""
            // Phase 6: contact-info block surfaces here as a friendly nudge.
            if "\(error)".contains("CONTACT_INFO_BLOCKED") {
                self.error = "Keep contact sharing to private Seed conversations 🌱"
            } else {
                self.error = error.localizedDescription
            }
        }
    }
```

- [ ] **Step 2: Rewrite the 1:1 send path**

In `Harvest/ViewModels/ChatViewModel.swift`, add after `var error: String?` (line 17):

```swift
    /// True while a send is in flight. See CommunityChatViewModel for why.
    private(set) var isSending = false
```

Replace `sendMessage`, `confirmSendDespiteWarning`, `dismissMindfulWarning`, and `performSend` (lines 108-167) with:

```swift
    func sendMessage(conversationId: String, senderId: String) async {
        guard !isSending else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        messageText = ""

        if mindfulService.isEnabled {
            let analysis = await mindfulService.analyzeMessage(text)
            let shouldBypassWarning = await shouldBypassMindfulWarning(
                for: analysis,
                conversationId: conversationId,
                userId: senderId
            )

            if analysis.needsReview && !shouldBypassWarning {
                mindfulAnalysis = analysis
                pendingMessageText = text
                pendingConversationId = conversationId
                pendingSenderId = senderId
                showMindfulWarning = true
                isSending = false
                return
            }
        }

        await performSend(text: text, conversationId: conversationId, senderId: senderId)
        isSending = false
    }

    func confirmSendDespiteWarning() async {
        guard !isSending else { return }
        showMindfulWarning = false
        mindfulAnalysis = nil
        let text = pendingMessageText
        guard !text.isEmpty else { return }

        isSending = true
        await performSend(
            text: text,
            conversationId: pendingConversationId,
            senderId: pendingSenderId
        )
        isSending = false
    }

    func dismissMindfulWarning() {
        showMindfulWarning = false
        mindfulAnalysis = nil
        // Put the text back, or "Edit" would silently discard it.
        if !pendingMessageText.isEmpty {
            messageText = pendingMessageText
            pendingMessageText = ""
        }
    }

    private func performSend(text: String, conversationId: String, senderId: String) async {
        do {
            if let message = try await chatService.sendMessage(
                conversationId: conversationId,
                senderId: senderId,
                content: text
            ) {
                // Only add if not already added by realtime
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
            pendingMessageText = ""
        } catch {
            self.error = error.localizedDescription
            messageText = text // Restore on failure
            pendingMessageText = ""
        }
    }
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/ViewModels/ChatViewModel.swift
git commit -m "fix(chat): guard re-entry on send so a double tap can't insert twice"
```

---

### Task 6: Rebuild the community room chat

**Files:**
- Modify: `Harvest/Views/Field/CommunityChatView.swift`

**Interfaces:**
- Consumes: `MessageGrouping`, `MessagePosition`, `DateSeparator`, `ChatAccent.field`, `ChatBubbleShape`, `.chatBubble(accent:isMine:shape:)`, `ChatBackdrop`, `ChatComposer`, `CommunityChatViewModel.isSending`.
- Produces: nothing consumed downstream.

Re-read §6 of the spec before starting. Everything in this file that is not listed below is being **restyled, not rewritten** — the mindful blur, mention highlighting, reply quote, reactions, report menu, swipe-to-reply, prompt picker, and profile sheet all keep their current logic verbatim.

- [ ] **Step 1: Precompute positions on the view model**

Add to `Harvest/ViewModels/CommunityChatViewModel.swift`, after `quotedMessage(for:)` (line 100):

```swift
    /// Grouping metadata for every loaded message, keyed by message id.
    /// Computed once per messages change rather than per bubble redraw.
    var positions: [String: MessagePosition] {
        var result: [String: MessagePosition] = [:]
        let dates = messages.map { MessageGrouping.date(from: $0.createdAt) }
        for (i, message) in messages.enumerated() {
            result[message.id] = MessageGrouping.position(
                previousSender: i > 0 ? messages[i - 1].senderId : nil,
                previousDate: i > 0 ? dates[i - 1] : nil,
                currentSender: message.senderId,
                currentDate: dates[i],
                nextSender: i + 1 < messages.count ? messages[i + 1].senderId : nil,
                nextDate: i + 1 < messages.count ? dates[i + 1] : nil
            )
        }
        return result
    }

    /// "9:41" for a message, or "" when the timestamp is unusable.
    func timeLabel(for message: CommunityMessage) -> String {
        guard let date = MessageGrouping.date(from: message.createdAt) else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
```

- [ ] **Step 2: Swap the backdrop and composer**

In `CommunityChatView.body`, replace the background modifier (line 167):

```swift
        .background(ChatBackdrop(accent: .field))
```

Replace the entire `composer` computed property (lines 260-291) with:

```swift
    private var composer: some View {
        ChatComposer(
            text: $vm.draft,
            focused: $isComposerFocused,
            accent: .field,
            placeholder: "Share something…",
            isSending: vm.isSending,
            onSend: { Task { await vm.send(communityId: community.id, senderId: userId) } },
            accessory: {
                Button { showPrompts.toggle() } label: {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                        .frame(width: 36, height: 36)
                }
            }
        )
    }
```

Delete the now-unused `canSend` property (lines 15-17) — `ChatComposer` owns that decision. Add the focus state alongside the other `@State` declarations:

```swift
    @FocusState private var isComposerFocused: Bool
```

and let tapping the transcript dismiss the keyboard, matching the Seed chat. Add to the `ScrollView` in `body`:

```swift
                .contentShape(Rectangle())
                .onTapGesture { isComposerFocused = false }
```

- [ ] **Step 3: Insert date separators and pass grouping into the bubble**

In the `ForEach(vm.messages)` at line 42, wrap each row so the separator precedes it. Replace the opening of the loop body:

```swift
                        ForEach(Array(vm.messages.enumerated()), id: \.element.id) { _, msg in
                            let position = vm.positions[msg.id]
                                ?? MessagePosition(showsDateSeparator: false,
                                                   isFirstInGroup: true,
                                                   isLastInGroup: true)

                            if position.showsDateSeparator,
                               let date = MessageGrouping.date(from: msg.createdAt) {
                                DateSeparator(date: date)
                            }

                            SwipeToReply(onReply: { vm.replyTarget = msg }) {
```

and pass the new values into `CommunityBubble` by adding these arguments to the existing call (after `isMine:`, line 54):

```swift
                                        position: position,
                                        timeLabel: position.isLastInGroup ? vm.timeLabel(for: msg) : "",
```

- [ ] **Step 4: Rebuild the bubble**

In `private struct CommunityBubble`, add the two new stored properties after `let isMine: Bool` (line 377):

```swift
    let position: MessagePosition
    var timeLabel: String = ""
```

Replace the `body` (lines 395-475) with:

```swift
    var body: some View {
        let isBlurred = flag != nil && !revealed
        let shape = ChatBubbleShape(
            isMine: isMine,
            isFirstInGroup: position.isFirstInGroup,
            isLastInGroup: position.isLastInGroup
        )

        HStack(alignment: .bottom, spacing: HarvestTheme.Spacing.xs) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                // The avatar sits on the last message of a run only; earlier
                // rows reserve its width so the column stays flush.
                Group {
                    if position.isLastInGroup {
                        avatar
                            .contentShape(Circle())
                            .onTapGesture { onTapSender?() }
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                    }
                }
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                // Name once per run, and never on your own messages.
                if !isMine, position.isFirstInGroup {
                    Text(sender?.nickname ?? "Member")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(onTapSender == nil
                                         ? HarvestTheme.Colors.textTertiary
                                         : HarvestTheme.Colors.fieldGreenLight)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapSender?() }
                        .padding(.leading, HarvestTheme.Spacing.xs)
                }

                if message.replyToId != nil {
                    replyQuote
                }

                MentionText(
                    content: message.content,
                    nicknames: mentionNicknames,
                    baseColor: isMine
                        ? HarvestTheme.Colors.textOnRedPrimary
                        : HarvestTheme.Colors.textPrimary
                )
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .frame(minWidth: isBlurred ? 150 : nil,
                           minHeight: isBlurred ? 44 : nil,
                           alignment: .leading)
                    .blur(radius: isBlurred ? 7 : 0)
                    .chatBubble(accent: .field, isMine: isMine, shape: shape)
                    .overlay { if isBlurred { blurOverlay } }
                    .overlay {
                        if mentionsMe {
                            shape.stroke(HarvestTheme.Colors.fieldGreen.opacity(0.55), lineWidth: 1)
                        }
                    }
                    .contentShape(shape)
                    .onTapGesture {
                        if isBlurred { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }

                if !timeLabel.isEmpty {
                    Text(timeLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                        .padding(.horizontal, HarvestTheme.Spacing.xs)
                }
            }

            // No avatar on your own messages — you know who you are.
            if !isMine { Spacer(minLength: 48) }
        }
    }

    /// The quoted original above a reply. Logic unchanged from before the
    /// redesign; only the surface is new.
    private var replyQuote: some View {
        HStack(spacing: HarvestTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(HarvestTheme.Colors.fieldGreen)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(quotedSenderName ?? "Member")
                    .font(HarvestTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                Text(quoted.map { $0.isRemoved ? "Message removed" : $0.content } ?? "…")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.sm)
        .padding(.vertical, HarvestTheme.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .fill(HarvestTheme.Colors.wineBlack.opacity(0.30))
                }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = message.replyToId { onTapQuote?(id) }
        }
    }
```

Change the avatar frame (line 518) from `30` to `28` so it matches the reserved spacer:

```swift
        .frame(width: 28, height: 28)
```

- [ ] **Step 5: Fix the reaction chip alignment**

In `ReactionChips`, replace both hardcoded paddings (lines 365-366) with a single one tied to the avatar gutter. The old trailing inset existed to clear your *own* avatar, which no longer renders, so it goes away entirely:

```swift
        // Line the chips up with the bubble, clearing the avatar gutter.
        .padding(.leading, isMine ? 0 : 28 + HarvestTheme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
```

- [ ] **Step 6: Build and run the room chat**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`, zero new warnings.

Then launch in the simulator, open a room with existing messages, and confirm: separators appear, consecutive messages from one sender show one avatar and one name, your own messages have neither, and a timestamp sits under the last message of each run.

- [ ] **Step 7: Commit**

```bash
git add Harvest/Views/Field/CommunityChatView.swift Harvest/ViewModels/CommunityChatViewModel.swift
git commit -m "feat(chat): rebuild community room chat on shared components"
```

---

### Task 7: Rebuild the Seed chat

**Files:**
- Modify: `Harvest/Views/Chat/MessageBubbleView.swift`
- Modify: `Harvest/Views/Chat/ChatDetailView.swift:60-117,174-192`

**Interfaces:**
- Consumes: everything from Tasks 1-5, with `ChatAccent.rose`.
- Produces: nothing consumed downstream.

- [ ] **Step 1: Add grouping to the chat view model**

Add to `Harvest/ViewModels/ChatViewModel.swift`, after `loadMessages` (line 66):

```swift
    /// Grouping metadata for every loaded message, keyed by message id.
    var positions: [String: MessagePosition] {
        var result: [String: MessagePosition] = [:]
        let dates = messages.map { MessageGrouping.date(from: $0.createdAt) }
        for (i, message) in messages.enumerated() {
            result[message.id] = MessageGrouping.position(
                previousSender: i > 0 ? messages[i - 1].senderId : nil,
                previousDate: i > 0 ? dates[i - 1] : nil,
                currentSender: message.senderId,
                currentDate: dates[i],
                nextSender: i + 1 < messages.count ? messages[i + 1].senderId : nil,
                nextDate: i + 1 < messages.count ? dates[i + 1] : nil
            )
        }
        return result
    }
```

`Message.senderId` is a non-optional `String` (`Harvest/Models/Message.swift:6`), so it drops straight in — same shape as `CommunityMessage.senderId`.

- [ ] **Step 2: Rebuild the bubble**

Replace `Harvest/Views/Chat/MessageBubbleView.swift` `body` (lines 17-69) and add two stored properties after `let isSent: Bool` (line 5):

```swift
    let position: MessagePosition
    var timeLabel: String = ""
```

```swift
    var body: some View {
        let isBlurred = flag != nil && !revealed
        let shape = ChatBubbleShape(
            isMine: isSent,
            isFirstInGroup: position.isFirstInGroup,
            isLastInGroup: position.isLastInGroup
        )

        HStack {
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.content ?? "")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(isSent
                                     ? HarvestTheme.Colors.textOnRedPrimary
                                     : HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .frame(minWidth: isBlurred ? 150 : nil,
                           minHeight: isBlurred ? 44 : nil,
                           alignment: .leading)
                    .blur(radius: isBlurred ? 7 : 0)
                    .chatBubble(accent: .rose, isMine: isSent, shape: shape)
                    .overlay { if isBlurred { blurOverlay } }
                    .contentShape(shape)
                    .onTapGesture {
                        if isBlurred { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }

                // Metadata once per run, not once per bubble.
                if !timeLabel.isEmpty {
                    HStack(spacing: 4) {
                        Text(timeLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)

                        if isSent {
                            Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(message.isRead
                                                 ? HarvestTheme.Colors.primary
                                                 : HarvestTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }
```

Delete `formatMessageTime` (lines 100-106) — the label now arrives precomputed, and `MessageGrouping` owns timestamp parsing.

- [ ] **Step 3: Wire the detail view**

In `Harvest/Views/Chat/ChatDetailView.swift`, add this helper inside the struct:

```swift
    /// "9:41" for a message, or "" when the timestamp is unusable.
    private func timeLabel(for message: Message) -> String {
        guard let date = MessageGrouping.date(from: message.createdAt) else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
```

In the message `ForEach`, insert separators and pass the new arguments:

```swift
                        ForEach(viewModel.messages) { message in
                            let position = viewModel.positions[message.id]
                                ?? MessagePosition(showsDateSeparator: false,
                                                   isFirstInGroup: true,
                                                   isLastInGroup: true)

                            if position.showsDateSeparator,
                               let date = MessageGrouping.date(from: message.createdAt) {
                                DateSeparator(date: date)
                            }

                            MessageBubbleView(
                                message: message,
                                isSent: message.isSentBy(authViewModel.currentUserId ?? ""),
                                position: position,
                                timeLabel: position.isLastInGroup ? timeLabel(for: message) : ""
                            )
                            .id(message.id)
                        }
```

Replace the background modifier (line 117) with:

```swift
        .background(ChatBackdrop(accent: .rose))
```

Replace the composer `HStack` (lines 60-114 — the `TextField` plus the paperplane `Button`) with:

```swift
            ChatComposer(
                text: $viewModel.messageText,
                focused: $isMessageFieldFocused,
                accent: .rose,
                placeholder: "Message",
                isSending: viewModel.isSending,
                onSend: {
                    Task {
                        await viewModel.sendMessage(
                            conversationId: conversationId,
                            senderId: authViewModel.currentUserId ?? ""
                        )
                    }
                }
            )
```

Keep the existing `@FocusState private var isMessageFieldFocused` and the `.onTapGesture` that clears it (lines 119-121) — passing the binding through is exactly what preserves tap-to-dismiss.

- [ ] **Step 4: Restyle the typing indicator**

In `Harvest/Views/Components/TypingIndicatorView.swift`, replace the `.background` block (lines 18-23) so the indicator sits on the same surface as an incoming bubble:

```swift
            .chatBubble(
                accent: .rose,
                isMine: false,
                shape: ChatBubbleShape(isMine: false, isFirstInGroup: true, isLastInGroup: true)
            )
```

The dots themselves stay as they are.

- [ ] **Step 5: Build and run the Seed chat**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`, zero new warnings.

Open a Seed conversation and confirm separators appear, timestamps and read receipts show once per run, and the composer matches the room chat's geometry in rose.

- [ ] **Step 6: Commit**

```bash
git add Harvest/Views/Chat/ Harvest/ViewModels/ChatViewModel.swift Harvest/Views/Components/TypingIndicatorView.swift
git commit -m "feat(chat): rebuild Seed chat on shared components"
```

---

### Task 8: Field events banner

**Files:**
- Create: `Harvest/Views/Field/EventsComingSoonBanner.swift`
- Modify: `Harvest/Views/Field/FieldView.swift:11-13`

**Interfaces:**
- Consumes: `HarvestTheme`.
- Produces: `struct EventsComingSoonBanner: View` — no parameters, no state.

- [ ] **Step 1: Write the banner**

Create `Harvest/Views/Field/EventsComingSoonBanner.swift`:

```swift
import SwiftUI

/// Announcement only — there is no events feature yet. Deliberately
/// stateless: no dismiss, no persistence, nothing to fetch.
struct EventsComingSoonBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("COMING SOON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.8)
            }
            .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)

            Text("Community events")
                .font(HarvestTheme.Typography.h3)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)

            Text("Online and in person. Gather with gardeners near you — and everywhere.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: HarvestTheme.Spacing.sm) {
                modePill("Online", systemImage: "video.fill")
                modePill("In person", systemImage: "mappin.and.ellipse")
            }
            .padding(.top, HarvestTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HarvestTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            HarvestTheme.Colors.fieldGreen.opacity(0.22),
                            HarvestTheme.Colors.wineCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(HarvestTheme.Colors.fieldGreen.opacity(0.35), lineWidth: 1)
                }
        }
        .overlay(alignment: .topTrailing) {
            // Oversized leaf, clipped by the card — a watermark, not an icon.
            Image(systemName: "leaf.fill")
                .font(.system(size: 96))
                .foregroundStyle(HarvestTheme.Colors.fieldGreen.opacity(0.10))
                .rotationEffect(.degrees(-18))
                .offset(x: 22, y: -18)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
    }

    private func modePill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(HarvestTheme.Typography.caption)
            .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
            .padding(.horizontal, HarvestTheme.Spacing.sm)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(HarvestTheme.Colors.fieldGreenSoft)
                    .overlay {
                        Capsule().stroke(HarvestTheme.Colors.fieldGreenBorder, lineWidth: 1)
                    }
            }
    }
}
```

- [ ] **Step 2: Place it in The Field**

In `Harvest/Views/Field/FieldView.swift`, change the `VStack` contents (lines 11-13) so the banner sits above the header:

```swift
                VStack(spacing: HarvestTheme.Spacing.md) {
                    EventsComingSoonBanner()

                    header
```

- [ ] **Step 3: Build and look at it**

Run: `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

Launch, open The Field, and confirm the banner renders above the room list with the leaf watermark clipped to the card and both mode pills visible.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Field/EventsComingSoonBanner.swift Harvest/Views/Field/FieldView.swift
git commit -m "feat(field): community events coming soon banner"
```

---

### Task 9: Verification checklist and full-suite run

**Files:**
- Create: `docs/verification/2026-08-04-chat-overhaul-checklist.md`

- [ ] **Step 1: Run the whole test suite**

Run: `xcodebuild test -project Harvest.xcodeproj -scheme Harvest -destination "platform=iOS Simulator,name=$SIM"`
Expected: every test passes, including the pre-existing `AxisScoresTests`, `QuestionScoringTests`, `BlurbServiceTests`, `CompatibilityServiceTests`, and `SafetyAnalysisServiceTests`.

- [ ] **Step 2: Write the checklist**

Create `docs/verification/2026-08-04-chat-overhaul-checklist.md`, following the format of `docs/verification/2026-08-01-community-rooms-xcode-checklist.md`. It needs two test accounts sharing a room.

```markdown
# Xcode verification — chat overhaul (2026-08-04)

Needs two test accounts that share at least one room, and a Supabase SQL
editor tab for the double-send check.

## Build
- [ ] Compiles with zero new warnings.
- [ ] Unit tests pass (`MessageGroupingTests`, `DateSeparatorTests`).

## Double-send — the actual bug
- [ ] Settings → mindful messaging ON. Type a message, tap send twice fast.
      `select count(*) from community_messages where content = '<text>'`
      returns exactly 1.
- [ ] Same in a Seed chat against `messages`. Returns exactly 1.
- [ ] Send button shows a spinner while in flight, then returns to the arrow.
- [ ] Airplane mode: send fails, the text comes back in the field, error shows.
- [ ] Mindful warning → "Edit": the text is back in the composer, not lost.
- [ ] Mindful warning → "Send anyway": exactly one message posts.

## Grouping
- [ ] Three quick messages from one sender: one avatar, one name, one timestamp.
- [ ] Same sender after a 10-minute gap: new group, avatar and name return.
- [ ] Alternating senders: every message keeps its own avatar and name.
- [ ] Own messages show no avatar and no "You" label.
- [ ] Bubble corners tighten within a run and round off at the ends.

## Date separators
- [ ] "Today" above the first message of the day.
- [ ] Older conversation shows "Yesterday" / a weekday / a date.
- [ ] Separator appears once at the top of the transcript.

## Regressions — room chat
- [ ] Pagination: >50 messages, "Load earlier" prepends without scroll jump.
- [ ] New incoming message still autoscrolls to the bottom.
- [ ] Swipe right to reply; X clears the reply bar.
- [ ] Reply renders the quoted sender and snippet; tapping scrolls to the original.
- [ ] Admin-remove the original → the quote reads "Message removed".
- [ ] "@" autocomplete lists members; the mention renders green and bold.
- [ ] Mentioned account sees the green bubble edge.
- [ ] Long-press → 🌱 💚 🌻 😂 👏 🤔; toggling syncs live to the second account.
- [ ] Reaction chips line up under the bubble, clear of the avatar gutter.
- [ ] Icebreakers sheet still opens from the composer's lightbulb.
- [ ] Contact-info block still shows the friendly nudge.
- [ ] Blurred message: tap to reveal works, hint text correct.
- [ ] Report message, and tap-avatar → profile with "Send a Seed".

## Regressions — Seed chat
- [ ] Timestamps and read receipts show once per run, on the last message.
- [ ] Typing indicator matches the incoming bubble surface.
- [ ] Blur/reveal, report, block, unmatch, Ready to Move all still work.

## Field
- [ ] Banner renders above the room list; leaf watermark clipped to the card.
- [ ] Both mode pills visible; nothing overflows at the largest Dynamic Type size.
- [ ] Room cards, join, and leave unchanged.
```

- [ ] **Step 3: Commit**

```bash
git add docs/verification/2026-08-04-chat-overhaul-checklist.md
git commit -m "docs: manual verification checklist for the chat overhaul"
```

- [ ] **Step 4: Work the checklist on the Mac**

Run every item. Anything that fails is a bug in this change, not a follow-up — fix it and re-run before calling the work done.
