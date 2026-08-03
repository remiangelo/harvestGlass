import Foundation

/// Where a message sits within a run of consecutive messages from one sender.
struct MessagePosition: Equatable {
    let showsDateSeparator: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
}

/// Decides how messages clump together in a transcript. Pure and
/// synchronous so it can be unit tested without a view or a network.
enum MessageGrouping {
    /// Messages from one sender closer together than this, on the same day,
    /// render as a single group.
    static let groupWindow: TimeInterval = 5 * 60

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses a Supabase timestamp, which may or may not carry fractional
    /// seconds. Formatters are cached — the previous per-call
    /// `ISO8601DateFormatter()` ran once per bubble per redraw.
    ///
    /// Postgres emits up to six fractional digits but `ISO8601DateFormatter`
    /// only accepts three, so an unparseable string gets its fraction trimmed
    /// and retried. Without that, every timestamp would come back nil and
    /// grouping, separators, and time labels would all quietly disappear.
    static func date(from iso: String?) -> Date? {
        guard let iso else { return nil }
        if let parsed = fractional.date(from: iso) { return parsed }
        if let parsed = whole.date(from: iso) { return parsed }
        guard let trimmed = trimmingFractionalSeconds(iso) else { return nil }
        return fractional.date(from: trimmed) ?? whole.date(from: trimmed)
    }

    /// "…:30.123456+00:00" → "…:30.123+00:00". nil when there is nothing to trim.
    private static func trimmingFractionalSeconds(_ iso: String) -> String? {
        guard let dot = iso.firstIndex(of: ".") else { return nil }
        let firstDigit = iso.index(after: dot)
        let end = iso[firstDigit...].firstIndex(where: { !$0.isNumber }) ?? iso.endIndex
        guard iso.distance(from: firstDigit, to: end) > 3 else { return nil }
        let keepThrough = iso.index(firstDigit, offsetBy: 3)
        return String(iso[..<keepThrough]) + String(iso[end...])
    }

    static func position(
        previousSender: String?, previousDate: Date?,
        currentSender: String, currentDate: Date?,
        nextSender: String?, nextDate: Date?
    ) -> MessagePosition {
        // Without a usable timestamp a message can't be placed in a run,
        // so it stands alone rather than guessing.
        guard let currentDate else {
            return MessagePosition(
                showsDateSeparator: false,
                isFirstInGroup: true,
                isLastInGroup: true
            )
        }

        let showsDateSeparator: Bool = {
            guard previousSender != nil else { return true }   // top of the transcript
            guard let previousDate else { return false }       // unusable — don't invent a break
            return !Calendar.current.isDate(previousDate, inSameDayAs: currentDate)
        }()

        return MessagePosition(
            showsDateSeparator: showsDateSeparator,
            isFirstInGroup: !continues(
                fromSender: previousSender, fromDate: previousDate,
                toSender: currentSender, toDate: currentDate
            ),
            isLastInGroup: !continues(
                fromSender: currentSender, fromDate: currentDate,
                toSender: nextSender, toDate: nextDate
            )
        )
    }

    /// True when the second message continues the first: same sender, same
    /// calendar day, inside the window.
    private static func continues(
        fromSender: String?, fromDate: Date?,
        toSender: String?, toDate: Date?
    ) -> Bool {
        guard let fromSender, let toSender, fromSender == toSender,
              let fromDate, let toDate,
              Calendar.current.isDate(fromDate, inSameDayAs: toDate)
        else { return false }
        return toDate.timeIntervalSince(fromDate) < groupWindow
    }
}
