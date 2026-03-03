import SwiftUI

enum HarvestTheme {
    // MARK: - Colors

    enum Colors {
        // Primary - Rose Pink Red
        static let primary = Color(hex: "EB1E66")
        static let primaryDark = Color(hex: "C91854")
        static let primaryLight = Color(hex: "F04D85")
        static let primarySoft = Color(hex: "EB1E66").opacity(0.15)

        // Accent - Bright Green
        static let accent = Color(hex: "27CF8A")
        static let accentLight = Color(hex: "4EDBA0")
        static let accentDark = Color(hex: "1FB076")
        static let accentSoft = Color(hex: "27CF8A").opacity(0.15)

        // Backgrounds
        static let background = Color.white
        static let surface = Color.white
        static let secondary = Color(hex: "F5E6D3")

        // Text
        static let textPrimary = Color.black
        static let textSecondary = Color(hex: "666666")
        static let textTertiary = Color(hex: "999999")
        static let textInverse = Color.white

        // Semantic
        static let error = Color(hex: "DC2626")
        static let success = Color(hex: "27CF8A")
        static let warning = Color(hex: "F59E0B")
        static let info = Color(hex: "3B82F6")

        // UI
        static let border = Color(hex: "E5E5E5")
        static let divider = Color(hex: "F0F0F0")

        // Swipe actions
        static let like = Color(hex: "27CF8A")
        static let nope = Color(hex: "DC2626")
        static let superLike = Color(hex: "EB1E66")

        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [Color(hex: "EB1E66"), Color(hex: "F04D85")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let overlayGradient = LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography

    enum Typography {
        static let displayFont = "Georgia"
        static let bodyFont = Font.Design.default

        static let h1 = Font.system(size: 28, weight: .bold, design: .serif)
        static let h2 = Font.system(size: 24, weight: .bold, design: .serif)
        static let h3 = Font.system(size: 20, weight: .bold, design: .serif)
        static let h4 = Font.system(size: 18, weight: .semibold, design: .serif)

        static let bodyLarge = Font.system(size: 18, weight: .regular)
        static let bodyRegular = Font.system(size: 16, weight: .regular)
        static let bodySmall = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)

        static let buttonText = Font.system(size: 16, weight: .semibold)
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
