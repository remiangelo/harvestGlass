import SwiftUI

struct LocationStepView: View {
    let viewModel: OnboardingViewModel

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
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HarvestTheme.Spacing.xl)

            Spacer()
        }
    }
}
