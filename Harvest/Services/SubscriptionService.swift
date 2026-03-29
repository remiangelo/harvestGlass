import Foundation
import Supabase
import StoreKit

struct SubscriptionService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - StoreKit Product IDs
    // These must match your App Store Connect configuration
    enum ProductID: String {
        case greenMonthly = "com.harvestglass.harvest.green.monthly"
        case greenYearly = "com.harvestglass.harvest.green.yearly"
        case goldMonthly = "com.harvestglass.harvest.gold.monthly"
        case goldYearly = "com.harvestglass.harvest.gold.yearly"

        var tierName: TierName {
            switch self {
            case .greenMonthly, .greenYearly: return .green
            case .goldMonthly, .goldYearly: return .gold
            }
        }
    }

    func getSubscriptionTiers() async throws -> [SubscriptionTier] {
        let tiers: [SubscriptionTier] = try await client
            .from("subscription_tiers")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
        return tiers
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
            ProductID.greenMonthly.rawValue,
            ProductID.greenYearly.rawValue,
            ProductID.goldMonthly.rawValue,
            ProductID.goldYearly.rawValue
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
