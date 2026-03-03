import SwiftUI

struct NicknameStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "person.text.rectangle")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("What should we call you?")
                .font(HarvestTheme.Typography.h2)

            Text("This is how other users will see you")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            GlassCard {
                TextField("Your nickname", text: Bindable(viewModel).nickname)
                    .font(HarvestTheme.Typography.bodyLarge)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HarvestTheme.Spacing.xl)

            Spacer()
        }
    }
}
