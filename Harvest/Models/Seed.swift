import Foundation

enum SeedStatus: String, Codable {
    case pending, accepted, declined
}

struct Seed: Identifiable, Codable, Equatable {
    let id: String
    let senderId: String
    let recipientId: String
    let openingMessage: String
    let status: SeedStatus
    let conversationId: String?
    let createdAt: String?
    let respondedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case openingMessage = "opening_message"
        case status
        case conversationId = "conversation_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}
