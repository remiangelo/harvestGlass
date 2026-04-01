import SwiftUI

struct ReadyToMoveGateView: View {
    let analysis: SafetyAnalysis
    let isReady: Bool
    let reason: String?
    var onSharePreferredContact: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.lg) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "hourglass")
                .font(.system(size: 50))
                .foregroundStyle(isReady ? HarvestTheme.Colors.accent : HarvestTheme.Colors.warning)

            Text(isReady ? "You're Clear to Share" : "Not Yet Ready")
                .font(HarvestTheme.Typography.h2)
                .foregroundStyle(.primary)

            if let reason {
                Text(reason)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress checklist
            GlassCard(style: .light) {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    checklistItem(
                        "24 hours elapsed",
                        isComplete: analysis.has24HourHistory
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

            if isReady {
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    Text("You can now choose to share contact details outside the app.")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if onSharePreferredContact != nil {
                        Button {
                            onSharePreferredContact?()
                        } label: {
                            Text("Share Preferred Contact")
                                .font(HarvestTheme.Typography.buttonText)
                                .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                                .background {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .fill(HarvestTheme.Colors.blackSurface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                                .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                                        }
                                }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .foregroundStyle(.primary)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func checklistItem(_ text: String, isComplete: Bool) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? AnyShapeStyle(HarvestTheme.Colors.accent) : AnyShapeStyle(Color.secondary))

            Text(text)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(isComplete ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
    }
}
