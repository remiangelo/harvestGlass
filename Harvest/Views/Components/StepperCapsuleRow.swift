import SwiftUI

struct StepperCapsuleRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    private let controlWidth: CGFloat = 124
    private let controlHeight: CGFloat = 42

    var body: some View {
        HStack(spacing: HarvestTheme.Spacing.md) {
            Text(title)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: HarvestTheme.Spacing.sm)

            HStack(spacing: 0) {
                stepperButton(systemName: "minus", isEnabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - 1)
                }

                Rectangle()
                    .fill(HarvestTheme.Colors.formBorder)
                    .frame(width: 1, height: 28)

                stepperButton(systemName: "plus", isEnabled: value < range.upperBound) {
                    value = min(range.upperBound, value + 1)
                }
            }
            .frame(width: controlWidth, height: controlHeight)
            .background {
                Capsule()
                    .fill(HarvestTheme.Colors.formSurfaceStrong)
            }
            .overlay {
                Capsule()
                    .stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
            }
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    private func stepperButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isEnabled ? HarvestTheme.Colors.textPrimary : HarvestTheme.Colors.textSecondary.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
