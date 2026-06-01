import SwiftUI
import UIKit

struct ValueChipGrid: View {
    let values: [Value]
    let selectedIds: Set<String>
    let maxSelection: Int
    let onToggle: (Value) -> Void

    @State private var shakingId: String?

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: HarvestTheme.Spacing.sm)
    ]

    var body: some View {
        GlassEffectContainer(spacing: HarvestTheme.Spacing.sm) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                ForEach(values) { value in
                    ChipView(
                        title: value.name,
                        isSelected: selectedIds.contains(value.id)
                    ) {
                        handleTap(value)
                    }
                    .modifier(ShakeEffect(animatableData: shakingId == value.id ? 1 : 0))
                }
            }
        }
    }

    private func handleTap(_ value: Value) {
        let isSelected = selectedIds.contains(value.id)
        if !isSelected && selectedIds.count >= maxSelection {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.linear(duration: 0.35)) {
                shakingId = value.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shakingId = nil
            }
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onToggle(value)
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amount: CGFloat = 6
        let translation = amount * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
