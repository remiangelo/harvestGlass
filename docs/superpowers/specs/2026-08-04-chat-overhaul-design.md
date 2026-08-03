# Chat overhaul + Field events banner — design (2026-08-04)

Three changes, shipped together:

1. A static "community events coming soon" banner at the top of The Field.
2. A full visual overhaul of both chat surfaces, built on shared components.
3. A fix for double-sent messages, which affects both chat surfaces today.

## Why these are one change

The double-send fix touches the composer's disabled state, and the overhaul
replaces the composer. Splitting them would mean writing the guard twice. The
banner is independent but lives in `FieldView`, the same screen the room chat
is entered from.

## Scope decisions already made

- **Both chats** get the redesign — `CommunityChatView` (Field room) and
  `ChatDetailView` (1:1 Seed).
- **Full visual overhaul**, not a restyle-in-place. Accepted knowing the diff
  is large and verifiable only by hand on a Mac.
- **Banner is static.** No dismiss, no persistence, no backend.

---

## 1. The double-send bug

### Root cause

Neither send path guards against re-entry, and both clear the draft *after* an
`await`:

- `Harvest/ViewModels/CommunityChatViewModel.swift:269` — `draft = ""` runs
  after `await service.post(...)`.
- `Harvest/ViewModels/ChatViewModel.swift:150` — `messageText = ""` runs inside
  `performSend`, reached only after `await mindfulService.analyzeMessage(text)`
  at line 114.

The send button's `disabled` state derives purely from the draft being
non-empty (`CommunityChatView.swift:15`, `ChatDetailView.swift:111`). So for the
whole round trip the button stays enabled with the text still present. When
mindful messaging is on, that round trip includes an OpenAI network call
(`MindfulMessagingService.swift:176`), widening the window to seconds.

Two taps produce two inserted rows with two distinct ids. The existing dedupe
(`CommunityChatViewModel.swift:273`, `ChatViewModel.swift:159`) compares ids, so
it cannot catch this — it only ever guarded against the realtime echo of a
single insert.

### Fix

Both view models gain:

```swift
private(set) var isSending = false
```

- `send` / `sendMessage` return immediately when `isSending` is true.
- `isSending` is set true at entry and cleared in a `defer`.
- The draft is cleared **before** the network call and restored on failure.
  `ChatViewModel` already restores; `CommunityChatViewModel` currently does not
  and must start doing so.
- The composer's send button is disabled while `isSending` and renders a
  spinner in place of the send glyph.

The mindful-warning path must keep working: when `analysis.needsReview` short
circuits the send, `isSending` has to be cleared before the sheet appears, or
"Send anyway" will be swallowed by the guard.

---

## 2. Shared chat components

New directory: `Harvest/Views/Components/Chat/`

### `MessageGrouping.swift`

Pure logic, no SwiftUI, unit tested.

```swift
struct MessagePosition {
    let showsDateSeparator: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
}

enum MessageGrouping {
    static func position(
        previousSender: String?, previousDate: Date?,
        currentSender: String,  currentDate: Date?,
        nextSender: String?,    nextDate: Date?
    ) -> MessagePosition
}
```

**Grouping rule.** A message continues the previous one when all hold:
same sender, under 5 minutes apart, same calendar day. `showsDateSeparator` is
true when the previous message falls on a different calendar day, and for the
first message in the list.

Both models store `createdAt` as `String?` (ISO8601). Parsing uses one cached
formatter held by the grouping type — replacing the per-call
`ISO8601DateFormatter()` currently allocated in
`MessageBubbleView.formatMessageTime`. A `nil` or unparseable `createdAt` is
treated as "cannot group": the message starts and ends its own group and shows
no date separator.

### `ChatBubbleShape.swift`

Grouping-aware shape. 20pt corners; the tail corner (bottom-trailing for
outgoing, bottom-leading for incoming) drops to 6pt on the last message of a
group. Interior messages in a streak use 6pt on the whole tail side so the
group reads as one column.

### `ChatAccent.swift`

Bundles the three tints a chat surface needs, so components take one parameter
instead of three loose colors:

```swift
struct ChatAccent {
    let base: Color     // outgoing bubble fill, send button
    let deep: Color     // outgoing gradient end
    let light: Color    // quotes, mentions, metadata
    static let rose: ChatAccent   // rose / roseDeep / roseLight
    static let field: ChatAccent  // fieldGreen / fieldGreenDeep / fieldGreenLight
}
```

`HarvestTheme.Colors` has no deep green — rose has `roseDeep` but the field
palette stops at `fieldGreen` and `fieldGreenLight` (`HarvestTheme.swift:24-27`).
Add `fieldGreenDeep` (a darker, slightly desaturated `4DB380`) alongside them.

