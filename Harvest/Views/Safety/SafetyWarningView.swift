import SwiftUI

struct SafetyWarningView: View {
    let safetyLevel: SafetyLevel
    let message: String
    var onViewDetails: (() -> Void)?

    var body: some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: safetyLevel.icon)
                .foregroundStyle(HarvestTheme.Colors.accent)

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
                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                .padding(.horizontal, HarvestTheme.Spacing.sm)
                .padding(.vertical, HarvestTheme.Spacing.xs)
                .background(HarvestTheme.Colors.blackSurface)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.md)
        .padding(.vertical, HarvestTheme.Spacing.sm)
        .background(HarvestTheme.Colors.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .stroke(HarvestTheme.Colors.border, lineWidth: 1)
        }
    }
}
