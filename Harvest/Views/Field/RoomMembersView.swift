import SwiftUI

/// Everyone in a room, filterable by profile attributes. Reached from the
/// room chat's toolbar. Tapping a member opens their profile with the
/// "Send a Seed" CTA, same as tapping an avatar in the transcript.
struct RoomMembersView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = RoomMembersViewModel()
    @State private var showFilters = false
    @State private var selectedProfile: UserProfile?
    @Environment(\.dismiss) private var dismiss

    private var userId: String { authViewModel.currentUserId ?? "" }
    private var visible: [UserProfile] { vm.visibleMembers(excluding: userId) }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.members.isEmpty {
                    ProgressView().tint(HarvestTheme.Colors.rose)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visible.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .searchable(text: $vm.filter.search, prompt: "Search members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: vm.filter.activeAttributeCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .tint(HarvestTheme.Colors.rose)
                }
            }
            .task { await vm.load(communityId: community.id, userId: userId) }
            .sheet(isPresented: $showFilters) {
                RoomMemberFiltersSheet(vm: vm, authViewModel: authViewModel)
            }
            .sheet(item: $selectedProfile) { profile in
                ProfileDetailView(
                    profile: profile,
                    currentProfile: authViewModel.profile,
                    showSwipeActions: true,
                    authViewModel: authViewModel
                ) { _ in
                    selectedProfile = nil
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: HarvestTheme.Spacing.sm) {
                HStack {
                    Text("\(visible.count) member\(visible.count == 1 ? "" : "s")")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    Spacer()
                    if vm.filter.activeAttributeCount > 0 {
                        Button("Clear filters") { vm.resetFilter() }
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.accent)
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.xs)

                ForEach(visible) { profile in
                    Button { selectedProfile = profile } label: {
                        MemberRow(profile: profile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HarvestTheme.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundStyle(HarvestTheme.Colors.rose)
            Text(vm.filter.activeAttributeCount > 0 || !vm.filter.search.isEmpty
                 ? "No one here matches those filters."
                 : "No other members yet.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if vm.filter.activeAttributeCount > 0 {
                Button("Clear filters") { vm.resetFilter() }
                    .buttonStyle(.harvestGlass(.secondary))
            }
        }
        .padding(HarvestTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MemberRow: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: HarvestTheme.Spacing.md) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: HarvestTheme.Spacing.xs) {
                    Text(profile.displayName)
                        .font(HarvestTheme.Typography.cardTitle)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    if let age = profile.age {
                        Text("\(age)")
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    }
                }
                if let location = profile.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                }
                if let lookingFor = profile.lookingFor, !lookingFor.isEmpty {
                    Text(lookingFor)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.accent)
                }
            }
            Spacer(minLength: HarvestTheme.Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HarvestTheme.Colors.textTertiary)
        }
        .padding(HarvestTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                .fill(HarvestTheme.Colors.wineCard)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = profile.primaryPhoto, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(HarvestTheme.Colors.wineRaised)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
            }
    }
}
