import XCTest
@testable import Harvest

final class CompatibilityServiceTests: XCTestCase {
    var service: CompatibilityService!

    override func setUp() {
        super.setUp()
        service = CompatibilityService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Interest Scoring Tests

    func testInterestScore_NoSharedInterests() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            hobbies: ["Reading", "Hiking"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            hobbies: ["Gaming", "Cooking"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // No shared interests should give minimal interest score
        XCTAssertLessThan(score.interestsScore, 20)
    }

    func testInterestScore_AllSharedInterests() {
        let sharedHobbies = ["Reading", "Hiking", "Cooking"]
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            hobbies: sharedHobbies
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            hobbies: sharedHobbies
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // 100% overlap should give maximum interest score (40)
        XCTAssertEqual(score.interestsScore, 40)
    }

    func testInterestScore_PartialOverlap() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            hobbies: ["Reading", "Hiking", "Cooking"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            hobbies: ["Reading", "Gaming", "Movies"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // 1 shared out of 5 total unique = 20% overlap
        // Should give score between 0 and 40
        XCTAssertGreaterThan(score.interestsScore, 0)
        XCTAssertLessThan(score.interestsScore, 40)
    }

    func testInterestScore_CaseInsensitive() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            hobbies: ["reading", "hiking"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            hobbies: ["Reading", "Hiking"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // Case shouldn't matter
        XCTAssertEqual(score.interestsScore, 40)
    }

    func testInterestScore_EmptyHobbies() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            hobbies: []
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            hobbies: ["Reading"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // Empty hobbies should give neutral score (20)
        XCTAssertEqual(score.interestsScore, 20)
    }

    // MARK: - Values Scoring Tests

    func testValuesScore_PerfectMatch() {
        let value1 = MockSupabaseClient.createTestValue(id: "v1", name: "Honesty")
        let value2 = MockSupabaseClient.createTestValue(id: "v2", name: "Loyalty")

        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")

        // User1 seeks what User2 brings, and vice versa
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserValuesBrought: [value1],
            currentUserValuesSought: [value2],
            otherUserValuesBrought: [value2],
            otherUserValuesSought: [value1]
        )

        // Perfect bidirectional match should give maximum values score (30)
        XCTAssertEqual(score.valuesScore, 30)
    }

    func testValuesScore_NoMatch() {
        let value1 = MockSupabaseClient.createTestValue(id: "v1", name: "Honesty")
        let value2 = MockSupabaseClient.createTestValue(id: "v2", name: "Loyalty")
        let value3 = MockSupabaseClient.createTestValue(id: "v3", name: "Adventure")
        let value4 = MockSupabaseClient.createTestValue(id: "v4", name: "Stability")

        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")

        // No overlap between what they seek and bring
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserValuesBrought: [value1],
            currentUserValuesSought: [value2],
            otherUserValuesBrought: [value3],
            otherUserValuesSought: [value4]
        )

        // No match should give 0 values score
        XCTAssertEqual(score.valuesScore, 0)
    }

    func testValuesScore_PartialMatch() {
        let value1 = MockSupabaseClient.createTestValue(id: "v1", name: "Honesty")
        let value2 = MockSupabaseClient.createTestValue(id: "v2", name: "Loyalty")
        let value3 = MockSupabaseClient.createTestValue(id: "v3", name: "Adventure")

        let user1 = MockSupabaseClient.createTestUser(id: "user1")
        let user2 = MockSupabaseClient.createTestUser(id: "user2")

        // User1 seeks value2, User2 brings value2 (50% match one direction)
        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserValuesBrought: [value1],
            currentUserValuesSought: [value2],
            otherUserValuesBrought: [value2, value3],
            otherUserValuesSought: [value3]
        )

        // Partial match should give between 0 and 30
        XCTAssertGreaterThan(score.valuesScore, 0)
        XCTAssertLessThan(score.valuesScore, 30)
    }

    // MARK: - Goals Scoring Tests

    func testGoalsScore_SharedGoal() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            goals: ["Long-term relationship"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            goals: ["Long-term relationship", "Marriage"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // One shared goal should give 10 points
        XCTAssertEqual(score.goalsScore, 10)
    }

    func testGoalsScore_MultipleSharedGoals() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            goals: ["Long-term relationship", "Marriage"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            goals: ["Long-term relationship", "Marriage"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // Multiple shared goals should give 15 points
        XCTAssertEqual(score.goalsScore, 15)
    }

    func testGoalsScore_NoSharedGoals() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            goals: ["Casual dating"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            goals: ["Marriage"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // No shared goals should give 0 points
        XCTAssertEqual(score.goalsScore, 0)
    }

    // MARK: - Age Scoring Tests

    func testAgeScore_SameAge() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1", age: 28)
        let user2 = MockSupabaseClient.createTestUser(id: "user2", age: 28)

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // Same age should give 10 points
        XCTAssertEqual(score.ageScore, 10)
    }

    func testAgeScore_SmallDifference() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1", age: 28)
        let user2 = MockSupabaseClient.createTestUser(id: "user2", age: 30)

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // 2 year difference should give 10 points
        XCTAssertEqual(score.ageScore, 10)
    }

    func testAgeScore_MediumDifference() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1", age: 25)
        let user2 = MockSupabaseClient.createTestUser(id: "user2", age: 29)

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // 4 year difference should give 7 points
        XCTAssertEqual(score.ageScore, 7)
    }

    func testAgeScore_LargeDifference() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1", age: 25)
        let user2 = MockSupabaseClient.createTestUser(id: "user2", age: 40)

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // 15 year difference should give 2 points
        XCTAssertEqual(score.ageScore, 2)
    }

