import SwiftUI

/// The three tints one chat surface needs. Field rooms are green, Seed
/// conversations are red; everything else about the two is identical, so
/// components take one of these rather than three loose colors.
struct ChatAccent {
    let base: Color     // outgoing bubble fill, send button
    let deep: Color     // outgoing gradient end
    let light: Color    // quotes, mentions, metadata

    static let rose = ChatAccent(
        base: HarvestTheme.Colors.rose,
        deep: HarvestTheme.Colors.roseDeep,
        light: HarvestTheme.Colors.accent
    )

    static let field = ChatAccent(
        base: HarvestTheme.Colors.fieldGreen,
        deep: HarvestTheme.Colors.fieldGreenDeep,
        light: HarvestTheme.Colors.fieldGreenLight
    )
}
