import XCTest
@testable import Harvest

final class MessageGroupingTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_754_000_000)  // fixed, no "now"

    private func position(
        prevSender: String?, prevOffset: TimeInterval?,
        sender: String, offset: TimeInterval?,
        nextSender: String? = nil, nextOffset: TimeInterval? = nil
    ) -> MessagePosition {
        MessageGrouping.position(
            previousSender: prevSender,
            previousDate: prevOffset.map { base.addingTimeInterval($0) },
            currentSender: sender,
            currentDate: offset.map { base.addingTimeInterval($0) },
            nextSender: nextSender,
            nextDate: nextOffset.map { base.addingTimeInterval($0) }
        )
    }

    func testGroupsWhenJustUnderFiveMinutes() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 299)
        XCTAssertFalse(p.isFirstInGroup)
    }

    func testDoesNotGroupWhenJustOverFiveMinutes() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 301)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testDoesNotGroupDifferentSenders() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "b", offset: 1)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testIsLastInGroupWhenNextIsDifferentSender() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 10,
                         nextSender: "b", nextOffset: 20)
        XCTAssertTrue(p.isLastInGroup)
    }

    func testIsNotLastInGroupWhenNextContinues() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: 10,
                         nextSender: "a", nextOffset: 20)
        XCTAssertFalse(p.isLastInGroup)
    }

    func testFirstMessageInListShowsSeparator() {
        let p = position(prevSender: nil, prevOffset: nil, sender: "a", offset: 0)
        XCTAssertTrue(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testSeparatorAcrossMidnightAndNoGrouping() {
        // 30s either side of midnight: one minute apart, but different days.
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: base.addingTimeInterval(86_400))
        let before = midnight.addingTimeInterval(-30)
        let after = midnight.addingTimeInterval(30)
        let p = MessageGrouping.position(
            previousSender: "a", previousDate: before,
            currentSender: "a", currentDate: after,
            nextSender: nil, nextDate: nil
        )
        XCTAssertTrue(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup, "a day break always starts a new group")
    }

    func testSameDayDoesNotShowSeparator() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "b", offset: 60)
        XCTAssertFalse(p.showsDateSeparator)
    }

    func testUnparseableCurrentDateStandsAlone() {
        let p = position(prevSender: "a", prevOffset: 0, sender: "a", offset: nil)
        XCTAssertTrue(p.isFirstInGroup)
        XCTAssertTrue(p.isLastInGroup)
        XCTAssertFalse(p.showsDateSeparator)
    }

    func testUnparseablePreviousDateDoesNotInventASeparator() {
        let p = position(prevSender: "a", prevOffset: nil, sender: "a", offset: 0)
        XCTAssertFalse(p.showsDateSeparator)
        XCTAssertTrue(p.isFirstInGroup)
    }

    func testParsesTimestampWithFractionalSeconds() {
        XCTAssertNotNil(MessageGrouping.date(from: "2026-08-04T10:15:30.123456+00:00"))
    }

    func testParsesTimestampWithoutFractionalSeconds() {
        XCTAssertNotNil(MessageGrouping.date(from: "2026-08-04T10:15:30Z"))
    }

    func testReturnsNilForGarbageTimestamp() {
        XCTAssertNil(MessageGrouping.date(from: "not a date"))
        XCTAssertNil(MessageGrouping.date(from: nil))
    }
}
