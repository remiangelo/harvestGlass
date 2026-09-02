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

/// The image call returns prose, not JSON. The only structure is the refusal
/// sentinel — the previous JSON verdict was truncated by `maxTokens` on long
/// replies and surfaced as "The Gardener returned no verdict".
///
/// Mirrors `GardenerScreenshotTest.kt`; the placeholder assertions use the same
/// literal strings, since both platforms read each other's rows.
@MainActor
final class GardenerImageReviewTests: XCTestCase {
    func testCaptionBecomesATextPartBeforeTheImages() {
        let parts = GardenerService.imageParts(
            caption: "what do you think?",
            imageDataURLs: ["data:a", "data:b"]
        )
        let expected: [OpenAIService.ChatMessage.ContentPart] = [
            .text("what do you think?"),
            .imageURL("data:a"),
            .imageURL("data:b")
        ]
        XCTAssertEqual(parts, expected)
    }

    func testEmptyCaptionContributesNoTextPart() {
        let parts = GardenerService.imageParts(caption: "   ", imageDataURLs: ["data:a"])
        let expected: [OpenAIService.ChatMessage.ContentPart] = [.imageURL("data:a")]
        XCTAssertEqual(parts, expected)
    }

    func testImageOrderIsSelectionOrder() {
        let urls = ["data:1", "data:2", "data:3"]
        let parts = GardenerService.imageParts(caption: "", imageDataURLs: urls)
        let expected: [OpenAIService.ChatMessage.ContentPart] = [
            .imageURL("data:1"), .imageURL("data:2"), .imageURL("data:3")
        ]
        XCTAssertEqual(parts, expected)
    }

    func testSentinelBecomesTheCannedRefusal() {
        XCTAssertEqual(
            GardenerService.resolveReply("REFUSE_EXPLICIT"),
            GardenerService.explicitRefusalReply
        )
    }

    func testSentinelIsRecognisedWithSurroundingWhitespace() {
        XCTAssertEqual(
            GardenerService.resolveReply("  REFUSE_EXPLICIT\n\n"),
            GardenerService.explicitRefusalReply
        )
    }

    /// A reply that merely mentions the sentinel is a real reply.
    func testProseContainingTheWordIsNotARefusal() {
        let raw = "I won't REFUSE_EXPLICIT anything here — the tone reads warm."
        XCTAssertTrue(GardenerService.resolveReply(raw).contains("tone reads warm"))
    }

    func testOrdinaryProseIsFormattedAndReturned() {
        XCTAssertEqual(
            GardenerService.resolveReply("They're pulling back."),
            "They're pulling back."
        )
    }

    func testPlaceholderIsSingularForOneImage() {
        XCTAssertEqual(
            GardenerService.screenshotPlaceholder(caption: "read this", imageCount: 1),
            "📷 Screenshot — read this"
        )
    }

    func testPlaceholderCountsSeveralImages() {
        XCTAssertEqual(
            GardenerService.screenshotPlaceholder(caption: "read this", imageCount: 3),
            "📷 3 screenshots — read this"
        )
    }

    func testEmptyCaptionDropsTheDash() {
        XCTAssertEqual(
            GardenerService.screenshotPlaceholder(caption: "", imageCount: 1),
            "📷 Screenshot"
        )
        XCTAssertEqual(
            GardenerService.screenshotPlaceholder(caption: "", imageCount: 2),
            "📷 2 screenshots"
        )
    }

    func testSentinelIsExactlyTheAgreedString() {
        XCTAssertEqual(GardenerService.refuseSentinel, "REFUSE_EXPLICIT")
    }
}

/// The picker is opened with the tier's cap, but the cap is applied again here:
/// a picker limit is a UI affordance, not a guarantee, and a 20-image request is
/// several megabytes. Mirrors `GardenerSelectionTest.kt`.
@MainActor
final class GardenerSelectionTests: XCTestCase {
    private func items(_ n: Int) -> [String] { (0..<n).map { "uri-\($0)" } }

    func testSelectionWithinTheCapIsUntouched() {
        let picked = items(3)
        XCTAssertEqual(GardenerViewModel.clampSelection(picked, cap: 6), picked)
    }

    func testOverLongSelectionKeepsTheFirstCapImages() {
        let picked = items(9)
        let clamped = GardenerViewModel.clampSelection(picked, cap: 6)
        XCTAssertEqual(clamped.count, 6)
        XCTAssertEqual(clamped, Array(picked.prefix(6)))
    }

