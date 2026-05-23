# Chat Header — Profile Avatar + Tap-to-View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the chat partner's circular avatar + display name in the navigation bar of `ChatDetailView`, with the whole header tappable to open the partner's `ProfileDetailView` as a full-screen cover.

**Architecture:** Single file change. Replace the `.navigationTitle(...)` line with a `.principal` toolbar item containing a `Button` that wraps an HStack of (`AsyncImage` avatar, `Text` display name). Tapping flips a new `@State` flag that drives a `.fullScreenCover` showing the existing `ProfileDetailView` with a no-op `onSwipe` (users in chat are already matched).

**Tech Stack:** SwiftUI / `ToolbarItem(.principal)` / `AsyncImage` / `.fullScreenCover`.

**Spec:** [`docs/superpowers/specs/2026-05-24-chat-header-profile-design.md`](../specs/2026-05-24-chat-header-profile-design.md)

---

## File Inventory

**Modified**
- `Harvest/Views/Chat/ChatDetailView.swift`

---

## Task 1: Replace navigation title with avatar + name button

**Files:**
- Modify: `Harvest/Views/Chat/ChatDetailView.swift`

### Step 1.1: Add the `showProfile` state

In `ChatDetailView` (around lines 10–12 where other `@State` properties live, immediately after `@State private var viewModel = ChatViewModel()`), insert:

```swift
    @State private var showProfile = false
```

### Step 1.2: Replace the `.navigationTitle` line with a `.principal` toolbar item

The current code (line 121) is:

```swift
        .navigationTitle(viewModel.partnerProfile?.displayName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    /* ... existing menu contents ... */
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
        }
```

DELETE the line:

```swift
        .navigationTitle(viewModel.partnerProfile?.displayName ?? "Chat")
```

Then INSIDE the existing `.toolbar { ... }` block, immediately BEFORE the existing `ToolbarItem(placement: .topBarTrailing)`, insert a new `.principal` ToolbarItem:

```swift
            ToolbarItem(placement: .principal) {
                if let profile = viewModel.partnerProfile {
                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: HarvestTheme.Spacing.xs) {
                            avatar(for: profile)
                            Text(profile.displayName)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Chat")
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
```

`.navigationBarTitleDisplayMode(.inline)` stays — it's already there immediately after the deleted line, and `.principal` placement requires `.inline`.

### Step 1.3: Add the `avatar` helper

After the existing `body` closing brace and before the file's final closing brace, add a helper:

```swift
    @ViewBuilder
    private func avatar(for profile: UserProfile) -> some View {
        if let url = profile.primaryPhoto.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
    }
```

`UserProfile.primaryPhoto` is an existing computed property (`photos?.first`). `HarvestTheme.Colors.divider` and `HarvestTheme.Colors.textSecondary` are existing tokens.

### Step 1.4: Add the `.fullScreenCover` modifier

The body chain currently has several `.sheet(isPresented:)` modifiers near the bottom (around lines 176, 190). Immediately AFTER the existing `.task { ... }` modifier (the one that calls `viewModel.loadPartnerProfile(userId: partnerUserId)`, around line 172), add:

```swift
        .fullScreenCover(isPresented: $showProfile) {
            if let profile = viewModel.partnerProfile {
                ProfileDetailView(profile: profile) { _ in
                    showProfile = false
                }
            }
        }
```

The `onSwipe: { _ in showProfile = false }` closure dismisses the cover if for any reason the user triggers a swipe gesture inside `ProfileDetailView` (defensive — in practice they shouldn't).

### Step 1.5: Commit

```
git add Harvest/Views/Chat/ChatDetailView.swift
git commit -m "feat(chat): tappable partner avatar in chat header

Shows the partner's circular avatar + display name in the navigation
bar as a custom principal toolbar item. Tapping opens ProfileDetailView
as a fullScreenCover.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Checklist

- [x] **Spec coverage:**
  - "Custom `.principal` toolbar item with HStack of AsyncImage + Text" → Step 1.2.
  - "28pt circular avatar" → Step 1.3 (`.frame(width: 28, height: 28).clipShape(Circle())`).
  - "Placeholder `person.circle.fill` when no photo" → Step 1.3 else-branch.
  - "AsyncImage placeholder Circle in divider color" → Step 1.3 inner placeholder.
  - "Button wraps the HStack; tap sets `showProfile = true`" → Step 1.2.
  - "`.fullScreenCover` showing `ProfileDetailView` with no-op onSwipe" → Step 1.4.
  - "Only shown when `partnerProfile != nil`; otherwise 'Chat' fallback" → Step 1.2 if/else.
  - "No changes to ProfileDetailView" → Task 1 only touches ChatDetailView.
- [x] **No placeholders:** every code block is complete; no TBDs.
- [x] **Type consistency:** `showProfile` is a `Bool`, used as both the binding source for `.fullScreenCover` and the target for the button's `showProfile = true` write. `UserProfile.primaryPhoto` returns `String?`; `URL.init(string:)` returns `URL?`; `flatMap` handles the chain correctly.