### `ChatBubbleBackground.swift`

Takes a `ChatAccent`.

- Outgoing: gradient from `accent.base` to `accent.deep`, plus a 1pt inner
  highlight stroke at low white opacity.
- Incoming: `.ultraThinMaterial` over `wineCard`, hairline `border` stroke.

### `DateSeparator.swift`

Centered material pill. "Today", "Yesterday", weekday name within the last
week, else a short date.

### `ChatComposer.swift`

Floating material capsule, safe-area aware.

- Expanding `TextField`, `lineLimit(1...5)`.
- Optional leading accessory slot — the room chat passes its icebreaker
  lightbulb; the Seed chat passes nothing.
- Send button with three states: disabled (empty draft), ready, sending
  (`ProgressView`).
- Takes a `ChatAccent`.

### `ChatBackdrop.swift`

`deepPlum` base plus two radial gradients in the accent color at very low
opacity. Static — no animation.

---

## 3. Accent per surface

The room chat stays **field green**, the Seed chat stays **rose**. Same
geometry and components, different tint. The Field's green identity is
established (`HarvestTheme.swift:22-27` scopes it to Field views by
convention) and converging both on rose would erase it.

---

## 4. Community chat changes

`Harvest/Views/Field/CommunityChatView.swift`

- Adopt `ChatBackdrop`, `DateSeparator`, `ChatComposer`, and the shared bubble
  shape/background.
- Incoming avatar renders only on the **last** message of a group,
  bottom-aligned. 28pt.
- Sender name renders only on the **first** message of a group.
- Outgoing messages lose the avatar and the "You" label entirely
  (currently `:409` and `:469`).
- Timestamps: community messages currently show **none**. Add one on the last
  message of each group.
- Reaction chips keep their behaviour; restyled onto material. Their current
  magic-number alignment padding (`:365-366`, hardcoded 38) is derived from the
  avatar width instead.
- Reply-quote block and the mention/blur treatments are restyled but keep
  identical logic.

## 5. Seed chat changes

`Harvest/Views/Chat/ChatDetailView.swift`, `Harvest/Views/Chat/MessageBubbleView.swift`

- Same components, rose accent.
- Timestamp and read receipt render only on the last message of a group,
  replacing the current per-bubble stamp (`MessageBubbleView.swift:51-63`).
- Date separators added — currently absent.
- `TypingIndicatorView` restyled to sit on the same material as incoming
  bubbles.

---

## 6. Must not change

Behaviour that is being restyled but not altered. Each is a regression risk:

- Mindful warning sheet, including the "send anyway" confirm path.
- Blur / tap-to-reveal on flagged incoming messages, and the category hints.
- `CONTACT_INFO_BLOCKED` mapping to the friendly nudge.
- Report message / report user flows.
- Swipe-to-reply, and the reply bar's clear button.
- Mention autocomplete, boundary-checked token matching, green highlighting,
  and the mentioned-me bubble edge.
- Reactions: curated emoji set, optimistic toggle, in-flight guard, rollback.
- Pagination: "load earlier", no scroll jump, autoscroll on new message.
- Realtime id-dedupe on both channels.
- Read receipts and the typing indicator.
- Tap-avatar profile sheet with its "Send a Seed" CTA.

---

## 7. Field banner

`Harvest/Views/Field/FieldView.swift`, above the existing header.

Green gradient card, leaf motif, "COMING SOON" eyebrow, headline "Community
events", body naming both online and in-person, and two mode pills. Static —
no state, no backend, no dismiss. Built from the existing `GlassCard` where it
fits, so it inherits the app's card geometry.

---

## 8. Verification

**Unit tests** (`HarvestTests`) for `MessageGrouping`:

- 4m59s apart, same sender → grouped.
- 5m01s apart, same sender → not grouped.
- Same timestamp, different sender → not grouped.
- Messages either side of midnight → not grouped, separator shown.
- First message in list → separator shown.
- `nil` / unparseable `createdAt` → own group, no separator.

**Manual**, on the Mac. A checklist lands in
`docs/verification/2026-08-04-chat-overhaul-checklist.md`, in the same format
as the existing community-rooms checklist, covering every item in §6 plus the
new grouping, separators, and composer states. The double-send fix gets an
explicit case: rapid double-tap on send, with mindful messaging **on**, must
produce exactly one message — verified in the database, not just on screen.

## 9. Out of scope

- Any real events feature. The banner is an announcement only.
- iOS 26 `.glassEffect`. Material-based first so it can be verified; swapping
  the composer to native Liquid Glass is a follow-up once it's seen on device.
- The Gardener chat (`GardenerChatView`), which is an AI surface with different
  needs.
