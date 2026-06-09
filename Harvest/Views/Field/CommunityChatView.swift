import SwiftUI

struct CommunityChatView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = CommunityChatViewModel()
    @State private var showPrompts = false
    @State private var reportTarget: (senderId: String, messageId: String)? = nil
    private var userId: String { authViewModel.currentUserId ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
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
                    .padding()
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let error = vm.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal)
            }

            HStack(spacing: 8) {
                Button { showPrompts.toggle() } label: {
                    Image(systemName: "lightbulb")
                }
                TextField("Share something…", text: $vm.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await vm.send(communityId: community.id, senderId: userId) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
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
            if isMine { Spacer() }
            Text(message.content)
                .padding(10)
                .background(isMine ? HarvestTheme.Colors.primary.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isMine { Spacer() }
        }
    }
}

private struct PromptPicker: View {
    let prompts: [CommunityPrompt]
    let onPick: (String) -> Void
    var body: some View {
        NavigationStack {
            List(prompts) { p in
                Button(p.text) { onPick(p.text) }
            }
            .navigationTitle("Icebreakers")
        }
    }
}
