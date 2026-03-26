import SwiftUI

struct CompleteView: View {
    let viewModel: OnboardingViewModel
    let authViewModel: AuthViewModel

    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(HarvestTheme.Colors.accent.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showConfetti ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showConfetti)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(HarvestTheme.Colors.accent)
                    .scaleEffect(showConfetti ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: showConfetti)
            }

            Text("You're all set!")
                .font(HarvestTheme.Typography.h1)
                .opacity(showConfetti ? 1 : 0)
                .animation(.easeIn.delay(0.4), value: showConfetti)

            Text("Time to start discovering amazing people")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.55))
                .multilineTextAlignment(.center)
                .opacity(showConfetti ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: showConfetti)

            Spacer()

            GlassButton(title: "Start Exploring", icon: "safari", style: .primary) {
                Task {
                    if let userId = authViewModel.currentUserId {
                        if let updatedProfile = await viewModel.completeOnboarding(userId: userId) {
                            authViewModel.profile = updatedProfile
                        } else if viewModel.error == nil {
                            // Update returned nil without error — reload profile from database as fallback
                            await authViewModel.loadProfile()
                            if authViewModel.needsOnboarding {
                                viewModel.error = "Failed to save profile. Please try again."
                            }
                        }
                    }
                }
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            if viewModel.isLoading {
                ProgressView()
                    .tint(HarvestTheme.Colors.primary)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.error)
            }

            Spacer(minLength: HarvestTheme.Spacing.xxl)
        }
        .onAppear {
            showConfetti = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
