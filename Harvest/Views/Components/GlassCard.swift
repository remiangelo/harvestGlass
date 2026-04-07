import SwiftUI

struct GlassCard<Content: View>: View {
    enum Style {
        case dark
        case light
    }

    let cornerRadius: CGFloat
    let padding: CGFloat
    let style: Style
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = HarvestTheme.Radius.xl,
        padding: CGFloat = HarvestTheme.Spacing.md,
        style: Style = .dark,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.style = style
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
    }

    private var backgroundColor: Color {
        switch style {
        case .dark:
            return HarvestTheme.Colors.glassFill
        case .light:
            return HarvestTheme.Colors.formSurface
        }
    }

    private var borderColor: Color {
        switch style {
        case .dark:
            return HarvestTheme.Colors.border
        case .light:
            return HarvestTheme.Colors.formBorder
        }
    }
}
