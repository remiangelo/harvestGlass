import Foundation

struct Community: Identifiable, Codable, Equatable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let kind: String
    let memberCount: Int?
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, kind
        case memberCount = "member_count"
        case displayOrder = "display_order"
    }
}

struct CommunityMessage: Identifiable, Codable, Equatable {
    let id: String
    let communityId: String
    let senderId: String
    let content: String
    let isRemoved: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case senderId = "sender_id"
        case content
        case isRemoved = "is_removed"
        case createdAt = "created_at"
    }
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
