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
        return AcceptedSeedRoute(id: convoId, conversationId: convoId, partnerUserId: partnerId)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $vm.segment) {
                    Text("Requests").tag(SeedsViewModel.Segment.requests)
                    Text("Conversations").tag(SeedsViewModel.Segment.conversations)
                }
                .pickerStyle(.segmented)
                .padding(HarvestTheme.Spacing.md)

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
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .navigationTitle("Seeds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await vm.load(userId: userId) }
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
        let items = vm.requestKind == .received ? vm.received : vm.sent

        VStack(spacing: 0) {
            Picker("", selection: $vm.requestKind) {
                Text("Received").tag(SeedsViewModel.RequestKind.received)
                Text("Sent").tag(SeedsViewModel.RequestKind.sent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HarvestTheme.Spacing.md)
            .padding(.bottom, HarvestTheme.Spacing.sm)

            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    if items.isEmpty {
                        emptyState
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
                .padding(HarvestTheme.Spacing.md)
            }
            .refreshable { await vm.load(userId: userId) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Text("🌱")
                .font(.system(size: 40))
            Text(vm.requestKind == .received ? "No new Seeds yet" : "No pending sent Seeds")
                .font(HarvestTheme.Typography.h4)
            Text(vm.requestKind == .received
                 ? "When someone sends you a Seed, it'll appear here."
                 : "Seeds you send will wait here until they're accepted.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HarvestTheme.Spacing.xxl)
    }
}

private struct SeedRow: View {
    let seed: Seed
    let isReceived: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text(seed.openingMessage)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isReceived {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        Button("Let It Grow", action: onAccept)
                            .buttonStyle(.harvestGlass(.primary))
                        Button("No Thanks", action: onDecline)
                            .buttonStyle(.harvestGlass(.secondary))
                    }
                } else {
                    HStack(spacing: HarvestTheme.Spacing.xs) {
                        Image(systemName: "clock")
                        Text("Pending")
                    }
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }
            }
        }
    }
}
