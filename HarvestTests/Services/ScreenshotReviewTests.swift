import XCTest
import UIKit
@testable import Harvest

final class ChatMessageEncodingTests: XCTestCase {
    private func encodedJSON(_ message: OpenAIService.ChatMessage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(message)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The load-bearing one: every pre-existing caller must encode exactly as
    /// it did before content parts were introduced.
    func testTextOnlyEncodesAsBareString() throws {
        let json = try encodedJSON(.init(role: "user", content: "hello"))
        XCTAssertEqual(json["role"] as? String, "user")
        XCTAssertEqual(json["content"] as? String, "hello")
    }

    func testTextPlusImageEncodesAsContentParts() throws {
        let json = try encodedJSON(.init(role: "user", parts: [
            .text("what do you think?"),
            .imageURL("data:image/jpeg;base64,AAAA")
        ]))

        let parts = try XCTUnwrap(json["content"] as? [[String: Any]])
        XCTAssertEqual(parts.count, 2)

        XCTAssertEqual(parts[0]["type"] as? String, "text")
        XCTAssertEqual(parts[0]["text"] as? String, "what do you think?")

        XCTAssertEqual(parts[1]["type"] as? String, "image_url")
        let imageURL = try XCTUnwrap(parts[1]["image_url"] as? [String: Any])
        XCTAssertEqual(imageURL["url"] as? String, "data:image/jpeg;base64,AAAA")
    }

    func testImageOnlyStillEncodesAsArray() throws {
        let json = try encodedJSON(.init(role: "user", parts: [.imageURL("https://x/y.jpg")]))
        XCTAssertNotNil(json["content"] as? [[String: Any]])
        XCTAssertNil(json["content"] as? String)
    }

    func testRoundTripsThroughDecoding() throws {
        let original = OpenAIService.ChatMessage(role: "user", parts: [
            .text("a"), .imageURL("data:image/jpeg;base64,BBBB")
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIService.ChatMessage.self, from: data)
        XCTAssertEqual(decoded.parts, original.parts)
    }

    func testDecodesBareStringContent() throws {
        let data = Data(#"{"role":"assistant","content":"hi"}"#.utf8)
        let decoded = try JSONDecoder().decode(OpenAIService.ChatMessage.self, from: data)
        XCTAssertEqual(decoded.parts, [.text("hi")])
        XCTAssertEqual(decoded.content, "hi")
    }
}

final class ScreenshotVerdictParsingTests: XCTestCase {
    func testParsesPlainJSON() throws {
        let verdict = try GardenerService.parseVerdict(
            #"{"is_chat_screenshot": true, "reply": "Looks warm."}"#
        )
        XCTAssertTrue(verdict.isChatScreenshot)
        XCTAssertEqual(verdict.reply, "Looks warm.")
    }

    func testParsesFencedJSON() throws {
        let verdict = try GardenerService.parseVerdict("""
            ```json
            {"is_chat_screenshot": false, "reply": ""}
            ```
            """)
        XCTAssertFalse(verdict.isChatScreenshot)
        XCTAssertEqual(verdict.reply, "")
    }

    func testParsesJSONWithSurroundingProse() throws {
        let verdict = try GardenerService.parseVerdict(
            "Sure! {\"is_chat_screenshot\": true, \"reply\": \"ok\"} Hope that helps."
        )
        XCTAssertTrue(verdict.isChatScreenshot)
    }

    func testThrowsOnMissingKey() {
        XCTAssertThrowsError(try GardenerService.parseVerdict(#"{"reply": "nope"}"#))
    }

    func testThrowsOnNonJSON() {
        XCTAssertThrowsError(try GardenerService.parseVerdict("I couldn't tell."))
    }
}

final class ScreenshotEncoderTests: XCTestCase {
    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func testDownscalesLongestSideToLimit() {
        let result = ScreenshotEncoder.downscaled(image(width: 3000, height: 1500), limit: 1024)
        XCTAssertEqual(max(result.size.width, result.size.height), 1024, accuracy: 1)
    }

    func testPreservesAspectRatio() {
        let result = ScreenshotEncoder.downscaled(image(width: 2000, height: 1000), limit: 1000)
        XCTAssertEqual(result.size.width / result.size.height, 2.0, accuracy: 0.02)
    }

    func testLeavesSmallImagesAlone() {
        let original = image(width: 400, height: 300)
        let result = ScreenshotEncoder.downscaled(original, limit: 1024)
        XCTAssertEqual(result.size.width, 400, accuracy: 1)
        XCTAssertEqual(result.size.height, 300, accuracy: 1)
    }

    func testProducesAJPEGDataURL() throws {
        let url = try ScreenshotEncoder.dataURL(from: image(width: 1200, height: 800))
        XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
        let base64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        XCTAssertNotNil(Data(base64Encoded: base64))
    }
}
