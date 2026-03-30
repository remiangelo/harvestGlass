import SwiftUI

struct SafetyDashboardView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = SafetyDashboardViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.analyses.isEmpty {
                VStack(spacing: HarvestTheme.Spacing.md) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(HarvestTheme.Colors.accent)

                    Text("No Safety Data Yet")
                        .font(HarvestTheme.Typography.h3)

                    Text("Safety scores will appear as you chat with your matches.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HarvestTheme.Spacing.xxl)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.analyses) { analysis in
                    Button {
                        viewModel.selectedAnalysis = analysis
                        Task { await viewModel.loadRedFlags(analysisId: analysis.id) }
                    } label: {
                        HStack(spacing: HarvestTheme.Spacing.md) {
                            // Safety score circle
                            ZStack {
                                Circle()
                                    .stroke(analysis.safetyLevel.color.opacity(0.3), lineWidth: 4)
                                    .frame(width: 50, height: 50)

                                Circle()
                                    .trim(from: 0, to: CGFloat(analysis.safetyScore) / 100)
                                    .stroke(analysis.safetyLevel.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(.degrees(-90))

                                Text("\(analysis.safetyScore)")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .fontWeight(.bold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.profiles[analysis.otherUserId]?.displayName ?? "User")
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .fontWeight(.semibold)

                                HStack(spacing: 4) {
                                    Image(systemName: analysis.safetyLevel.icon)
                                        .font(.caption)
                                    Text(analysis.safetyLevel.displayName)
                                        .font(HarvestTheme.Typography.caption)
                                }
                                .foregroundStyle(analysis.safetyLevel.color)
                            }

                            Spacer()

                            if analysis.redFlagCount > 0 {
                                GlassBadge(
                                    text: "\(analysis.redFlagCount) flags",
                                    color: HarvestTheme.Colors.warning
                                )
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(HarvestTheme.Colors.textOnWhiteTertiary)
                        }
                    }
                    .foregroundStyle(HarvestTheme.Colors.textOnWhitePrimary)
                }
            }
        }
        .navigationTitle("Safety Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        if let userId = authViewModel.currentUserId {
                            await viewModel.runBulkRetroactiveAnalysis(userId: userId)
                        }
                    }
                } label: {
                    Text("Analyze")
                }
                .foregroundStyle(HarvestTheme.Colors.primary)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Analyze all conversations")
            }
        }
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.loadDashboard(userId: userId)
            }
        }
        .sheet(item: $viewModel.selectedAnalysis) { analysis in
            SafetyDetailSheet(analysis: analysis, redFlags: viewModel.redFlags)
        }
    }
}

private struct SafetyDetailSheet: View {
    let analysis: SafetyAnalysis
    let redFlags: [RedFlagReport]
    @Environment(\.dismiss) private var dismiss

    private var fallbackFlags: [SafetyFlagSnapshot] {
        analysis.redFlags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Score display
                    ZStack {
                        Circle()
                            .stroke(analysis.safetyLevel.color.opacity(0.3), lineWidth: 8)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: CGFloat(analysis.safetyScore) / 100)
                            .stroke(analysis.safetyLevel.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack {
                            Text("\(analysis.safetyScore)")
                                .font(HarvestTheme.Typography.h1)
                                .fontWeight(.bold)
                            Text(analysis.safetyLevel.displayName)
                                .font(HarvestTheme.Typography.caption)
                                .foregroundStyle(analysis.safetyLevel.color)
                        }
                    }

                    // Stats
                    GlassCard {
                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            statRow("Total Messages", value: "\(analysis.totalMessages)")
                            statRow("Red Flags", value: "\(analysis.redFlagCount)")
                        }
                    }
                    .padding(.horizontal)

                    // Red flags
                    if !redFlags.isEmpty || !fallbackFlags.isEmpty {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                            Text("Red Flags")
                                .font(HarvestTheme.Typography.h3)
                                .padding(.horizontal)

                            if !redFlags.isEmpty {
                                ForEach(redFlags) { flag in
                                    flagRow(
                                        title: flag.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                                        detail: flag.detail
                                    )
                                }
                            } else {
                                ForEach(fallbackFlags) { flag in
                                    flagRow(
                                        title: flag.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                                        detail: flag.evidence
                                    )
                                }
                            }
                        }
                    }

                    // Recommendations
                    GlassCard {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                            Text("Recommendations")
                                .font(HarvestTheme.Typography.h4)

                            if analysis.safetyScore >= 80 {
                                Text("This conversation appears safe. Continue enjoying your connection!")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
                            } else if analysis.safetyScore >= 50 {
                                Text("Some concerns have been noted. Stay mindful and report anything that makes you uncomfortable.")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
                            } else {
                                Text("Multiple concerns detected. Consider reporting or blocking this user if you feel unsafe.")
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.error)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Safety Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
            Spacer()
            Text(value)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
        }
    }

    private func flagRow(title: String, detail: String) -> some View {
        GlassCard {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(HarvestTheme.Colors.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HarvestTheme.Typography.bodySmall)
                        .fontWeight(.semibold)
                    Text(detail)
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
