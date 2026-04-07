import SwiftUI

struct AgeStepView: View {
    let viewModel: OnboardingViewModel

    private var minDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("How old are you?")
                .font(HarvestTheme.Typography.h2)

            Text("You must be at least 18 years old")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                    .fill(HarvestTheme.Colors.formSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                            .stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
                    }

                DatePicker(
                    "Birthday",
                    selection: Bindable(viewModel).birthDate,
                    in: minDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            if viewModel.age > 0 {
                Text("Age: \(viewModel.age)")
                    .font(HarvestTheme.Typography.h3)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }

            if !viewModel.isAgeValid && viewModel.age > 0 {
                Text("You must be 18 or older to use Harvest")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.error)
            }

            Spacer()
        }
    }
}
