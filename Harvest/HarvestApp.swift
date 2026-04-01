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
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            Image("Splash Page Gradient")
                .resizable()
                .scaledToFill()
                .scaleEffect(animateGlow ? 1.02 : 1.0)
                .ignoresSafeArea()

            Color.black.opacity(0.06)
                .ignoresSafeArea()

            Image("Harvest_Wordmark_Black")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .shadow(color: Color.white.opacity(0.08), radius: 8, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}
