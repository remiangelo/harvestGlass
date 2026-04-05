import SwiftUI

struct FiltersView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = FiltersViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var minHeightFeet: Int = 4
    @State private var minHeightInches: Int = 11
    @State private var maxHeightFeet: Int = 6
    @State private var maxHeightInches: Int = 7

    private let genderOptions: [(label: String, value: String)] = [
        ("Male", "male"),
        ("Female", "female"),
        ("Non-binary", "non-binary"),
        ("Everyone", "everyone")
    ]
    private let lookingForOptions = ["Dating", "Relationship", "Long-Term Commitment", "Marriage"]
    private let smokingOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let drinkingOptions = ["Never", "Socially", "Often", "Prefer not to say"]
    private let cannabisOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let faithOptions = ["Christianity", "Islam", "Judaism", "Buddhism", "Hinduism", "Spiritual", "Agnostic", "Atheist", "Other"]
    private let childrenOptions = ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure", "Prefer not to say"]

    var body: some View {
        List {
            Section("Age Range") {
                Stepper("Minimum: \(viewModel.filters.ageMin)", value: $viewModel.filters.ageMin, in: 18...99)
                Stepper("Maximum: \(viewModel.filters.ageMax)", value: $viewModel.filters.ageMax, in: 18...99)
            }

            Section("Distance") {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                    Text("Maximum distance: \(viewModel.filters.distanceMax) \(viewModel.filters.distanceUnit)")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(.primary)

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.filters.distanceMax) },
                            set: { viewModel.filters.distanceMax = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    .tint(HarvestTheme.Colors.primary)
                }

                Picker("Unit", selection: $viewModel.filters.distanceUnit) {
                    Text("Miles").tag("mi")
                    Text("Kilometers").tag("km")
                }
            }

            Section {
                ForEach(genderOptions, id: \.value) { option in
                    Button {
                        toggleShowMe(option.value)
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(
                                    viewModel.filters.showMe.contains(option.value)
                                    ? AnyShapeStyle(.primary)
                                    : AnyShapeStyle(.secondary)
                                )
                            Spacer()
                            if viewModel.filters.showMe.contains(option.value) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                            }
                        }
                    }
                }
            } header: {
                Text("Show Me")
                    .textCase(nil)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Visible to others", isOn: $viewModel.filters.isVisible)
                    .tint(HarvestTheme.Colors.primary)
            }

            Section("Advanced Filters") {
                if viewModel.canAccessAdvanced {
                    Picker("Looking For", selection: Binding(
                        get: { viewModel.filters.lookingFor ?? "" },
                        set: { viewModel.filters.lookingFor = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(lookingForOptions, id: \.self) { Text($0).tag($0) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min Height: \(minHeightFeet)'\(minHeightInches)\"")
                        Stepper("Feet: \(minHeightFeet)", value: $minHeightFeet, in: 4...7)
                            .onChange(of: minHeightFeet) { viewModel.filters.heightMin = feetInchesToCm(feet: minHeightFeet, inches: minHeightInches) }
                        Stepper("Inches: \(minHeightInches)", value: $minHeightInches, in: 0...11)
                            .onChange(of: minHeightInches) { viewModel.filters.heightMin = feetInchesToCm(feet: minHeightFeet, inches: minHeightInches) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Height: \(maxHeightFeet)'\(maxHeightInches)\"")
                        Stepper("Feet: \(maxHeightFeet)", value: $maxHeightFeet, in: 4...7)
                            .onChange(of: maxHeightFeet) { viewModel.filters.heightMax = feetInchesToCm(feet: maxHeightFeet, inches: maxHeightInches) }
                        Stepper("Inches: \(maxHeightInches)", value: $maxHeightInches, in: 0...11)
                            .onChange(of: maxHeightInches) { viewModel.filters.heightMax = feetInchesToCm(feet: maxHeightFeet, inches: maxHeightInches) }
                    }

                    Picker("Smoking", selection: Binding(
                        get: { viewModel.filters.smoking ?? "" },
                        set: { viewModel.filters.smoking = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(smokingOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker("Drinking", selection: Binding(
                        get: { viewModel.filters.drinking ?? "" },
                        set: { viewModel.filters.drinking = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(drinkingOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker("Cannabis", selection: Binding(
                        get: { viewModel.filters.cannabis ?? "" },
                        set: { viewModel.filters.cannabis = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(cannabisOptions, id: \.self) { Text($0).tag($0) }
                    }
                } else {
                    PremiumGateView(
                        featureName: "Advanced Filters",
                        requiredTier: "Grow",
                        authViewModel: authViewModel
                    )
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Premium Filters") {
                if viewModel.canAccessFull {
                    Picker("Spiritual/Faith", selection: Binding(
                        get: { viewModel.filters.spiritualFaith ?? "" },
                        set: { viewModel.filters.spiritualFaith = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(faithOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker("Children", selection: Binding(
                        get: { viewModel.filters.childrenStatus ?? "" },
                        set: { viewModel.filters.childrenStatus = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(childrenOptions, id: \.self) { Text($0).tag($0) }
                    }
                } else {
                    PremiumGateView(
                        featureName: "Full Filters",
                        requiredTier: "Gold",
                        authViewModel: authViewModel
                    )
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    if let userId = authViewModel.currentUserId {
                        Task { await viewModel.resetFilters(userId: userId) }
                    }
                }
            }
        }
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
                .foregroundStyle(.primary)
            }
        }
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.loadFilters(userId: userId)
                let (minFt, minIn) = cmToFeetInches(viewModel.filters.heightMin ?? 150)
                minHeightFeet = minFt
                minHeightInches = minIn
                let (maxFt, maxIn) = cmToFeetInches(viewModel.filters.heightMax ?? 200)
                maxHeightFeet = maxFt
                maxHeightInches = maxIn
            }
        }
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .listSectionSpacing(20)
        .listStyle(.insetGrouped)
    }

    private func toggleShowMe(_ option: String) {
        if let index = viewModel.filters.showMe.firstIndex(of: option) {
            viewModel.filters.showMe.remove(at: index)
        } else {
            viewModel.filters.showMe.append(option)
        }
    }

    private func cmToFeetInches(_ cm: Int) -> (Int, Int) {
        let totalInches = Int(round(Double(cm) / 2.54))
        return (totalInches / 12, totalInches % 12)
    }

    private func feetInchesToCm(feet: Int, inches: Int) -> Int {
        Int(round(Double(feet * 12 + inches) * 2.54))
    }
}
