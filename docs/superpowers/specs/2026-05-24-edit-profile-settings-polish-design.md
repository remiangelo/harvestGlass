# Edit Profile + Settings Polish Design

**Date:** 2026-05-24
**Goal:** Tighten the spacing and visual hierarchy of `ProfileEditView` and `SettingsView` with eight targeted fixes. No structural redesign; no new color tokens; no GlassCard replacement.

## 1. Shared section-header style

Today both screens use `Text(title).font(.h4).foregroundStyle(textPrimary or textSecondary)` for section labels — large (18pt semibold) and inconsistent between the two screens.

Replace with a new shared view in `Harvest/Views/Components/SectionHeader.swift`:

```swift
import SwiftUI

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(HarvestTheme.Typography.caption)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
            .padding(.leading, HarvestTheme.Spacing.xs)
    }
}
```

- 12pt (`Typography.caption`) / `.medium` weight / uppercase / tracking 0.8 / `textSecondary`.
- Small `xs` leading padding so the title sits slightly inset from the card edge — iOS-Settings inset-grouped feel.

Both views replace their private `sectionTitle(_:)` helpers with calls to `SectionHeader(title:)`.

## 2. Row vertical padding consistency (Settings only)

In `SettingsView`, `toggleRow` uses `padding(.vertical, .xs)` (4pt) while sibling row helpers (`row`, `navRow`) use `padding(.vertical, .sm)` (8pt). Standardize `toggleRow` to `.sm` so all row heights match within a card.

## 3. Gardener-time row alignment (Settings only)

The Gardener-time HStack currently has its own `.padding(.horizontal, HarvestTheme.Spacing.md)` plus `.padding(.vertical, HarvestTheme.Spacing.sm)`. The horizontal override visually insets it by an extra 16pt relative to sibling toggle rows (which rely solely on the GlassCard's inner padding).

Remove the explicit `.padding(.horizontal, .md)` line. Keep the vertical padding. The Gardener-hour row will then align horizontally with the toggles above it.

## 4. Combined destructive-actions card (Settings only)

Today Log Out and Delete Account each sit in their own `GlassCard`, producing two adjacent single-row cards. Merge into one `GlassCard(style: .light)` containing:

```
VStack(spacing: 0):
    logOutButtonRow
    dividerRow
    deleteAccountButtonRow
```

Each row keeps its existing button label/action and `padding(.vertical, .sm)`. Reduces vertical real estate by ~24pt and groups the two "exit" actions visually.

## 5. About row merged into Support card (Settings only)

The "About" section is a one-row card containing just the Version row. The "Support" section is a one-row card containing Help Center. Both are visually lonely.

Drop the standalone "About" `sectionTitle` and the standalone About-card. Move the Version row into the existing Support `GlassCard` as a second row separated by `dividerRow()`. The Support card becomes:

```
VStack(spacing: 0):
    navRow("Help Center") { HelpCenterView(...) }
    dividerRow
    row(title: "Version", trailing: "1.0.0")
```

## 6. Bio editor breathing room (Edit Profile only)

The "About Me" `GlassCard` wraps a `TextEditor` with `minHeight: 120` and no inner padding. Cramped.

Bump `minHeight` to 140 and add `.padding(.vertical, HarvestTheme.Spacing.xs)` inside the GlassCard, around the TextEditor. The cursor and first line no longer kiss the card's inner border.

## 7. Picker label flex-width (Edit Profile only)

`pickerRow`'s right-aligned label has a fixed `.frame(width: 150, alignment: .trailing)`. Long option labels like "Spiritual, not religious" or "Have and don't want more" truncate. Replace the fixed frame with:

```swift
.lineLimit(1)
.minimumScaleFactor(0.7)
.frame(maxWidth: .infinity, alignment: .trailing)
```

Picker labels now occupy the natural trailing slack and shrink down to 70% before truncating. The `Spacer(minLength: HarvestTheme.Spacing.sm)` between the title `Text` and the `Menu` already prevents collision with the leading label.

## 8. Top-of-scroll headroom (both)

Both screens' outer `ScrollView`'s inner `VStack` is wrapped in `.padding()` — 16pt all sides. With the new (much smaller) section header style, the first section title sits closer to the nav bar than ideal.

Add `.padding(.top, HarvestTheme.Spacing.sm)` (8pt extra at the top) to the inner `VStack` in both views. Net top breathing room becomes 16 + 8 = 24pt.

## Files

**New:**
- `Harvest/Views/Components/SectionHeader.swift`

**Modified:**
- `Harvest/Views/Profile/ProfileEditView.swift` — replace `sectionTitle(_:)` calls with `SectionHeader(title:)`; delete the private helper; pickerRow flex-width fix; Bio editor padding + minHeight; top-of-scroll headroom.
- `Harvest/Views/Settings/SettingsView.swift` — same SectionHeader swap; row vertical-padding consistency on toggleRow; remove Gardener-time horizontal override; combine destructive-actions card; merge Version into Support card; top-of-scroll headroom.

## Out of Scope

- No SF Symbol icons before rows.
- No inset-grouped iOS table style; GlassCard stays as-is.
- No new color or font tokens.
- No changes to `ProfilePhotoGrid`, `compactStepper`, `GlassBadge`, alerts, sheets.
- No changes to row alignment behavior on dynamic-type accessibility sizes.
- No section reordering beyond the About → Support merge.

## Assumptions

- `HarvestTheme.Typography.caption` (12pt medium) and `Spacing.xs`/`sm`/`md`/`lg` exist (verified).
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` so the new `SectionHeader.swift` file is auto-discovered when added under `Harvest/Views/Components/`.
- `.textCase(.uppercase)` + `.tracking()` render correctly on iOS 17+, which is the project's target.
- Both views currently fit within their `body` size limit; the changes are net-neutral on body length so no decomposition is forced.
