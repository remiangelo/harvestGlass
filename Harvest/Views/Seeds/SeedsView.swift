// Harvest/Views/Seeds/SeedsView.swift
import SwiftUI

/// Carries both ids needed to open ChatDetailView from an accepted Seed.
struct AcceptedSeedRoute: Identifiable, Hashable {
    let id: String          // conversation id (stable, used as Identifiable id)
    let conversationId: String
    let partnerUserId: String
}

struct SeedsView: View {
    let authViewModel: AuthViewModel
    @Binding var pendingChatDeepLink: String?

    @State private var vm = SeedsViewModel()

    private var userId: String { authViewModel.currentUserId ?? "" }

    /// Build the route when both ids are available.
    private var acceptedRoute: AcceptedSeedRoute? {
        guard let convoId = vm.openedConversationId,
              let partnerId = vm.openedPartnerUserId else { return nil }
        return AcceptedSeedRoute(
            id: convoId,
            conversationId: convoId,
            partnerUserId: partnerId
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $vm.segment) {
                    Text("Requests").tag(SeedsViewModel.Segment.requests)
                    Text("Conversations").tag(SeedsViewModel.Segment.conversations)
                }
                .pickerStyle(.segmented)
                .padding()

                switch vm.segment {
                case .requests:
                    requests
                case .conversations:
                    MindfulMessagesView(
                        authViewModel: authViewModel,
                        pendingChatDeepLink: $pendingChatDeepLink
                    )
                }
            }
            .navigationTitle("Seeds")
            .task { await vm.load(userId: userId) }
            .refreshable { await vm.load(userId: userId) }
            .navigationDestination(item: Binding(
                get: { acceptedRoute },
                set: { if $0 == nil { vm.openedConversationId = nil; vm.openedPartnerUserId = nil } }
            )) { route in
                ChatDetailView(
                    authViewModel: authViewModel,
                    conversationId: route.conversationId,
                    partnerUserId: route.partnerUserId
                )
            }
        }
    }

    @ViewBuilder private var requests: some View {
        VStack(spacing: 0) {
            Picker("", selection: $vm.requestKind) {
                Text("Received").tag(SeedsViewModel.RequestKind.received)
                Text("Sent").tag(SeedsViewModel.RequestKind.sent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                let items = vm.requestKind == .received ? vm.received : vm.sent
                if items.isEmpty {
                    Text(vm.requestKind == .received ? "No new Seeds yet 🌱" : "No pending sent Seeds.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { seed in
                        SeedRow(
                            seed: seed,
                            isReceived: vm.requestKind == .received,
                            onAccept: { Task { await vm.accept(seed, userId: userId) } },
                            onDecline: { Task { await vm.decline(seed, userId: userId) } }
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct SeedRow: View {
    let seed: Seed
    let isReceived: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(seed.openingMessage).font(.body)
            if isReceived {
                HStack {
                    Button("Let It Grow", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .tint(HarvestTheme.Colors.primary)
                    Button("No Thanks", action: onDecline)
                        .buttonStyle(.bordered)
                }
            } else {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
