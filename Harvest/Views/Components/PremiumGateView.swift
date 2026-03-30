import SwiftUI

struct PremiumGateView: View {
    let featureName: String
    let requiredTier: String
    let authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .fill(HarvestTheme.Colors.blackSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }

            VStack(spacing: HarvestTheme.Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(HarvestTheme.Colors.primary)

                Text(featureName)
                    .font(HarvestTheme.Typography.h4)
                    .multilineTextAlignment(.center)

                Text("Unlock with \(requiredTier)")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)

                NavigationLink {
                    SubscriptionView(authViewModel: authViewModel)
                } label: {
                    HStack(spacing: HarvestTheme.Spacing.xs) {
                        Image(systemName: "crown.fill")
                        Text("Upgrade")
                    }
                    .font(HarvestTheme.Typography.buttonText)
                    .foregroundStyle(HarvestTheme.Colors.textOnRedPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background(HarvestTheme.Colors.redSurface)
                    .clipShape(Capsule())
                }
            }
            .padding()
        }
    }
}
