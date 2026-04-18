import SwiftUI

struct GardenerChatView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = GardenerViewModel()
    @State private var selectedTab = 0
    @FocusState private var isMessageFieldFocused: Bool

    private let previewSegmentBackground = Color(hex: "5A1B33")
    private let previewSegmentSurface = Color(hex: "6E2A45")
    private let previewSegmentBorder = HarvestTheme.Colors.harvestCream.opacity(0.22)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    gardenerSegmentButton("Chat", tag: 0)
                    gardenerSegmentButton("Tips", tag: 1)
                }
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    Capsule()
                        .fill(previewSegmentBackground)
                        .overlay {
                            Capsule()
                                .stroke(previewSegmentBorder, lineWidth: 1)
                        }
                }
                .padding(.horizontal)

                if selectedTab == 0 {
                    chatView
                } else {
                    TipsView()
                }
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("The Gardener")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(HarvestTheme.Colors.accent)
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadChat(userId: userId)
                    await viewModel.checkDailyQuiz(userId: userId)
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUserId {
                    Task {
                        await viewModel.loadChat(userId: userId)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDailyQuiz) {
                if let quiz = viewModel.dailyQuiz {
                    DailyQuizPopup(quiz: quiz) { answer in
                        if let userId = authViewModel.currentUserId {
                            Task { await viewModel.submitQuizAnswer(userId: userId, answer: answer) }
                        }
                    }
                    .presentationDetents([.large])
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func gardenerSegmentButton(_ title: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tag
            }
        } label: {
            Text(title)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(
                    selectedTab == tag
                    ? HarvestTheme.Colors.textOnCream
                    : HarvestTheme.Colors.harvestCream
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(selectedTab == tag ? HarvestTheme.Colors.harvestCream : previewSegmentSurface)
                }
        }
        .buttonStyle(.plain)
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            VStack(spacing: HarvestTheme.Spacing.md) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(HarvestTheme.Colors.accent)

                                Text("Welcome to The Gardener")
                                    .font(HarvestTheme.Typography.h3)

                                Text("I'm your AI dating coach. Ask me anything about dating, relationships, or personal growth!")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, HarvestTheme.Spacing.xxl)
                            .padding(.horizontal)
                        }

                        ForEach(viewModel.messages) { message in
                            gardenerBubble(message)
                                .id(message.id)
                        }

                        if viewModel.isSending {
                            HStack {
                                ProgressView()
                                    .tint(HarvestTheme.Colors.accent)
                                Text("Thinking...")
                                    .font(HarvestTheme.Typography.caption)
                                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                                Spacer()
                            }
                            .padding(.horizontal)
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
            if viewModel.isAtLimit {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    Text("Character limit reached. Upgrade for more!")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    Spacer()
                    NavigationLink {
                        SubscriptionView(authViewModel: authViewModel)
                    } label: {
                        Text("Upgrade")
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)
            } else {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    TextField(
                        "",
                        text: $viewModel.messageText,
                        prompt: Text("Ask The Gardener...").foregroundStyle(HarvestTheme.Colors.textTertiary),
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

                    VStack(spacing: 2) {
                        Button {
                            if let userId = authViewModel.currentUserId {
                                Task { await viewModel.sendMessage(userId: userId) }
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(HarvestTheme.Colors.accent)
                                .frame(width: 40, height: 40)
                        }
                        .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)

                        Text("\(viewModel.remainingChars)")
                            .font(.system(size: 9))
                            .foregroundStyle(viewModel.remainingChars < 500 ? HarvestTheme.Colors.warning : HarvestTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)
            }
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .contentShape(Rectangle())
        .onTapGesture {
            isMessageFieldFocused = false
        }
    }

    private func gardenerBubble(_ message: GardenerMessage) -> some View {
        let isUser = message.role == "user"

        return HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(isUser ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .fill(HarvestTheme.Colors.outgoingMessageSurface)
                    } else {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .fill(HarvestTheme.Colors.glassFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
                }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
