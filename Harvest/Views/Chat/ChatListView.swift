import SwiftUI

struct ChatListView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = MatchesViewModel()
    @State private var searchText = ""

    private var filteredConversations: [ConversationWithProfile] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        return viewModel.conversations.filter {
            $0.profile.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
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
                .padding(.vertical, HarvestTheme.Spacing.sm)

                if filteredConversations.isEmpty {
                    Spacer()
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
                    Spacer()
                } else {
                    List(filteredConversations) { convoWithProfile in
                        NavigationLink {
                            ChatDetailView(
                                authViewModel: authViewModel,
                                conversationId: convoWithProfile.conversation.id,
                                partnerUserId: convoWithProfile.profile.id,
                                matchId: convoWithProfile.conversation.matchId,
                                onConversationRemoved: {
                                    if let userId = authViewModel.currentUserId {
                                        await viewModel.loadConversations(userId: userId)
                                    }
                                }
                            )
                        } label: {
                            chatRow(convoWithProfile)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            convoWithProfile.hasReplyHighlight
                            ? HarvestTheme.Colors.primary.opacity(0.12)
                            : HarvestTheme.Colors.glassFillStrong
                        )
                    }
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .background(HarvestTheme.Colors.background)
                    .listStyle(.plain)
                }
            }
            .dismissKeyboardOnTap()
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .navigationTitle("Messages")
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .refreshable {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadConversations(userId: userId)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadConversations(userId: userId)
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUserId {
                    Task {
                        await viewModel.loadConversations(userId: userId)
                    }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func chatRow(_ convoWithProfile: ConversationWithProfile) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            AsyncImage(url: URL(string: convoWithProfile.profile.primaryPhoto ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(convoWithProfile.profile.displayName)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Spacer()

                    if let time = convoWithProfile.conversation.lastMessageAt {
                        Text(formatTime(time))
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }

                Text(convoWithProfile.conversation.lastMessagePreview ?? "Tap to start chatting")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
