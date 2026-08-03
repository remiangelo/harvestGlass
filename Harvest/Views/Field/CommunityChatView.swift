import SwiftUI

struct CommunityChatView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = CommunityChatViewModel()
    @State private var showPrompts = false
    @State private var reportTarget: (senderId: String, messageId: String)? = nil
    @State private var selectedProfile: UserProfile?
    @State private var isLoadingProfile = false
    @State private var showMembers = false
    @FocusState private var isComposerFocused: Bool
    private let profileService = ProfileService()
    private var userId: String { authViewModel.currentUserId ?? "" }

    /// Invisible row pinned below the last message; the scroll target.
    private static let bottomAnchor = "chatBottomAnchor"
    /// Avatar diameter, and the gutter reserved for it on grouped rows.
    fileprivate static let avatarSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                        if vm.hasMore {
                            Button {
                                Task { await vm.loadOlder(communityId: community.id) }
                            } label: {
                                if vm.isLoadingOlder {
                                    ProgressView().tint(HarvestTheme.Colors.rose)
                                } else {
                                    Label("Load earlier messages", systemImage: "arrow.up.circle")
                                        .font(HarvestTheme.Typography.caption)
                                        .foregroundStyle(HarvestTheme.Colors.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HarvestTheme.Spacing.xs)
                        }
                        if vm.messages.isEmpty {
                            emptyState
                        }
                        ForEach(vm.messages) { msg in
                            let position = vm.positions[msg.id]
                                ?? MessagePosition(showsDateSeparator: false,
                                                   isFirstInGroup: true,
                                                   isLastInGroup: true)

                            if position.showsDateSeparator,
                               let date = MessageGrouping.date(from: msg.createdAt) {
                                DateSeparator(date: date)
                            }

                            SwipeToReply(onReply: { vm.replyTarget = msg }) {
                                VStack(alignment: msg.senderId == userId ? .trailing : .leading, spacing: 2) {
                                    CommunityBubble(
                                        message: msg,
                                        quoted: vm.quotedMessage(for: msg),
                                        quotedSenderName: vm.quotedMessage(for: msg).map {
                                            vm.senders[$0.senderId]?.nickname ?? "Member"
                                        },
                                        mentionNicknames: vm.mentionedNicknames(for: msg),
                                        mentionsMe: (msg.mentions ?? []).contains(userId),
                                        sender: vm.senders[msg.senderId],
                                        isMine: msg.senderId == userId,
                                        position: position,
                                        timeLabel: position.isLastInGroup ? vm.timeLabel(for: msg) : "",
                                        onTapSender: msg.senderId == userId
                                            ? nil
                                            : { Task { await openProfile(senderId: msg.senderId) } },
                                        onTapQuote: { originalId in
                                            if vm.messages.contains(where: { $0.id == originalId }) {
                                                withAnimation { proxy.scrollTo(originalId, anchor: .center) }
                                            }
                                        }
                                    )
                                    if let rs = vm.reactions[msg.id], !rs.isEmpty {
                                        ReactionChips(
                                            reactions: rs,
                                            myUserId: userId,
                                            isMine: msg.senderId == userId
                                        ) { emoji in
                                            Task { await vm.toggleReaction(emoji: emoji, message: msg, userId: userId) }
                                        }
                                    }
                                }
                            }
                                .id(msg.id)
                                .contextMenu {
                                    ControlGroup {
                                        ForEach(CommunityReaction.curatedEmoji, id: \.self) { emoji in
                                            Button(emoji) {
                                                Task { await vm.toggleReaction(emoji: emoji, message: msg, userId: userId) }
                                            }
                                        }
                                    }
                                    .controlGroupStyle(.palette)
                                    Button {
                                        vm.replyTarget = msg
                                    } label: {
                                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                                    }
                                    if msg.senderId != userId {
                                        Button(role: .destructive) {
                                            reportTarget = (senderId: msg.senderId, messageId: msg.id)
                                        } label: {
                                            Label("Report message", systemImage: "flag")
                                        }
                                    }
                                }
                        }

                        // Scroll target. Anchoring on the last *message* left
                        // it flush against the composer; this sentinel gives
                        // it room to clear.
                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchor)
                    }
                    .padding(HarvestTheme.Spacing.md)
                    .padding(.bottom, HarvestTheme.Spacing.sm)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture { isComposerFocused = false }
                .onChange(of: vm.messages.last?.id) { _, _ in
                    withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
                }
                .onChange(of: isComposerFocused) { _, focused in
                    // Keyboard opening must not hide the newest message.
                    if focused {
                        withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
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

            if let target = vm.replyTarget {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HarvestTheme.Colors.rose)
                        .frame(width: 3, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replying to \(vm.senders[target.senderId]?.nickname ?? "Member")")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.accent)
                        Text(target.content)
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        vm.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.top, HarvestTheme.Spacing.xs)
            }

            if !vm.mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(vm.mentionSuggestions) { member in
                            Button {
                                vm.pickMention(member)
                            } label: {
                                Text("@\(member.nickname ?? "")")
                                    .font(HarvestTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                                    .padding(.horizontal, HarvestTheme.Spacing.sm)
                                    .padding(.vertical, HarvestTheme.Spacing.xs)
                                    .background(Capsule().fill(HarvestTheme.Colors.fieldGreenSoft))
                            }
                        }
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                }
                .padding(.top, HarvestTheme.Spacing.xs)
            }

            composer
        }
        .background(ChatBackdrop(accent: .rose))
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showMembers = true } label: {
                    Image(systemName: "person.2.fill")
                }
                .tint(HarvestTheme.Colors.rose)
                .accessibilityLabel("View members")
            }
        }
        .sheet(isPresented: $showMembers) {
            RoomMembersView(authViewModel: authViewModel, community: community)
        }
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
                // Field views stay green; primary would leak the app's red in.
                .foregroundStyle(HarvestTheme.Colors.rose)
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
        ChatComposer(
            text: $vm.draft,
            focused: $isComposerFocused,
            accent: .rose,
            placeholder: "Share something…",
            isSending: vm.isSending,
            onSend: { Task { await vm.send(communityId: community.id, senderId: userId) } },
            accessory: {
                Button { showPrompts.toggle() } label: {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(HarvestTheme.Colors.accent)
                        .frame(width: 36, height: 36)
                }
            }
        )
    }
}

