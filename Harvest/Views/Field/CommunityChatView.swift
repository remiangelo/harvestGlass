import SwiftUI

struct CommunityChatView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = CommunityChatViewModel()
    @State private var showPrompts = false
    @State private var reportTarget: (senderId: String, messageId: String)? = nil
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
                            CommunityBubble(message: msg, isMine: msg.senderId == userId)
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
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.content)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(isMine ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                        .fill(isMine ? HarvestTheme.Colors.rose : HarvestTheme.Colors.wineCard)
                )
            if !isMine { Spacer(minLength: 40) }
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
