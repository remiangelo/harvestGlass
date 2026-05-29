import SwiftUI

struct ValuesStepView: View {
    let viewModel: OnboardingViewModel
    @State private var selectedTab = 0

    private let maxSelections = 3

    private var isBroughtMode: Bool { selectedTab == 0 }
    private var currentSet: Set<String> {
        isBroughtMode ? viewModel.selectedValuesBrought : viewModel.selectedValuesSought
    }
    private var remaining: Int { maxSelections - currentSet.count }

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            VStack(spacing: HarvestTheme.Spacing.xs) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HarvestTheme.Colors.primary)

                Text("Your values")
                    .font(HarvestTheme.Typography.h2)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                Text("Pick what you bring and what you seek. We match on values, not just photos.")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
            }
            .padding(.top, HarvestTheme.Spacing.md)

            Picker("", selection: $selectedTab) {
                Text("I bring").tag(0)
                Text("I seek").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Text("\(currentSet.count)/\(maxSelections) selected · pick at least 1")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            if viewModel.isLoadingValues {
                Spacer()
                ProgressView().tint(HarvestTheme.Colors.primary)
                Spacer()
            } else {
                ScrollView {
                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                        ForEach(viewModel.allValues, id: \.id) { value in
                            ChipView(
                                title: value.name,
                                isSelected: currentSet.contains(value.id),
                                lightStyle: true
                            ) {
                                toggle(valueId: value.id)
                            }
                        }
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.bottom, HarvestTheme.Spacing.md)
                }
            }
        }
        .task {
            await viewModel.loadValuesIfNeeded()
        }
    }

    private func toggle(valueId: String) {
        if isBroughtMode {
            if viewModel.selectedValuesBrought.contains(valueId) {
                viewModel.selectedValuesBrought.remove(valueId)
            } else if viewModel.selectedValuesBrought.count < maxSelections {
                viewModel.selectedValuesBrought.insert(valueId)
            }
        } else {
            if viewModel.selectedValuesSought.contains(valueId) {
                viewModel.selectedValuesSought.remove(valueId)
            } else if viewModel.selectedValuesSought.count < maxSelections {
                viewModel.selectedValuesSought.insert(valueId)
            }
        }
    }
}
