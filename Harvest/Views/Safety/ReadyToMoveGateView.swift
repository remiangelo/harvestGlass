import SwiftUI

struct ReadyToMoveGateView: View {
    let analysis: SafetyAnalysis
    let isReady: Bool
    let reason: String?

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.lg) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "hourglass")
                .font(.system(size: 50))
                .foregroundStyle(isReady ? HarvestTheme.Colors.accent : HarvestTheme.Colors.warning)

            Text(isReady ? "You're Clear to Share" : "Not Yet Ready")
                .font(HarvestTheme.Typography.h2)

            if let reason {
                Text(reason)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Progress checklist
            GlassCard {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    checklistItem(
                        "24 hours elapsed",
                        isComplete: analysis.firstMessageAt != nil
                    )

                    checklistItem(
                        "20+ messages exchanged",
                        isComplete: analysis.totalMessages >= 20
                    )

                    checklistItem(
                        "Safety score >= 70",
                        isComplete: analysis.safetyScore >= 70
                    )
                }
            }
            .padding(.horizontal)
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .padding()
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
    }

    private func checklistItem(_ text: String, isComplete: Bool) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? HarvestTheme.Colors.accent : HarvestTheme.Colors.textTertiary)

            Text(text)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(isComplete ? HarvestTheme.Colors.textPrimary : HarvestTheme.Colors.textSecondary)
        }
    }
}
