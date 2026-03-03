import Foundation
import Supabase

struct FilterService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getFilters(userId: String) async throws -> FilterPreferences {
        struct FilterRow: Decodable {
            let preferences: FilterPreferences?
        }

        let rows: [FilterRow] = try await client
            .from("user_preferences")
            .select("preferences")
            .eq("user_id", value: userId)
            .execute()
            .value

        return rows.first?.preferences ?? FilterPreferences()
    }

    func saveFilters(userId: String, filters: FilterPreferences) async throws {
        let encoded = try JSONEncoder().encode(filters)
        guard let json = String(data: encoded, encoding: .utf8) else { return }

        // Upsert into user_preferences
        try await client
            .from("user_preferences")
            .upsert([
                "user_id": AnyJSON.string(userId),
                "preferences": AnyJSON.string(json)
            ])
            .execute()
    }

    func resetFilters(userId: String) async throws {
        let defaults = FilterPreferences()
        try await saveFilters(userId: userId, filters: defaults)
    }
}
