import Foundation

enum TierName: String, Codable, Sendable {
    case seed
    case green
    case gold

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()

        switch rawValue {
        case "seed":
            self = .seed
        case "green", "grow":
            self = .green
        case "gold":
            self = .gold
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown tier name: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// How much of the member-roster and profile filtering a tier unlocks.
///
/// The roster and the profile filters used to branch on `TierName`, which meant
/// the tier table and the code could disagree about what a plan bought. The
/// table is the source of truth now.
enum FieldFilterLevel: String, Codable, Sendable {
    case none
    case advanced
    case full

    /// Unknown values decode as `.none` rather than throwing: a filter that
    /// silently stays locked is a better failure than a tier that won't load.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        self = FieldFilterLevel(rawValue: rawValue) ?? .none
    }

    var unlocksAdvanced: Bool { self != .none }
    var unlocksFull: Bool { self == .full }
}

struct SubscriptionTier: Codable, Identifiable, Sendable {
    let id: String
    let name: TierName
    let displayName: String
    let description: String
    let priceMonthly: Double
    let priceWeekly: Double
    let gardenerConversationsPerDay: Int?
    let gardenerCharacterLimit: Int
    /// Screenshot reviews per day. Separate from the character budget — a
    /// review no longer eats the day's chat allowance.
    let gardenerScreenshotsPerDay: Int
    /// Max images attachable to one Gardener message. Separate from
    /// `gardenerScreenshotsPerDay`: a message carrying several screenshots is
    /// still one review.
    let gardenerImagesPerReview: Int
    let fieldFilterLevel: FieldFilterLevel
    let hasDeepSoilInsights: Bool
    let hasGrowthFeatures: Bool
    let canDisableMindfulMessaging: Bool
    let sortOrder: Int
    let dailySeedLimit: Int

    var marketingDisplayName: String {
        switch name {
        case .green:
            return "Grow"
        case .seed, .gold:
            return displayName
        }
    }

    /// Any paid plan. Used by the legacy "Likes You" list, which the swipe-era
    /// `can_see_likes` column used to gate.
    var isPaid: Bool { priceMonthly > 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case displayName = "display_name"
        case priceMonthly = "price_monthly"
        case priceWeekly = "price_weekly"
        case legacyPriceYearly = "price_yearly"
        case gardenerConversationsPerDay = "gardener_conversations_per_day"
        case gardenerCharacterLimit = "gardener_character_limit"
        case gardenerScreenshotsPerDay = "gardener_screenshots_per_day"
        case gardenerImagesPerReview = "gardener_images_per_review"
        case fieldFilterLevel = "field_filter_level"
        case hasDeepSoilInsights = "has_deep_soil_insights"
        case hasGrowthFeatures = "has_growth_features"
        case canDisableMindfulMessaging = "can_disable_mindful_messaging"
        case sortOrder = "sort_order"
        case dailySeedLimit = "daily_seed_limit"
    }

    init(
        id: String,
        name: TierName,
        displayName: String,
        description: String,
        priceMonthly: Double,
        priceWeekly: Double,
        gardenerConversationsPerDay: Int?,
        gardenerCharacterLimit: Int,
        gardenerScreenshotsPerDay: Int = 1,
        gardenerImagesPerReview: Int = 1,
        fieldFilterLevel: FieldFilterLevel = .none,
        hasDeepSoilInsights: Bool = false,
        hasGrowthFeatures: Bool = false,
        canDisableMindfulMessaging: Bool,
        sortOrder: Int,
        dailySeedLimit: Int = 3
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.priceMonthly = priceMonthly
        self.priceWeekly = priceWeekly
        self.gardenerConversationsPerDay = gardenerConversationsPerDay
        self.gardenerCharacterLimit = gardenerCharacterLimit
        self.gardenerScreenshotsPerDay = gardenerScreenshotsPerDay
        self.gardenerImagesPerReview = gardenerImagesPerReview
        self.fieldFilterLevel = fieldFilterLevel
        self.hasDeepSoilInsights = hasDeepSoilInsights
        self.hasGrowthFeatures = hasGrowthFeatures
        self.canDisableMindfulMessaging = canDisableMindfulMessaging
        self.sortOrder = sortOrder
        self.dailySeedLimit = dailySeedLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(TierName.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        priceMonthly = try container.decode(Double.self, forKey: .priceMonthly)
        priceWeekly = try container.decodeIfPresent(Double.self, forKey: .priceWeekly)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyPriceYearly)
            ?? 0
        gardenerConversationsPerDay = try container.decodeIfPresent(Int.self, forKey: .gardenerConversationsPerDay)
        gardenerCharacterLimit = try container.decode(Int.self, forKey: .gardenerCharacterLimit)
        gardenerScreenshotsPerDay = try container.decodeIfPresent(Int.self, forKey: .gardenerScreenshotsPerDay) ?? 1
        gardenerImagesPerReview = try container.decodeIfPresent(Int.self, forKey: .gardenerImagesPerReview) ?? 1
        fieldFilterLevel = try container.decodeIfPresent(FieldFilterLevel.self, forKey: .fieldFilterLevel) ?? .none
        hasDeepSoilInsights = try container.decodeIfPresent(Bool.self, forKey: .hasDeepSoilInsights) ?? false
        hasGrowthFeatures = try container.decodeIfPresent(Bool.self, forKey: .hasGrowthFeatures) ?? false
        canDisableMindfulMessaging = try container.decode(Bool.self, forKey: .canDisableMindfulMessaging)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        dailySeedLimit = try container.decodeIfPresent(Int.self, forKey: .dailySeedLimit) ?? 3
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(priceMonthly, forKey: .priceMonthly)
        try container.encode(priceWeekly, forKey: .priceWeekly)
        try container.encodeIfPresent(gardenerConversationsPerDay, forKey: .gardenerConversationsPerDay)
        try container.encode(gardenerCharacterLimit, forKey: .gardenerCharacterLimit)
        try container.encode(gardenerScreenshotsPerDay, forKey: .gardenerScreenshotsPerDay)
        try container.encode(gardenerImagesPerReview, forKey: .gardenerImagesPerReview)
        try container.encode(fieldFilterLevel, forKey: .fieldFilterLevel)
        try container.encode(hasDeepSoilInsights, forKey: .hasDeepSoilInsights)
        try container.encode(hasGrowthFeatures, forKey: .hasGrowthFeatures)
        try container.encode(canDisableMindfulMessaging, forKey: .canDisableMindfulMessaging)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(dailySeedLimit, forKey: .dailySeedLimit)
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