/// Identifiable wrapper so the sheet(item:) binding works.
private struct ReportSheetItem: Identifiable, Equatable {
    let senderId: String
    let messageId: String
    var id: String { messageId }
}

/// Drag-right-to-reply. Threshold 40pt; the row springs back either way.
private struct SwipeToReply<Content: View>: View {
    let onReply: () -> Void
    @ViewBuilder let content: Content

    @State private var offsetX: CGFloat = 0

    var body: some View {
        content
            .offset(x: offsetX)
            .simultaneousGesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        guard value.translation.width > 0,
                              abs(value.translation.width) > abs(value.translation.height) else { return }
                        offsetX = min(value.translation.width * 0.5, 60)
                    }
                    .onEnded { value in
                        if offsetX > 40 { onReply() }
                        withAnimation(.spring(duration: 0.25)) { offsetX = 0 }
                    }
            )
    }
}

/// Grouped emoji counts under a bubble. Your own reactions tint green.
private struct ReactionChips: View {
    let reactions: [CommunityReaction]
    let myUserId: String
    let isMine: Bool
    let onToggle: (String) -> Void

    private var grouped: [(emoji: String, count: Int, mine: Bool)] {
        CommunityReaction.curatedEmoji.compactMap { emoji in
            let matching = reactions.filter { $0.emoji == emoji }
            guard !matching.isEmpty else { return nil }
            return (emoji, matching.count, matching.contains { $0.userId == myUserId })
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(grouped, id: \.emoji) { group in
                Button {
                    onToggle(group.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(group.emoji).font(.system(size: 12))
                        Text("\(group.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(group.mine ? HarvestTheme.Colors.accent : HarvestTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(group.mine ? HarvestTheme.Colors.primarySoft : HarvestTheme.Colors.wineRaised)
                    )
                    .overlay(
                        Capsule().stroke(group.mine ? HarvestTheme.Colors.rose.opacity(0.22) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        // Line the chips up with the bubble, clearing the avatar gutter.
        // The old trailing inset cleared your own avatar, which no longer renders.
        .padding(.leading, isMine ? 0 : CommunityChatView.avatarSize + HarvestTheme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

private struct CommunityBubble: View {
    let message: CommunityMessage
    var quoted: CommunityMessage? = nil
    var quotedSenderName: String? = nil
    var mentionNicknames: [String] = []
    var mentionsMe: Bool = false
    let sender: CommunitySender?
    let isMine: Bool
    let position: MessagePosition
    var timeLabel: String = ""
    var onTapSender: (() -> Void)? = nil
    var onTapQuote: ((String) -> Void)? = nil

    @State private var revealed = false
    private let mindful = MindfulMessagingService()

    /// Non-nil when an incoming message should be blurred for the viewer.
    /// Respects the viewer's own mindful-messaging toggle.
    private var flag: MindfulMessagingService.MindfulAnalysis? {
        guard !isMine, mindful.isEnabled else { return nil }
        return mindful.localFlag(for: message.content)
    }

    var body: some View {
        let isBlurred = flag != nil && !revealed
        let shape = ChatBubbleShape(
            isMine: isMine,
            isFirstInGroup: position.isFirstInGroup,
            isLastInGroup: position.isLastInGroup
        )

        HStack(alignment: .bottom, spacing: HarvestTheme.Spacing.xs) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                // The avatar sits on the last message of a run only; earlier
                // rows reserve its width so the column stays flush.
                if position.isLastInGroup {
                    avatar
                        .contentShape(Circle())
                        .onTapGesture { onTapSender?() }
                } else {
                    Color.clear.frame(width: CommunityChatView.avatarSize, height: CommunityChatView.avatarSize)
                }
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                // Name once per run, and never on your own messages.
                if !isMine, position.isFirstInGroup {
                    Text(sender?.nickname ?? "Member")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(onTapSender == nil
                                         ? HarvestTheme.Colors.textTertiary
                                         : HarvestTheme.Colors.accent)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapSender?() }
                        .padding(.leading, HarvestTheme.Spacing.xs)
                }

                if message.replyToId != nil {
                    replyQuote
                }

                MentionText(
                    content: message.content,
                    nicknames: mentionNicknames,
                    baseColor: isMine ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary
                )
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .frame(minWidth: isBlurred ? 150 : nil, minHeight: isBlurred ? 44 : nil, alignment: .leading)
                    .blur(radius: isBlurred ? 7 : 0)
                    .chatBubble(accent: .rose, isMine: isMine, shape: shape)
                    .overlay {
                        if isBlurred { blurOverlay }
                    }
                    .overlay {
                        if mentionsMe {
                            shape.stroke(HarvestTheme.Colors.fieldGreen.opacity(0.55), lineWidth: 1)
                        }
                    }
                    .contentShape(shape)
                    .onTapGesture {
                        if isBlurred { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }

                if !timeLabel.isEmpty {
                    Text(timeLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                        .padding(.horizontal, HarvestTheme.Spacing.xs)
                }
            }

            // No avatar on your own messages — you know who you are.
            if !isMine { Spacer(minLength: 48) }
        }
    }

    /// The quoted original above a reply. Logic unchanged from before the
    /// redesign; only the surface is new.
    private var replyQuote: some View {
        HStack(spacing: HarvestTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(HarvestTheme.Colors.rose)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(quotedSenderName ?? "Member")
                    .font(HarvestTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(HarvestTheme.Colors.accent)
                Text(quoted.map { $0.isRemoved ? "Message removed" : $0.content } ?? "…")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.sm)
        .padding(.vertical, HarvestTheme.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(HarvestTheme.Colors.primarySoft)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = message.replyToId { onTapQuote?(id) }
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
        .frame(width: CommunityChatView.avatarSize, height: CommunityChatView.avatarSize)
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

/// Message text with "@nickname" spans tinted green. Falls back to plain
/// text when a mentioned user's nickname changed and no longer matches.
private struct MentionText: View {
    let content: String
    let nicknames: [String]
    let baseColor: Color

    var body: some View {
        Text(attributed)
            .font(HarvestTheme.Typography.bodyRegular)
            .foregroundStyle(baseColor)
    }

    private var attributed: AttributedString {
        var attr = AttributedString(content)
        for nick in nicknames where !nick.isEmpty {
            let needle = "@" + nick
            var searchStart = attr.startIndex
            while searchStart < attr.endIndex,
                  let range = attr[searchStart...].range(of: needle, options: [.caseInsensitive]) {
                // Word-boundary check: "@Al" must not highlight inside "@Alex".
                let after = range.upperBound
                let isBoundary: Bool = {
                    guard after < attr.endIndex else { return true }
                    let c = attr.characters[after]
                    return !c.isLetter && !c.isNumber
                }()
                if isBoundary {
                    attr[range].foregroundColor = HarvestTheme.Colors.fieldGreenLight
                    attr[range].inlinePresentationIntent = .stronglyEmphasized
                }
                searchStart = range.upperBound
            }
        }
        return attr
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
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
