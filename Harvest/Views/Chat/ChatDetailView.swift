import SwiftUI

struct ChatDetailView: View {
    let authViewModel: AuthViewModel
    let conversationId: String
    let partnerUserId: String
    var matchId: String?
    var onConversationRemoved: (() async -> Void)? = nil

    @State private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMessageFieldFocused: Bool

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

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isSent: message.isSentBy(authViewModel.currentUserId ?? "")
                            )
                            .id(message.id)
                        }

                        if viewModel.isPartnerTyping {
                            TypingIndicatorView()
                        }
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
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: HarvestTheme.Spacing.sm) {
                TextField(
                    "",
                    text: $viewModel.messageText,
                    prompt: Text("Type a message...").foregroundStyle(HarvestTheme.Colors.textTertiary),
                    axis: .vertical
                )
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                    .tint(HarvestTheme.Colors.textOnBlack)
                    .focused($isMessageFieldFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }

                Button {
                    Task {
                        await viewModel.sendMessage(
                            conversationId: conversationId,
                            senderId: authViewModel.currentUserId ?? ""
                        )
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(HarvestTheme.Colors.accent)
                        .frame(width: 40, height: 40)
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, HarvestTheme.Spacing.sm)
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            isMessageFieldFocused = false
        }
        .navigationTitle(viewModel.partnerProfile?.displayName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                onSubmit: { category, description in
                    Task {
                        await viewModel.reportUser(
                            reporterId: authViewModel.currentUserId ?? "",
                            reportedUserId: partnerUserId,
                            category: category,
                            description: description
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
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
