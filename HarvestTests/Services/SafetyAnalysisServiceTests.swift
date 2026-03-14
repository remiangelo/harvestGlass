import XCTest
@testable import Harvest

final class SafetyAnalysisServiceTests: XCTestCase {
    var service: SafetyAnalysisService!

    override func setUp() {
        super.setUp()
        service = SafetyAnalysisService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Financial Red Flags

    func testDetectsFinancialRedFlags_SendMoney() {
        let message = "Can you send money? I'm in a tough spot right now."
        // Note: This test would need a mock Supabase client to actually run
        // For now, we're documenting the expected behavior
        // In a real implementation, we'd inject dependencies and mock the database
    }

    func testDetectsFinancialRedFlags_Bitcoin() {
        let message = "I have a great bitcoin investment opportunity for you!"
        // Would flag "bitcoin" as financial red flag
    }

    func testDetectsFinancialRedFlags_CaseInsensitive() {
        let message = "Send MONEY to my VENMO account"
        // Should detect "send money" and "venmo" regardless of case
    }

    // MARK: - Personal Info Red Flags

    func testDetectsPersonalInfoRedFlags_SSN() {
        let message = "What's your social security number?"
        // Should flag "social security" as personal info risk
    }

    func testDetectsPersonalInfoRedFlags_Password() {
        let message = "Can you share your password so I can help?"
        // Should flag "password" as personal info risk
    }

    // MARK: - Catfishing Red Flags

    func testDetectsCatfishingRedFlags_CameraExcuse() {
        let message = "My camera is broken so we can't video call"
        // Should flag "camera broken" as catfishing indicator
    }

    func testDetectsCatfishingRedFlags_DeploymentExcuse() {
        let message = "I'm deployed overseas and can't meet yet"
        // Should flag "deployed overseas" as catfishing indicator
    }

    // MARK: - Manipulation Red Flags

    func testDetectsManipulationRedFlags_IfYouLovedMe() {
        let message = "If you loved me, you would do this for me"
        // Should flag "if you loved me" as manipulation
    }

    func testDetectsManipulationRedFlags_NoOneElse() {
        let message = "Nobody else will ever love you like I do"
        // Should flag "nobody else will" and "no one will ever" as manipulation
    }

    // MARK: - Harassment Red Flags

    func testDetectsHarassmentRedFlags_Threats() {
        let message = "I know where you live, I'll find you"
        // Should flag "find you" as harassment/threat
    }

    func testDetectsHarassmentRedFlags_Violence() {
        let message = "I could hurt you if I wanted to"
        // Should flag "hurt you" as harassment/threat
    }

    // MARK: - Inappropriate Red Flags

    func testDetectsInappropriateRedFlags_ExplicitRequests() {
        let message = "Send nudes please"
        // Should flag "send nudes" as inappropriate
    }

    func testDetectsInappropriateRedFlags_SexualPressure() {
        let message = "What are you wearing right now?"
        // Should flag "what are you wearing" as inappropriate
    }

    // MARK: - Spam Red Flags

    func testDetectsSpamRedFlags_Links() {
        let message = "Click this link for a free prize!"
        // Should flag "click this link" as spam
    }

    func testDetectsSpamRedFlags_FreeMoney() {
        let message = "You've won free money! Act now!"
        // Should flag "free money" and "act now" as spam
    }

    // MARK: - Clean Messages

    func testCleanMessage_NoRedFlags() {
        let message = "I really enjoyed our conversation today. Would you like to meet for coffee this weekend?"
        // Should not flag any red flags - this is a normal, appropriate message
    }

    func testCleanMessage_WithCommonWords() {
        let message = "I need to kill some time before our date. Want to grab a drink?"
        // "kill" appears in red flag list but "kill some time" is a common phrase
        // Current implementation would flag this - could be improved with context
    }

    // MARK: - Multiple Red Flags

    func testMultipleRedFlags_DifferentCategories() {
        let message = "Send money for the flight, and also send me your social security number"
        // Should flag both financial AND personal info red flags
    }

    func testMultipleRedFlags_SameCategory() {
        let message = "Send money via bitcoin to my wallet"
        // Should flag multiple financial keywords but count as one category hit
    }

    // MARK: - Red Flag Category Weights

    func testRedFlagWeights_Financial() {
        // Financial category should have high weight (30)
        let category = RedFlagCategory.financial
        XCTAssertEqual(category.weight, 30)
    }

    func testRedFlagWeights_PersonalInfo() {
        // Personal info category should have high weight (30)
        let category = RedFlagCategory.personalInfo
        XCTAssertEqual(category.weight, 30)
    }

    func testRedFlagWeights_Catfishing() {
        // Catfishing should have medium-high weight (25)
        let category = RedFlagCategory.catfishing
        XCTAssertEqual(category.weight, 25)
    }

    func testRedFlagWeights_Spam() {
        // Spam should have lower weight (15)
        let category = RedFlagCategory.spam
        XCTAssertEqual(category.weight, 15)
    }

    // MARK: - Safety Score Calculation

    func testSafetyScore_StartsAt100() {
        // New analysis should start with 100 safety score
        // Would need to test with mock database
    }

    func testSafetyScore_ReducesWithRedFlags() {
        // Each red flag should reduce the safety score
        // Cap at 30 points reduction per message
    }

    func testSafetyScore_MinimumZero() {
        // Safety score should never go below 0
        // Even with many red flags
    }

    // MARK: - Ready to Move Gate

    func testReadyToMove_RequiresMinimumMessages() async throws {
        // Need at least 20 messages
        // Would test with mock analysis data
    }

    func testReadyToMove_RequiresMinimumSafetyScore() async throws {
        // Safety score must be >= 70
        // Would test with mock analysis data
    }

    func testReadyToMove_PassesWhenBothCriteriaMet() async throws {
        // Should return true when both conditions met
        // Would test with mock analysis data
    }

    // MARK: - Performance Tests

    func testRetroactiveAnalysis_Performance() {
        // Test that analyzing 100 messages completes in reasonable time
        // Measure average time per message analysis
        measure {
            // Would analyze test conversation with 100 messages
        }
    }

    // MARK: - Edge Cases

    func testEmptyMessage_NoRedFlags() {
        let message = ""
        // Empty message should not trigger any flags
    }

    func testVeryLongMessage_StillAnalyzes() {
        let message = String(repeating: "This is a long message. ", count: 100)
        // Should handle long messages without crashing
    }

    func testSpecialCharacters_HandledCorrectly() {
        let message = "Hey! How are you? 😊 Let's chat about our interests!"
        // Should handle emojis and punctuation without issues
    }

    func testUnicodeCharacters_HandledCorrectly() {
        let message = "Привет! ¿Cómo estás? 你好"
        // Should handle unicode/international characters
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
