import SwiftUI

struct MatchesView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = MatchesViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                    // Recent matches
                    if !viewModel.recentMatches.isEmpty {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                            Text("New Matches")
                                .font(HarvestTheme.Typography.h4)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: HarvestTheme.Spacing.md) {
                                    ForEach(viewModel.recentMatches) { matchWithProfile in
                                        matchAvatar(matchWithProfile.profile)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Conversations
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                        Text("Conversations")
                            .font(HarvestTheme.Typography.h4)
                            .padding(.horizontal)

                        if viewModel.conversations.isEmpty {
                            emptyConversations
                        } else {
                            LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                                ForEach(viewModel.conversations) { convoWithProfile in
                                    NavigationLink {
                                        ChatDetailView(
                                            authViewModel: authViewModel,
                                            conversationId: convoWithProfile.conversation.id,
                                            partnerUserId: convoWithProfile.profile.id
                                        )
                                    } label: {
                                        conversationRow(convoWithProfile)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Matches")
            .refreshable {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadMatches(userId: userId)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.recentMatches.isEmpty {
                    ProgressView()
                        .tint(HarvestTheme.Colors.primary)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadMatches(userId: userId)
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func matchAvatar(_ profile: UserProfile) -> some View {
        VStack(spacing: 4) {
            AsyncImage(url: URL(string: profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(HarvestTheme.Colors.divider)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            .overlay(Circle().stroke(HarvestTheme.Colors.primary, lineWidth: 2))

            Text(profile.displayName)
                .font(HarvestTheme.Typography.caption)
                .lineLimit(1)
                .frame(width: 70)
        }
    }

    private func conversationRow(_ convoWithProfile: ConversationWithProfile) -> some View {
        GlassCard(padding: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                AsyncImage(url: URL(string: convoWithProfile.profile.primaryPhoto ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(HarvestTheme.Colors.divider)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(convoWithProfile.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text(convoWithProfile.conversation.lastMessagePreview ?? "Start a conversation")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let time = convoWithProfile.conversation.lastMessageAt {
                    Text(formatTime(time))
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                }
            }
        }
    }

    private var emptyConversations: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.textTertiary)

            Text("No conversations yet")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            Text("Match with someone to start chatting")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HarvestTheme.Spacing.xxl)
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
