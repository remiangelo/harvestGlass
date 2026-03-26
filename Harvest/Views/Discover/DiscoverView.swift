import SwiftUI

struct DiscoverView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                HarvestTheme.Colors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.profiles.isEmpty {
                    ProgressView("Finding people near you...")
                        .tint(HarvestTheme.Colors.primary)
                } else if !viewModel.hasProfiles {
                    emptyState
                } else {
                    VStack(spacing: HarvestTheme.Spacing.md) {
                        // Card stack
                        cardStack
                            .frame(maxHeight: .infinity)

                        // Action buttons
                        actionButtons
                            .padding(.bottom, HarvestTheme.Spacing.md)
                    }
                }
            }
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        FiltersView(authViewModel: authViewModel)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.remainingCount > 0 {
                        GlassBadge(text: "\(viewModel.remainingCount)")
                    }
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadProfiles(userId: userId)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showMatchModal) {
                if let matchedProfile = viewModel.matchedProfile {
                    MatchModalView(
                        matchedProfile: matchedProfile,
                        currentProfile: authViewModel.profile,
                        onSendMessage: {
                            viewModel.dismissMatchModal()
                        },
                        onContinue: {
                            viewModel.dismissMatchModal()
                        }
                    )
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var cardStack: some View {
        ZStack {
            ForEach(
                Array(viewModel.profiles.enumerated().reversed())
                    .filter { $0.offset >= viewModel.currentIndex && $0.offset < viewModel.currentIndex + 3 },
                id: \.element.id
            ) { index, profile in
                SwipeCardView(
                    profile: profile,
                    isTopCard: index == viewModel.currentIndex,
                    onSwipe: { action in
                        if let userId = authViewModel.currentUserId {
                            Task {
                                await viewModel.swipe(action: action, userId: userId)
                            }
                        }
                    }
                )
                .scaleEffect(index == viewModel.currentIndex ? 1 : 0.95)
                .offset(y: CGFloat(index - viewModel.currentIndex) * 8)
                .allowsHitTesting(index == viewModel.currentIndex)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.md)
    }

    private var actionButtons: some View {
        HStack(spacing: HarvestTheme.Spacing.xl) {
            // Nope
            Button {
                if let userId = authViewModel.currentUserId {
                    Task { await viewModel.swipe(action: .nope, userId: userId) }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(HarvestTheme.Colors.nope)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }

            // Super Like
            Button {
                if let userId = authViewModel.currentUserId {
                    Task { await viewModel.swipe(action: .superLike, userId: userId) }
                }
            } label: {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(HarvestTheme.Colors.superLike)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }

            // Like
            Button {
                if let userId = authViewModel.currentUserId {
                    Task { await viewModel.swipe(action: .like, userId: userId) }
                }
            } label: {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(HarvestTheme.Colors.like)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(HarvestTheme.Colors.blackSurface)
                            .overlay {
                                Circle()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
            }
        }
        .disabled(!viewModel.hasProfiles)
    }

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(HarvestTheme.Colors.textTertiary)

            Text("No more profiles")
                .font(HarvestTheme.Typography.h3)

            Text("Check back later for new people")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            GlassButton(title: "Refresh", icon: "arrow.clockwise", style: .secondary) {
                if let userId = authViewModel.currentUserId {
                    Task { await viewModel.loadProfiles(userId: userId) }
                }
            }
            .frame(width: 160)
        }
    }
}
