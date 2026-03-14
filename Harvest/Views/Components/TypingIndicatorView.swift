import SwiftUI

struct TypingIndicatorView: View {
    @State private var dotOffset: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(HarvestTheme.Colors.textTertiary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffset[index])
                }
            }
            .padding(.horizontal, HarvestTheme.Spacing.md)
            .padding(.vertical, HarvestTheme.Spacing.sm + 4)
            .background {
                BubbleShape(isSent: false)
                    .fill(.thinMaterial)
                    .glassEffect(.regular, in: BubbleShape(isSent: false))
            }

            Spacer(minLength: 60)
        }
        .onAppear {
            for index in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
                ) {
                    dotOffset[index] = -6
                }
            }
        }
    }
}
