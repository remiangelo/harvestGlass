import SwiftUI

struct GoalsStepView: View {
    let viewModel: OnboardingViewModel

    private let goals = [
        "Dating",
        "Relationship",
        "Long-term Commitment",
        "Marriage"
    ]

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("What are you looking for?")
                .font(HarvestTheme.Typography.h2)

            Text("Select all that apply")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: HarvestTheme.Spacing.sm) {
                ForEach(goals, id: \.self) { goal in
                    let isSelected = viewModel.selectedGoals.contains(goal)

                    Button {
                        if viewModel.selectedGoals.contains(goal) {
                            viewModel.selectedGoals.remove(goal)
                        } else {
                            viewModel.selectedGoals.insert(goal)
                        }
                    } label: {
                        Text(goal)
                            .font(HarvestTheme.Typography.bodySmall)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                            .padding(.horizontal, HarvestTheme.Spacing.md)
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                            .background {
                                Capsule()
                                    .fill(isSelected ? HarvestTheme.Colors.redSurface : Color(.secondarySystemBackground))
                                    .overlay {
                                        Capsule()
                                            .stroke(Color(.separator), lineWidth: 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            Spacer()
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
