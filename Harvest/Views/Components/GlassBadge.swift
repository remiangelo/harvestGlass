import SwiftUI

struct GlassBadge: View {
    let text: String
    var color: Color = HarvestTheme.Colors.textOnBlack

    var body: some View {
        Text(text)
            .font(HarvestTheme.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(HarvestTheme.Colors.textOnBlack)
            .padding(.horizontal, HarvestTheme.Spacing.sm)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(HarvestTheme.Colors.blackSurface)
                    .overlay {
                        Capsule()
                            .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                    }
            }
    }
}
