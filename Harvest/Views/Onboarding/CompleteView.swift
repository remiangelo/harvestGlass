import SwiftUI

struct CompleteView: View {
    let viewModel: OnboardingViewModel
    let authViewModel: AuthViewModel

    @State private var showConfetti = false
    @AppStorage("notifications_prompted_at_onboarding") private var notificationsPrompted = false

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

            Text("Meet your AI coach — let's find values-aligned matches")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showConfetti ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: showConfetti)

            Spacer()

            if !notificationsPrompted {
                GlassCard {
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                        HStack(spacing: HarvestTheme.Spacing.sm) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title3)
                                .foregroundStyle(HarvestTheme.Colors.accent)
                            Text("Stay in the loop")
                                .font(HarvestTheme.Typography.h4)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        }
                        Text("We'll let you know about new matches, messages, and likes — and a gentle daily reflection from your Gardener.")
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        HStack {
                            Button("Maybe later") {
                                notificationsPrompted = true
                            }
                            .font(HarvestTheme.Typography.buttonText)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            Spacer()
                            Button {
                                Task {
                                    await NotificationService.shared.requestPermissionAndRegister()
                                    await NotificationService.shared.scheduleGardenerLocalNotification(hour: 9, enabled: true)
                                    notificationsPrompted = true
                                }
                            } label: {
                                Text("Turn on")
                                    .font(HarvestTheme.Typography.buttonText)
                                    .foregroundStyle(HarvestTheme.Colors.textOnCream)
                                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                                    .padding(.vertical, HarvestTheme.Spacing.sm)
                                    .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
                            }
                        }
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.lg)
            }

            GlassButton(title: "Meet The Gardener", icon: "leaf.fill", style: .primary) {
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
