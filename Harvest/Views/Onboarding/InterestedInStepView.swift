import SwiftUI

struct InterestedInStepView: View {
    let viewModel: OnboardingViewModel

    private let options = ["Men", "Women", "Non-binary", "Everyone"]

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "heart.circle")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("Who are you interested in?")
                .font(HarvestTheme.Typography.h2)

            Text("Select all that apply")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.45))

            VStack(spacing: HarvestTheme.Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    let value = option.lowercased()
                    let isSelected = viewModel.interestedIn.contains(value)

                    Button {
                        if value == "everyone" {
                            if isSelected {
                                viewModel.interestedIn.removeAll()
                            } else {
                                viewModel.interestedIn = Set(options.map { $0.lowercased() })
                            }
                        } else {
                            if isSelected {
                                viewModel.interestedIn.remove(value)
                                viewModel.interestedIn.remove("everyone")
                            } else {
                                viewModel.interestedIn.insert(value)
                            }
                        }
                    } label: {
                        HStack {
                            Text(option)
                                .font(HarvestTheme.Typography.bodyRegular)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HarvestTheme.Colors.textOnRedPrimary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(HarvestTheme.Colors.textOnCream.opacity(0.35))
                            }
                        }
                        .foregroundStyle(isSelected ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textOnCream)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .fill(isSelected ? HarvestTheme.Colors.redSurface : Color.white)
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(HarvestTheme.Colors.deepPlum.opacity(0.12), lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Spacer()
        }
    }
}
