import SwiftUI

struct MatchesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = MatchesViewModel()
    @State private var activeChatRoute: ChatRoute?
    @State private var selectedInboundLike: InboundLikeWithProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                    likesYouSection

                    Text("Matches")
                        .font(HarvestTheme.Typography.h4)
                        .padding(.horizontal)

                    if viewModel.matchThreads.isEmpty {
                        emptyConversations
                    } else {
                        LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                            ForEach(viewModel.matchThreads) { thread in
                                Button {
                                    openMatch(thread.match)
                                } label: {
                                    threadRow(thread)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, HarvestTheme.Spacing.sm)
                .padding(.bottom, HarvestTheme.Spacing.lg)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Matches")
            .navigationDestination(item: $activeChatRoute) { route in
                ChatDetailView(
                    authViewModel: authViewModel,
                    conversationId: route.conversationId,
                    partnerUserId: route.partnerUserId,
                    matchId: route.matchId,
                    onConversationRemoved: {
                        if let userId = authViewModel.currentUserId {
                            await viewModel.loadMatches(userId: userId)
                        }
                    }
                )
            }
            .fullScreenCover(item: $selectedInboundLike) { inboundLike in
                ProfileDetailView(profile: inboundLike.profile) { action in
                    guard let currentUserId = authViewModel.currentUserId else { return }
                    Task {
                        await viewModel.respondToInboundLike(
                            currentUserId: currentUserId,
                            inboundLike: inboundLike,
                            action: action
                        )
                    }
                }
            }
            .refreshable {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadMatches(userId: userId)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.matchThreads.isEmpty {
                    ProgressView()
                        .tint(HarvestTheme.Colors.primary)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadMatches(userId: userId)
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUserId {
                    Task {
                        await viewModel.loadMatches(userId: userId)
                    }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var likesYouSection: some View {
        if !viewModel.inboundLikes.isEmpty {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                Text("Likes You (\(viewModel.inboundLikes.count))")
                    .font(HarvestTheme.Typography.h4)
                    .padding(.horizontal)

                if viewModel.canSeeLikes {
                    LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(viewModel.inboundLikes) { inboundLike in
                            Button {
                                selectedInboundLike = inboundLike
                            } label: {
                                inboundLikeRow(inboundLike)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    PremiumGateView(
                        featureName: "See who likes you",
                        requiredTier: "Gold",
                        authViewModel: authViewModel
                    )
                    .frame(height: 220)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, HarvestTheme.Spacing.md)
        }
    }

    private func openMatch(_ matchWithProfile: MatchWithProfile) {
        guard let currentUserId = authViewModel.currentUserId else { return }

        Task {
            if let conversationId = await viewModel.startConversation(
                matchWithProfile: matchWithProfile,
                currentUserId: currentUserId
            ) {
                await MainActor.run {
                    activeChatRoute = ChatRoute(
                        conversationId: conversationId,
                        partnerUserId: matchWithProfile.profile.id,
                        matchId: matchWithProfile.match.id
                    )
                }
            }
        }
    }

    private func threadRow(_ thread: MatchThread) -> some View {
        GlassCard(padding: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                AsyncImage(url: URL(string: thread.match.profile.primaryPhoto ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(HarvestTheme.Colors.divider)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.match.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text(thread.conversation?.conversation.lastMessagePreview ?? "Start the conversation")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private func inboundLikeRow(_ inboundLike: InboundLikeWithProfile) -> some View {
        GlassCard(padding: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                AsyncImage(url: URL(string: inboundLike.profile.primaryPhoto ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(HarvestTheme.Colors.divider)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(inboundLike.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text(inboundLike.swipe.action == .superLike ? "Super liked you" : "Liked you")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if inboundLike.swipe.action == .superLike {
                    GlassBadge(text: "Super Like", color: HarvestTheme.Colors.accent)
                }
            }
        }
    }

    private var emptyConversations: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.textTertiary)

            Text("No matches yet")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            Text("Match with someone to start chatting")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HarvestTheme.Spacing.xxl)
    }
}

private struct ChatRoute: Identifiable, Hashable {
    let conversationId: String
    let partnerUserId: String
    let matchId: String?

    var id: String { conversationId }
}
