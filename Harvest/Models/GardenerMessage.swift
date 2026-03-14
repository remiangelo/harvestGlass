import Foundation

struct GardenerMessage: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let role: String
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
