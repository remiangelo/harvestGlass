import SwiftUI

/// The chat background: the cream page warmed by two faint accent glows.
/// Deliberately static — no animation, so it costs nothing per frame.
struct ChatBackdrop: View {
    let accent: ChatAccent

    var body: some View {
        ZStack {
            HarvestTheme.Colors.background
            RadialGradient(
                colors: [accent.base.opacity(0.07), .clear],
                center: UnitPoint(x: 0.08, y: 0.04),
                startRadius: 0,
                endRadius: 340
            )
            RadialGradient(
                colors: [accent.deep.opacity(0.06), .clear],
                center: UnitPoint(x: 0.96, y: 0.88),
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}