    // MARK: - Total Score Tests

    func testTotalScore_ExcellentMatch() {
        let sharedHobbies = ["Reading", "Hiking", "Cooking"]
        let sharedGoals = ["Long-term relationship", "Marriage"]
        let value1 = MockSupabaseClient.createTestValue(id: "v1", name: "Honesty")
        let value2 = MockSupabaseClient.createTestValue(id: "v2", name: "Loyalty")

        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            age: 28,
            hobbies: sharedHobbies,
            goals: sharedGoals
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            age: 29,
            hobbies: sharedHobbies,
            goals: sharedGoals
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2,
            currentUserValuesBrought: [value1],
            currentUserValuesSought: [value2],
            otherUserValuesBrought: [value2],
            otherUserValuesSought: [value1]
        )

        // Excellent match should score 80+
        // Interests: 40, Values: 30, Goals: 15, Age: 7, Distance: 5 = 97
        XCTAssertGreaterThanOrEqual(score.total, 80)
        XCTAssertEqual(score.compatibilityLevel, "Excellent Match")
    }

    func testTotalScore_PoorMatch() {
        let user1 = MockSupabaseClient.createTestUser(
            id: "user1",
            age: 25,
            hobbies: ["Reading"],
            goals: ["Casual dating"]
        )
        let user2 = MockSupabaseClient.createTestUser(
            id: "user2",
            age: 45,
            hobbies: ["Gaming"],
            goals: ["Marriage"]
        )

        let score = service.calculateCompatibility(
            currentUser: user1,
            otherUser: user2
        )

        // Poor match should score low
        XCTAssertLessThan(score.total, 40)
        XCTAssertTrue(score.compatibilityLevel.contains("Low") || score.compatibilityLevel.contains("Fair"))
    }

    // MARK: - Ranking Tests

    func testRankProfiles_SortsByCompatibility() {
        let user1 = MockSupabaseClient.createTestUser(id: "user1", hobbies: ["Reading", "Hiking"])

        // High compatibility profile
        let user2 = MockSupabaseClient.createTestUser(id: "user2", age: 27, hobbies: ["Reading", "Hiking"])

        // Medium compatibility profile
        let user3 = MockSupabaseClient.createTestUser(id: "user3", age: 30, hobbies: ["Reading"])

        // Low compatibility profile
        let user4 = MockSupabaseClient.createTestUser(id: "user4", age: 45, hobbies: ["Gaming"])

        let ranked = service.rankProfiles(
            currentUser: user1,
            profiles: [user4, user2, user3], // Intentionally unsorted
            currentUserValuesBrought: [],
            currentUserValuesSought: [],
            otherUsersValues: [:]
        )

        // Should be sorted high to low
        XCTAssertEqual(ranked[0].profile.id, "user2")
        XCTAssertEqual(ranked[1].profile.id, "user3")
        XCTAssertEqual(ranked[2].profile.id, "user4")

        // Scores should be descending
        XCTAssertGreaterThan(ranked[0].score.total, ranked[1].score.total)
        XCTAssertGreaterThan(ranked[1].score.total, ranked[2].score.total)
    }
}
