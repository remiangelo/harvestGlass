import SwiftUI

/// Filters for the room roster. Gating mirrors `FiltersView` exactly —
/// basic is free, advanced needs Grow, full needs Gold — so the two screens
/// never disagree about what a tier buys.
struct RoomMemberFiltersSheet: View {
    @Bindable var vm: RoomMembersViewModel
    let authViewModel: AuthViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                    sectionTitle("Age")
                    GlassCard(style: .light) {
                        VStack(spacing: 0) {
                            StepperCapsuleRow(
                                title: "Minimum: \(vm.filter.ageMin)",
                                value: $vm.filter.ageMin,
                                range: 18...99
                            )
                            divider
                            StepperCapsuleRow(
                                title: "Maximum: \(vm.filter.ageMax)",
                                value: $vm.filter.ageMax,
                                range: 18...99
                            )
                        }
                    }

                    sectionTitle("Gender")
                    GlassCard(style: .light) {
                        pickerRow(
                            title: "Gender",
                            selection: binding(\.gender),
                            options: ["Any"] + ProfileFilterOptions.genderIdentity
                        )
                    }

                    sectionTitle("Advanced")
                    if vm.canAccessAdvanced {
                        GlassCard(style: .light) {
                            VStack(spacing: 0) {
                                pickerRow(
                                    title: "Looking for",
                                    selection: binding(\.lookingFor),
                                    options: ["Any"] + ProfileFilterOptions.lookingFor
                                )
                                divider
                                pickerRow(
                                    title: "Smoking",
                                    selection: binding(\.smoking),
                                    options: ["Any"] + ProfileFilterOptions.smoking
                                )
                                divider
                                pickerRow(
                                    title: "Drinking",
                                    selection: binding(\.drinking),
                                    options: ["Any"] + ProfileFilterOptions.drinking
                                )
                                divider
                                pickerRow(
                                    title: "Cannabis",
                                    selection: binding(\.cannabis),
                                    options: ["Any"] + ProfileFilterOptions.cannabis
                                )
                            }
                        }
                    } else {
                        PremiumGateView(
                            featureName: "Advanced Filters",
                            requiredTier: "Grow",
                            authViewModel: authViewModel
                        )
                        .frame(height: 200)
                    }

                    sectionTitle("Premium")
                    if vm.canAccessFull {
                        GlassCard(style: .light) {
                            VStack(spacing: 0) {
                                pickerRow(
                                    title: "Spiritual/Faith",
                                    selection: binding(\.faith),
                                    options: ["Any"] + ProfileFilterOptions.faith
                                )
                                divider
                                pickerRow(
                                    title: "Children",
                                    selection: binding(\.childrenStatus),
                                    options: ["Any"] + ProfileFilterOptions.children
                                )
                            }
                        }
                    } else {
                        PremiumGateView(
                            featureName: "Full Filters",
                            requiredTier: "Gold",
                            authViewModel: authViewModel
                        )
                        .frame(height: 200)
                    }

                    Button("Clear all", role: .destructive) { vm.resetFilter() }
                        .frame(maxWidth: .infinity)
                        .padding(.top, HarvestTheme.Spacing.sm)
                }
                .padding(HarvestTheme.Spacing.md)
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Filter members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(HarvestTheme.Colors.rose)
                }
            }
        }
    }

    /// "Any" in the picker means "no constraint", i.e. nil on the filter.
    private func binding(_ keyPath: WritableKeyPath<RoomMemberFilter, String?>) -> Binding<String> {
        Binding(
            get: { vm.filter[keyPath: keyPath] ?? "Any" },
            set: { vm.filter[keyPath: keyPath] = $0 == "Any" ? nil : $0 }
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
    }

    private var divider: some View {
        Divider().overlay(HarvestTheme.Colors.formBorder)
    }

    private func pickerRow(
        title: String,
        selection: Binding<String>,
        options: [String]
    ) -> some View {
        HStack {
            Text(title)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnWhitePrimary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(HarvestTheme.Colors.rose)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
        .padding(.horizontal, HarvestTheme.Spacing.xs)
    }
}
