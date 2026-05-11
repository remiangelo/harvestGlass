import SwiftUI

struct DifferentiationView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            HarvestTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: HarvestTheme.Spacing.xl) {
                Spacer()

                VStack(spacing: HarvestTheme.Spacing.sm) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(HarvestTheme.Colors.accent)

                    Text("Dating, done differently")
                        .font(HarvestTheme.Typography.h1)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Three things you won't find on other apps")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, HarvestTheme.Spacing.lg)

                VStack(spacing: HarvestTheme.Spacing.md) {
                    differentiator(
                        icon: "sparkles",
                        title: "AI Coach",
                        body: "The Gardener helps you reflect, communicate better, and grow."
                    )
                    differentiator(
                        icon: "heart.text.square.fill",
                        title: "Values Matching",
                        body: "Connect with people whose values line up with yours — not just their photos."
                    )
                    differentiator(
                        icon: "exclamationmark.shield.fill",
                        title: "Red-Flag Detection",
                        body: "Safety analysis flags manipulative or unsafe behaviour in your chats."
                    )
                }
                .padding(.horizontal, HarvestTheme.Spacing.lg)

                Spacer()

                GlassButton(title: "Meet your Gardener", icon: "leaf.fill", style: .primary, action: onDismiss)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.bottom, HarvestTheme.Spacing.xl)
            }
        }
    }

    private func differentiator(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(HarvestTheme.Colors.accent)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                Text(body)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(HarvestTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                .fill(HarvestTheme.Colors.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        }
    }
}
