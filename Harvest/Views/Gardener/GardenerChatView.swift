import SwiftUI
import PhotosUI

struct GardenerChatView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = GardenerViewModel()
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @FocusState private var isMessageFieldFocused: Bool

    /// The staged screenshots, shown above the composer so they can be
    /// captioned or individually removed before sending.
    private func screenshotStrip(_ images: [UIImage]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                ForEach(images.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.sm))

                        Button {
                            viewModel.unstageScreenshot(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(2)
                    }
                    .frame(width: 56, height: 56)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, HarvestTheme.Spacing.xs)
        }
    }

    /// Tells the user their next message will re-send the last review's images
    /// without them attaching anything — and lets them stop it. The view model
    /// outlives a single review, so without this the retention is invisible.
    private var retainedImagesChip: some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textTertiary)

            Text(viewModel.retainedImageURLs.count == 1
                 ? "Following up on 1 image"
                 : "Following up on \(viewModel.retainedImageURLs.count) images")
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            Spacer()

            Button {
                viewModel.clearRetainedImages()
            } label: {
                Image(systemName: "xmark")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, HarvestTheme.Spacing.xs)
    }

    var body: some View {
        NavigationStack {
            chatView
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .background(HarvestTheme.Colors.background.ignoresSafeArea())
                .navigationTitle("Gardener")
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
                .onChange(of: pickedPhotos) { _, items in
                    guard !items.isEmpty else { return }
                    Task {
                        // Loaded into memory only — never written to disk.
                        var images: [UIImage] = []
                        for item in items {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                images.append(image)
                            }
                        }

                        if images.isEmpty {
                            viewModel.error = "That image couldn't be read. Try a different screenshot."
                        } else {
                            viewModel.stageScreenshots(images)
                        }
                        // Cleared so picking the same photo again still fires.
                        pickedPhotos = []
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
                .toolbarColorScheme(.light, for: .navigationBar)
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

                                Text("I'm your AI coach. Ask me about values, red flags, communication, or anything on your mind.")
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
                                    .tint(HarvestTheme.Colors.primary)
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

            // Input bar. Chat characters and screenshot reviews are separate
            // allowances now, so the bar only locks outright once both are spent.
            if viewModel.isAtLimit && viewModel.isAtScreenshotLimit {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    Text("You've used today's Gardener allowance. Upgrade for more!")
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
                if viewModel.hasPendingScreenshot {
                    screenshotStrip(viewModel.pendingScreenshots)
                } else if !viewModel.retainedImageURLs.isEmpty {
                    retainedImagesChip
                }

                HStack(spacing: HarvestTheme.Spacing.sm) {
                    // .images, not .screenshots: a screenshot someone was *sent*
                    // isn't flagged as one by iOS, and the refusal path has to
                    // be reachable for images that genuinely aren't chats.
                    PhotosPicker(
                        selection: $pickedPhotos,
                        maxSelectionCount: max(viewModel.imageCap, 1),
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundStyle(viewModel.isAtScreenshotLimit
                                             ? HarvestTheme.Colors.textTertiary
                                             : HarvestTheme.Colors.accent)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(viewModel.isSending || viewModel.isAtScreenshotLimit)

                    TextField(
                        "",
                        text: $viewModel.messageText,
                        prompt: Text(viewModel.hasPendingScreenshot
                                     ? "Add a note (optional)…"
                                     : "Ask The Gardener...")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary),
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
                            guard let userId = authViewModel.currentUserId else { return }
                            Task {
                                if viewModel.hasPendingScreenshot {
                                    await viewModel.sendImages(userId: userId)
                                } else {
                                    await viewModel.sendMessage(userId: userId)
                                }
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(HarvestTheme.Colors.accent)
                                .frame(width: 40, height: 40)
                        }
                        // A staged screenshot is sendable on its own — the
                        // caption is optional.
                        .disabled(
                            (!viewModel.hasPendingScreenshot
                             && viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            || viewModel.isSending
                            // Out of characters still leaves a staged
                            // screenshot sendable — different budget.
                            || (viewModel.isAtLimit && !viewModel.hasPendingScreenshot)
                        )

                        Text(viewModel.hasPendingScreenshot
                             ? "\(viewModel.pendingScreenshots.count) / \(viewModel.imageCap) 📷"
                             : "\(viewModel.remainingChars)")
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
