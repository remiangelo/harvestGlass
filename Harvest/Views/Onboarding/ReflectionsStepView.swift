import SwiftUI

struct ReflectionsStepView: View {
    let viewModel: OnboardingViewModel

    private var currentQuestion: Question? {
        guard viewModel.currentReflectionIndex < viewModel.allQuestions.count else { return nil }
        return viewModel.allQuestions[viewModel.currentReflectionIndex]
    }

    private var selectedOptionId: String? {
        guard let q = currentQuestion else { return nil }
        return viewModel.reflectionAnswers[q.id]
    }

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            header

            if viewModel.isLoadingQuestions {
                Spacer()
                ProgressView().tint(HarvestTheme.Colors.primary)
                Spacer()
            } else if let q = currentQuestion {
                questionCard(q)
                Spacer()
                footer
            } else {
                Text("No questions available.")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, HarvestTheme.Spacing.lg)
        .padding(.bottom, HarvestTheme.Spacing.lg)
        .task {
            await viewModel.loadQuestionsIfNeeded()
        }
    }

    private var header: some View {
        VStack(spacing: HarvestTheme.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.primary)
            Text("A few reflections")
                .font(HarvestTheme.Typography.h2)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            if !viewModel.allQuestions.isEmpty {
                Text("Question \(viewModel.currentReflectionIndex + 1) of \(viewModel.allQuestions.count)")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
        .padding(.top, HarvestTheme.Spacing.md)
    }

    private func questionCard(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text(q.prompt)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .padding(.bottom, HarvestTheme.Spacing.xs)

                VStack(spacing: HarvestTheme.Spacing.sm) {
                    ForEach(q.options) { option in
                        optionRow(option: option, isSelected: selectedOptionId == option.id)
                    }
                }
            }
        }
    }

    private func optionRow(option: QuestionOption, isSelected: Bool) -> some View {
        Button {
            viewModel.reflectionAnswers[option.questionId] = option.id
        } label: {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textSecondary)
                Text(option.label)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(HarvestTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                    .fill(isSelected
                          ? HarvestTheme.Colors.primary.opacity(0.15)
                          : HarvestTheme.Colors.formBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                            .stroke(
                                isSelected ? HarvestTheme.Colors.primary : HarvestTheme.Colors.divider,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: HarvestTheme.Spacing.md) {
            if viewModel.currentReflectionIndex > 0 {
                GlassButton(title: "Back", icon: "chevron.left", style: .primary) {
                    withAnimation { viewModel.currentReflectionIndex -= 1 }
                }
            }

            GlassButton(title: "Continue", icon: "chevron.right", style: .primary) {
                let isLast = viewModel.currentReflectionIndex >= viewModel.allQuestions.count - 1
                withAnimation {
                    if isLast {
                        viewModel.nextStep()
                    } else {
                        viewModel.currentReflectionIndex += 1
                    }
                }
            }
            .disabled(selectedOptionId == nil)
            .opacity(selectedOptionId == nil ? 0.5 : 1)
        }
    }
}
