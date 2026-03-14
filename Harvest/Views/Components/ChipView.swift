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
                .foregroundStyle(isSelected ? .white : HarvestTheme.Colors.textPrimary)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, HarvestTheme.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(HarvestTheme.Colors.primary)
                    } else {
                        Capsule()
                            .fill(.thinMaterial)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
