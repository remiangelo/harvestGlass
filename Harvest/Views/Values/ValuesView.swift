import SwiftUI

struct ValuesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = ValuesViewModel()
    @State private var tipsViewModel = TipsViewModel()

    private let chipSurface = Color(hex: "5F2039")
    private let chipSelected = Color(hex: "C67E95")
    private let chipBorder = HarvestTheme.Colors.harvestCream.opacity(0.2)
    private let cardSurface = Color(hex: "5A1B33")
    private let cardBorder = HarvestTheme.Colors.harvestCream.opacity(0.16)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    radarSection
                    blurbSection
                    bringSection
                    seekSection
                    displayTogglesSection
                    tipsSection
                }
                .padding(.vertical)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(HarvestTheme.Colors.accent)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.load(userId: userId)
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var radarSection: some View {
        if viewModel.valuesBrought.isEmpty && viewModel.valuesSought.isEmpty {
            GlassCard {
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "chart.dots.scatter")
                        .font(.system(size: 32))
                        .foregroundStyle(HarvestTheme.Colors.accent)
                    Text("Take the questionnaire to see your values map.")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    NavigationLink {
                        ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: 0)
                    } label: {
                        Text("Start Questionnaire")
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.textOnCream)
                            .padding(.horizontal, HarvestTheme.Spacing.lg)
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                            .background {
                                Capsule().fill(HarvestTheme.Colors.harvestCream)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HarvestTheme.Spacing.md)
            }
            .padding(.horizontal)
        } else {
            ValuesRadarCard(brought: viewModel.valuesBrought, sought: viewModel.valuesSought)
                .padding(.horizontal)
        }
    }

    private var blurbSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Your Blurb")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if let blurb = viewModel.profile?.valuesBlurb, !blurb.isEmpty {
                    Text(blurb)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                } else {
                    Text("Generate a blurb that describes the values you bring and seek.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }

                HStack {
                    Spacer()
                    if viewModel.isGeneratingBlurb {
                        ProgressView().tint(HarvestTheme.Colors.accent)
                    } else {
                        Button {
                            if let userId = authViewModel.currentUserId {
                                Task { await viewModel.generateBlurb(userId: userId) }
                            }
                        } label: {
                            Text(viewModel.profile?.valuesBlurb?.isEmpty == false ? "Regenerate" : "Generate")
                                .font(HarvestTheme.Typography.buttonText)
                                .foregroundStyle(HarvestTheme.Colors.textOnCream)
                                .padding(.horizontal, HarvestTheme.Spacing.md)
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                                .background {
                                    Capsule().fill(HarvestTheme.Colors.harvestCream)
                                }
                        }
                        .disabled(viewModel.valuesBrought.isEmpty && viewModel.valuesSought.isEmpty)
                    }
                }

                if let error = viewModel.blurbError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private var bringSection: some View {
        valuesSection(
            title: "What I Bring",
            values: viewModel.valuesBrought,
            initialTab: 0
        )
    }

    private var seekSection: some View {
        valuesSection(
            title: "What I Seek",
            values: viewModel.valuesSought,
            initialTab: 1
        )
    }

    private func valuesSection(title: String, values: [Value], initialTab: Int) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                HStack {
                    Text(title)
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    Spacer()
                    NavigationLink {
                        ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: initialTab)
                    } label: {
                        Text("Edit")
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.accent)
                    }
                }

                if values.isEmpty {
                    Text("None selected yet.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                } else {
                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                        ForEach(values) { value in
                            ChipView(title: value.name)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var displayTogglesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Show on Profile")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                toggleRow(label: "Values I Bring",
                          isOn: Binding(get: { viewModel.profile?.showValuesBrought ?? true },
                                        set: { setToggle(.brought, $0) }))
                toggleRow(label: "Values I Seek",
                          isOn: Binding(get: { viewModel.profile?.showValuesSought ?? true },
                                        set: { setToggle(.sought, $0) }))
                toggleRow(label: "Generated Blurb",
                          isOn: Binding(get: { viewModel.profile?.showValuesBlurb ?? true },
                                        set: { setToggle(.blurb, $0) }))
                toggleRow(label: "Values Graph",
                          isOn: Binding(get: { viewModel.profile?.showValuesGraph ?? true },
                                        set: { setToggle(.graph, $0) }))

                if let error = viewModel.toggleError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
        }
        .tint(HarvestTheme.Colors.accent)
    }

    private func setToggle(_ key: ValuesViewModel.DisplayToggle, _ value: Bool) {
        guard let userId = authViewModel.currentUserId else { return }
        Task { await viewModel.setDisplayToggle(userId: userId, key: key, isOn: value) }
    }

    // MARK: - Tips (embedded)

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
            Text("Values-Based Dating Tips")
                .font(HarvestTheme.Typography.h3)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    tipsChip(title: "All", isSelected: tipsViewModel.selectedCategory == nil) {
                        tipsViewModel.selectedCategory = nil
                    }
                    ForEach(TipsViewModel.TipCategory.allCases, id: \.rawValue) { category in
                        tipsChip(title: category.rawValue, isSelected: tipsViewModel.selectedCategory == category) {
                            tipsViewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }

            VStack(spacing: HarvestTheme.Spacing.md) {
                ForEach(tipsViewModel.filteredTips) { tip in
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
                                        Capsule().fill(HarvestTheme.Colors.harvestCream)
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
                        .overlay { Capsule().stroke(chipBorder, lineWidth: 1) }
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
                    .overlay { RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg).stroke(cardBorder, lineWidth: 1) }
            }
    }
}
