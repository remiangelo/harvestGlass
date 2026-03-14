import SwiftUI

struct PremiumGateView: View {
    let featureName: String
    let requiredTier: String
    let authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: HarvestTheme.Radius.lg))

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
                    .foregroundStyle(.white)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background {
                        Capsule().fill(HarvestTheme.Colors.primary)
                    }
                }
            }
            .padding()
        }
    }
}
