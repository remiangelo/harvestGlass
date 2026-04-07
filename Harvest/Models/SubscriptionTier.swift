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
    let priceWeekly: Double
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

    var marketingDisplayName: String {
        switch name {
        case .green:
            return "Grow"
        case .seed, .gold:
            return displayName
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case displayName = "display_name"
        case priceMonthly = "price_monthly"
        case priceWeekly = "price_weekly"
        case legacyPriceYearly = "price_yearly"
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

    init(
        id: String,
        name: TierName,
        displayName: String,
        description: String,
        priceMonthly: Double,
        priceWeekly: Double,
        matchesPerWeek: Int?,
        maxDistanceMiles: Int?,
        gardenerConversationsPerDay: Int?,
        gardenerCharacterLimit: Int,
        hasValuesMatching: Bool,
        hasBasicFilters: Bool,
        hasAdvancedFilters: Bool,
        hasFullFilters: Bool,
        canSeeLikes: Bool,
        canDisableMindfulMessaging: Bool,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.priceMonthly = priceMonthly
        self.priceWeekly = priceWeekly
        self.matchesPerWeek = matchesPerWeek
        self.maxDistanceMiles = maxDistanceMiles
        self.gardenerConversationsPerDay = gardenerConversationsPerDay
        self.gardenerCharacterLimit = gardenerCharacterLimit
        self.hasValuesMatching = hasValuesMatching
        self.hasBasicFilters = hasBasicFilters
        self.hasAdvancedFilters = hasAdvancedFilters
        self.hasFullFilters = hasFullFilters
        self.canSeeLikes = canSeeLikes
        self.canDisableMindfulMessaging = canDisableMindfulMessaging
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(TierName.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decode(String.self, forKey: .description)
        priceMonthly = try container.decode(Double.self, forKey: .priceMonthly)
        priceWeekly = try container.decodeIfPresent(Double.self, forKey: .priceWeekly)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyPriceYearly)
            ?? 0
        matchesPerWeek = try container.decodeIfPresent(Int.self, forKey: .matchesPerWeek)
        maxDistanceMiles = try container.decodeIfPresent(Int.self, forKey: .maxDistanceMiles)
        gardenerConversationsPerDay = try container.decodeIfPresent(Int.self, forKey: .gardenerConversationsPerDay)
        gardenerCharacterLimit = try container.decode(Int.self, forKey: .gardenerCharacterLimit)
        hasValuesMatching = try container.decode(Bool.self, forKey: .hasValuesMatching)
        hasBasicFilters = try container.decode(Bool.self, forKey: .hasBasicFilters)
        hasAdvancedFilters = try container.decode(Bool.self, forKey: .hasAdvancedFilters)
        hasFullFilters = try container.decode(Bool.self, forKey: .hasFullFilters)
        canSeeLikes = try container.decode(Bool.self, forKey: .canSeeLikes)
        canDisableMindfulMessaging = try container.decode(Bool.self, forKey: .canDisableMindfulMessaging)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(priceMonthly, forKey: .priceMonthly)
        try container.encode(priceWeekly, forKey: .priceWeekly)
        try container.encodeIfPresent(matchesPerWeek, forKey: .matchesPerWeek)
        try container.encodeIfPresent(maxDistanceMiles, forKey: .maxDistanceMiles)
        try container.encodeIfPresent(gardenerConversationsPerDay, forKey: .gardenerConversationsPerDay)
        try container.encode(gardenerCharacterLimit, forKey: .gardenerCharacterLimit)
        try container.encode(hasValuesMatching, forKey: .hasValuesMatching)
        try container.encode(hasBasicFilters, forKey: .hasBasicFilters)
        try container.encode(hasAdvancedFilters, forKey: .hasAdvancedFilters)
        try container.encode(hasFullFilters, forKey: .hasFullFilters)
        try container.encode(canSeeLikes, forKey: .canSeeLikes)
        try container.encode(canDisableMindfulMessaging, forKey: .canDisableMindfulMessaging)
        try container.encode(sortOrder, forKey: .sortOrder)
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
