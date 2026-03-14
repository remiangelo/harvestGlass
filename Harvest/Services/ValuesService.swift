import Foundation
import Supabase

struct ValuesService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getAllValues() async throws -> [Value] {
        do {
            let values: [Value] = try await client
                .from("values")
                .select()
                .order("category", ascending: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            if !values.isEmpty { return values }
        } catch {
            // DB unavailable or decode error — fall through to defaults
        }

        return Self.defaultValues
    }

    private static let defaultValues: [Value] = {
        var values: [Value] = []
        let categories: [(String, [String])] = [
            ("communication", [
                "Honesty", "Active Listening", "Openness", "Directness",
                "Vulnerability", "Empathy", "Patience"
            ]),
            ("relationship", [
                "Commitment", "Trust", "Loyalty", "Independence",
                "Partnership", "Quality Time", "Physical Affection",
                "Words of Affirmation", "Acts of Service"
            ]),
            ("lifestyle", [
                "Adventure", "Stability", "Ambition", "Work-Life Balance",
                "Health & Wellness", "Spontaneity", "Routine",
                "Financial Responsibility", "Minimalism"
            ]),
            ("personal growth", [
                "Self-Awareness", "Continuous Learning", "Resilience",
                "Accountability", "Gratitude", "Mindfulness",
                "Emotional Intelligence", "Courage"
            ]),
            ("social", [
                "Family", "Friendship", "Community", "Inclusivity",
                "Generosity", "Humor", "Respect", "Kindness",
                "Cultural Awareness"
            ]),
            ("core beliefs", [
                "Authenticity", "Integrity", "Compassion", "Faith",
                "Justice", "Freedom", "Creativity", "Purpose"
            ])
        ]

        for (category, names) in categories {
            for (index, name) in names.enumerated() {
                values.append(Value(
                    id: "\(category)-\(index)",
                    name: name,
                    category: category,
                    displayOrder: index
                ))
            }
        }
        return values
    }()

    func getUserValuesBrought(userId: String) async throws -> [Value] {
        struct JoinedValue: Decodable {
            let valueId: String
            let values: Value

            enum CodingKeys: String, CodingKey {
                case valueId = "value_id"
                case values
            }
        }

        let joined: [JoinedValue] = try await client
            .from("user_values_brought")
            .select("value_id, values(*)")
            .eq("user_id", value: userId)
            .execute()
            .value

        return joined.map(\.values)
    }

    func getUserValuesSought(userId: String) async throws -> [Value] {
        struct JoinedValue: Decodable {
            let valueId: String
            let values: Value

            enum CodingKeys: String, CodingKey {
                case valueId = "value_id"
                case values
            }
        }

        let joined: [JoinedValue] = try await client
            .from("user_values_sought")
            .select("value_id, values(*)")
            .eq("user_id", value: userId)
            .execute()
            .value

        return joined.map(\.values)
    }

    func saveUserValuesBrought(userId: String, valueIds: [String]) async throws {
        // Delete existing
        try await client
            .from("user_values_brought")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // Insert new
        if !valueIds.isEmpty {
            let rows = valueIds.enumerated().map { index, valueId in
                [
                    "user_id": AnyJSON.string(userId),
                    "value_id": AnyJSON.string(valueId),
                    "ranking": AnyJSON.double(Double(index + 1))
                ]
            }
            try await client
                .from("user_values_brought")
                .insert(rows)
                .execute()
        }
    }

    func saveUserValuesSought(userId: String, valueIds: [String]) async throws {
        // Delete existing
        try await client
            .from("user_values_sought")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // Insert new
        if !valueIds.isEmpty {
            let rows = valueIds.enumerated().map { index, valueId in
                [
                    "user_id": AnyJSON.string(userId),
                    "value_id": AnyJSON.string(valueId),
                    "ranking": AnyJSON.double(Double(index + 1))
                ]
            }
            try await client
                .from("user_values_sought")
                .insert(rows)
                .execute()
        }
    }

    func calculateCompatibility(userId: String, otherUserId: String) async throws -> (score: Double, matchingValues: [String]) {
        let sought = try await getUserValuesSought(userId: userId)
        let brought = try await getUserValuesBrought(userId: otherUserId)

        let soughtNames = Set(sought.map(\.name))
        let broughtNames = Set(brought.map(\.name))
        let matching = soughtNames.intersection(broughtNames)

        let score = sought.isEmpty ? 0.0 : (Double(matching.count) / Double(sought.count)) * 100
        return (score, Array(matching))
    }
}
