import SwiftUI

struct MindfulWarningView: View {
    let analysis: MindfulMessagingService.MindfulAnalysis
    let onEdit: () -> Void
    let onSendAnyway: () -> Void

    private var severityColor: Color {
        switch analysis.severity {
        case .low: return Color(hex: "F7D9DD")
        case .medium: return Color(hex: "F3C5CC")
        case .high: return Color(hex: "EDB0BA")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Severity indicator
                    Circle()
                        .fill(severityColor)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "pause.fill")
                                .font(.title)
                                .foregroundStyle(HarvestTheme.Colors.primary)
                        }

                    Text("Mindful Messaging")
                        .font(HarvestTheme.Typography.h2)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text(analysis.reason)
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    // Growth lesson
                    if let lesson = analysis.growthLesson {
                        GlassCard(style: .light) {
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(HarvestTheme.Colors.accent)
                                    Text(lesson.title)
                                        .font(HarvestTheme.Typography.h4)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                }

                                Text(lesson.reflection)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: HarvestTheme.Spacing.md) {
                        GlassButton(title: "Edit Message", icon: "pencil", style: .primary) {
                            onEdit()
                        }

                        GlassButton(title: "Send Anyway", style: .secondary) {
                            onSendAnyway()
                        }
                    }
                }
                .padding()
            }
            .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
            .navigationTitle("Message Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
