import SwiftUI

enum HarvestTheme {
    // MARK: - Colors

    enum Colors {
        // MARK: Core Brand Palette
        // Pink / wine-black direction.
        // Wines (dark surfaces, from deepest to most lifted)
        static let wineBlack = Color(hex: "150A0F")   // nav bar / deepest base
        static let deepPlum = Color(hex: "1A0C12")    // app background
        static let wineCard = Color(hex: "271019")    // card / glass surface
        static let wineRaised = Color(hex: "331622")  // elevated surface

        // Hot pinks (brand accent family)
        static let rose = Color(hex: "FB2E63")        // primary hot pink
        static let roseLight = Color(hex: "FF5C8A")   // lighter accent / 2nd series
        static let roseDeep = Color(hex: "E01248")    // gradient end (redder)
        static let roseBloom = Color(hex: "F0466E")   // softer pink (labels)
        static let amber = Color(hex: "F5872E")       // warm orange — 2nd radar series ("Them")

        // Legacy brand tokens — kept defined so older views compile,
        // but no longer the semantic accent/text.
        static let iconRed = Color(hex: "CB0419")
        static let appleRed = Color(hex: "C9413B")
        static let heartGlow = rose
        static let harvestGold = Color(hex: "D18A4A")
        static let harvestCream = Color(hex: "F0D5C8")
        static let pureWhite = Color(hex: "FFFFFF")
        static let black = Color(hex: "000000")

        // MARK: Existing Tokens (kept for compatibility)
        // Primary
        static let primary = rose
        static let primaryDark = roseDeep
        static let primaryLight = roseLight
        static let primarySoft = rose.opacity(0.15)
        static let blackSurface = wineBlack
        static let redSurface = rose
        static let outgoingMessageSurface = roseDeep

        // Accent
        static let accent = roseLight
        static let accentLight = Color(hex: "FF85A7")
        static let accentDark = Color(hex: "E0245A")
        static let accentSoft = roseLight.opacity(0.15)

        // Backgrounds
        // Kept token names the same so old views still compile.
        static let background = deepPlum
        static let surface = wineCard
        static let secondary = harvestCream
        static let creamSurface = harvestCream

        // Text
        static let textPrimary = Color(hex: "FBF6F8")     // near-white
        static let textSecondary = Color(hex: "C9A9B4")   // muted rose-gray
        static let textTertiary = Color(hex: "94787F")
        static let textInverse = black
        static let textOnCream = deepPlum
        static let textOnRedPrimary = pureWhite           // white on pink buttons
        static let textOnRedAccent = pureWhite
        static let textOnBlack = roseLight
        static let textOnWhitePrimary = deepPlum
        static let textOnWhiteSecondary = deepPlum.opacity(0.78)
        static let textOnWhiteTertiary = deepPlum.opacity(0.58)
        static let whiteFormSurface = Color.white
        static let whiteFormBorder = deepPlum.opacity(0.12)

        // Semantic
        static let error = Color(hex: "FF4D4F")
        static let success = rose
        static let warning = Color(hex: "F5A623")
        static let info = primaryLight

        // UI
        static let border = rose.opacity(0.14)            // faint pink hairline
        static let divider = pureWhite.opacity(0.08)
        static let glassFill = wineCard
        static let glassFillStrong = wineRaised
        static let fieldFill = wineCard
        static let blackFill = black

        // Swipe actions
        static let like = rose
        static let nope = iconRed
        static let superLike = roseLight

        // Gradients
        // Keep the old names so dependent views still work.
        static let primaryGradient = LinearGradient(
            colors: [rose, roseDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let overlayGradient = LinearGradient(
            colors: [.clear, black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: Extra Brand Gradients
        static let splashGradient = LinearGradient(
            colors: [
                Color(hex: "2A0F1A"),
                roseDeep,
                rose,
                roseLight
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let iconGradient = LinearGradient(
            colors: [rose, roseDeep],
            startPoint: .top,
            endPoint: .bottom
        )

        static let glowGradient = RadialGradient(
            colors: [rose.opacity(0.9), rose.opacity(0.18), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 120
        )

        // Helpful utility surfaces for future screens
        static let cardBackground = surface
        static let elevatedSurface = wineRaised

        // Form surfaces
        static let formBackground = Color(hex: "2A0F1A")
        static let formSurface = Color(hex: "3A1825")
        static let formSurfaceStrong = Color(hex: "46202F")
        static let formBorder = pureWhite.opacity(0.14)
        static let formAccent = rose
        static let tabBarBackground = wineBlack
        static let tabBarSelectedBackground = rose
        static let tabBarText = textPrimary
    }

    // MARK: - Typography

    enum Typography {
        // Keep old names for compatibility
        static let displayFont = "Orange Squash"
        static let bodyFont = Font.Design.default

        // Add explicit font-name tokens for future use
        static let displayFontName = "Orange Squash"
        static let headingFontName = "DM Serif Display"
        static let bodyFontName = "SF Pro Display" // or "DM Sans" if bundled

        // Existing token names preserved
        // Uses system fallbacks so nothing breaks if custom fonts are not yet installed.
        static let h1 = Font.system(size: 28, weight: .bold, design: .serif)
        static let h2 = Font.system(size: 24, weight: .bold, design: .serif)
        static let h3 = Font.system(size: 20, weight: .bold, design: .default)
        static let h4 = Font.system(size: 18, weight: .semibold, design: .default)

        static let bodyLarge = Font.system(size: 18, weight: .regular)
        static let bodyRegular = Font.system(size: 16, weight: .regular)
        static let bodySmall = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)

        static let buttonText = Font.system(size: 16, weight: .semibold)

        // Future-ready optional brand styles
        static let display = Font.system(size: 48, weight: .regular, design: .serif)
        static let sectionTitle = Font.system(size: 36, weight: .bold, design: .serif)
        static let subsection = Font.system(size: 22, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 16, weight: .semibold, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Border Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Animation

    enum Animation {
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
