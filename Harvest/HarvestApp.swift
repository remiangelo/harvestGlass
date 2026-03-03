import SwiftUI

@main
struct HarvestApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoading {
                    LaunchScreenView()
                } else if authViewModel.isAuthenticated {
                    if authViewModel.needsOnboarding {
                        OnboardingContainerView(authViewModel: authViewModel)
                    } else {
                        MainTabView(authViewModel: authViewModel)
                    }
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
            .task {
                authViewModel.listenToAuthChanges()
                await authViewModel.checkSession()
            }
        }
    }
}

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            HarvestTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: HarvestTheme.Spacing.md) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(HarvestTheme.Colors.primary)

                Text("Harvest")
                    .font(HarvestTheme.Typography.h1)
                    .foregroundStyle(HarvestTheme.Colors.primary)

                ProgressView()
                    .tint(HarvestTheme.Colors.primary)
            }
        }
    }
}
