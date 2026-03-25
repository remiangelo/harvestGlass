import SwiftUI

struct ChipView: View {
    let title: String
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(title)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(HarvestTheme.Colors.redSurface)
                    } else {
                        Capsule()
                            .fill(HarvestTheme.Colors.glassFillStrong)
                            .overlay {
                                Capsule()
                                    .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
