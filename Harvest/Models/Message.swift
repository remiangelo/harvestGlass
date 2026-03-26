import Foundation

struct Message: Codable, Identifiable, Sendable {
    let id: String
    let conversationId: String
    let senderId: String
    var content: String?
    var messageType: String?
    var mediaUrl: String?
    var isRead: Bool
    var readAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case messageType = "message_type"
        case mediaUrl = "media_url"
        case isRead = "is_read"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    func isSentBy(_ userId: String) -> Bool {
        senderId.lowercased() == userId.lowercased()
    }
}
