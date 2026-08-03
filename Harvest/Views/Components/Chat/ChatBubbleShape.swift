import SwiftUI

/// A bubble outline that tightens the corners facing its neighbours, so a
/// run of messages reads as one column instead of a stack of separate pills.
struct ChatBubbleShape: Shape {
    let isMine: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool

    private let round: CGFloat = 20
    private let tight: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        // The "tail" side is the one nearest the sender: trailing for mine,
        // leading for theirs. Only that side tightens.
        let top = isFirstInGroup ? round : tight
        let bottom = isLastInGroup ? round : tight

        let radii = RectangleCornerRadii(
            topLeading: isMine ? round : top,
            bottomLeading: isMine ? round : bottom,
            bottomTrailing: isMine ? bottom : round,
            topTrailing: isMine ? top : round
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
            .path(in: rect)
    }
}
