import SwiftUI

struct ValuesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = ValuesViewModel()
    @State private var tipsViewModel = TipsViewModel()
    @State private var showQuestionSheet = false

    private let chipSurface = HarvestTheme.Colors.wineCard
    private let chipSelected = HarvestTheme.Colors.rose
    private let chipBorder = HarvestTheme.Colors.rose.opacity(0.25)
    private let cardSurface = HarvestTheme.Colors.wineCard
    private let cardBorder = HarvestTheme.Colors.rose.opacity(0.22)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    topModePicker

                    switch viewModel.mode {
                    case .main:
                        mainContent
                    case .tips:
                        tipsSection
                    }
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
            .sheet(isPresented: $showQuestionSheet) {
                QuestionSheetView(authViewModel: authViewModel, viewModel: viewModel)
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Mode + Side pickers

    private var topModePicker: some View {
        Picker("", selection: $viewModel.mode) {
            Text("Main").tag(ValuesViewModel.Mode.main)
            Text("Tips").tag(ValuesViewModel.Mode.tips)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var sidePicker: some View {
        Picker("", selection: $viewModel.side) {
            Text("I Need").tag(ValuesViewModel.Side.need)
            Text("I Bring").tag(ValuesViewModel.Side.bring)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: HarvestTheme.Spacing.lg) {
            if viewModel.showRetakeBanner {
                retakeBanner
            }
            sidePicker
            radarCard
            moreQuestionsButton
            valuesPicker
            blurbSection
            displayTogglesSection
        }
    }

    private var retakeBanner: some View {
        Button {
            showQuestionSheet = true
        } label: {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(HarvestTheme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your values questionnaire has been updated")
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("Answer 10 quick questions so we can find new matches for you.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
            .padding(HarvestTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                    .fill(HarvestTheme.Colors.glassFillStrong)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .stroke(HarvestTheme.Colors.rose.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var radarCard: some View {
        ValuesRadarCard(
            primary: viewModel.activeScores,
            primaryLabel: viewModel.side == .need ? "I Need" : "I Bring",
            onEmptyTap: { showQuestionSheet = true }
        )
        .padding(.horizontal)
    }

    private var moreQuestionsButton: some View {
        Button {
            showQuestionSheet = true
        } label: {
            HStack {
                Image(systemName: viewModel.remainingQuestionCount == 0 ? "checkmark.seal.fill" : "questionmark.circle.fill")
                Text(viewModel.remainingQuestionCount == 0
                     ? "All caught up"
                     : "More questions (\(viewModel.remainingQuestionCount) left)")
            }
        }
        .buttonStyle(.harvestGlass(.primary))
        .disabled(viewModel.remainingQuestionCount == 0)
    }

    private var valuesPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                HStack {
                    Text(viewModel.side == .need ? "Values I Need" : "Values I Bring")
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    Spacer()
                    Text("\(viewModel.activeValueIds.count) / 3")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }
                Text("Pick your top 3.")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)

                ValueChipGrid(
                    values: viewModel.allValues,
                    selectedIds: viewModel.activeValueIds,
                    maxSelection: 3
                ) { value in
                    if let userId = authViewModel.currentUserId {
                        Task { await viewModel.toggleValue(userId: userId, valueId: value.id) }
                    }
                }

                if let err = viewModel.saveError {
                    Text(err)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
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
                        ProgressView().tint(HarvestTheme.Colors.primary)
                    } else {
                        Button {
                            if let userId = authViewModel.currentUserId {
                                Task { await viewModel.generateBlurb(userId: userId) }
                            }
                        } label: {
                            Text(viewModel.profile?.valuesBlurb?.isEmpty == false ? "Regenerate" : "Generate")
                        }
                        .buttonStyle(.harvestGlass(.primary))
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

    private var displayTogglesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Show on Profile")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                toggleRow(label: "Values I Bring",
                          isOn: Binding(get: { viewModel.profile?.showValuesBrought ?? true },
                                        set: { setToggle(.brought, $0) }))
                toggleRow(label: "Generated Blurb",
                          isOn: Binding(get: { viewModel.profile?.showValuesBlurb ?? true },
                                        set: { setToggle(.blurb, $0) }))
                toggleRow(label: "Values Graph",
                          isOn: Binding(get: { viewModel.profile?.showValuesGraph ?? true },
                                        set: { setToggle(.graph, $0) }))

                if viewModel.profile?.showValuesGraph ?? true {
                    HStack {
                        Text("Graph side")
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        Spacer()
                        Picker("", selection: graphSideBinding) {
                            Text("Need").tag(ValuesViewModel.Side.need)
                            Text("Bring").tag(ValuesViewModel.Side.bring)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                    }
                }

                if let error = viewModel.toggleError {
                    Text(error)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.warning)
                }
            }
        }
        .padding(.horizontal)
    }

    private var graphSideBinding: Binding<ValuesViewModel.Side> {
        Binding(
            get: {
                ValuesViewModel.Side(rawValue: viewModel.profile?.profileGraphSide ?? "bring") ?? .bring
            },
            set: { newSide in
                guard let userId = authViewModel.currentUserId else { return }
                Task { await viewModel.setGraphSide(userId: userId, side: newSide) }
            }
        )
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
        }
        .tint(HarvestTheme.Colors.primary)
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
                                    .foregroundStyle(HarvestTheme.Colors.accent)
                                Text(tip.title)
                                    .font(HarvestTheme.Typography.h4)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                Spacer()
                                Text(tip.category.rawValue)
                                    .font(HarvestTheme.Typography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(HarvestTheme.Colors.accent)
                                    .padding(.horizontal, HarvestTheme.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background { Capsule().fill(HarvestTheme.Colors.accentSoft) }
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
                        .tint(HarvestTheme.Colors.primary)
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
                .foregroundStyle(isSelected ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
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
