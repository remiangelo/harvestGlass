import SwiftUI

struct ChipView: View {
    let title: String
    var isSelected: Bool = false
    var lightStyle: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        if lightStyle {
            lightChip
        } else {
            Button {
                onTap?()
            } label: {
                Text(title)
            }
            .buttonStyle(.harvestGlass(.chip(selected: isSelected)))
        }
    }

    // Light chips live on cream/white form surfaces, so they keep the
    // solid-capsule treatment for contrast rather than translucent glass.
    private var lightChip: some View {
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
                        Capsule().fill(HarvestTheme.Colors.formAccent)
                    } else {
                        Capsule()
                            .fill(HarvestTheme.Colors.formSurface)
                            .overlay {
                                Capsule().stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
