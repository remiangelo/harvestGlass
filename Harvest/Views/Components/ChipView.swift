import SwiftUI

struct ChipView: View {
    let title: String
    var isSelected: Bool = false
    var lightStyle: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(title)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(HarvestTheme.Colors.redSurface)
                    } else {
                        Capsule()
                            .fill(lightStyle ? HarvestTheme.Colors.formSurface : HarvestTheme.Colors.glassFillStrong)
                            .overlay {
                                Capsule()
                                    .stroke(lightStyle ? HarvestTheme.Colors.formBorder : HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected {
            return HarvestTheme.Colors.textOnRedPrimary
        }
        return lightStyle ? HarvestTheme.Colors.textPrimary : HarvestTheme.Colors.textPrimary
    }
}
