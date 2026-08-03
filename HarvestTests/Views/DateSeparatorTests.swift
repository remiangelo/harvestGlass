import XCTest
@testable import Harvest

final class DateSeparatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_754_000_000)

    func testTodayLabel() {
        XCTAssertEqual(DateSeparator.label(for: now, now: now), "Today")
    }

    func testEarlierSameDayIsStillToday() {
        let earlier = Calendar.current.startOfDay(for: now).addingTimeInterval(60)
        XCTAssertEqual(DateSeparator.label(for: earlier, now: now), "Today")
    }

    func testYesterdayLabel() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(DateSeparator.label(for: yesterday, now: now), "Yesterday")
    }

    func testWeekdayLabelWithinLastWeek() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let label = DateSeparator.label(for: threeDaysAgo, now: now)
        XCTAssertTrue(
            Calendar.current.weekdaySymbols.contains(label),
            "expected a weekday name, got \(label)"
        )
    }

    func testOlderThanAWeekFallsBackToADate() {
        let longAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let label = DateSeparator.label(for: longAgo, now: now)
        XCTAssertFalse(Calendar.current.weekdaySymbols.contains(label))
        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
    }

    func testExactlySevenDaysAgoIsNotAWeekday() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let label = DateSeparator.label(for: sevenDaysAgo, now: now)
        XCTAssertFalse(
            Calendar.current.weekdaySymbols.contains(label),
            "seven days back collides with today's weekday name — must show a date"
        )
    }

    func testFutureDateDoesNotRenderAsAWeekday() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let label = DateSeparator.label(for: tomorrow, now: now)
        XCTAssertFalse(Calendar.current.weekdaySymbols.contains(label))
        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
    }
}
