import Foundation
import Supabase

struct FilterService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getFilters(userId: String) async throws -> FilterPreferences {
        let rows: [FilterPreferencesRow] = try await client
            .from("user_preferences")
            .select("""
                user_id,
                min_age,
                max_age,
                max_distance,
                distance_unit,
                show_me,
                is_visible,
                looking_for,
                height_min,
                height_max,
                smoking,
                drinking,
                cannabis,
                spiritual_faith,
                children_status
            """)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return FilterPreferences()
        }

        return row.asPreferences()
    }

    func saveFilters(userId: String, filters: FilterPreferences) async throws {
        let row = FilterPreferencesRow(userId: userId, filters: filters)

        try await client
            .from("user_preferences")
            .upsert([
                "user_id": AnyJSON.string(row.userId),
                "min_age": AnyJSON.double(Double(row.minAge)),
                "max_age": AnyJSON.double(Double(row.maxAge)),
                "max_distance": AnyJSON.double(Double(row.maxDistance)),
                "distance_unit": AnyJSON.string(row.distanceUnit),
                "show_me": AnyJSON.array(row.showMe.map { AnyJSON.string($0) }),
                "is_visible": AnyJSON.bool(row.isVisible),
                "looking_for": anyJSONStringOrNull(row.lookingFor),
                "height_min": anyJSONIntOrNull(row.heightMin),
                "height_max": anyJSONIntOrNull(row.heightMax),
                "smoking": anyJSONStringOrNull(row.smoking),
                "drinking": anyJSONStringOrNull(row.drinking),
                "cannabis": anyJSONStringOrNull(row.cannabis),
                "spiritual_faith": anyJSONStringOrNull(row.spiritualFaith),
                "children_status": anyJSONStringOrNull(row.childrenStatus)
            ], onConflict: "user_id")
            .execute()
    }

    func resetFilters(userId: String) async throws {
        try await saveFilters(userId: userId, filters: FilterPreferences())
    }

    private func anyJSONStringOrNull(_ value: String?) -> AnyJSON {
        guard let value, !value.isEmpty else { return .null }
        return .string(value)
    }

    private func anyJSONIntOrNull(_ value: Int?) -> AnyJSON {
        guard let value else { return .null }
        return .double(Double(value))
    }
}

private struct FilterPreferencesRow: Decodable {
    let userId: String
    let minAge: Int
    let maxAge: Int
    let maxDistance: Int
    let distanceUnit: String
    let showMe: [String]
    let isVisible: Bool
    let lookingFor: String?
    let heightMin: Int?
    let heightMax: Int?
    let smoking: String?
    let drinking: String?
    let cannabis: String?
    let spiritualFaith: String?
    let childrenStatus: String?

    init(
        userId: String,
        minAge: Int = 18,
        maxAge: Int = 50,
        maxDistance: Int = 50,
        distanceUnit: String = "mi",
        showMe: [String] = [],
        isVisible: Bool = true,
        lookingFor: String? = nil,
        heightMin: Int? = nil,
        heightMax: Int? = nil,
        smoking: String? = nil,
        drinking: String? = nil,
        cannabis: String? = nil,
        spiritualFaith: String? = nil,
        childrenStatus: String? = nil
    ) {
        self.userId = userId
        self.minAge = minAge
        self.maxAge = maxAge
        self.maxDistance = maxDistance
        self.distanceUnit = distanceUnit
        self.showMe = showMe
        self.isVisible = isVisible
        self.lookingFor = lookingFor
        self.heightMin = heightMin
        self.heightMax = heightMax
        self.smoking = smoking
        self.drinking = drinking
        self.cannabis = cannabis
        self.spiritualFaith = spiritualFaith
        self.childrenStatus = childrenStatus
    }

    init(userId: String, filters: FilterPreferences) {
        self.init(
            userId: userId,
            minAge: filters.ageMin,
            maxAge: filters.ageMax,
            maxDistance: filters.distanceMax,
            distanceUnit: filters.distanceUnit,
            showMe: filters.showMe,
            isVisible: filters.isVisible,
            lookingFor: filters.lookingFor,
            heightMin: filters.heightMin,
            heightMax: filters.heightMax,
            smoking: filters.smoking,
            drinking: filters.drinking,
            cannabis: filters.cannabis,
            spiritualFaith: filters.spiritualFaith,
            childrenStatus: filters.childrenStatus
        )
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case minAge = "min_age"
        case maxAge = "max_age"
        case maxDistance = "max_distance"
        case distanceUnit = "distance_unit"
        case showMe = "show_me"
        case isVisible = "is_visible"
        case lookingFor = "looking_for"
        case heightMin = "height_min"
        case heightMax = "height_max"
        case smoking
        case drinking
        case cannabis
        case spiritualFaith = "spiritual_faith"
        case childrenStatus = "children_status"
    }

    func asPreferences() -> FilterPreferences {
        FilterPreferences(
            ageMin: minAge,
            ageMax: maxAge,
            distanceMax: maxDistance,
            distanceUnit: distanceUnit,
            showMe: showMe,
            isVisible: isVisible,
            lookingFor: lookingFor,
            heightMin: heightMin,
            heightMax: heightMax,
            smoking: smoking,
            drinking: drinking,
            cannabis: cannabis,
            spiritualFaith: spiritualFaith,
            childrenStatus: childrenStatus
        )
    }
}
