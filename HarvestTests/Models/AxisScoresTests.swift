import XCTest
@testable import Harvest

final class AxisScoresTests: XCTestCase {
    func testIsZero_emptyScores() {
        let s = AxisScores()
        XCTAssertTrue(s.isZero)
        XCTAssertEqual(s.sum, 0)
    }

    func testIsZero_anyValueMakesItNonZero() {
        var s = AxisScores()
        s.connection = 0.1
        XCTAssertFalse(s.isZero)
    }

    func testNormalized_zeroVectorStaysZero() {
        let s = AxisScores().normalized()
        XCTAssertTrue(s.isZero)
    }

    func testNormalized_sumsToOne() {
        var s = AxisScores()
        s.emotionalIntelligence = 2
        s.stability = 1
        s.integrity = 1
        let n = s.normalized()
        XCTAssertEqual(n.sum, 1.0, accuracy: 0.0001)
    }

    func testNormalized_relativeShape() {
        var s = AxisScores()
        s.emotionalIntelligence = 4
        s.connection = 1
        let n = s.normalized()
        XCTAssertEqual(n.emotionalIntelligence, 0.8, accuracy: 0.0001)
        XCTAssertEqual(n.connection, 0.2, accuracy: 0.0001)
        XCTAssertEqual(n.stability, 0, accuracy: 0.0001)
    }

    func testValueFor_returnsTheRightAxis() {
        var s = AxisScores()
        s.growth = 0.5
        XCTAssertEqual(s.value(for: .growth), 0.5)
        XCTAssertEqual(s.value(for: .integrity), 0)
    }

    func testCosine_identicalVectorsIsOne() {
        var a = AxisScores()
        a.emotionalIntelligence = 0.4
        a.connection = 0.6
        let c = AxisScores.cosine(a, a)
        XCTAssertEqual(c, 1.0, accuracy: 0.0001)
    }

    func testCosine_zeroVectorIsZero() {
        var a = AxisScores()
        a.growth = 1
        let c = AxisScores.cosine(a, AxisScores())
        XCTAssertEqual(c, 0, accuracy: 0.0001)
    }

    func testCosine_orthogonalAxesIsZero() {
        var a = AxisScores(); a.emotionalIntelligence = 1
        var b = AxisScores(); b.growth = 1
        XCTAssertEqual(AxisScores.cosine(a, b), 0, accuracy: 0.0001)
    }
}
