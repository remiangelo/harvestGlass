import XCTest
@testable import Harvest

/// `localFlag` is the on-device keyword pass — the same analysis that warns a
/// sender and blurs an incoming bubble. These tests cover it directly; the
/// OpenAI second pass isn't exercised here (it needs the network).
final class MindfulMessagingServiceTests: XCTestCase {
    private let service = MindfulMessagingService()

    private func assertClean(_ messages: [String], file: StaticString = #filePath, line: UInt = #line) {
        for message in messages {
            let flag = service.localFlag(for: message)
            XCTAssertNil(
                flag,
                "false positive on \(message.debugDescription): \(flag?.flaggedWords.joined(separator: ", ") ?? "")",
                file: file,
                line: line
            )
        }
    }

    private func assertFlagged(_ messages: [String], file: StaticString = #filePath, line: UInt = #line) {
        for message in messages {
            XCTAssertNotNil(
                service.localFlag(for: message),
                "missed \(message.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Greetings and small talk

    /// The reported bug: "hello" contained "hell", so greetings were flagged.
    func testGreetingsAreNeverFlagged() {
        assertClean([
            "hello", "Hello!", "hello there", "hi", "hi!!", "HI!!!", "hey", "heyyy",
            "hey there :)", "Hi! How are you?", "yo", "good morning!"
        ])
    }

    func testEverydayChatIsNotFlagged() {
        assertClean([
            "Want to grab breakfast tomorrow?",
            "One of us should pick a place",
            "Let's take a break and get coffee",
            "I need to kill some time before our date",
            "Nice shoes!",
            "I bought a new hoe for the garden",
            "That class was tough",
            "The food was insane, so good",
            "That movie was terrible lol",
            "I'm obsessed with this show",
            "This weather is killing me",
            "Do you like hiking?",
            "Are you free this weekend?",
            "I'll be there tonight",
            "I'm free right now if you want to call",
            "Let me know if you can't make it",
            "Show me your favorite playlist",
            "I love your dog",
            "You're so funny",
            "You're amazing"
        ])
    }

    /// Ordinary affection is not a safety event — flagging it warns the sender
    /// and blurs the message for the person receiving it.
    func testAffectionIsNotFlagged() {
        assertClean(["I love you", "I had a lovely time", "I miss you", "you're the best"])
    }

    /// Disclosures and self-directed remarks read as insults to a naive matcher.
    func testSelfDirectedAndSupportiveRemarksAreNotFlagged() {
        assertClean([
            "You know, that was stupid of me",
            "It's not your fault at all",
            "I don't blame you for that",
            "I felt so guilty about it"
        ])
    }

    // MARK: - Still caught

    func testInsultsAimedAtThePersonAreFlagged() {
        assertFlagged([
            "You're such an idiot",
            "you are so stupid",
            "ur pathetic",
            "you're a worthless loser"
        ])
    }

    func testProfanityAndSlursAreFlagged() {
        assertFlagged(["fuck you", "what a piece of shit", "shut up", "you bitch"])
    }

    func testThreatsAreFlagged() {
        assertFlagged([
            "I'll kill you if you leave",
            "I will hurt you",
            "I'm going to ruin your life"
        ])
    }

    func testCoercionAndControlAreFlagged() {
        assertFlagged([
            "You belong to me",
            "you're mine",
            "If you loved me you would do it",
            "No one will ever love you like I do",
            "you owe me after everything i did"
        ])
    }

    func testSexualPressureIsFlagged() {
        assertFlagged([
            "send nudes",
            "what are you wearing right now",
            "take it off",
            "are you naked"
        ])
    }

    func testSensitiveDataAndPhoneNumbersAreFlagged() {
        assertFlagged([
            "send me your password",
            "what's your social security number",
            "can you send money to my cashapp",
            "call me at 555-123-4567"
        ])
    }

    func testSeverityFollowsTheCategory() {
        XCTAssertEqual(service.localFlag(for: "send me your password")?.severity, .high)
        XCTAssertEqual(service.localFlag(for: "you are so stupid")?.severity, .medium)
    }

    // MARK: - Profile field screening

    func testProfileScreeningAllowsOrdinaryBiosAndBlocksSlurs() {
        XCTAssertFalse(MindfulMessagingService.containsObjectionableContent("Hello! I garden and hike."))
        XCTAssertFalse(MindfulMessagingService.containsObjectionableContent("Bought a new hoe for the raised beds"))
        XCTAssertFalse(MindfulMessagingService.containsObjectionableContent("It was a hell of a year"))
        XCTAssertTrue(MindfulMessagingService.containsObjectionableContent("fuck off"))
        XCTAssertTrue(MindfulMessagingService.containsObjectionableContent("send nudes"))
    }

    // MARK: - Known limitation

    /// An insult with no target word is missed — "stop being so ugly" has no
    /// "you" for the directed rule to anchor to. Deliberate: the alternative
    /// (any clause without a first-person word arms every insult term) put
    /// "the party was trash" back in the flagged pile.
    func testUntargetedInsultIsAKnownMiss() {
        XCTAssertNil(service.localFlag(for: "stop being so ugly"))
    }
}
