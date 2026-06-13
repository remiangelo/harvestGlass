import SwiftUI

struct CommunityChatView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = CommunityChatViewModel()
    @State private var showPrompts = false
    @State private var reportTarget: (senderId: String, messageId: String)? = nil
    @State private var selectedProfile: UserProfile?
    @State private var isLoadingProfile = false
    private let profileService = ProfileService()
    private var userId: String { authViewModel.currentUserId ?? "" }

    private var canSend: Bool {
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                        if vm.messages.isEmpty {
                            emptyState
                        }
                        ForEach(vm.messages) { msg in
                            CommunityBubble(
                                message: msg,
                                sender: vm.senders[msg.senderId],
                                isMine: msg.senderId == userId,
                                onTapSender: msg.senderId == userId
                                    ? nil
                                    : { Task { await openProfile(senderId: msg.senderId) } }
                            )
                                .id(msg.id)
                                .contextMenu {
                                    if msg.senderId != userId {
                                        Button(role: .destructive) {
                                            reportTarget = (senderId: msg.senderId, messageId: msg.id)
                                        } label: {
                                            Label("Report message", systemImage: "flag")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(HarvestTheme.Spacing.md)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = vm.error {
                Text(error)
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.top, HarvestTheme.Spacing.xs)
            }

            composer
        }
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.start(communityId: community.id) }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showPrompts) {
            PromptPicker(prompts: vm.prompts) { chosen in
                vm.draft = chosen
                showPrompts = false
            }
        }
        .sheet(isPresented: $vm.showMindfulWarning) {
            if let analysis = vm.mindfulAnalysis {
                MindfulWarningView(
                    analysis: analysis,
                    onEdit: {
                        vm.dismissMindfulWarning()
                    },
                    onSendAnyway: {
                        Task { await vm.confirmSendDespiteWarning(communityId: community.id, senderId: userId) }
                    }
                )
                .presentationDetents([.large])
            }
        }
        .sheet(item: $selectedProfile) { profile in
            // showSwipeActions surfaces the "Send a Seed" CTA — the point of
            // opening a room member's profile.
            ProfileDetailView(
                profile: profile,
                currentProfile: authViewModel.profile,
                showSwipeActions: true,
                authViewModel: authViewModel
            ) { _ in
                selectedProfile = nil
            }
        }
        .sheet(item: Binding(
            get: { reportTarget.map { ReportSheetItem(senderId: $0.senderId, messageId: $0.messageId) } },
            set: { if $0 == nil { reportTarget = nil } }
        )) { item in
            ReportUserView(
                reporterId: userId,
                reportedUserId: item.senderId,
                target: .communityMessage(id: item.messageId)
            ) { category, description, reportTargetValue in
                Task {
                    let service = MatchService()
                    try? await service.reportUser(
                        reporterId: userId,
                        reportedUserId: item.senderId,
                        category: category,
                        description: description,
                        target: reportTargetValue
                    )
                }
            }
        }
    }

    /// Fetch a sender's full profile, then present it so the viewer can see
    /// values/interests and send a Seed.
    private func openProfile(senderId: String) async {
        guard !isLoadingProfile, senderId != userId else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        if let profile = try? await profileService.getProfile(userId: senderId) {
            selectedProfile = profile
        }
    }

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(HarvestTheme.Colors.primary)
            Text("Be the first to share something.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            Button {
                showPrompts = true
            } label: {
                Label("Use an icebreaker", systemImage: "lightbulb.fill")
            }
            .buttonStyle(.harvestGlass(.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HarvestTheme.Spacing.xxl)
    }

    private var composer: some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Button { showPrompts.toggle() } label: {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(HarvestTheme.Colors.primary)
            }

            TextField("Share something…", text: $vm.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(HarvestTheme.Colors.fieldFill)
                        .overlay(Capsule().stroke(HarvestTheme.Colors.border, lineWidth: 1))
                )

            Button {
                Task { await vm.send(communityId: community.id, senderId: userId) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(canSend ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textTertiary)
            }
            .disabled(!canSend)
        }
        .padding(HarvestTheme.Spacing.md)
        .background(HarvestTheme.Colors.wineBlack.ignoresSafeArea(edges: .bottom))
    }
}

/// Identifiable wrapper so the sheet(item:) binding works.
private struct ReportSheetItem: Identifiable, Equatable {
    let senderId: String
    let messageId: String
    var id: String { messageId }
}

private struct CommunityBubble: View {
    let message: CommunityMessage
    let sender: CommunitySender?
    let isMine: Bool
    var onTapSender: (() -> Void)? = nil

    @State private var revealed = false
    private let mindful = MindfulMessagingService()

    private var senderName: String {
        isMine ? "You" : (sender?.nickname ?? "Member")
    }

    /// Non-nil when an incoming message should be blurred for the viewer.
    /// Respects the viewer's own mindful-messaging toggle.
    private var flag: MindfulMessagingService.MindfulAnalysis? {
        guard !isMine, mindful.isEnabled else { return nil }
        return mindful.localFlag(for: message.content)
    }

    var body: some View {
        let isBlurred = flag != nil && !revealed
        let bubble = RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)

        HStack(alignment: .top, spacing: HarvestTheme.Spacing.xs) {
            if isMine {
                Spacer(minLength: 40)
            } else {
                avatar
                    .contentShape(Circle())
                    .onTapGesture { onTapSender?() }
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(senderName)
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(onTapSender == nil ? HarvestTheme.Colors.textTertiary : HarvestTheme.Colors.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapSender?() }

                Text(message.content)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(isMine ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .frame(minWidth: isBlurred ? 150 : nil, minHeight: isBlurred ? 44 : nil, alignment: .leading)
                    .blur(radius: isBlurred ? 7 : 0)
                    .background(
                        bubble.fill(isMine ? HarvestTheme.Colors.rose : HarvestTheme.Colors.wineCard)
                    )
                    .overlay {
                        if isBlurred { blurOverlay }
                    }
                    .contentShape(bubble)
                    .onTapGesture {
                        if isBlurred { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }
            }

            if isMine {
                avatar
            } else {
                Spacer(minLength: 40)
            }
        }
    }

    private var blurOverlay: some View {
        VStack(spacing: 2) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
            Text(hint)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Tap to reveal")
                .font(.system(size: 10))
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .padding(.horizontal, HarvestTheme.Spacing.sm)
    }

    /// Viewer-facing hint about why a message is hidden.
    private var hint: String {
        switch flag?.category {
        case "aggressive":           return "May contain hostile language"
        case "sexual_pressure":      return "May contain explicit content"
        case "manipulative":         return "May contain manipulative language"
        case "possessive":           return "May contain controlling language"
        case "pressuring":           return "May contain pressuring language"
        case "excessive_intensity":  return "Very intense message"
        case "personal_info", "phone_number": return "May contain personal info"
        default:                     return "Possibly sensitive content"
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = sender?.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(HarvestTheme.Colors.wineCard)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
            }
    }
}

private struct PromptPicker: View {
    let prompts: [CommunityPrompt]
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(prompts) { prompt in
                        Button { onPick(prompt.text) } label: {
                            HStack {
                                Text(prompt.text)
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(HarvestTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                                .fill(HarvestTheme.Colors.glassFill)
                                .overlay(RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg).stroke(HarvestTheme.Colors.border, lineWidth: 1))
                        )
                    }
                }
                .padding(HarvestTheme.Spacing.md)
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Icebreakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
