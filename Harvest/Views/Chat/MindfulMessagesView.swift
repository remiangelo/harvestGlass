import SwiftUI

struct MindfulMessagesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = MindfulMessagesViewModel()
    @State private var searchText = ""
    @State private var activeChatRoute: ChatRoute?
    @State private var selectedInboundLike: InboundLikeWithProfile?

    private var newMatches: [MatchThread] {
        viewModel.matchThreads.filter { $0.conversation == nil }
    }

    private var unifiedMessages: [InboxRow] {
        let conversationsFromMatches: [InboxRow] = viewModel.matchThreads
            .compactMap { thread in
                guard let convo = thread.conversation else { return nil }
                return InboxRow(
                    conversationId: convo.conversation.id,
                    profile: thread.match.profile,
                    matchId: thread.match.match.id,
                    lastMessagePreview: convo.conversation.lastMessagePreview,
                    lastMessageAt: convo.conversation.lastMessageAt,
                    hasReplyHighlight: convo.hasReplyHighlight
                )
            }

        let standaloneConversations: [InboxRow] = viewModel.conversations.map { convo in
            InboxRow(
                conversationId: convo.conversation.id,
                profile: convo.profile,
                matchId: convo.conversation.matchId,
                lastMessagePreview: convo.conversation.lastMessagePreview,
                lastMessageAt: convo.conversation.lastMessageAt,
                hasReplyHighlight: convo.hasReplyHighlight
            )
        }

        var seen = Set<String>()
        let merged = (conversationsFromMatches + standaloneConversations)
            .filter { row in
                guard !seen.contains(row.conversationId) else { return false }
                seen.insert(row.conversationId)
                return true
            }
            .sorted { (lhs, rhs) in
                (lhs.lastMessageAt ?? "") > (rhs.lastMessageAt ?? "")
            }

        guard !searchText.isEmpty else { return merged }
        return merged.filter { $0.profile.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    searchBar

                    if !viewModel.inboundLikes.isEmpty {
                        likesYouSection
                    }

                    if !newMatches.isEmpty {
                        newMatchesSection
                    }

                    messagesSection
                }
                .padding(.vertical, HarvestTheme.Spacing.sm)
            }
            .dismissKeyboardOnTap()
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Mindful Messages")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $activeChatRoute) { route in
                ChatDetailView(
                    authViewModel: authViewModel,
                    conversationId: route.conversationId,
                    partnerUserId: route.partnerUserId,
                    matchId: route.matchId,
                    onConversationRemoved: {
                        if let userId = authViewModel.currentUserId {
                            await viewModel.loadMatches(userId: userId)
                            await viewModel.loadConversations(userId: userId)
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
                await refresh()
            }
            .task {
                await refresh()
            }
            .onAppear {
                Task { await refresh() }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search conversations").foregroundStyle(HarvestTheme.Colors.textTertiary)
            )
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                .tint(HarvestTheme.Colors.textOnBlack)
        }
        .padding(HarvestTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(HarvestTheme.Colors.blackSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var likesYouSection: some View {
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
    }

    private var newMatchesSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text("New Matches")
                .font(HarvestTheme.Typography.h4)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HarvestTheme.Spacing.md) {
                    ForEach(newMatches) { thread in
                        Button {
                            openMatch(thread.match)
                        } label: {
                            newMatchBubble(thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text("Messages")
                .font(HarvestTheme.Typography.h4)
                .padding(.horizontal)

            if unifiedMessages.isEmpty {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 50))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    Text("No messages yet")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    Text("Start swiping to find your match")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HarvestTheme.Spacing.xl)
            } else {
                LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(unifiedMessages) { row in
                        Button {
                            openInboxRow(row)
                        } label: {
                            inboxRowView(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Row builders

    private func newMatchBubble(_ thread: MatchThread) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: thread.match.profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay { Circle().stroke(HarvestTheme.Colors.accent, lineWidth: 2) }

            Text(thread.match.profile.displayName)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
    }

    private func inboxRowView(_ row: InboxRow) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            AsyncImage(url: URL(string: row.profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Spacer()

                    if let time = row.lastMessageAt {
                        Text(formatTime(time))
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }

                Text(row.lastMessagePreview ?? "Tap to start chatting")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, HarvestTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(row.hasReplyHighlight
                      ? HarvestTheme.Colors.primary.opacity(0.12)
                      : HarvestTheme.Colors.glassFillStrong)
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

    // MARK: - Actions

    private func refresh() async {
        guard let userId = authViewModel.currentUserId else { return }
        await viewModel.loadMatches(userId: userId)
        await viewModel.loadConversations(userId: userId)
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

    private func openInboxRow(_ row: InboxRow) {
        activeChatRoute = ChatRoute(
            conversationId: row.conversationId,
            partnerUserId: row.profile.id,
            matchId: row.matchId
        )
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

private struct ChatRoute: Identifiable, Hashable {
    let conversationId: String
    let partnerUserId: String
    let matchId: String?

    var id: String { conversationId }
}

private struct InboxRow: Identifiable, Hashable {
    let conversationId: String
    let profile: UserProfile
    let matchId: String?
    let lastMessagePreview: String?
    let lastMessageAt: String?
    let hasReplyHighlight: Bool

    var id: String { conversationId }

    static func == (lhs: InboxRow, rhs: InboxRow) -> Bool { lhs.conversationId == rhs.conversationId }
    func hash(into hasher: inout Hasher) { hasher.combine(conversationId) }
}
