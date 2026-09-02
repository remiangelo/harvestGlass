import Foundation
@testable import Harvest

/// Mock Supabase client for testing
/// This allows us to test services without making real database calls
class MockSupabaseClient {
    var mockUsers: [UserProfile] = []
    var mockMessages: [Message] = []
    var mockMatches: [(user1: String, user2: String)] = []
    var mockValues: [String: (brought: [Value], sought: [Value])] = [:]
    var mockSubscriptions: [String: SubscriptionTier] = [:]

    // Track method calls for verification
    var insertCalls: [(table: String, data: Any)] = []
    var selectCalls: [String] = []
    var updateCalls: [(table: String, data: Any)] = []
    var deleteCalls: [String] = []

    func reset() {
        mockUsers = []
        mockMessages = []
        mockMatches = []
        mockValues = [:]
        mockSubscriptions = [:]
        insertCalls = []
        selectCalls = []
        updateCalls = []
        deleteCalls = []
    }

    // MARK: - Mock Data Setup

    func addMockUser(_ user: UserProfile) {
        mockUsers.append(user)
    }

    func addMockMessage(_ message: Message) {
        mockMessages.append(message)
    }

    func addMockMatch(user1: String, user2: String) {
        mockMatches.append((user1, user2))
    }

    func addMockValues(userId: String, brought: [Value], sought: [Value]) {
        mockValues[userId] = (brought, sought)
    }

    func addMockSubscription(userId: String, tier: SubscriptionTier) {
        mockSubscriptions[userId] = tier
    }
}

// MARK: - Test Helpers

extension MockSupabaseClient {
    static func createTestUser(
        id: String = "test-user-1",
        name: String = "Test User",
        age: Int = 28,
        hobbies: [String] = ["Reading", "Hiking", "Cooking"],
        goals: [String] = ["Long-term relationship"]
    ) -> UserProfile {
        UserProfile(
            id: id,
            email: "\(id)@test.com",
            nickname: name,
            age: age,
            gender: "Non-binary",
            interestedIn: ["Women", "Men"],
            location: "Test City",
            photos: ["\(id)-photo1.jpg"],
            hobbies: hobbies,
            goals: goals,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    static func createTestValue(
        id: String = "test-value-1",
        name: String = "Honesty",
        category: String = "Core"
    ) -> Value {
        Value(
            id: id,
            name: name,
            category: category,
            description: "Test value description",
            iconName: "heart.fill"
        )
    }

    /// Mirrors the production tier rows (see
    /// 20260811100000_subscription_tiers_restructure.sql) so tests exercise the
    /// same allowances users get.
    static func createTestTier(
        name: TierName = .seed,
        gardenerConversationsPerDay: Int? = nil,
        gardenerCharacterLimit: Int? = nil,
        gardenerScreenshotsPerDay: Int? = nil,
        gardenerImagesPerReview: Int? = nil
    ) -> SubscriptionTier {
        let defaultCharacters: Int
        let defaultScreenshots: Int
        let defaultImagesPerReview: Int
        let filterLevel: FieldFilterLevel

        switch name {
        case .seed:
            defaultCharacters = 2_000
            defaultScreenshots = 1
            defaultImagesPerReview = 3
            filterLevel = .none
        case .green:
            defaultCharacters = 10_000
            defaultScreenshots = 5
            defaultImagesPerReview = 6
            filterLevel = .advanced
        case .gold:
            defaultCharacters = 25_000
            defaultScreenshots = 20
            defaultImagesPerReview = 10
            filterLevel = .full
        }

        return SubscriptionTier(
            id: "test-tier-\(name.rawValue)",
            name: name,
            displayName: name.rawValue.capitalized,
            description: "Test \(name.rawValue) tier",
            priceMonthly: name == .seed ? 0 : (name == .green ? 19.99 : 24.99),
            priceWeekly: name == .seed ? 0 : 6.99,
            gardenerConversationsPerDay: gardenerConversationsPerDay,
            gardenerCharacterLimit: gardenerCharacterLimit ?? defaultCharacters,
            gardenerScreenshotsPerDay: gardenerScreenshotsPerDay ?? defaultScreenshots,
            gardenerImagesPerReview: gardenerImagesPerReview ?? defaultImagesPerReview,
            fieldFilterLevel: filterLevel,
            hasDeepSoilInsights: name != .seed,
            hasGrowthFeatures: name == .gold,
            canDisableMindfulMessaging: name == .gold,
            sortOrder: 0,
            dailySeedLimit: name == .seed ? 3 : (name == .green ? 5 : 25)
        )
    }
}
