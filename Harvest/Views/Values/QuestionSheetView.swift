import SwiftUI

struct QuestionSheetView: View {
    let authViewModel: AuthViewModel
    let viewModel: ValuesViewModel

    @Environment(\.dismiss) private var dismiss

    private var queue: [Question] { viewModel.unansweredQuestionsForActiveSide }
    private var current: Question? { queue.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: HarvestTheme.Spacing.md) {
                if let q = current {
                    questionView(q)
                } else {
                    emptyView
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)
            .padding(.vertical, HarvestTheme.Spacing.lg)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(viewModel.side == .need ? "More about what you need" : "More about what you bring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }
            }
        }
    }

    private func questionView(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text(q.prompt)
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                ForEach(q.options) { option in
                    Button {
                        guard let userId = authViewModel.currentUserId else { return }
                        Task {
                            await viewModel.saveAnswer(
                                userId: userId,
                                questionId: q.id,
                                optionId: option.id
                            )
                        }
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: "circle")
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
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
                                .fill(HarvestTheme.Colors.formBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(HarvestTheme.Colors.divider, lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text("You've answered everything for now.")
                .font(HarvestTheme.Typography.h4)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("New questions will appear here as they're added.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(HarvestTheme.Typography.buttonText)
                    .foregroundStyle(HarvestTheme.Colors.textOnCream)
                    .padding(.horizontal, HarvestTheme.Spacing.lg)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
