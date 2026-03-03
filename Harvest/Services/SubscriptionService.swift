import Foundation
import Supabase

struct SubscriptionService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

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
}
