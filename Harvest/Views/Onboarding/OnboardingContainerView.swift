import SwiftUI

struct OnboardingContainerView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .tint(HarvestTheme.Colors.primary)
                    .padding(.horizontal)

                // Step content
                Group {
                    switch viewModel.currentStep {
                    case .age:
                        AgeStepView(viewModel: viewModel)
                    case .nickname:
                        NicknameStepView(viewModel: viewModel)
                    case .photos:
                        PhotosStepView(viewModel: viewModel, userId: authViewModel.currentUserId ?? "")
                    case .goals:
                        GoalsStepView(viewModel: viewModel)
                    case .genderIdentity:
                        GenderStepView(viewModel: viewModel)
                    case .interestedIn:
                        InterestedInStepView(viewModel: viewModel)
                    case .location:
                        LocationStepView(viewModel: viewModel)
                    case .terms:
                        TermsStepView(viewModel: viewModel)
                    case .complete:
                        CompleteView(viewModel: viewModel, authViewModel: authViewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Navigation buttons
                if viewModel.currentStep != .complete {
                    HStack(spacing: HarvestTheme.Spacing.md) {
                        if viewModel.currentStep != .age {
                            GlassButton(title: "Back", icon: "chevron.left", style: .primary) {
                                withAnimation { viewModel.previousStep() }
                            }
                        }

                        GlassButton(
                            title: "Continue",
                            icon: "chevron.right",
                            style: .primary
                        ) {
                            withAnimation { viewModel.nextStep() }
                        }
                        .disabled(!viewModel.canProceed)
                        .opacity(viewModel.canProceed ? 1 : 0.5)
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.bottom, HarvestTheme.Spacing.lg)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Set Up Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign Out") {
                        Task { await authViewModel.logout() }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
