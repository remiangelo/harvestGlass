import XCTest
@testable import Harvest

final class SafetyAnalysisServiceTests: XCTestCase {

    private func flags(_ message: String) -> [SafetyFlagSnapshot] {
        SafetyAnalysisService.detectFlags(in: message)
    }

    private func categories(_ message: String) -> Set<RedFlagCategory> {
        Set(flags(message).map(\.category))
    }

    // MARK: - Clean messages

    /// A red flag here costs the other person 25-30 safety points and can gate
    /// contact sharing, so ordinary conversation must never produce one.
    func testOrdinaryConversationIsNotFlagged() {
        let clean = [
            "hello", "hi!!", "Hey! How was your week?",
            "I really enjoyed our conversation today. Coffee this weekend?",
            "I need to kill some time before our date",
            "I'll contact now that I'm off work",
            "Let's take a break from the apps",
            "My camera roll is a mess",
            "I can loan you my copy of that book",
            "Do you follow any good podcasts?",
            "I work from home most days"
        ]

        for message in clean {
            let detected = flags(message)
            XCTAssertTrue(
                detected.isEmpty,
                "false positive on \(message.debugDescription): \(detected.map(\.evidence))"
            )
        }
    }

    func testEmptyMessageIsNotFlagged() {
        XCTAssertTrue(flags("").isEmpty)
    }

    func testUnicodeAndEmojiAreHandled() {
        XCTAssertTrue(flags("Привет! ¿Cómo estás? 你好").isEmpty)
        XCTAssertTrue(flags("Hey! How are you? 😊 Let's chat about our interests!").isEmpty)
    }

    // MARK: - Financial

    func testDetectsFinancialRedFlags() {
        XCTAssertEqual(categories("Can you send money? I'm in a tough spot."), [.financial])
        XCTAssertEqual(categories("I have a great bitcoin investment opportunity for you!"), [.financial])
        XCTAssertEqual(categories("Send MONEY to my CASHAPP"), [.financial])
        XCTAssertEqual(categories("Could you loan me $200 until Friday?"), [.financial])
    }

    // MARK: - Personal info

    func testDetectsPersonalInfoRedFlags() {
        XCTAssertEqual(categories("What's your social security number?"), [.personalInfo])
        XCTAssertEqual(categories("Can you share your password so I can help?"), [.personalInfo])
    }

    // MARK: - Catfishing

    func testDetectsCatfishingRedFlags() {
        XCTAssertEqual(categories("My camera is broken so we can't video call"), [.catfishing])
        XCTAssertEqual(categories("I'm deployed overseas and can't meet yet"), [.catfishing])
    }

    // MARK: - Manipulation

    func testDetectsManipulationRedFlags() {
        XCTAssertEqual(categories("If you loved me, you would do this for me"), [.manipulation])
        XCTAssertEqual(categories("Nobody else will ever love you like I do"), [.manipulation])
    }

    // MARK: - Harassment

    func testDetectsHarassmentRedFlags() {
        XCTAssertEqual(categories("I know where you live, I will find you"), [.harassment])
        XCTAssertEqual(categories("I could hurt you if I wanted to"), [.harassment])
        XCTAssertEqual(categories("He has been stalking me for weeks"), [.harassment])
    }

    /// "kill" alone used to be a harassment keyword, which made every "kill
    /// some time" a red flag on someone's record.
    func testHarassmentNeedsATarget() {
        XCTAssertTrue(flags("This heat is killing me").isEmpty)
        XCTAssertEqual(categories("I'll kill you"), [.harassment])
    }

    // MARK: - Inappropriate and spam

    func testDetectsInappropriateRedFlags() {
        XCTAssertEqual(categories("Send nudes please"), [.inappropriate])
        XCTAssertEqual(categories("What are you wearing right now?"), [.inappropriate])
    }

    func testDetectsSpamRedFlags() {
        XCTAssertEqual(categories("Click this link for a free prize!"), [.spam])
        XCTAssertEqual(categories("You've won! Act now, limited time offer"), [.spam])
    }

    // MARK: - Multiple categories

    func testMultipleCategoriesAreReportedSeparately() {
        let detected = categories("Send money for the flight, and also send me your social security number")
        XCTAssertEqual(detected, [.financial, .personalInfo])
    }

    /// Several hits in one category still count once — the score penalty is
    /// per category, not per word.
    func testSameCategoryCountsOnce() {
        XCTAssertEqual(flags("Send money via bitcoin to my wallet").count, 1)
    }

    func testFlagCarriesEvidenceAndMessageId() {
        let detected = SafetyAnalysisService.detectFlags(in: "send nudes", messageId: "msg-1")
        XCTAssertEqual(detected.count, 1)
        XCTAssertEqual(detected.first?.messageId, "msg-1")
        XCTAssertEqual(detected.first?.severity, .medium)
        XCTAssertTrue(detected.first?.evidence.contains("send nudes") == true)
    }

    // MARK: - Category weights

    func testRedFlagWeights() {
        XCTAssertEqual(RedFlagCategory.financial.weight, 30)
        XCTAssertEqual(RedFlagCategory.personalInfo.weight, 30)
        XCTAssertEqual(RedFlagCategory.catfishing.weight, 25)
        XCTAssertEqual(RedFlagCategory.harassment.weight, 25)
        XCTAssertEqual(RedFlagCategory.manipulation.weight, 20)
        XCTAssertEqual(RedFlagCategory.inappropriate.weight, 20)
        XCTAssertEqual(RedFlagCategory.spam.weight, 10)
    }

    // MARK: - Long input

    func testVeryLongMessageStillAnalyzes() {
        let message = String(repeating: "This is a long message. ", count: 100)
        XCTAssertTrue(flags(message).isEmpty)
    }
}

// MARK: - Integration Test Notes

/*
 Integration tests that would require real or mocked Supabase client:

 1. Test full conversation analysis workflow
 2. Test red flag report persistence
 3. Test safety score updates in database
 4. Test retroactive analysis on existing conversations
 5. Test concurrent analysis of multiple conversations
 6. Test error handling when database operations fail
 7. Test transaction rollback on partial failures

 These would be implemented in a separate integration test suite
 with a test database or comprehensive mocking infrastructure.
 */
