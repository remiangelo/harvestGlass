import SwiftUI

struct LocationStepView: View {
    let viewModel: OnboardingViewModel

    @State private var validationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("Where are you located?")
                .font(HarvestTheme.Typography.h2)

            Text("Enter your city name")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            GlassCard {
                TextField("City name", text: Bindable(viewModel).location)
                    .font(HarvestTheme.Typography.bodyLarge)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HarvestTheme.Spacing.xl)

            if viewModel.isValidatingLocation {
                ProgressView()
                    .tint(HarvestTheme.Colors.primary)
            } else if let resolved = viewModel.resolvedLocation {
                Text(resolved)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }

            Spacer()
        }
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .onChange(of: viewModel.location) {
            viewModel.resolvedLocation = nil
            validationTask?.cancel()
            validationTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                await viewModel.validateLocation()
            }
        }
    }
}
