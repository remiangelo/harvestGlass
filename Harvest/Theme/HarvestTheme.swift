import SwiftUI

enum HarvestTheme {
    // MARK: - Colors

    enum Colors {
        // MARK: Core Brand Palette
        // Brand guide palette
        static let deepPlum = Color(hex: "#3A1020")
        static let iconRed = Color(hex: "CB0419")
        static let appleRed = Color(hex: "C9413B")
        static let heartGlow = Color(hex: "DB2637")
        static let harvestGold = Color(hex: "D18A4A")
        static let harvestCream = Color(hex: "F0D5C8")
        static let black = Color(hex: "000000")

        // MARK: Existing Tokens (kept for compatibility)
        // Primary
        static let primary = iconRed
        static let primaryDark = deepPlum
        static let primaryLight = appleRed
        static let primarySoft = iconRed.opacity(0.15)

        // Accent
        static let accent = harvestGold
        static let accentLight = harvestGold.opacity(0.75)
        static let accentDark = Color(hex: "B06D35")
        static let accentSoft = harvestGold.opacity(0.15)

        // Backgrounds
        // Kept token names the same so old views still compile.
        // These values now reflect the dark-first brand direction.
        static let background = deepPlum
        static let surface = Color(hex: "4A1B18")
        static let secondary = harvestCream

        // Text
        static let textPrimary = harvestCream
        static let textSecondary = harvestCream.opacity(0.88)
        static let textTertiary = harvestCream.opacity(0.72)
        static let textInverse = black

        // Semantic
        static let error = Color(hex: "DC2626")
        static let success = harvestGold
        static let warning = Color(hex: "F59E0B")
        static let info = appleRed

        // UI
        static let border = harvestCream.opacity(0.18)
        static let divider = harvestCream.opacity(0.10)
        static let glassFill = deepPlum.opacity(0.72)
        static let glassFillStrong = deepPlum.opacity(0.86)

        // Swipe actions
        static let like = harvestGold
        static let nope = iconRed
        static let superLike = heartGlow

        // Gradients
        // Keep the old names so dependent views still work.
        static let primaryGradient = LinearGradient(
            colors: [iconRed, appleRed],
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
                Color(hex: "7B1E2B"),
                heartGlow,
                appleRed,
                harvestGold.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let iconGradient = LinearGradient(
            colors: [iconRed, appleRed],
            startPoint: .top,
            endPoint: .bottom
        )

        static let glowGradient = RadialGradient(
            colors: [heartGlow.opacity(0.9), heartGlow.opacity(0.18), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 120
        )

        // Helpful utility surfaces for future screens
        static let cardBackground = surface
        static let elevatedSurface = Color(hex: "5A221D")
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
