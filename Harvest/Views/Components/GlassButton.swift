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
        case .primary: return .white
        case .secondary: return HarvestTheme.Colors.textPrimary
        case .destructive: return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return HarvestTheme.Colors.primary
        case .secondary: return .clear
        case .destructive: return HarvestTheme.Colors.error
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
                if style == .secondary {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .fill(.ultraThinMaterial)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: HarvestTheme.Radius.md))
                } else {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .fill(backgroundColor)
                }
            }
        }
    }
}
