import Foundation
import Supabase
import StoreKit

struct SubscriptionService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct SubscriptionTierDTO: Decodable {
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(TierName.self, forKey: .name)
            displayName = try container.decode(String.self, forKey: .displayName)
            description = try container.decode(String.self, forKey: .description)
            priceMonthly = try Self.decodeDouble(in: container, forKey: .priceMonthly) ?? 0
            let weeklyPrice = try Self.decodeDouble(in: container, forKey: .priceWeekly)
            let legacyPrice = try Self.decodeDouble(in: container, forKey: .legacyPriceYearly)
            priceWeekly = weeklyPrice ?? legacyPrice ?? 0
            matchesPerWeek = try Self.decodeInt(in: container, forKey: .matchesPerWeek)
            maxDistanceMiles = try Self.decodeInt(in: container, forKey: .maxDistanceMiles)
            gardenerConversationsPerDay = try Self.decodeInt(in: container, forKey: .gardenerConversationsPerDay)
            gardenerCharacterLimit = try Self.decodeInt(in: container, forKey: .gardenerCharacterLimit) ?? 1000
            hasValuesMatching = try container.decodeIfPresent(Bool.self, forKey: .hasValuesMatching) ?? false
            hasBasicFilters = try container.decodeIfPresent(Bool.self, forKey: .hasBasicFilters) ?? false
            hasAdvancedFilters = try container.decodeIfPresent(Bool.self, forKey: .hasAdvancedFilters) ?? false
            hasFullFilters = try container.decodeIfPresent(Bool.self, forKey: .hasFullFilters) ?? false
            canSeeLikes = try container.decodeIfPresent(Bool.self, forKey: .canSeeLikes) ?? false
            canDisableMindfulMessaging = try container.decodeIfPresent(Bool.self, forKey: .canDisableMindfulMessaging) ?? false
            sortOrder = try Self.decodeInt(in: container, forKey: .sortOrder) ?? 0
        }

        private static func decodeDouble(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double? {
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let intValue = try container.decodeIfPresent(Int.self, forKey: key) {
                return Double(intValue)
            }
            if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
                return Double(stringValue)
            }
            return nil
        }

        private static func decodeInt(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int? {
            if let value = try container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let doubleValue = try container.decodeIfPresent(Double.self, forKey: key) {
                return Int(doubleValue)
            }
            if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
                return Int(stringValue)
            }
            return nil
        }

        var tier: SubscriptionTier {
            SubscriptionTier(
                id: id,
                name: name,
                displayName: displayName,
                description: description,
                priceMonthly: priceMonthly,
                priceWeekly: priceWeekly,
                matchesPerWeek: matchesPerWeek,
                maxDistanceMiles: maxDistanceMiles,
                gardenerConversationsPerDay: gardenerConversationsPerDay,
                gardenerCharacterLimit: gardenerCharacterLimit,
                hasValuesMatching: hasValuesMatching,
                hasBasicFilters: hasBasicFilters,
                hasAdvancedFilters: hasAdvancedFilters,
                hasFullFilters: hasFullFilters,
                canSeeLikes: canSeeLikes,
                canDisableMindfulMessaging: canDisableMindfulMessaging,
                sortOrder: sortOrder
            )
        }
    }

    // MARK: - StoreKit Product IDs
    // These must match your App Store Connect configuration
    enum ProductID: String {
        case growWeekly = "com.harvestglass.harvest.grow.weekly"
        case growMonthly = "com.harvestglass.harvest.grow.monthly"
        case goldWeekly = "com.harvestglass.harvest.gold.weekly"
        case goldMonthly = "com.harvestglass.harvest.gold.monthly"

        var tierName: TierName {
            switch self {
            case .growWeekly, .growMonthly: return .green
            case .goldWeekly, .goldMonthly: return .gold
            }
        }
    }

    func getSubscriptionTiers() async throws -> [SubscriptionTier] {
        let tierDTOs: [SubscriptionTierDTO] = try await client
            .from("subscription_tiers")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
        return tierDTOs.map(\.tier)
    }

    func getUserSubscription(userId: String) async throws -> UserSubscription? {
        let subs: [UserSubscription] = try await client
            .from("user_subscriptions")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return subs.first
    }

    func initializeUserSubscription(userId: String) async throws {
        struct TierId: Decodable { let id: String }

        let seedTiers: [TierId] = try await client
            .from("subscription_tiers")
            .select("id")
            .eq("name", value: "seed")
            .execute()
            .value

        guard let seedTierId = seedTiers.first?.id else { return }

        // Check if already exists
        let existing: [UserSubscription] = try await client
            .from("user_subscriptions")
            .select("id")
            .eq("user_id", value: userId)
            .execute()
            .value

        if !existing.isEmpty { return }

        try await client
            .from("user_subscriptions")
            .insert([
                "user_id": userId,
                "tier_id": seedTierId,
                "status": "active"
            ])
            .execute()
    }

    // MARK: - StoreKit 2 Integration

    /// Fetch available products from App Store
    func fetchProducts() async throws -> [Product] {
        let productIDs = [
            ProductID.growWeekly.rawValue,
            ProductID.growMonthly.rawValue,
            ProductID.goldWeekly.rawValue,
            ProductID.goldMonthly.rawValue,
        ]

        let products = try await Product.products(for: productIDs)
        return products
    }

    /// Purchase a subscription product
    func purchase(product: Product, userId: String) async throws -> Transaction {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Update subscription in database
            try await updateSubscriptionAfterPurchase(
                userId: userId,
                transaction: transaction
            )

            // Finish the transaction
            await transaction.finish()

            return transaction

        case .userCancelled:
            throw SubscriptionError.userCancelled

        case .pending:
            throw SubscriptionError.purchasePending

        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    /// Restore previous purchases
    func restorePurchases(userId: String) async throws {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Update subscription in database
                try await updateSubscriptionAfterPurchase(
                    userId: userId,
                    transaction: transaction
                )

                hasActiveSubscription = true
            } catch {
                print("Warning: Failed to verify transaction during restore: \(error)")
            }
        }

        if !hasActiveSubscription {
            try await syncToSeedTier(userId: userId)
            throw SubscriptionError.noPurchasesToRestore
        }
    }

    /// Check for active subscription status
    func checkSubscriptionStatus(userId: String) async throws {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Keep database in sync
                try await updateSubscriptionAfterPurchase(
                    userId: userId,
                    transaction: transaction
                )
                hasActiveSubscription = true
            } catch {
                print("Warning: Transaction verification failed: \(error)")
            }
        }

        if !hasActiveSubscription {
            try await syncToSeedTier(userId: userId)
        }
    }

    // MARK: - Private Helpers

    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw SubscriptionError.verificationFailed(error)
        case .verified(let safe):
            return safe
        }
    }

    private func updateSubscriptionAfterPurchase(
        userId: String,
        transaction: Transaction
    ) async throws {
        guard let productID = ProductID(rawValue: transaction.productID) else {
            print("Warning: Unknown product ID: \(transaction.productID)")
            return
        }

        let tierName = productID.tierName

        // Get tier ID from database
        guard let tierId = try await getTierId(for: tierName) else {
            throw SubscriptionError.tierNotFound
        }

        // Update or insert user subscription
        let now = ISO8601DateFormatter().string(from: Date())

        do {
            try await client
                .from("user_subscriptions")
                .upsert([
                    "user_id": AnyJSON.string(userId),
                    "tier_id": AnyJSON.string(tierId),
                    "status": AnyJSON.string("active"),
                    "started_at": AnyJSON.string(now),
                    "cancelled_at": AnyJSON.null,
                    "updated_at": AnyJSON.string(now)
                ], onConflict: "user_id")
                .execute()
        } catch {
            print("Error: Failed to update subscription in database: \(error)")
            throw error
        }
    }

    private func syncToSeedTier(userId: String) async throws {
        guard let seedTierId = try await getTierId(for: .seed) else {
            throw SubscriptionError.tierNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await client
            .from("user_subscriptions")
            .upsert([
                "user_id": AnyJSON.string(userId),
                "tier_id": AnyJSON.string(seedTierId),
                "status": AnyJSON.string("active"),
                "cancelled_at": AnyJSON.string(now),
                "updated_at": AnyJSON.string(now)
            ], onConflict: "user_id")
            .execute()
    }

    private func getTierId(for tierName: TierName) async throws -> String? {
        struct TierId: Decodable { let id: String }

        let tiers: [TierId] = try await client
            .from("subscription_tiers")
            .select("id")
            .eq("name", value: tierName.rawValue)
            .limit(1)
            .execute()
            .value

        return tiers.first?.id
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case userCancelled
    case purchasePending
    case verificationFailed(VerificationResult<Transaction>.VerificationError)
    case tierNotFound
    case noPurchasesToRestore
    case unknown

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .verificationFailed(let error):
            return "Transaction verification failed: \(error.localizedDescription)"
        case .tierNotFound:
            return "Subscription tier not found in database"
        case .noPurchasesToRestore:
            return "No previous purchases found to restore"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
