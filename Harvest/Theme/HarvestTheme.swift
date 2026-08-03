import SwiftUI

enum HarvestTheme {
    // MARK: - Colors

    enum Colors {
        // MARK: Core Brand Palette
        // Warm light direction: a blush-cream page with a strong red accent.
        //
        // The token NAMES below are historical — they date from the dark
        // wine/plum theme and are referenced by ~300 call sites, so they were
        // kept and re-valued rather than renamed. Read "wine*" as "surface,
        // deepest to most lifted"; they are light tints now, not darks.
        static let wineBlack = Color(hex: "E6C6B6")   // nav / tab bars — deepest tint
        static let deepPlum = Color(hex: "F0D5C8")    // app background
        static let wineCard = Color(hex: "FFF9F5")    // card / glass surface
        static let wineRaised = Color(hex: "FFFFFF")  // elevated surface

        /// The one place a genuine dark is still needed: a scrim over
        /// user photography so white text stays legible on top of it.
        /// Do not use it as a surface.
        static let photoScrim = Color(hex: "2A1714")

        // Reds (brand accent family)
        static let rose = Color(hex: "DB2637")        // primary red
        static let roseLight = Color(hex: "EE6A72")   // lighter tint / 2nd series
        static let roseDeep = Color(hex: "A81C2B")    // gradient end (deeper)
        static let roseBloom = Color(hex: "C94F58")   // softer red (labels)
        static let amber = Color(hex: "D97A28")       // warm amber — 2nd radar series ("Them")

        // Field greens — The Field / community rooms accent.
        // Used ONLY inside Field views; the rest of the app stays red.
        // Deepened from the old mint so they hold contrast against cream.
        static let fieldGreen = Color(hex: "2E7D5B")
        /// Despite the name this is the DARKER green: it is used as a
        /// foreground (labels, metadata), which now sits on light surfaces.
        static let fieldGreenLight = Color(hex: "246B4C")
        static let fieldGreenDeep = Color(hex: "1E5A40")   // gradient end for Field bubbles
        static let fieldGreenBorder = fieldGreen.opacity(0.28)
        static let fieldGreenSoft = fieldGreen.opacity(0.12)

        // Legacy brand tokens — kept defined so older views compile,
        // but no longer the semantic accent/text.
        static let iconRed = Color(hex: "B81D2A")
        static let appleRed = Color(hex: "BE3A34")
        static let heartGlow = rose
        static let harvestGold = Color(hex: "C07A3C")
        static let harvestCream = Color(hex: "F0D5C8")
        static let pureWhite = Color(hex: "FFFFFF")
        static let black = Color(hex: "000000")

        // MARK: Existing Tokens (kept for compatibility)
        // Primary
        static let primary = rose
        static let primaryDark = roseDeep
        static let primaryLight = roseLight
        static let primarySoft = rose.opacity(0.10)
        static let blackSurface = wineBlack
        static let redSurface = rose
        static let outgoingMessageSurface = rose

        // Accent
        // Deeper than `roseLight` because accent is used as a FOREGROUND
        // (icons, links) and needs to hold up against the cream page.
        static let accent = Color(hex: "C41F2E")
        static let accentLight = Color(hex: "E8555F")
        static let accentDark = Color(hex: "8E1622")
        static let accentSoft = rose.opacity(0.10)

        // Backgrounds
        // Kept token names the same so old views still compile.
        static let background = deepPlum
        static let surface = wineCard
        static let secondary = harvestCream
        static let creamSurface = harvestCream

        // Text
        // Flipped to warm darks — the page is light now.
        static let textPrimary = Color(hex: "2B1A16")     // deep warm brown-black
        static let textSecondary = Color(hex: "6E524A")   // muted warm brown
        static let textTertiary = Color(hex: "8A6E66")
        static let textInverse = pureWhite
        static let textOnCream = Color(hex: "2B1A16")
        static let textOnRedPrimary = pureWhite           // white on red buttons
        static let textOnRedAccent = pureWhite
        /// Historical name: the surfaces it sits on are light now, so it is dark.
        static let textOnBlack = Color(hex: "2B1A16")
        static let textOnWhitePrimary = Color(hex: "2B1A16")
        static let textOnWhiteSecondary = Color(hex: "2B1A16").opacity(0.75)
        static let textOnWhiteTertiary = Color(hex: "2B1A16").opacity(0.55)
        static let whiteFormSurface = Color.white
        static let whiteFormBorder = Color(hex: "2B1A16").opacity(0.12)

        // Semantic
        static let error = Color(hex: "C62828")
        static let success = rose
        static let warning = Color(hex: "C77700")
        static let info = accent

        // UI
        static let border = Color(hex: "2B1A16").opacity(0.12)   // warm hairline
        static let divider = Color(hex: "2B1A16").opacity(0.10)
        static let glassFill = wineCard
        static let glassFillStrong = wineRaised
        static let fieldFill = wineCard
        static let blackFill = black

        // Swipe actions
        static let like = rose
        static let nope = iconRed
        static let superLike = accent

        // Gradients
        // Keep the old names so dependent views still work.
        static let primaryGradient = LinearGradient(
            colors: [rose, roseDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Sits over photography, so it stays genuinely dark.
        static let overlayGradient = LinearGradient(
            colors: [.clear, photoScrim.opacity(0.65)],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: Extra Brand Gradients
        static let splashGradient = LinearGradient(
            colors: [
                harvestCream,
                roseLight,
                rose,
                roseDeep
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
            colors: [rose.opacity(0.55), rose.opacity(0.12), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 120
        )

        // Helpful utility surfaces for future screens
        static let cardBackground = surface
        static let elevatedSurface = wineRaised

        // Form surfaces
        static let formBackground = Color(hex: "FFF4EE")
        static let formSurface = Color(hex: "FFFFFF")
        static let formSurfaceStrong = Color(hex: "F7E7DE")
        static let formBorder = Color(hex: "2B1A16").opacity(0.12)
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
