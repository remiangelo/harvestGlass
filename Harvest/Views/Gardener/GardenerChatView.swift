import SwiftUI

struct GardenerChatView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = GardenerViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("View", selection: $selectedTab) {
                    Text("Chat").tag(0)
                    Text("Tips").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)

                if selectedTab == 0 {
                    chatView
                } else {
                    TipsView()
                }
            }
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
            .sheet(isPresented: $viewModel.showDailyQuiz) {
                if let quiz = viewModel.dailyQuiz {
                    DailyQuizPopup(quiz: quiz) { answer in
                        Task { await viewModel.submitQuizAnswer(answer: answer) }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
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
                            .foregroundStyle(HarvestTheme.Colors.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, HarvestTheme.Spacing.sm)
            } else {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    TextField("Ask The Gardener...", text: $viewModel.messageText, axis: .vertical)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .lineLimit(1...4)
                        .padding(.horizontal, HarvestTheme.Spacing.md)
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                                .fill(.ultraThinMaterial)
                                .glassEffect(.regular, in: .rect(cornerRadius: HarvestTheme.Radius.xl))
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
    }

    private func gardenerBubble(_ message: GardenerMessage) -> some View {
        let isUser = message.role == "user"

        return HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(isUser ? .white : HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .fill(HarvestTheme.Colors.primary)
                    } else {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular, in: .rect(cornerRadius: HarvestTheme.Radius.lg))
                    }
                }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
