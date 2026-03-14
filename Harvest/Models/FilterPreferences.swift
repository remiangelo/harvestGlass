import Foundation

struct FilterPreferences: Codable, Sendable {
    // Basic (all tiers)
    var ageMin: Int = 18
    var ageMax: Int = 50
    var distanceMax: Int = 50
    var distanceUnit: String = "mi"
    var showMe: [String] = []
    var isVisible: Bool = true

    // Premium (Green+)
    var lookingFor: String?
    var heightMin: Int?
    var heightMax: Int?
    var smoking: String?
    var drinking: String?
    var cannabis: String?

    // Gold only
    var spiritualFaith: String?
    var childrenStatus: String?

    enum CodingKeys: String, CodingKey {
        case ageMin = "age_min"
        case ageMax = "age_max"
        case distanceMax = "distance_max"
        case distanceUnit = "distance_unit"
        case showMe = "show_me"
        case isVisible = "is_visible"
        case lookingFor = "looking_for"
        case heightMin = "height_min"
        case heightMax = "height_max"
        case smoking, drinking, cannabis
        case spiritualFaith = "spiritual_faith"
        case childrenStatus = "children_status"
    }
}
