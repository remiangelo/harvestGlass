import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel
    @State private var vm = FieldViewModel()
    private var userId: String { authViewModel.currentUserId ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    header

                    if vm.available.isEmpty && !vm.isLoading {
                        emptyState
                    }

                    ForEach(vm.available) { community in
                        CommunityCard(
                            community: community,
                            isJoined: vm.isJoined(community),
                            authViewModel: authViewModel,
                            onToggle: { Task { await vm.toggleJoin(community, userId: userId) } }
                        )
                    }
                }
                .padding(HarvestTheme.Spacing.md)
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("The Field")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await vm.load(userId: userId) }
            .refreshable { await vm.load(userId: userId) }
        }
    }

    private var header: some View {
        Text("Join the spaces where you're hoping to grow connection.")
            .font(HarvestTheme.Typography.bodyRegular)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: HarvestTheme.Spacing.sm) {
                Image(systemName: "leaf.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(HarvestTheme.Colors.primary)
                Text("No spaces yet")
                    .font(HarvestTheme.Typography.h4)
                Text("Update your relationship status in Profile to unlock connection spaces.")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HarvestTheme.Spacing.sm)
        }
    }
}

private struct CommunityCard: View {
    let community: Community
    let isJoined: Bool
    let authViewModel: AuthViewModel
    let onToggle: () -> Void

    var body: some View {
        if isJoined {
            NavigationLink {
                CommunityChatView(authViewModel: authViewModel, community: community)
            } label: {
                cardBody(joined: true)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: onToggle) {
                    Label("Leave room", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } else {
            cardBody(joined: false)
        }
    }

    private func cardBody(joined: Bool) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                    Text(community.name)
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    if let description = community.description {
                        Text(description)
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if joined {
                        Label("Tap to open room", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.primary)
                            .padding(.top, HarvestTheme.Spacing.xxs)
                    }
                }

                Spacer(minLength: HarvestTheme.Spacing.sm)

                if joined {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                        .padding(.top, HarvestTheme.Spacing.xxs)
                } else {
                    Button("Join", action: onToggle)
                        .buttonStyle(.harvestGlass(.primary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
