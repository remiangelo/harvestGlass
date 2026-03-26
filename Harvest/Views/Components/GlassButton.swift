import SwiftUI

struct GlassButton: View {
    let title: String
    var icon: String?
    var style: ButtonStyle = .primary
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return HarvestTheme.Colors.textOnRedPrimary
        case .secondary: return HarvestTheme.Colors.textOnBlack
        case .destructive: return HarvestTheme.Colors.textOnRedAccent
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return HarvestTheme.Colors.redSurface
        case .secondary: return HarvestTheme.Colors.blackSurface
        case .destructive: return HarvestTheme.Colors.redSurface
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(HarvestTheme.Typography.buttonText)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                    .fill(backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                            .stroke(HarvestTheme.Colors.border, lineWidth: style == .secondary ? 1 : 0)
                    }
            }
        }
    }
}
