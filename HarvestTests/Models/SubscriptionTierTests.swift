import XCTest
@testable import Harvest

final class SubscriptionTierTests: XCTestCase {

    private func decodeTier(_ json: String) throws -> SubscriptionTier {
        try JSONDecoder().decode(SubscriptionTier.self, from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testDecodesTheNewTierShape() throws {
        let tier = try decodeTier("""
        {
          "id": "tier-green",
          "name": "green",
          "display_name": "Green",
          "description": "",
          "price_monthly": 19.99,
          "price_weekly": 6.99,
          "gardener_character_limit": 10000,
          "gardener_screenshots_per_day": 5,
          "field_filter_level": "advanced",
          "has_deep_soil_insights": true,
          "has_growth_features": false,
          "can_disable_mindful_messaging": false,
          "sort_order": 1,
          "daily_seed_limit": 5
        }
        """)

        XCTAssertEqual(tier.name, .green)
        XCTAssertEqual(tier.dailySeedLimit, 5)
        XCTAssertEqual(tier.gardenerCharacterLimit, 10_000)
        XCTAssertEqual(tier.gardenerScreenshotsPerDay, 5)
        XCTAssertEqual(tier.fieldFilterLevel, .advanced)
        XCTAssertTrue(tier.hasDeepSoilInsights)
        XCTAssertFalse(tier.hasGrowthFeatures)
        XCTAssertTrue(tier.isPaid)
    }

    /// A row that predates the migration must still decode — the app ships
    /// before the SQL is applied.
    func testDecodesARowMissingTheNewColumns() throws {
        let tier = try decodeTier("""
        {
          "id": "tier-seed",
          "name": "seed",
          "display_name": "Seed",
          "description": "",
          "price_monthly": 0,
          "price_weekly": 0,
          "gardener_character_limit": 2000,
          "can_disable_mindful_messaging": false,
          "sort_order": 0
        }
        """)

        XCTAssertEqual(tier.gardenerScreenshotsPerDay, 1)
        XCTAssertEqual(tier.fieldFilterLevel, FieldFilterLevel.none)
        XCTAssertFalse(tier.hasDeepSoilInsights)
        XCTAssertFalse(tier.hasGrowthFeatures)
        XCTAssertEqual(tier.dailySeedLimit, 3)
        XCTAssertFalse(tier.isPaid)
    }

    /// An unrecognised level locks the filters rather than failing the whole
    /// tier load, which would leave the app with no tier at all.
    func testUnknownFilterLevelDecodesAsLocked() throws {
        let tier = try decodeTier("""
        {
          "id": "tier-x",
          "name": "gold",
          "display_name": "Gold",
          "description": "",
          "price_monthly": 24.99,
          "price_weekly": 6.99,
          "gardener_character_limit": 25000,
          "field_filter_level": "platinum",
          "can_disable_mindful_messaging": true,
          "sort_order": 2
        }
        """)

        XCTAssertEqual(tier.fieldFilterLevel, FieldFilterLevel.none)
    }

    func testRoundTripsThroughEncoding() throws {
        let original = MockSupabaseClient.createTestTier(name: .gold)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SubscriptionTier.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.dailySeedLimit, original.dailySeedLimit)
        XCTAssertEqual(decoded.gardenerScreenshotsPerDay, original.gardenerScreenshotsPerDay)
        XCTAssertEqual(decoded.fieldFilterLevel, original.fieldFilterLevel)
        XCTAssertEqual(decoded.hasGrowthFeatures, original.hasGrowthFeatures)
    }

    // MARK: - Gates

    func testFilterLevelGates() {
        XCTAssertFalse(FieldFilterLevel.none.unlocksAdvanced)
        XCTAssertFalse(FieldFilterLevel.none.unlocksFull)
        XCTAssertTrue(FieldFilterLevel.advanced.unlocksAdvanced)
        XCTAssertFalse(FieldFilterLevel.advanced.unlocksFull)
        XCTAssertTrue(FieldFilterLevel.full.unlocksAdvanced)
        XCTAssertTrue(FieldFilterLevel.full.unlocksFull)
    }

    /// The shipped matrix. Prices are unchanged by this rework.
    func testTierMatrixMatchesTheMigration() {
        let seed = MockSupabaseClient.createTestTier(name: .seed)
        let green = MockSupabaseClient.createTestTier(name: .green)
        let gold = MockSupabaseClient.createTestTier(name: .gold)

        XCTAssertEqual([seed.priceMonthly, green.priceMonthly, gold.priceMonthly], [0, 19.99, 24.99])
        XCTAssertEqual([seed.dailySeedLimit, green.dailySeedLimit, gold.dailySeedLimit], [3, 5, 25])
        XCTAssertEqual(
            [seed.gardenerCharacterLimit, green.gardenerCharacterLimit, gold.gardenerCharacterLimit],
            [2_000, 10_000, 25_000]
        )
        XCTAssertEqual(
            [seed.gardenerScreenshotsPerDay, green.gardenerScreenshotsPerDay, gold.gardenerScreenshotsPerDay],
            [1, 5, 20]
        )
        XCTAssertEqual(
            [seed.fieldFilterLevel, green.fieldFilterLevel, gold.fieldFilterLevel],
            [FieldFilterLevel.none, .advanced, .full]
        )
        XCTAssertEqual(
            [seed.hasDeepSoilInsights, green.hasDeepSoilInsights, gold.hasDeepSoilInsights],
            [false, true, true]
        )
        XCTAssertEqual(
            [seed.hasGrowthFeatures, green.hasGrowthFeatures, gold.hasGrowthFeatures],
            [false, false, true]
        )
    }

    func testMarketingNameRenamesGreenOnly() {
        XCTAssertEqual(MockSupabaseClient.createTestTier(name: .green).marketingDisplayName, "Grow")
        XCTAssertEqual(MockSupabaseClient.createTestTier(name: .seed).marketingDisplayName, "Seed")
        XCTAssertEqual(MockSupabaseClient.createTestTier(name: .gold).marketingDisplayName, "Gold")
    }
}
