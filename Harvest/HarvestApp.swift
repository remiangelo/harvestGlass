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

            HeartGlowField(animateGlow: animateGlow)
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

private struct HeartGlowField: View {
    let animateGlow: Bool

    var body: some View {
        ZStack {
            HeartShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color(hex: "F7B7CA").opacity(0.58),
                            Color(hex: "F19AB2").opacity(0.34),
                            .clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: animateGlow ? 310 : 270
                    )
                )
                .frame(width: 380, height: 330)
                .scaleEffect(animateGlow ? 1.03 : 0.97)
                .blur(radius: 24)
                .offset(y: -36)

            HeartShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "F8C0D0").opacity(0.36),
                            Color(hex: "F3A5BB").opacity(0.24),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 330, height: 290)
                .blur(radius: 32)
                .offset(y: -54)
                .scaleEffect(animateGlow ? 1.02 : 0.98)

            Ellipse()
                .fill(Color(hex: "F6AFC3").opacity(0.22))
                .frame(width: 360, height: 250)
                .blur(radius: 44)
                .offset(y: 6)
        }
        .compositingGroup()
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let topCurveHeight = height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: width / 2, y: height))

        path.addCurve(
            to: CGPoint(x: 0, y: topCurveHeight),
            control1: CGPoint(x: width * 0.1, y: height * 0.78),
            control2: CGPoint(x: 0, y: height * 0.5)
        )

        path.addArc(
            center: CGPoint(x: width * 0.25, y: topCurveHeight),
            radius: width * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        path.addArc(
            center: CGPoint(x: width * 0.75, y: topCurveHeight),
            radius: width * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width, y: height * 0.5),
            control2: CGPoint(x: width * 0.9, y: height * 0.78)
        )

        return path
    }
}
