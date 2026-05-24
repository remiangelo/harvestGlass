# Edit Profile + Settings Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten spacing and visual hierarchy of `ProfileEditView` and `SettingsView` via eight targeted polish fixes plus one new shared component (`SectionHeader`).

**Architecture:** Three tasks. Task 1 introduces the shared `SectionHeader` component. Task 2 modifies `ProfileEditView` (header swap + bio breathing room + picker label flex-width + top-of-scroll headroom). Task 3 modifies `SettingsView` (header swap + row padding consistency + Gardener-time alignment + merge destructive cards + merge About into Support + top-of-scroll headroom).

**Tech Stack:** SwiftUI / `HarvestTheme` tokens.

**Spec:** [`docs/superpowers/specs/2026-05-24-edit-profile-settings-polish-design.md`](../specs/2026-05-24-edit-profile-settings-polish-design.md)

---

## File Inventory

**New:**
- `Harvest/Views/Components/SectionHeader.swift`

**Modified:**
- `Harvest/Views/Profile/ProfileEditView.swift`
- `Harvest/Views/Settings/SettingsView.swift`

---

## Task 1: New `SectionHeader` shared component

**Files:**
- Create: `Harvest/Views/Components/SectionHeader.swift`

- [ ] **Step 1.1: Create the file**

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

#Preview {
    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
        SectionHeader(title: "Notifications")
        SectionHeader(title: "Privacy")
        SectionHeader(title: "Account")
    }
    .padding()
    .background(HarvestTheme.Colors.formBackground)
}
```

- [ ] **Step 1.2: Commit**

```
git add Harvest/Views/Components/SectionHeader.swift
git commit -m "feat(components): SectionHeader for inset uppercase labels"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 2: `ProfileEditView` polish

**Files:**
- Modify: `Harvest/Views/Profile/ProfileEditView.swift`

- [ ] **Step 2.1: Replace all `sectionTitle(...)` call sites with `SectionHeader(title:)`**

In `Harvest/Views/Profile/ProfileEditView.swift`, find every line that reads `sectionTitle("...")` and replace it with `SectionHeader(title: "...")`. There are 6 such lines (Photos, Basic Info, About Me, Lifestyle & Intentions, Interests; verify by grep). Concrete substitutions:

```
sectionTitle("Photos")                   → SectionHeader(title: "Photos")
sectionTitle("Basic Info")               → SectionHeader(title: "Basic Info")
sectionTitle("About Me")                 → SectionHeader(title: "About Me")
sectionTitle("Lifestyle & Intentions")   → SectionHeader(title: "Lifestyle & Intentions")
sectionTitle("Interests")                → SectionHeader(title: "Interests")
```

- [ ] **Step 2.2: Delete the private `sectionTitle(_:)` helper**

In the same file, find this helper (it should be the first private function under `// after body` around lines 190–194):

```swift
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
    }
```

Delete it entirely.

- [ ] **Step 2.3: Bio editor breathing room**

The current "About Me" GlassCard contents (lines 117–122) are:

```swift
                sectionTitle("About Me")
                GlassCard(style: .light) {
                    TextEditor(text: $viewModel.editBio)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
```

After Step 2.1 the `sectionTitle` line is already `SectionHeader(title: "About Me")`. Replace the `GlassCard` body of this section with:

```swift
                SectionHeader(title: "About Me")
                GlassCard(style: .light) {
                    TextEditor(text: $viewModel.editBio)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(.vertical, HarvestTheme.Spacing.xs)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
```

Two changes: `minHeight: 120 → 140`, plus a new `.padding(.vertical, HarvestTheme.Spacing.xs)` line.

- [ ] **Step 2.4: PickerRow flex-width**

In the private `pickerRow(title:selection:options:)` helper (currently lines 215–244), the `Menu` label HStack currently uses:

```swift
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLabel(for: selection.wrappedValue, options: options))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(HarvestTheme.Colors.formAccent)
                .frame(width: 150, alignment: .trailing)
            }
```

Change two things:
- `minimumScaleFactor(0.72)` → `minimumScaleFactor(0.7)` (matches the spec's 70% value).
- `.frame(width: 150, alignment: .trailing)` → `.frame(maxWidth: .infinity, alignment: .trailing)`.

After the change the same block reads:

```swift
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLabel(for: selection.wrappedValue, options: options))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(HarvestTheme.Colors.formAccent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
```

- [ ] **Step 2.5: Top-of-scroll headroom**

The outer `VStack` (line 58) currently reads:

```swift
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
```

Add `.padding(.top, HarvestTheme.Spacing.sm)` after the closing `}` of the `VStack` (which is the line `.padding()` at line 158). After the change the closing modifier chain becomes:

```swift
            }
            .padding()
            .padding(.top, HarvestTheme.Spacing.sm)
        }
```

- [ ] **Step 2.6: Commit**

```
git add Harvest/Views/Profile/ProfileEditView.swift
git commit -m "ui(profile): polish edit form spacing and headers"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 3: `SettingsView` polish

**Files:**
- Modify: `Harvest/Views/Settings/SettingsView.swift`

- [ ] **Step 3.1: Replace all `sectionTitle(...)` call sites with `SectionHeader(title:)`**

Find every `sectionTitle("...")` line in `Harvest/Views/Settings/SettingsView.swift` (Account, Notifications, Privacy, Legal, Safety, Support, About — 7 lines). Replace each:

```
sectionTitle("Account")        → SectionHeader(title: "Account")
sectionTitle("Notifications")  → SectionHeader(title: "Notifications")
sectionTitle("Privacy")        → SectionHeader(title: "Privacy")
sectionTitle("Legal")          → SectionHeader(title: "Legal")
sectionTitle("Safety")         → SectionHeader(title: "Safety")
sectionTitle("Support")        → SectionHeader(title: "Support")
```

DO NOT replace `sectionTitle("About")` — that whole section gets deleted in Step 3.5. Just remove its line along with its card.

- [ ] **Step 3.2: Delete the private `sectionTitle(_:)` helper**

In the same file, find this helper (around lines 368–372):

```swift
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
    }
