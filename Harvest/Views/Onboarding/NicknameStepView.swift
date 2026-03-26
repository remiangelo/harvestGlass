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
                .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.45))

            TextField("Your nickname", text: Bindable(viewModel).nickname)
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

            Spacer()
        }
    }
}
