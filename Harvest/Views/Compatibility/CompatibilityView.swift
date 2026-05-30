import SwiftUI

struct CompatibilityView: View {
    let currentProfile: UserProfile
    let otherProfile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var myNeedScores = AxisScores()
    @State private var myBringScores = AxisScores()
    @State private var theirNeedScores = AxisScores()
    @State private var theirBringScores = AxisScores()

    @State private var myNeeds: [Value] = []
    @State private var myBrings: [Value] = []
    @State private var theirNeeds: [Value] = []
    @State private var theirBrings: [Value] = []

    private let valuesService = ValuesService()
    private let questionsService = QuestionsService()
    private let compatibilityService = CompatibilityService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    if isLoading {
                        ProgressView()
                            .tint(HarvestTheme.Colors.accent)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let loadError {
                        errorView(loadError)
                    } else {
                        radarSection(
                            title: "What you both bring",
                            primary: myBringScores,
                            secondary: theirBringScores,
                            primaryLabel: "You bring",
                            secondaryLabel: "\(otherProfile.displayName) brings"
                        )

                        chipSection(
                            primaryLabel: "You bring",
                            primaryChips: myBrings,
                            secondaryLabel: "\(otherProfile.displayName) brings",
                            secondaryChips: theirBrings
                        )

                        radarSection(
                            title: "What you both need",
                            primary: myNeedScores,
                            secondary: theirNeedScores,
                            primaryLabel: "You need",
                            secondaryLabel: "\(otherProfile.displayName) needs"
                        )

                        chipSection(
                            primaryLabel: "You need",
                            primaryChips: myNeeds,
                            secondaryLabel: "\(otherProfile.displayName) needs",
                            secondaryChips: theirNeeds
                        )

                        overlapSection
                        blurbSection
                    }
                }
                .padding(.vertical)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Compatibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
            .task { await load() }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private func radarSection(
        title: String,
        primary: AxisScores,
        secondary: AxisScores,
        primaryLabel: String,
        secondaryLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            SectionHeader(title: title)
            ValuesRadarCard(
                primary: primary,
                primaryLabel: primaryLabel,
                secondary: secondary,
                secondaryLabel: secondaryLabel
            )
        }
        .padding(.horizontal)
    }

    private func chipSection(
        primaryLabel: String,
        primaryChips: [Value],
        secondaryLabel: String,
        secondaryChips: [Value]
    ) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                    Text(primaryLabel)
                        .font(HarvestTheme.Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    if primaryChips.isEmpty {
                        Text("—")
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    } else {
                        FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                            ForEach(primaryChips) { ChipView(title: $0.name) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(maxHeight: .infinity)
                    .background(HarvestTheme.Colors.divider)

                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                    Text(secondaryLabel)
                        .font(HarvestTheme.Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    if secondaryChips.isEmpty {
                        Text("—")
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    } else {
                        FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                            ForEach(secondaryChips) { ChipView(title: $0.name) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    private var overlapSection: some View {
        let overlap = compatibilityService.valueOverlap(
            myNeeds: myNeeds,
            myBrings: myBrings,
            theirNeeds: theirNeeds,
            theirBrings: theirBrings
        )
        return GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                SectionHeader(title: "Value overlap")

                overlapRow(
                    count: overlap.theyBringForMyNeeds.count,
                    total: myNeeds.count,
                    leadingText: "\(otherProfile.displayName) brings",
                    trailingText: "of your needs",
                    chips: overlap.theyBringForMyNeeds
                )

                Divider().background(HarvestTheme.Colors.divider)

                overlapRow(
                    count: overlap.iBringForTheirNeeds.count,
                    total: theirNeeds.count,
                    leadingText: "You bring",
                    trailingText: "of \(otherProfile.displayName)'s needs",
                    chips: overlap.iBringForTheirNeeds
                )
            }
        }
        .padding(.horizontal)
    }

    private func overlapRow(
        count: Int,
        total: Int,
        leadingText: String,
        trailingText: String,
        chips: [Value]
    ) -> some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
            Text("\(leadingText) \(count) of \(total) \(trailingText)")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            if !chips.isEmpty {
                FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                    ForEach(chips) { ChipView(title: $0.name) }
                }
            }
        }
    }

    private var blurbSection: some View {
        let bringCos = AxisScores.cosine(myBringScores, theirBringScores)
        let needCos = AxisScores.cosine(myNeedScores, theirNeedScores)
        let topAxis = compatibilityService.topSharedAxis(
            myBring: myBringScores,
            theirNeed: theirNeedScores
        )
        let overlap = compatibilityService.valueOverlap(
            myNeeds: myNeeds,
            myBrings: myBrings,
            theirNeeds: theirNeeds,
            theirBrings: theirBrings
        )
        let blurb = compatibilityService.compatibilityBlurb(
            otherName: otherProfile.displayName,
            bringCosine: bringCos,
            needCosine: needCos,
            topSharedAxis: topAxis,
            overlap: overlap,
            myNeedsCount: max(1, myNeeds.count)
        )
        return GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(HarvestTheme.Colors.accent)
                    Text("In summary")
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
                Text(blurb)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HarvestTheme.Colors.warning)
            Text(message)
                .font(HarvestTheme.Typography.bodyRegular)
                .multilineTextAlignment(.center)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        async let myAnswersTask = questionsService.getUserAnswers(userId: currentProfile.id)
        async let theirAnswersTask = questionsService.getUserAnswers(userId: otherProfile.id)
        async let questionsTask = questionsService.getAllQuestions()
        async let myBroughtTask = valuesService.getUserValuesBrought(userId: currentProfile.id)
        async let mySoughtTask = valuesService.getUserValuesSought(userId: currentProfile.id)
        async let theirBroughtTask = valuesService.getUserValuesBrought(userId: otherProfile.id)
        async let theirSoughtTask = valuesService.getUserValuesSought(userId: otherProfile.id)

        let myAnswers = (try? await myAnswersTask) ?? [:]
        let theirAnswers = (try? await theirAnswersTask) ?? [:]
        let allQuestions = (try? await questionsTask) ?? []

        let mine = AxisScoring.computeVectors(answers: myAnswers, questions: allQuestions)
        let theirs = AxisScoring.computeVectors(answers: theirAnswers, questions: allQuestions)

        myNeedScores = mine.need
        myBringScores = mine.bring
        theirNeedScores = theirs.need
        theirBringScores = theirs.bring

        myBrings = (try? await myBroughtTask) ?? []
        myNeeds = (try? await mySoughtTask) ?? []
        theirBrings = (try? await theirBroughtTask) ?? []
        theirNeeds = (try? await theirSoughtTask) ?? []
    }
}
