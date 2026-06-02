import SwiftUI

struct TermsStepView: View {
    let viewModel: OnboardingViewModel

    @State private var showTerms = false
    @State private var showGuidelines = false

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
                    bulletPoint("Be honest in your profile information")
                    bulletPoint("Report any suspicious or harmful behavior")
                    bulletPoint("Be at least 18 years old")
                }

                // Apple 1.2: the agreement must make zero tolerance explicit.
                HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(HarvestTheme.Colors.primary)
                    Text("There is zero tolerance for objectionable content or abusive behavior. Violations result in content removal and account termination, reviewed within 24 hours.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
                .padding(.top, HarvestTheme.Spacing.xs)

                HStack(spacing: HarvestTheme.Spacing.md) {
                    Button("Terms of Service") { showTerms = true }
                    Button("Community Guidelines") { showGuidelines = true }
                }
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
                .tint(HarvestTheme.Colors.primary)
                .padding(.top, HarvestTheme.Spacing.xs)
            }
            .padding(HarvestTheme.Spacing.lg)
            .background(HarvestTheme.Colors.formSurface)
            .overlay {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                    .stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
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
                            viewModel.termsAccepted ? AnyShapeStyle(HarvestTheme.Colors.primary) : AnyShapeStyle(HarvestTheme.Colors.textSecondary.opacity(0.55))
                        )

                    Text("I agree to the Terms, Community Guidelines, and zero-tolerance policy")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, HarvestTheme.Spacing.lg)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsOfServiceView() }
        }
        .sheet(isPresented: $showGuidelines) {
            NavigationStack { CommunityGuidelinesView() }
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
            Text("\u{2022}")
            Text(text)
        }
        .font(HarvestTheme.Typography.bodySmall)
        .foregroundStyle(HarvestTheme.Colors.textSecondary)
    }
}
