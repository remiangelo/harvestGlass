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
                .foregroundStyle(HarvestTheme.Colors.textPrimary)

            VStack(spacing: HarvestTheme.Spacing.sm) {
                ForEach(genders, id: \.0) { gender, icon in
                    let value = gender.lowercased().replacingOccurrences(of: " ", with: "-")
                    let isSelected = viewModel.gender == value

                    Button {
                        viewModel.gender = value
                    } label: {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                            Text(gender)
                                .font(HarvestTheme.Typography.bodyRegular)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : HarvestTheme.Colors.textPrimary)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .fill(isSelected ? HarvestTheme.Colors.redSurface : HarvestTheme.Colors.formSurface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(isSelected ? HarvestTheme.Colors.primaryLight : HarvestTheme.Colors.formBorder, lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Spacer()
        }
    }
}
