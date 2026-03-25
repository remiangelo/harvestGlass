import SwiftUI

struct FiltersView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = FiltersViewModel()
    @Environment(\.dismiss) private var dismiss

    private let genderOptions = ["Male", "Female", "Non-binary", "Everyone"]
    private let lookingForOptions = ["Relationship", "Casual", "Friendship", "Not sure"]
    private let smokingOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let drinkingOptions = ["Never", "Socially", "Often", "Prefer not to say"]
    private let cannabisOptions = ["Never", "Sometimes", "Often", "Prefer not to say"]
    private let faithOptions = ["Christianity", "Islam", "Judaism", "Buddhism", "Hinduism", "Spiritual", "Agnostic", "Atheist", "Other"]
    private let childrenOptions = ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure", "Prefer not to say"]

    var body: some View {
        Form {
            Section("Age Range") {
                Stepper("Minimum: \(viewModel.filters.ageMin)", value: $viewModel.filters.ageMin, in: 18...99)
                Stepper("Maximum: \(viewModel.filters.ageMax)", value: $viewModel.filters.ageMax, in: 18...99)
            }

            Section("Distance") {
                VStack(alignment: .leading) {
                    Text("Maximum distance: \(viewModel.filters.distanceMax) \(viewModel.filters.distanceUnit)")
                        .font(HarvestTheme.Typography.bodyRegular)
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

            Section("Show Me") {
                ForEach(genderOptions, id: \.self) { option in
                    Button {
                        toggleShowMe(option)
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                            Spacer()
                            if viewModel.filters.showMe.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Visible to others", isOn: $viewModel.filters.isVisible)
                    .tint(HarvestTheme.Colors.primary)
            }

            // Premium filters (Green+)
            Section("Advanced Filters") {
                if viewModel.canAccessAdvanced {
                    Picker("Looking For", selection: Binding(
                        get: { viewModel.filters.lookingFor ?? "" },
                        set: { viewModel.filters.lookingFor = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        ForEach(lookingForOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Stepper("Min Height: \(viewModel.filters.heightMin ?? 0) cm",
                            value: Binding(
                                get: { viewModel.filters.heightMin ?? 150 },
                                set: { viewModel.filters.heightMin = $0 }
                            ), in: 120...220)

                    Stepper("Max Height: \(viewModel.filters.heightMax ?? 0) cm",
                            value: Binding(
                                get: { viewModel.filters.heightMax ?? 200 },
                                set: { viewModel.filters.heightMax = $0 }
                            ), in: 120...220)

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
                        requiredTier: "Green",
                        authViewModel: authViewModel
                    )
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                }
            }

            // Gold-only filters
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
        .scrollContentBackground(.visible)
        .background(Color.white.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let userId = authViewModel.currentUserId {
                        Task {
                            await viewModel.saveFilters(userId: userId)
                            dismiss()
                        }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.primary)
            }
        }
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.loadFilters(userId: userId)
            }
        }
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func toggleShowMe(_ option: String) {
        if let index = viewModel.filters.showMe.firstIndex(of: option) {
            viewModel.filters.showMe.remove(at: index)
        } else {
            viewModel.filters.showMe.append(option)
        }
    }
}
