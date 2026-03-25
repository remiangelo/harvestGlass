import SwiftUI

struct GenderStepView: View {
    let viewModel: OnboardingViewModel

    private let genders = [
        ("Male", "figure.stand"),
        ("Female", "figure.stand.dress"),
        ("Non-binary", "figure.2"),
        ("Prefer not to say", "hand.raised")
    ]

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("What's your gender?")
                .font(HarvestTheme.Typography.h2)

            VStack(spacing: HarvestTheme.Spacing.sm) {
                ForEach(genders, id: \.0) { gender, icon in
                    Button {
                        viewModel.gender = gender.lowercased().replacingOccurrences(of: " ", with: "-")
                    } label: {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                            Text(gender)
                                .font(HarvestTheme.Typography.bodyRegular)
                            Spacer()
                            if viewModel.gender == gender.lowercased().replacingOccurrences(of: " ", with: "-") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                            }
                        }
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .fill(HarvestTheme.Colors.glassFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Spacer()
        }
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
    }
}
