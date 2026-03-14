import SwiftUI

struct SafetyWarningView: View {
    let safetyLevel: SafetyLevel
    let message: String
    var onViewDetails: (() -> Void)?

    var body: some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: safetyLevel.icon)
                .foregroundStyle(safetyLevel.color)

            Text(message)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)

            Spacer()

            if let onViewDetails {
                Button("Details") {
                    onViewDetails()
                }
                .font(HarvestTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.primary)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.md)
        .padding(.vertical, HarvestTheme.Spacing.sm)
        .background(safetyLevel.color.opacity(0.1))
    }
}
