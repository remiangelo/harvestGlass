import SwiftUI

struct TipsView: View {
    @State private var viewModel = TipsViewModel()
    private let chipSurface = Color(hex: "5F2039")
    private let chipSelected = Color(hex: "C67E95")
    private let chipBorder = HarvestTheme.Colors.harvestCream.opacity(0.2)
    private let cardSurface = Color(hex: "5A1B33")
    private let cardBorder = HarvestTheme.Colors.harvestCream.opacity(0.16)

    var body: some View {
        ScrollView {
            VStack(spacing: HarvestTheme.Spacing.lg) {
                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        tipsChip(
                            title: "All",
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            viewModel.selectedCategory = nil
                        }

                        ForEach(TipsViewModel.TipCategory.allCases, id: \.rawValue) { category in
                            tipsChip(
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
                        tipsCard {
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                HStack(spacing: HarvestTheme.Spacing.sm) {
                                    Image(systemName: tip.icon)
                                        .font(.title3)
                                        .foregroundStyle(HarvestTheme.Colors.harvestCream)

                                    Text(tip.title)
                                        .font(HarvestTheme.Typography.h4)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                                    Spacer()

                                    Text(tip.category.rawValue)
                                        .font(HarvestTheme.Typography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(HarvestTheme.Colors.textOnCream)
                                        .padding(.horizontal, HarvestTheme.Spacing.sm)
                                        .padding(.vertical, 6)
                                        .background {
                                            Capsule()
                                                .fill(HarvestTheme.Colors.harvestCream)
                                        }
                                }

                                Text(tip.body)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary.opacity(0.92))
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Quick Advice
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Quick Advice")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .padding(.horizontal)

                    ForEach(TipsViewModel.faqs) { faq in
                        tipsCard(padding: HarvestTheme.Spacing.sm) {
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
                            .tint(HarvestTheme.Colors.harvestCream)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func tipsChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? HarvestTheme.Colors.textOnCream : HarvestTheme.Colors.harvestCream)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    Capsule()
                        .fill(isSelected ? chipSelected : chipSurface)
                        .overlay {
                            Capsule()
                                .stroke(chipBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private func tipsCard<Content: View>(padding: CGFloat = HarvestTheme.Spacing.md, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                    .fill(cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .stroke(cardBorder, lineWidth: 1)
                    }
            }
    }
}
