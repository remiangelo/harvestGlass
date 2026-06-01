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

    private var glassKind: HarvestGlassButtonStyle.Kind {
        switch style {
        case .primary: return .primary
        case .secondary: return .secondary
        case .destructive: return .destructive
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.harvestGlass(glassKind))
    }
}