    /// An unknown tier decodes as 1, and must not become "unlimited".
    func testCapOfOneKeepsASingleImage() {
        XCTAssertEqual(GardenerViewModel.clampSelection(items(5), cap: 1).count, 1)
    }

    func testNonsenseCapStillSendsOneImageRatherThanNone() {
        XCTAssertEqual(GardenerViewModel.clampSelection(items(5), cap: 0).count, 1)
    }

    func testEmptySelectionStaysEmpty() {
        XCTAssertTrue(GardenerViewModel.clampSelection([String](), cap: 6).isEmpty)
    }

    func testSelectionWithinBudgetIsAccepted() {
        XCTAssertNil(GardenerViewModel.payloadRejection([
            String(repeating: "a", count: 1000),
            String(repeating: "b", count: 1000)
        ]))
    }

    func testOversizedSelectionIsRefusedByCountNotByBytes() throws {
        let huge = (0..<3).map { _ in String(repeating: "x", count: 3_000_000) }
        let message = try XCTUnwrap(GardenerViewModel.payloadRejection(huge))
        XCTAssertTrue(message.contains("3 images"))
    }
}

/// Retained images are in-memory, view-model-scoped state (see the view model's
/// `retainedImageURLs` doc). Android had to reflect into a private `_state` flow
/// to seed the precondition; on iOS the view model is directly constructible and
/// the properties are `var`, so the start state is just assigned and the real,
/// unmodified production methods run against it. Mirrors
/// `GardenerRetentionTest.kt`.
@MainActor
final class GardenerRetentionTests: XCTestCase {
    func testStagingANewSelectionClearsAnyRetainedImages() {
        let viewModel = GardenerViewModel()
        viewModel.retainedImageURLs = ["data:image/jpeg;base64,AAA"]
        viewModel.imageCap = 3

        viewModel.stageScreenshots([UIImage()])

        XCTAssertTrue(viewModel.retainedImageURLs.isEmpty)
        XCTAssertEqual(viewModel.pendingScreenshots.count, 1)
    }

    func testClearRetainedImagesEmptiesTheField() {
        let viewModel = GardenerViewModel()
        viewModel.retainedImageURLs = [
            "data:image/jpeg;base64,AAA",
            "data:image/jpeg;base64,BBB"
        ]

        viewModel.clearRetainedImages()

        XCTAssertTrue(viewModel.retainedImageURLs.isEmpty)
    }

    /// The other half of the same contract, and cheap to reach on iOS: the
    /// tier's cap is applied at staging time, not only by the picker.
    func testStagingClampsToTheTiersCap() {
        let viewModel = GardenerViewModel()
        viewModel.imageCap = 2

        viewModel.stageScreenshots([UIImage(), UIImage(), UIImage()])

        XCTAssertEqual(viewModel.pendingScreenshots.count, 2)
    }

    func testUnstagingRemovesOnlyThatImage() {
        let viewModel = GardenerViewModel()
        viewModel.imageCap = 3
        let first = UIImage()
        let second = UIImage()
        let third = UIImage()
        viewModel.stageScreenshots([first, second, third])

        viewModel.unstageScreenshot(at: 1)

        XCTAssertEqual(viewModel.pendingScreenshots.count, 2)
        XCTAssertTrue(viewModel.pendingScreenshots[0] === first)
        XCTAssertTrue(viewModel.pendingScreenshots[1] === third)
    }
}

@MainActor
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

    /// The ladder in `targetDimension` in ScreenshotEncoder.kt, rung for rung.
    func testTargetDimensionLadder() {
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 1), 1400)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 2), 1400)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 3), 1100)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 5), 1100)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 6), 900)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 12), 900)
    }

    /// A count of zero or less falls in the first rung, as on Android.
    func testTargetDimensionTreatsAnEmptySendAsTheTopRung() {
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: 0), 1400)
        XCTAssertEqual(ScreenshotEncoder.targetDimension(imageCount: -1), 1400)
    }

    /// A tighter target must actually shrink the encoded image — that is the
    /// whole point of the ladder when several images share one request.
    func testATighterTargetShrinksTheEncodedImage() throws {
        let url = try ScreenshotEncoder.dataURL(from: image(width: 2400, height: 1200), target: 900)
        XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))

        let base64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(max(decoded.size.width, decoded.size.height), 900, accuracy: 1)
    }

    func testProducesAJPEGDataURL() throws {
        let url = try ScreenshotEncoder.dataURL(from: image(width: 1200, height: 800))
        XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
        let base64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        XCTAssertNotNil(Data(base64Encoded: base64))
    }
}
