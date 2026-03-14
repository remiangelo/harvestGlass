import SwiftUI

struct GlassBadge: View {
    let text: String
    var color: Color = HarvestTheme.Colors.primary

    var body: some View {
        Text(text)
            .font(HarvestTheme.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, HarvestTheme.Spacing.sm)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(.thinMaterial)
                    .glassEffect(.regular, in: .capsule)
            }
    }
}
