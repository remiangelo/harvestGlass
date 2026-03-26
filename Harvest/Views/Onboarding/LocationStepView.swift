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
                .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.45))

            TextField("City name", text: Bindable(viewModel).location)
                .font(HarvestTheme.Typography.bodyLarge)
                .foregroundStyle(HarvestTheme.Colors.textOnCream)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(HarvestTheme.Colors.deepPlum.opacity(0.12), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
                .padding(.horizontal, HarvestTheme.Spacing.xl)

            if viewModel.isValidatingLocation {
                ProgressView()
                    .tint(HarvestTheme.Colors.primary)
            } else if let resolved = viewModel.resolvedLocation {
                Text(resolved)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.7))
            }

            Spacer()
        }
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
