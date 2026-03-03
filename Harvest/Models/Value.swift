import Foundation

struct Value: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case displayOrder = "display_order"
    }
}

struct UserValue: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let valueId: String
    let ranking: Int?

    enum CodingKeys: String, CodingKey {
        case id, ranking
        case userId = "user_id"
        case valueId = "value_id"
    }
}
