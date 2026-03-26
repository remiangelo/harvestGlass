import Foundation

struct Conversation: Codable, Identifiable, Sendable {
    let id: String
    let matchId: String?
    var lastMessageAt: String?
    var lastMessagePreview: String?
    let user1Id: String?
    let user2Id: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case lastMessageAt = "last_message_at"
        case lastMessagePreview = "last_message_preview"
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
    }

    func otherUserId(currentUserId: String) -> String? {
        let normalizedCurrentUserId = currentUserId.lowercased()
        if user1Id?.lowercased() == normalizedCurrentUserId { return user2Id }
        if user2Id?.lowercased() == normalizedCurrentUserId { return user1Id }
        return nil
    }
}

struct ConversationWithProfile: Identifiable, Sendable {
    let conversation: Conversation
    let profile: UserProfile
    let hasReplyHighlight: Bool

    var id: String { conversation.id }
}

