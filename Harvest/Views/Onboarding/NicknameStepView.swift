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
                .foregroundStyle(.secondary)

            TextField("Your nickname", text: Bindable(viewModel).nickname)
                .font(HarvestTheme.Typography.bodyLarge)
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(Color(.separator), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
                .padding(.horizontal, HarvestTheme.Spacing.xl)

            Spacer()
        }
    }
}