```

Delete it entirely.

- [ ] **Step 3.3: Standardize `toggleRow` vertical padding to `.sm`**

The current `toggleRow` helper (around lines 389–394) is:

```swift
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(HarvestTheme.Colors.formAccent)
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .padding(.vertical, HarvestTheme.Spacing.xs)
    }
```

Change `.padding(.vertical, HarvestTheme.Spacing.xs)` to `.padding(.vertical, HarvestTheme.Spacing.sm)`. Resulting helper:

```swift
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(HarvestTheme.Colors.formAccent)
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .padding(.vertical, HarvestTheme.Spacing.sm)
    }
```

- [ ] **Step 3.4: Remove Gardener-time horizontal padding override**

Find the Gardener-time row HStack (currently lines 95–108):

```swift
                            if profile?.notifGardenerLocalEnabled ?? true {
                                dividerRow()
                                HStack {
                                    Text("Gardener time")
                                        .font(HarvestTheme.Typography.bodyRegular)
                                    Spacer()
                                    Picker("", selection: gardenerHourBinding) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(formatHour(h)).tag(h)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.horizontal, HarvestTheme.Spacing.md)
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                            }
```

Remove the line `.padding(.horizontal, HarvestTheme.Spacing.md)`. Keep `.padding(.vertical, HarvestTheme.Spacing.sm)`. Result:

```swift
                            if profile?.notifGardenerLocalEnabled ?? true {
                                dividerRow()
                                HStack {
                                    Text("Gardener time")
                                        .font(HarvestTheme.Typography.bodyRegular)
                                    Spacer()
                                    Picker("", selection: gardenerHourBinding) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(formatHour(h)).tag(h)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                            }
```

- [ ] **Step 3.5: Merge About-Version row into Support card; drop standalone About**

The current "Support" section + "About" section (around lines 163–171) are:

```swift
                sectionTitle("Support")
                GlassCard(style: .light) {
                    navRow("Help Center") { HelpCenterView(authViewModel: authViewModel) }
                }

                sectionTitle("About")
                GlassCard(style: .light) {
                    row(title: "Version", trailing: "1.0.0")
                }
```

Replace the entire block (the two `sectionTitle` lines plus their two cards) with:

```swift
                SectionHeader(title: "Support")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        navRow("Help Center") { HelpCenterView(authViewModel: authViewModel) }
                        dividerRow()
                        row(title: "Version", trailing: "1.0.0")
                    }
                }
```

- [ ] **Step 3.6: Merge Log Out and Delete Account into one card**

The current logout + delete blocks (around lines 173–203) are two separate `GlassCard`s:

```swift
                GlassCard(style: .light) {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .fontWeight(.semibold)
                                .foregroundStyle(HarvestTheme.Colors.formAccent)
                            Spacer()
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }

                GlassCard(style: .light) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .fontWeight(.semibold)
                                .foregroundStyle(HarvestTheme.Colors.formAccent)
                            Spacer()
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
```

Replace BOTH blocks with this single card:

```swift
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Log Out")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(HarvestTheme.Colors.formAccent)
                                Spacer()
                            }
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)

                        dividerRow()

                        Button {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Account")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(HarvestTheme.Colors.formAccent)
                                Spacer()
                            }
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
```

- [ ] **Step 3.7: Top-of-scroll headroom**

The outer `VStack` opens at line 27:

```swift
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
```

And closes around line 204 with `.padding()`. After that `.padding()` line, append `.padding(.top, HarvestTheme.Spacing.sm)`. Result around lines 204–206:

```swift
            }
            .padding()
            .padding(.top, HarvestTheme.Spacing.sm)
        }
```

- [ ] **Step 3.8: Commit**

```
git add Harvest/Views/Settings/SettingsView.swift
git commit -m "ui(settings): polish spacing, headers, and grouping"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Self-Review Checklist

- [x] **Spec coverage:**
  - §1 SectionHeader → Task 1.
  - §2 Row vertical padding consistency → Task 3.3 (toggleRow → sm).
  - §3 Gardener-time alignment → Task 3.4 (remove horizontal padding).
  - §4 Combined destructive card → Task 3.6.
  - §5 About merged into Support → Task 3.5.
  - §6 Bio breathing room → Task 2.3 (minHeight 140 + xs vertical padding).
  - §7 Picker label flex-width → Task 2.4 (drop fixed 150, add `maxWidth: .infinity` trailing).
  - §8 Top-of-scroll headroom → Task 2.5 (ProfileEditView) and Task 3.7 (SettingsView).
- [x] **No placeholders:** every code block is complete. Line numbers for legacy code are approximate but each replacement quotes the exact source text to locate it by content.
- [x] **Type consistency:** `SectionHeader(title:)` is declared in Task 1 and called identically (`SectionHeader(title: "Section Name")`) in Tasks 2 and 3. The private `sectionTitle(_:)` helpers in both views are deleted in Tasks 2.2 and 3.2. The toggleRow padding-token change is consistent (xs → sm). All `HarvestTheme.Spacing.*` references match existing tokens (xs=4, sm=8, md=16, lg=24).
