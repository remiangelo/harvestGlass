import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel
    @State private var vm = FieldViewModel()
    private var userId: String { authViewModel.currentUserId ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    EventsComingSoonBanner()

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
                    .foregroundStyle(HarvestTheme.Colors.rose)
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
        VStack(alignment: .leading, spacing: 0) {
            banner
            details(joined: joined)
        }
        .background(HarvestTheme.Colors.wineCard)
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .stroke(joined ? HarvestTheme.Colors.fieldGreenBorder : HarvestTheme.Colors.border, lineWidth: 1)
        )
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlString = community.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        bannerPlaceholder
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, HarvestTheme.Colors.photoScrim.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)

            Text(community.name)
                .font(HarvestTheme.Typography.h4)
                // Sits on the photo scrim, not the page — stays white.
                .foregroundStyle(HarvestTheme.Colors.textInverse)
                .padding(HarvestTheme.Spacing.md)
        }
        .frame(height: 110)
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(HarvestTheme.Colors.wineRaised)
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(HarvestTheme.Colors.fieldGreen.opacity(0.4))
            }
    }

    private func details(joined: Bool) -> some View {
        HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                if let description = community.description {
                    Text(description)
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let count = community.memberCount, count > 0 {
                    Label("\(count) member\(count == 1 ? "" : "s")", systemImage: "leaf.fill")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.accent)
                }

                if joined {
                    Label("Tap to open room", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.accent)
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
                    .font(HarvestTheme.Typography.bodySmall.weight(.semibold))
                    // White on the red capsule — textPrimary is dark now.
                    .foregroundStyle(HarvestTheme.Colors.textOnRedPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background(Capsule().fill(HarvestTheme.Colors.rose))
                    .contentShape(Capsule())
            }
        }
        .padding(HarvestTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
