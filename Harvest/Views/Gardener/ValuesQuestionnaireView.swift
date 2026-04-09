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

    private var isBroughtMode: Bool { selectedTab == 0 }
    private var screenTitle: String { isBroughtMode ? "What I Bring" : "What I Seek" }
    private var currentSet: Set<String> { isBroughtMode ? selectedBrought : selectedSought }
    private var remainingSelections: Int { maxSelections - currentSet.count }

    init(authViewModel: AuthViewModel, initialTab: Int = 0) {
        self.authViewModel = authViewModel
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            HarvestTheme.Colors.formBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(HarvestTheme.Colors.formAccent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                        GlassCard(style: .light) {
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                                Text("Select up to \(maxSelections)")
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                Text("\(remainingSelections) remaining")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }

                        let grouped = Dictionary(grouping: allValues) { $0.category }
                        let sortedCategories = grouped.keys.sorted()

                        ForEach(sortedCategories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                Text(category.capitalized)
                                    .font(HarvestTheme.Typography.h4)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                                FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                    ForEach(grouped[category] ?? [], id: \.id) { value in
                                        ChipView(
                                            title: value.name,
                                            isSelected: currentSet.contains(value.id),
                                            lightStyle: true
                                        ) {
                                            toggleValue(value.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .disabled(isSaving)
            }
        }
        .task {
            await loadValues()
        }
        .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
