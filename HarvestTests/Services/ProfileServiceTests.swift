import XCTest
import Supabase
@testable import Harvest

/// `users.email` is NOT NULL with no default, and Postgres validates the
/// proposed tuple before it resolves ON CONFLICT, so an upsert that leaves
/// email out raises 23502 even when the row already exists. Onboarding's last
/// step is the only caller, which made a missing email strand the user on
/// "Failed to save profile" with no way forward.
///
/// Mirrors ProfileServiceTest.kt on Android.
final class ProfileServiceTests: XCTestCase {
    private let now = "2026-09-02T00:00:00Z"

    func testUpsertPayload_CarriesTheEmail() {
        let payload = ProfileService.upsertPayload(
            userId: "u1",
            email: "ada@example.com",
            updates: ["nickname": .string("Ada")],
            nowISO: now
        )

        XCTAssertEqual(payload["email"], .string("ada@example.com"))
    }

    func testUpsertPayload_KeepsTheIdUpdatesAndTimestamp() {
        let payload = ProfileService.upsertPayload(
            userId: "u1",
            email: "ada@example.com",
            updates: ["nickname": .string("Ada")],
            nowISO: now
        )

        XCTAssertEqual(payload["id"], .string("u1"))
        XCTAssertEqual(payload["nickname"], .string("Ada"))
        XCTAssertEqual(payload["updated_at"], .string(now))
    }

    /// Writing an explicit null would fail the NOT NULL just as surely, and
    /// would also blank a good address on an existing row.
    func testUpsertPayload_OmitsAnUnknownEmailRatherThanNullingIt() {
        let payload = ProfileService.upsertPayload(
            userId: "u1",
            email: nil,
            updates: [:],
            nowISO: now
        )

        XCTAssertNil(payload["email"])
    }

    func testUpsertPayload_AnExplicitEmailWinsOverTheSessionOne() {
        let payload = ProfileService.upsertPayload(
            userId: "u1",
            email: "session@example.com",
            updates: ["email": .string("explicit@example.com")],
            nowISO: now
        )

        XCTAssertEqual(payload["email"], .string("explicit@example.com"))
    }
}
