import SwiftUI

/// Fills a bubble: an accent gradient when it's yours, a lifted near-white
/// card when it isn't.
///
/// Deliberately not `.ultraThinMaterial`. On the cream page a light blur is
/// almost indistinguishable from the background, so incoming bubbles rely on
/// a solid surface, a hairline, and a soft shadow to separate instead.
struct ChatBubbleBackground: ViewModifier {
    let accent: ChatAccent
    let isMine: Bool
    let shape: ChatBubbleShape

    func body(content: Content) -> some View {
        content.background {
            if isMine {
                shape
                    .fill(
                        LinearGradient(
                            colors: [accent.base, accent.deep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay { shape.stroke(Color.white.opacity(0.16), lineWidth: 1) }
                    .shadow(color: accent.deep.opacity(0.22), radius: 6, y: 2)
            } else {
                shape
                    .fill(HarvestTheme.Colors.wineCard)
                    .overlay { shape.stroke(HarvestTheme.Colors.border, lineWidth: 1) }
                    .shadow(color: HarvestTheme.Colors.textPrimary.opacity(0.06), radius: 5, y: 2)
            }
        }
    }
}

extension View {
    func chatBubble(accent: ChatAccent, isMine: Bool, shape: ChatBubbleShape) -> some View {
        modifier(ChatBubbleBackground(accent: accent, isMine: isMine, shape: shape))
    }
}
