import SwiftUI

struct TipsView: View {
    @State private var viewModel = TipsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: HarvestTheme.Spacing.lg) {
                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        ChipView(
                            title: "All",
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            viewModel.selectedCategory = nil
                        }

                        ForEach(TipsViewModel.TipCategory.allCases, id: \.rawValue) { category in
                            ChipView(
                                title: category.rawValue,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Tips
                VStack(spacing: HarvestTheme.Spacing.md) {
                    ForEach(viewModel.filteredTips) { tip in
                        GlassCard {
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                HStack(spacing: HarvestTheme.Spacing.sm) {
                                    Image(systemName: tip.icon)
                                        .font(.title3)
                                        .foregroundStyle(HarvestTheme.Colors.accent)

                                    Text(tip.title)
                                        .font(HarvestTheme.Typography.h4)

                                    Spacer()

                                    GlassBadge(text: tip.category.rawValue, color: HarvestTheme.Colors.textSecondary)
                                }

                                Text(tip.body)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Quick Advice
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Quick Advice")
                        .font(HarvestTheme.Typography.h3)
                        .padding(.horizontal)

                    ForEach(TipsViewModel.faqs) { faq in
                        GlassCard(padding: HarvestTheme.Spacing.sm) {
                            DisclosureGroup {
                                Text(faq.answer)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                    .padding(.top, HarvestTheme.Spacing.sm)
                            } label: {
                                Text(faq.question)
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .fontWeight(.medium)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                            }
                            .tint(HarvestTheme.Colors.primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
    }
}
