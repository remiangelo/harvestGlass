import Foundation

struct Community: Identifiable, Codable, Equatable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let kind: String
    let memberCount: Int?
    let displayOrder: Int?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, kind
        case memberCount = "member_count"
        case displayOrder = "display_order"
        case imageUrl = "image_url"
    }
}

struct CommunityMessage: Identifiable, Codable, Equatable {
    let id: String
    let communityId: String
    let senderId: String
    let content: String
    let isRemoved: Bool
    let createdAt: String?
    let replyToId: String?
    let mentions: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case senderId = "sender_id"
        case content
        case isRemoved = "is_removed"
        case createdAt = "created_at"
        case replyToId = "reply_to_id"
        case mentions
    }
}

/// One emoji reaction by one user on one message.
/// community_id is filled server-side by a trigger; it exists so realtime
/// can filter reaction events per room.
struct CommunityReaction: Codable, Equatable, Hashable {
    let messageId: String
    let userId: String
    let emoji: String
    let communityId: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
        case communityId = "community_id"
    }

    /// The curated set — must match the DB check constraint exactly.
    static let curatedEmoji = ["🌱", "💚", "🌻", "😂", "👏", "🤔"]
}

struct CommunityPrompt: Identifiable, Codable, Equatable {
    let id: String
    let text: String
}

/// Lightweight sender info for community chat (name + avatar).
struct CommunitySender: Identifiable, Codable, Equatable {
    let id: String
    let nickname: String?
    let photos: [String]?

    var photoUrl: String? { photos?.first }
}
