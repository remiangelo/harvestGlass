import SwiftUI

struct ChatDetailView: View {
    let authViewModel: AuthViewModel
    let conversationId: String
    let partnerUserId: String
    var matchId: String?
    var onConversationRemoved: (() async -> Void)? = nil

    @State private var viewModel = ChatViewModel()
    @State private var showProfile = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMessageFieldFocused: Bool

    /// Invisible row pinned below the last message; the scroll target.
    private static let bottomAnchor = "chatBottomAnchor"

    /// "9:41" for a message, or "" when the timestamp is unusable.
    private func timeLabel(for message: Message) -> String {
        guard let date = MessageGrouping.date(from: message.createdAt) else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Safety warning banner
            if let warning = viewModel.safetyWarning {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                    Text(warning)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background(HarvestTheme.Colors.blackSurface)
            }

            // Safety status badge — always visible once analysis loads
            if let analysis = viewModel.safetyAnalysis {
                SafetyStatusBadge(level: analysis.safetyLevel)
                    .padding(.horizontal)
                    .padding(.vertical, HarvestTheme.Spacing.xs)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(viewModel.messages) { message in
                            let position = viewModel.positions[message.id]
                                ?? MessagePosition(showsDateSeparator: false,
                                                   isFirstInGroup: true,
                                                   isLastInGroup: true)

                            if position.showsDateSeparator,
                               let date = MessageGrouping.date(from: message.createdAt) {
                                DateSeparator(date: date)
                            }

                            MessageBubbleView(
                                message: message,
                                isSent: message.isSentBy(authViewModel.currentUserId ?? ""),
                                position: position,
                                timeLabel: position.isLastInGroup ? timeLabel(for: message) : ""
                            )
                            .id(message.id)
                        }

                        if viewModel.isPartnerTyping {
                            TypingIndicatorView()
                        }

                        // Scroll target. Anchoring on the last message left it
                        // flush against the composer; this gives it room.
                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchor)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    isMessageFieldFocused = false
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
                }
                .onChange(of: isMessageFieldFocused) { _, focused in
                    // Keyboard opening must not hide the newest message.
                    if focused {
                        withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
                    }
                }
            }

            ChatComposer(
                text: $viewModel.messageText,
                focused: $isMessageFieldFocused,
                accent: .rose,
                placeholder: "Type a message...",
                isSending: viewModel.isSending,
                onSend: {
                    Task {
                        await viewModel.sendMessage(
                            conversationId: conversationId,
                            senderId: authViewModel.currentUserId ?? ""
                        )
                    }
                }
            )
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .background(ChatBackdrop(accent: .rose))
        .contentShape(Rectangle())
        .onTapGesture {
            isMessageFieldFocused = false
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let profile = viewModel.partnerProfile {
                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: HarvestTheme.Spacing.xs) {
                            avatar(for: profile)
                            Text(profile.displayName)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Chat")
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await viewModel.presentReadyToMoveGate()
                        }
                    } label: {
                        Label("Ready to Move", systemImage: "person.crop.circle.badge.checkmark")
                    }

                    Button(role: .destructive) {
                        viewModel.showReportSheet = true
                    } label: {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }

                    Button(role: .destructive) {
                        viewModel.showBlockAlert = true
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }

                    Button(role: .destructive) {
                        viewModel.showUnmatchAlert = true
                    } label: {
                        Label("Unmatch", systemImage: "heart.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
        }
        .task {
            await viewModel.loadPartnerProfile(userId: partnerUserId)
            await viewModel.loadMessages(conversationId: conversationId)
            viewModel.subscribeToRealtime(conversationId: conversationId)
            if let userId = authViewModel.currentUserId {
                viewModel.subscribeToTyping(conversationId: conversationId, currentUserId: userId)
                await viewModel.markMessagesAsRead(currentUserId: userId)
            }
            if let matchId, let userId = authViewModel.currentUserId {
                await viewModel.loadSafetyAnalysis(
                    matchId: matchId,
                    userId: userId,
                    otherUserId: partnerUserId
                )
            }
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
        .fullScreenCover(isPresented: $showProfile) {
            if let profile = viewModel.partnerProfile {
                ProfileDetailView(
                    profile: profile,
                    currentProfile: authViewModel.profile,
                    showSwipeActions: false
                ) { _ in
                    showProfile = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showMindfulWarning) {
            if let analysis = viewModel.mindfulAnalysis {
                MindfulWarningView(
                    analysis: analysis,
                    onEdit: {
                        viewModel.dismissMindfulWarning()
                    },
                    onSendAnyway: {
                        Task { await viewModel.confirmSendDespiteWarning() }
                    }
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $viewModel.showReportSheet) {
            ReportUserView(
                reporterId: authViewModel.currentUserId ?? "",
                reportedUserId: partnerUserId,
                onSubmit: { category, description, reportTarget in
                    Task {
                        await viewModel.reportUser(
                            reporterId: authViewModel.currentUserId ?? "",
                            reportedUserId: partnerUserId,
                            category: category,
                            description: description,
                            target: reportTarget
                        )
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showReadyToMoveGate) {
            if let analysis = viewModel.safetyAnalysis {
                ReadyToMoveGateView(
                    analysis: analysis,
                    isReady: viewModel.isReadyToMove,
                    reason: viewModel.readyToMoveReason,
                    onSharePreferredContact: {
                        Task {
                            await viewModel.markPreferredContactShared()
                        }
                    }
                )
                .presentationDetents([.large])
            }
        }
        .alert("Ready to Move", isPresented: $viewModel.showReadyToMoveActionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.readyToMoveActionMessage ?? "")
        }
        .alert("Block User", isPresented: $viewModel.showBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                Task {
                    let didBlock = await viewModel.blockUser(
                        userId: authViewModel.currentUserId ?? "",
                        blockedUserId: partnerUserId
                    )
                    if didBlock {
                        await onConversationRemoved?()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to block this user? You won't see each other anymore.")
        }
        .alert("Unmatch", isPresented: $viewModel.showUnmatchAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unmatch", role: .destructive) {
                if let matchId {
                    Task {
                        let didUnmatch = await viewModel.unmatchUser(matchId: matchId)
                        if didUnmatch {
                            await onConversationRemoved?()
                            dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to unmatch? This conversation will be removed.")
        }
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    @ViewBuilder
    private func avatar(for profile: UserProfile) -> some View {
        if let url = profile.primaryPhoto.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(HarvestTheme.Colors.divider)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
    }
}
