import SwiftUI

struct DailyQuizPopup: View {
    let quiz: DailyQuiz
    let onAnswer: (String) -> Void

    @State private var selectedOption: String?
    @State private var isSubmitted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Category badge
                    GlassBadge(text: quiz.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                               color: HarvestTheme.Colors.accent)

                    Text("Daily Reflection")
                        .font(HarvestTheme.Typography.h2)

                    Text(quiz.question)
                        .font(HarvestTheme.Typography.bodyLarge)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Options
                    VStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(quiz.options, id: \.self) { option in
                            Button {
                                if !isSubmitted {
                                    selectedOption = option
                                }
                            } label: {
                                GlassCard(padding: HarvestTheme.Spacing.md) {
                                    HStack {
                                        Text(option)
                                            .font(HarvestTheme.Typography.bodyRegular)
                                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()

                                        if selectedOption == option {
                                            Image(systemName: isSubmitted ? "checkmark.circle.fill" : "circle.fill")
                                                .foregroundStyle(HarvestTheme.Colors.primary)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(HarvestTheme.Colors.textTertiary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Insight after submission
                    if isSubmitted, let insight = quiz.insight ?? quiz.selectedAnswer.map({ _ in "Great reflection! Self-awareness is key to meaningful connections." }) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(HarvestTheme.Colors.warning)
                                    Text("Insight")
                                        .font(HarvestTheme.Typography.h4)
                                }

                                Text(insight)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Submit / Close
                    if !isSubmitted {
                        GlassButton(title: "Submit", icon: "checkmark", style: .primary) {
                            guard let answer = selectedOption else { return }
                            onAnswer(answer)
                            isSubmitted = true
                        }
                        .disabled(selectedOption == nil)
                        .padding(.horizontal)
                    } else {
                        GlassButton(title: "Close", style: .secondary) {
                            dismiss()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
