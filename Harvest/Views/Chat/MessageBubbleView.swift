import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isSent: Bool
    let position: MessagePosition
    var timeLabel: String = ""

    @State private var revealed = false
    private let mindful = MindfulMessagingService()

    /// Non-nil when an incoming message should be blurred for this recipient.
    /// Respects the recipient's own mindful-messaging toggle.
    private var flag: MindfulMessagingService.MindfulAnalysis? {
        guard !isSent, mindful.isEnabled else { return nil }
        return mindful.localFlag(for: message.content ?? "")
    }

    var body: some View {
        let isBlurred = flag != nil && !revealed
        let shape = ChatBubbleShape(
            isMine: isSent,
            isFirstInGroup: position.isFirstInGroup,
            isLastInGroup: position.isLastInGroup
        )

        HStack {
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.content ?? "")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(isSent ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .frame(minWidth: isBlurred ? 150 : nil, minHeight: isBlurred ? 44 : nil, alignment: .leading)
                    .blur(radius: isBlurred ? 7 : 0)
                    .chatBubble(accent: .rose, isMine: isSent, shape: shape)
                    .overlay {
                        if isBlurred {
                            blurOverlay
                        }
                    }
                    .contentShape(shape)
                    .onTapGesture {
                        if isBlurred { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }

                // Metadata once per run, not once per bubble.
                if !timeLabel.isEmpty {
                    HStack(spacing: 4) {
                        Text(timeLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)

                        if isSent {
                            Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(message.isRead ? HarvestTheme.Colors.primary : HarvestTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }

    private var blurOverlay: some View {
        VStack(spacing: 2) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
            Text(hint)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Tap to reveal")
                .font(.system(size: 10))
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .padding(.horizontal, HarvestTheme.Spacing.sm)
    }

    /// Recipient-facing hint about why a message is hidden.
    private var hint: String {
        switch flag?.category {
        case "aggressive":           return "May contain hostile language"
        case "sexual_pressure":      return "May contain explicit content"
        case "manipulative":         return "May contain manipulative language"
        case "possessive":           return "May contain controlling language"
        case "pressuring":           return "May contain pressuring language"
        case "excessive_intensity":  return "Very intense message"
        case "personal_info", "phone_number": return "May contain personal info"
        default:                     return "Possibly sensitive content"
        }
    }

}
