import SwiftUI

/// A centred pill marking the day a run of messages belongs to.
struct DateSeparator: View {
    let date: Date

    var body: some View {
        Text(Self.label(for: date))
            .font(HarvestTheme.Typography.caption)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
            .padding(.horizontal, HarvestTheme.Spacing.md)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().stroke(HarvestTheme.Colors.border, lineWidth: 1) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    /// `now` is injectable so the label is testable without freezing the clock.
    /// Everything is derived from the day gap rather than `isDateInToday`,
    /// which would silently ignore an injected `now` and read the real clock.
    static func label(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? Int.max

        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: break
        }

        let formatter = DateFormatter()
        if (2..<7).contains(days) {
            formatter.dateFormat = "EEEE"
        } else {
            // Anything older than a week — or in the future, which shouldn't
            // happen but shouldn't render as a weekday either.
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
}
