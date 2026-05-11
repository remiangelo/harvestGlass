import SwiftUI

struct SafetyStatusBadge: View {
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: HarvestTheme.Spacing.xs) {
            Image(systemName: level.icon)
                .font(.system(size: 12, weight: .semibold))
            Text("Chat: \(level.displayName)")
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, HarvestTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(level.color)
        }
        .accessibilityLabel("Chat safety status: \(level.displayName)")
    }
}
