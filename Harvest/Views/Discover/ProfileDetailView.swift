import SwiftUI

struct ProfileDetailView: View {
    let profile: UserProfile
    let currentProfile: UserProfile?
    let onSwipe: (SwipeAction) -> Void
    @State private var valuesBrought: [Value] = []
    @State private var allQuestions: [Question] = []
    @State private var otherAnswers: [String: String] = [:]
    @State private var showCompatibility = false
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false

    private let valuesService = ValuesService()
    private let questionsService = QuestionsService()
    private let matchService = MatchService()
    @Environment(\.dismiss) private var dismiss

    /// Moderation actions are shown only when viewing someone else's profile while signed in.
    private var canModerate: Bool {
        guard let currentProfile else { return false }
        return currentProfile.id != profile.id
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Photo carousel
                    if let photos = profile.photos, !photos.isEmpty {
                        TabView {
                            ForEach(Array(photos.enumerated()), id: \.offset) { _, url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(HarvestTheme.Colors.divider)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 60))
                                                .foregroundStyle(HarvestTheme.Colors.textTertiary)
                                        }
                                }
                            }
                        }
                        .frame(height: 450)
                        .tabViewStyle(.page)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                        // Name & Age
                        HStack(alignment: .firstTextBaseline, spacing: HarvestTheme.Spacing.sm) {
                            Text(profile.displayName)
                                .font(HarvestTheme.Typography.h1)

                            if let age = profile.age {
                                Text("\(age)")
                                    .font(HarvestTheme.Typography.h2)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }

                            Spacer()
                        }

                        // Values I Bring — shown directly under name/age
                        if (profile.showValuesBrought ?? true), !valuesBrought.isEmpty {
                            FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                ForEach(valuesBrought) { value in
                                    ChipView(title: value.name)
                                }
                            }
                        }

                        // Location
                        if let location = profile.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                                Text(location)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }

                        // Bio
                        if let bio = profile.bio, !bio.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("About")
                                        .font(HarvestTheme.Typography.h4)
                                    Text(bio)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }
                        }

                        // See Compatibility (only when current user's profile is available)
                        if currentProfile != nil {
                            GlassButton(
                                title: "See Compatibility",
                                icon: "chart.dots.scatter",
                                style: .secondary
                            ) {
                                showCompatibility = true
                            }
                        }

                        if (profile.showValuesBlurb ?? true),
                           let blurb = profile.valuesBlurb,
                           !blurb.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values Blurb")
                                        .font(HarvestTheme.Typography.h4)
                                    Text(blurb)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }
                        }

                        // Goals
                        if !profile.goalsList.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Looking For")
                                        .font(HarvestTheme.Typography.h4)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(profile.goalsList, id: \.self) { goal in
                                            ChipView(title: goal)
                                        }
                                    }
                                }
                            }
                        }

                        // Hobbies
                        if let hobbies = profile.hobbies, !hobbies.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Interests")
                                        .font(HarvestTheme.Typography.h4)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(hobbies, id: \.self) { hobby in
                                            ChipView(title: hobby)
                                        }
                                    }
                                }
                            }
                        }
                        if (profile.showValuesGraph ?? true) {
                            let side = ValuesViewModel.Side(
                                rawValue: profile.profileGraphSide ?? "bring"
                            ) ?? .bring
                            let vectors = AxisScoring.computeRawVectors(
                                answers: otherAnswers,
                                questions: allQuestions
                            )
                            let scores = (side == .need) ? vectors.need : vectors.bring
                            if !scores.isZero {
                                ValuesRadarCard(
                                    primary: scores,
                                    primaryLabel: side == .need ? "I Need" : "I Bring"
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Spacer for action buttons
                    Color.clear.frame(height: 100)
                }
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .task {
                valuesBrought = (try? await valuesService.getUserValuesBrought(userId: profile.id)) ?? []
                allQuestions = (try? await questionsService.getAllQuestions()) ?? []
                otherAnswers = (try? await questionsService.getUserAnswers(userId: profile.id)) ?? [:]
            }
            .sheet(isPresented: $showCompatibility) {
                if let currentProfile {
                    CompatibilityView(
                        currentProfile: currentProfile,
                        otherProfile: profile
                    )
                }
            }
            .sheet(isPresented: $showReportSheet) {
                if let reporterId = currentProfile?.id {
                    ReportUserView(reporterId: reporterId, reportedUserId: profile.id) { category, description in
                        Task {
                            try? await matchService.reportUser(
                                reporterId: reporterId,
                                reportedUserId: profile.id,
                                category: category,
                                description: description
                            )
                        }
                    }
                }
            }
            .confirmationDialog(
                "Block \(profile.displayName)?",
                isPresented: $showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Block & Report", role: .destructive) { blockProfile() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They won't be able to see you or contact you, their content is removed from your feed, and we'll review this report within 24 hours.")
            }

            // Top bar: moderation menu (leading) + close (trailing)
            HStack {
                if canModerate {
                    moderationMenu
                        .padding()
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                        .frame(width: 32, height: 32)
                        .background(HarvestTheme.Colors.blackSurface)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }

            // Action buttons
            VStack {
                Spacer()
                actionButtons
                    .padding(.bottom, HarvestTheme.Spacing.lg)
            }
        }
    }

    private var moderationMenu: some View {
        Menu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
            Button(role: .destructive) {
                showBlockConfirm = true
            } label: {
                Label("Block", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                .frame(width: 32, height: 32)
                .background(HarvestTheme.Colors.blackSurface)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }

    private func blockProfile() {
        guard let currentId = currentProfile?.id else { return }
        Task {
            try? await matchService.blockUser(
                userId: currentId,
                blockedUserId: profile.id,
                reason: "Blocked from profile",
                description: "User blocked while browsing profiles — filed for moderator review."
            )
            await MainActor.run {
                onSwipe(.nope) // drop them from the deck instantly
                dismiss()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: HarvestTheme.Spacing.xl) {
            Button {
                onSwipe(.nope)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(HarvestTheme.Colors.nope)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }

            Button {
                onSwipe(.superLike)
                dismiss()
            } label: {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(HarvestTheme.Colors.superLike)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }

            Button {
                onSwipe(.like)
                dismiss()
            } label: {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(HarvestTheme.Colors.like)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }
        }
    }
}
