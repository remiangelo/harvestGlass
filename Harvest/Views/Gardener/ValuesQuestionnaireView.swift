import SwiftUI

struct ValuesQuestionnaireView: View {
    let authViewModel: AuthViewModel

    @State private var allValues: [Value] = []
    @State private var selectedBrought: Set<String> = []
    @State private var selectedSought: Set<String> = []
    @State private var selectedTab: Int
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private let valuesService = ValuesService()
    private let maxSelections = 5

    init(authViewModel: AuthViewModel, initialTab: Int = 0) {
        self.authViewModel = authViewModel
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $selectedTab) {
                Text("Values I Bring").tag(0)
                Text("Values I Seek").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                        let currentSet = selectedTab == 0 ? selectedBrought : selectedSought
                        let remaining = maxSelections - currentSet.count

                        Text("Select up to \(maxSelections) values (\(remaining) remaining)")
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .padding(.horizontal)

                        // Group by category
                        let grouped = Dictionary(grouping: allValues) { $0.category }
                        let sortedCategories = grouped.keys.sorted()

                        ForEach(sortedCategories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                Text(category.capitalized)
                                    .font(HarvestTheme.Typography.h4)
                                    .padding(.horizontal)

                                FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                    ForEach(grouped[category] ?? [], id: \.id) { value in
                                        ChipView(
                                            title: value.name,
                                            isSelected: currentSet.contains(value.id)
                                        ) {
                                            toggleValue(value.id)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("My Values")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.primary)
                .disabled(isSaving)
            }
        }
        .task {
            await loadValues()
        }
    }

    private func toggleValue(_ valueId: String) {
        if selectedTab == 0 {
            if selectedBrought.contains(valueId) {
                selectedBrought.remove(valueId)
            } else if selectedBrought.count < maxSelections {
                selectedBrought.insert(valueId)
            }
        } else {
            if selectedSought.contains(valueId) {
                selectedSought.remove(valueId)
            } else if selectedSought.count < maxSelections {
                selectedSought.insert(valueId)
            }
        }
    }

    private func loadValues() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authViewModel.currentUserId else { return }

        do {
            allValues = try await valuesService.getAllValues()
        } catch {
            self.error = error.localizedDescription
            return // Can't show picker without values
        }

        // Non-critical — user may not have saved values yet
        let brought = try? await valuesService.getUserValuesBrought(userId: userId)
        let sought = try? await valuesService.getUserValuesSought(userId: userId)
        selectedBrought = Set((brought ?? []).map(\.id))
        selectedSought = Set((sought ?? []).map(\.id))
    }

    private func save() async {
        guard let userId = authViewModel.currentUserId else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await valuesService.saveUserValuesBrought(userId: userId, valueIds: Array(selectedBrought))
            try await valuesService.saveUserValuesSought(userId: userId, valueIds: Array(selectedSought))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
