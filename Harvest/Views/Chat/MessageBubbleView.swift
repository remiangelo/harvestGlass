import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isSent: Bool

    var body: some View {
        HStack {
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.content ?? "")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(isSent ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background {
                        if isSent {
                            BubbleShape(isSent: true)
                                .fill(HarvestTheme.Colors.outgoingMessageSurface)
                        } else {
                            BubbleShape(isSent: false)
                                .fill(HarvestTheme.Colors.glassFill)
                                .overlay {
                                    BubbleShape(isSent: false)
                                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                                }
                        }
                    }

                HStack(spacing: 4) {
                    if let time = message.createdAt {
                        Text(formatMessageTime(time))
                            .font(.system(size: 10))
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }

                    if isSent {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(message.isRead ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }

    private func formatMessageTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

struct BubbleShape: Shape, InsettableShape {
    let isSent: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isSent {
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail on right
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - radius))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - tailSize - 8, y: rect.maxY))
        } else {
            path.addRoundedRect(
                in: CGRect(x: rect.minX + tailSize, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail on left
            path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + tailSize + 8, y: rect.maxY))
        }

        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        self
    }
}
