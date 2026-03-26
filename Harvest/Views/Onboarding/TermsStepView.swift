import SwiftUI

struct TermsStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("Terms & Conditions")
                .font(HarvestTheme.Typography.h2)

            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("By using Harvest, you agree to:")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                    bulletPoint("Treat others with respect and kindness")
                    bulletPoint("Not share inappropriate content")
                    bulletPoint("Be honest in your profile information")
                    bulletPoint("Report any suspicious or harmful behavior")
                    bulletPoint("Be at least 18 years old")
                }
            }
            .padding(HarvestTheme.Spacing.lg)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                    .stroke(HarvestTheme.Colors.deepPlum.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Button {
                viewModel.termsAccepted.toggle()
            } label: {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: viewModel.termsAccepted ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(
                            viewModel.termsAccepted ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textOnCream.opacity(0.35)
                        )

                    Text("I agree to the Terms & Conditions")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textOnCream)
                }
            }

            Spacer()
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
            Text("\u{2022}")
            Text(text)
        }
        .font(HarvestTheme.Typography.bodySmall)
        .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.7))
    }
}
