import SwiftUI

struct FiltersView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = FiltersViewModel()
    @Environment(\.dismiss) private var dismiss

    private let genderOptions: [(label: String, value: String)] = [
        ("Male", "male"),
        ("Female", "female"),
        ("Non-binary", "non-binary"),
        ("Everyone", "everyone")
    ]
    private let lookingForOptions = ["Dating", "Relationship", "Long-term Commitment", "Marriage"]
    private let smokingOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let drinkingOptions = ["Never", "Socially", "Often", "Prefer not to say"]
    private let cannabisOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let faithOptions = ["Christianity", "Islam", "Judaism", "Buddhism", "Hinduism", "Spiritual", "Agnostic", "Atheist", "Other"]
    private let childrenOptions = ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure", "Prefer not to say"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                sectionTitle("Age Range")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        StepperCapsuleRow(
                            title: "Minimum: \(viewModel.filters.ageMin)",
                            value: $viewModel.filters.ageMin,
                            range: 18...99
                        )
                        Divider().overlay(HarvestTheme.Colors.formBorder)
                        StepperCapsuleRow(
                            title: "Maximum: \(viewModel.filters.ageMax)",
                            value: $viewModel.filters.ageMax,
                            range: 18...99
                        )
                    }
                }

                sectionTitle("Distance")
                GlassCard(style: .light) {
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                        Text("Maximum distance: \(viewModel.filters.distanceMax) \(viewModel.filters.distanceUnit)")
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)

                        Slider(
                            value: Binding(
                                get: { Double(viewModel.filters.distanceMax) },
                                set: { viewModel.filters.distanceMax = Int($0) }
                            ),
                            in: 1...100,
                            step: 1
                        )
                        .tint(HarvestTheme.Colors.formAccent)

                        Divider().overlay(HarvestTheme.Colors.formBorder)

                        PickerRow(title: "Unit") {
                            Picker("Unit", selection: $viewModel.filters.distanceUnit) {
                                Text("Miles").tag("mi")
                                Text("Kilometers").tag("km")
                            }
                            .labelsHidden()
                            .tint(HarvestTheme.Colors.formAccent)
                        }
                    }
                }

                sectionTitle("Show Me")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        ForEach(Array(genderOptions.enumerated()), id: \.offset) { index, option in
                            Button {
                                toggleShowMe(option.value)
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                    Spacer()
                                    if viewModel.filters.showMe.contains(option.value) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(HarvestTheme.Colors.formAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                            }
                            .buttonStyle(.plain)

                            if index < genderOptions.count - 1 {
                                Divider().overlay(HarvestTheme.Colors.formBorder)
                            }
                        }
                    }
                }

                GlassCard(style: .light) {
                    Toggle("Visible to others", isOn: $viewModel.filters.isVisible)
                        .tint(HarvestTheme.Colors.formAccent)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }

                sectionTitle("Advanced Filters")
                if viewModel.canAccessAdvanced {
                    GlassCard(style: .light) {
                        VStack(spacing: 0) {
                            pickerRow(
                                title: "Looking For",
                                selection: Binding(
                                    get: { viewModel.filters.lookingFor ?? "" },
                                    set: { viewModel.filters.lookingFor = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + lookingForOptions
                            )
                            dividerRow()
                            StepperCapsuleRow(
                                title: "Min Height: \(HeightFormatter.string(from: viewModel.filters.heightMin ?? 150))",
                                value: Binding(
                                    get: { viewModel.filters.heightMin ?? 150 },
                                    set: { viewModel.filters.heightMin = $0 }
                                ),
                                range: 120...220
                            )
                            dividerRow()
                            StepperCapsuleRow(
                                title: "Max Height: \(HeightFormatter.string(from: viewModel.filters.heightMax ?? 200))",
                                value: Binding(
                                    get: { viewModel.filters.heightMax ?? 200 },
                                    set: { viewModel.filters.heightMax = $0 }
                                ),
                                range: 120...220
                            )
                            dividerRow()
                            pickerRow(
                                title: "Smoking",
                                selection: Binding(
                                    get: { viewModel.filters.smoking ?? "" },
                                    set: { viewModel.filters.smoking = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + smokingOptions
                            )
                            dividerRow()
                            pickerRow(
                                title: "Drinking",
                                selection: Binding(
                                    get: { viewModel.filters.drinking ?? "" },
                                    set: { viewModel.filters.drinking = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + drinkingOptions
                            )
                            dividerRow()
                            pickerRow(
                                title: "Cannabis",
                                selection: Binding(
                                    get: { viewModel.filters.cannabis ?? "" },
                                    set: { viewModel.filters.cannabis = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + cannabisOptions
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

                sectionTitle("Premium Filters")
                if viewModel.canAccessFull {
                    GlassCard(style: .light) {
                        VStack(spacing: 0) {
                            pickerRow(
                                title: "Spiritual/Faith",
                                selection: Binding(
                                    get: { viewModel.filters.spiritualFaith ?? "" },
                                    set: { viewModel.filters.spiritualFaith = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + faithOptions
                            )
                            dividerRow()
                            pickerRow(
                                title: "Children",
                                selection: Binding(
                                    get: { viewModel.filters.childrenStatus ?? "" },
                                    set: { viewModel.filters.childrenStatus = $0.isEmpty ? nil : $0 }
                                ),
                                options: ["Any"] + childrenOptions
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

                Button("Reset to Defaults", role: .destructive) {
                    if let userId = authViewModel.currentUserId {
                        Task { await viewModel.resetFilters(userId: userId) }
                    }
                }
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.formAccent)
            }
            .padding()
        }
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let userId = authViewModel.currentUserId {
                        Task {
                            if await viewModel.saveFilters(userId: userId) {
                                dismiss()
                            }
                        }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }
        }
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.loadFilters(userId: userId)
            }
        }
        .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
    }

    private func dividerRow() -> some View {
        Divider().overlay(HarvestTheme.Colors.formBorder)
    }

    private func pickerRow(title: String, selection: Binding<String>, options: [String]) -> some View {
        PickerRow(title: title) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    let value = option == "Any" ? "" : option
                    Text(option).tag(value)
                }
            }
            .labelsHidden()
            .tint(HarvestTheme.Colors.formAccent)
        }
    }

    private func toggleShowMe(_ option: String) {
        if let index = viewModel.filters.showMe.firstIndex(of: option) {
            viewModel.filters.showMe.remove(at: index)
        } else {
            viewModel.filters.showMe.append(option)
        }
    }
}

private struct PickerRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: HarvestTheme.Spacing.sm)
            content()
                .frame(maxWidth: 170, alignment: .trailing)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }
}
