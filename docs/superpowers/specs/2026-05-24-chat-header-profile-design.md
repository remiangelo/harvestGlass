# Chat Header — Profile Avatar + Tap-to-View Design

**Date:** 2026-05-24
**Goal:** Show the chat partner's avatar in the navigation bar of `ChatDetailView` and make the header tappable to open that user's profile.

## Change

Replace the existing `.navigationTitle(viewModel.partnerProfile?.displayName ?? "Chat")` in `ChatDetailView` with a `.principal` toolbar item containing a custom view:

```
HStack:
   AsyncImage(profile.primaryPhoto) → 28pt circular crop
   Text(profile.displayName)
```

The HStack is wrapped in a `Button` that sets `@State private var showProfile = true`. A `.fullScreenCover(isPresented: $showProfile)` presents `ProfileDetailView(profile: viewModel.partnerProfile!, onSwipe: { _ in })`.

## Details

- Avatar URL: `viewModel.partnerProfile?.primaryPhoto` (existing computed property on `UserProfile` returning `photos?.first`).
- Placeholder when no photo: `Image(systemName: "person.circle.fill")` at 28pt, in `HarvestTheme.Colors.textSecondary`.
- AsyncImage placeholder while loading: a 28pt circle filled with `HarvestTheme.Colors.divider`.
- Display name uses the existing `HarvestTheme.Typography` (whichever the navigation bar already inherits — no explicit font).
- The button is only shown when `viewModel.partnerProfile != nil`; otherwise fall back to the existing "Chat" placeholder title (no avatar, no tap target).
- `ProfileDetailView` is reused as-is. The `onSwipe: { _ in }` no-op is acceptable because users in an active chat are already matched — swipe semantics don't apply. ProfileDetailView's existing close affordance dismisses the cover.

## Files

- Modify: `Harvest/Views/Chat/ChatDetailView.swift` — add the `@State`, the `.principal` toolbar item, and the `.fullScreenCover`; remove the `.navigationTitle` line.

## Non-Goals

- No online / typing status indicator next to the avatar.
- No unread badges.
- No separate "View Profile" button — the whole header is the tap target.
- No changes to `ProfileDetailView` itself.
- No persisted "last viewed at" state.
