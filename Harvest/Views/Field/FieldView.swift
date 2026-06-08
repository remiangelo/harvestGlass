import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel
    @State private var vm = FieldViewModel()
    private var userId: String { authViewModel.currentUserId ?? "" }

    var body: some View {
        NavigationStack {
            List {
                if vm.available.isEmpty && !vm.isLoading {
                    Text("Set your relationship status in Profile to unlock connection spaces.")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.available) { community in
                    CommunityRow(
                        community: community,
                        isJoined: vm.isJoined(community),
                        authViewModel: authViewModel,
                        onToggle: { Task { await vm.toggleJoin(community, userId: userId) } }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("The Field")
            .task { await vm.load(userId: userId) }
            .refreshable { await vm.load(userId: userId) }
        }
    }
}

private struct CommunityRow: View {
    let community: Community
    let isJoined: Bool
    let authViewModel: AuthViewModel
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(community.name).font(.headline)
                    if let d = community.description {
                        Text(d).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(isJoined ? "Leave" : "Join", action: onToggle)
                    .buttonStyle(.bordered)
                    .tint(isJoined ? .secondary : HarvestTheme.Colors.primary)
            }
            if isJoined {
                NavigationLink {
                    CommunityChatView(authViewModel: authViewModel, community: community)
                } label: {
                    Label("Open room", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
