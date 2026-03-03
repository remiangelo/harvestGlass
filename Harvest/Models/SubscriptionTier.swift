import Foundation

enum TierName: String, Codable, Sendable {
    case seed
    case green
    case gold
}

struct SubscriptionTier: Codable, Identifiable, Sendable {
    let id: String
    let name: TierName
    let displayName: String
    let description: String
    let priceMonthly: Double
    let priceYearly: Double
    let matchesPerWeek: Int?
    let maxDistanceMiles: Int?
    let gardenerConversationsPerDay: Int?
    let gardenerCharacterLimit: Int
    let hasValuesMatching: Bool
    let hasBasicFilters: Bool
    let hasAdvancedFilters: Bool
    let hasFullFilters: Bool
    let canSeeLikes: Bool
    let canDisableMindfulMessaging: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case displayName = "display_name"
        case priceMonthly = "price_monthly"
        case priceYearly = "price_yearly"
        case matchesPerWeek = "matches_per_week"
        case maxDistanceMiles = "max_distance_miles"
        case gardenerConversationsPerDay = "gardener_conversations_per_day"
        case gardenerCharacterLimit = "gardener_character_limit"
        case hasValuesMatching = "has_values_matching"
        case hasBasicFilters = "has_basic_filters"
        case hasAdvancedFilters = "has_advanced_filters"
        case hasFullFilters = "has_full_filters"
        case canSeeLikes = "can_see_likes"
        case canDisableMindfulMessaging = "can_disable_mindful_messaging"
        case sortOrder = "sort_order"
    }
}

struct UserSubscription: Codable, Sendable {
    let id: String
    let userId: String
    let tierId: String
    let status: String
    let startedAt: String?
    let cancelledAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userId = "user_id"
        case tierId = "tier_id"
        case startedAt = "started_at"
        case cancelledAt = "cancelled_at"
    }
}
