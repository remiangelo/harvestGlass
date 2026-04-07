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
                .foregroundStyle(.primary)
                .opacity(showConfetti ? 1 : 0)
                .animation(.easeIn.delay(0.4), value: showConfetti)

            Text("Time to start discovering amazing people")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showConfetti ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: showConfetti)

            Spacer()

            GlassButton(title: "Start Exploring", icon: "safari", style: .primary) {
                Task {
                    guard let userId = authViewModel.currentUserId else { return }

                    if let updatedProfile = await viewModel.completeOnboarding(userId: userId) {
                        authViewModel.profile = updatedProfile
                        return
                    }

                    // Re-check the profile after any failure so temporary network issues
                    // don't strand users on the completion step if the save actually landed.
                    await authViewModel.loadProfile()

                    if authViewModel.needsOnboarding {
                        if viewModel.error == nil {
                            viewModel.error = "We couldn't finish setting up your profile. Please try again."
                        }
                    } else {
                        viewModel.error = nil
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
