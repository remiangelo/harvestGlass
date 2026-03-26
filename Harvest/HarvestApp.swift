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
            LinearGradient(
                colors: [
                    Color(hex: "5A1827"),
                    HarvestTheme.Colors.appleRed,
                    HarvestTheme.Colors.heartGlow,
                    Color(hex: "6B2034")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "F4A7BD").opacity(0.78),
                    Color(hex: "F08FA8").opacity(0.35),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: animateGlow ? 420 : 340
            )
            .scaleEffect(animateGlow ? 1.06 : 0.94)
            .blur(radius: 16)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color(hex: "F7B2C5").opacity(0.16),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: animateGlow ? 250 : 180
            )
            .offset(y: -30)
            .blur(radius: 12)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    .clear,
                    Color(hex: "4C1421").opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Text("Harvest")
                .font(.custom("Orange Squash", size: 64))
                .foregroundStyle(HarvestTheme.Colors.deepPlum.opacity(0.95))
                .shadow(color: Color.white.opacity(0.08), radius: 8, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}
