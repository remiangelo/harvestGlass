import SwiftUI

/// App-wide Liquid Glass button style.
///
/// Every button routed through this style gets the native iOS 26 Liquid Glass
/// material (`.glassEffect(...interactive())`, which reacts to touch) plus a
/// spring "tap-and-hold" press: a slight scale-down so it's unmistakably a button.
///
/// Usage: `.buttonStyle(.harvestGlass(.primary))`
struct HarvestGlassButtonStyle: ButtonStyle {
    enum Kind: Equatable {
        case primary            // bold pink prominent glass — main CTAs
        case secondary          // neutral frosted glass — secondary actions
        case destructive        // red prominent glass
        case chip(selected: Bool)   // compact selectable chip
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(font)
            .fontWeight(fontWeight)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(glass.interactive(), in: Capsule())
            .overlay {
                if case .chip(false) = kind {
                    Capsule().stroke(HarvestTheme.Colors.rose.opacity(0.3), lineWidth: 1)
                }
            }
            .scaleEffect(pressed ? 0.96 : 1)
            .brightness(pressed ? -0.03 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: pressed)
    }

    // MARK: - Per-kind appearance

    private var glass: Glass {
        switch kind {
        case .primary:
            return .regular.tint(HarvestTheme.Colors.rose)
        case .destructive:
            return .regular.tint(HarvestTheme.Colors.error)
        case .secondary:
            return .regular
        case .chip(let selected):
            return selected ? .regular.tint(HarvestTheme.Colors.rose) : .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .destructive:
            return HarvestTheme.Colors.textOnRedPrimary
        case .secondary:
            return HarvestTheme.Colors.textPrimary
        case .chip(let selected):
            return selected ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary
        }
    }

    private var font: Font {
        switch kind {
        case .chip: return HarvestTheme.Typography.bodySmall
        default: return HarvestTheme.Typography.buttonText
        }
    }

    private var fontWeight: Font.Weight {
        switch kind {
        case .chip(let selected): return selected ? .semibold : .regular
        default: return .semibold
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .chip: return HarvestTheme.Spacing.md
        default: return HarvestTheme.Spacing.lg
        }
    }

    private var verticalPadding: CGFloat {
        switch kind {
        case .chip: return HarvestTheme.Spacing.sm
        default: return 14
        }
    }
}

extension ButtonStyle where Self == HarvestGlassButtonStyle {
    /// Liquid Glass button style with the app's tap-and-hold press feedback.
    static func harvestGlass(_ kind: HarvestGlassButtonStyle.Kind) -> HarvestGlassButtonStyle {
        HarvestGlassButtonStyle(kind: kind)
    }
}
