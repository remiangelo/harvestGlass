import Foundation
import Supabase

struct FilterService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getFilters(userId: String) async throws -> FilterPreferences {
        struct FilterRow: Decodable {
            let preferences: PreferencesPayload?
        }

        enum PreferencesPayload: Decodable {
            case filters(FilterPreferences)
            case legacyString(String)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()

                if let filters = try? container.decode(FilterPreferences.self) {
                    self = .filters(filters)
                    return
                }

                if let jsonString = try? container.decode(String.self) {
                    self = .legacyString(jsonString)
                    return
                }

                throw DecodingError.typeMismatch(
                    PreferencesPayload.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported preferences payload"
                    )
                )
            }
        }

        let rows: [FilterRow] = try await client
            .from("user_preferences")
            .select("preferences")
            .eq("user_id", value: userId)
            .execute()
            .value

        guard let payload = rows.first?.preferences else {
            return FilterPreferences()
        }

        switch payload {
        case .filters(let filters):
            return filters
        case .legacyString(let jsonString):
            guard let data = jsonString.data(using: .utf8) else {
                return FilterPreferences()
            }
            return (try? JSONDecoder().decode(FilterPreferences.self, from: data)) ?? FilterPreferences()
        }
    }

    func saveFilters(userId: String, filters: FilterPreferences) async throws {
        let encoded = try JSONEncoder().encode(filters)
        let rawObject = try JSONSerialization.jsonObject(with: encoded)
        guard let jsonObject = rawObject as? [String: Any] else {
            throw NSError(
                domain: "FilterService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode filter preferences"]
            )
        }

        // Upsert into user_preferences
        try await client
            .from("user_preferences")
            .upsert([
                "user_id": AnyJSON.string(userId),
                "preferences": anyJSON(from: jsonObject)
            ], onConflict: "user_id")
            .execute()
    }

    func resetFilters(userId: String) async throws {
        let defaults = FilterPreferences()
        try await saveFilters(userId: userId, filters: defaults)
    }

    private func anyJSON(from value: Any) -> AnyJSON {
        switch value {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .double(Double(int))
        case let double as Double:
            return .double(double)
        case let array as [Any]:
            return .array(array.map(anyJSON(from:)))
        case let dictionary as [String: Any]:
            return .object(dictionary.mapValues(anyJSON(from:)))
        default:
            return .null
        }
    }
}
