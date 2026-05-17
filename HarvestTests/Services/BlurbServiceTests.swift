import XCTest
@testable import Harvest

final class BlurbServiceTests: XCTestCase {
    func testGenerateBlurb_TrimsWhitespace() async throws {
        let service = BlurbService(chat: { _ in
            "   I value honesty.\n\n"
        })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]
        let sought: [Value] = []

        let result = try await service.generateBlurb(brought: brought, sought: sought)

        XCTAssertEqual(result, "I value honesty.")
    }

    func testGenerateBlurb_CapsAtLengthLimit() async throws {
        let longResponse = String(repeating: "a", count: 500)
        let service = BlurbService(chat: { _ in longResponse })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]

        let result = try await service.generateBlurb(brought: brought, sought: [])

        XCTAssertEqual(result.count, 280)
    }

    func testGenerateBlurb_PropagatesErrors() async {
        struct StubError: Error {}
        let service = BlurbService(chat: { _ in throw StubError() })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]

        do {
            _ = try await service.generateBlurb(brought: brought, sought: [])
            XCTFail("Expected error")
        } catch is StubError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateBlurb_IncludesValueNamesInPrompt() async throws {
        var capturedMessages: [OpenAIService.ChatMessage] = []
        let service = BlurbService(chat: { messages in
            capturedMessages = messages
            return "ok"
        })

        let brought = [Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0)]
        let sought = [Value(id: "2", name: "Curiosity", category: "personal growth", displayOrder: 0)]

        _ = try await service.generateBlurb(brought: brought, sought: sought)

        let combined = capturedMessages.map(\.content).joined(separator: "\n")
        XCTAssertTrue(combined.contains("Honesty"))
        XCTAssertTrue(combined.contains("Curiosity"))
    }
}
