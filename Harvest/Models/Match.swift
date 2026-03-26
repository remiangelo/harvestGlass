import Foundation

struct Match: Codable, Identifiable, Sendable {
    let id: String
    let user1Id: String
    let user2Id: String
    var isActive: Bool
    let matchedAt: String?
    var unmatchedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case isActive = "is_active"
        case matchedAt = "matched_at"
        case unmatchedAt = "unmatched_at"
    }

    func otherUserId(currentUserId: String) -> String? {
        if user1Id == currentUserId { return user2Id }
        if user2Id == currentUserId { return user1Id }
        return nil
    }
}

struct MatchWithProfile: Identifiable, Sendable {
    let match: Match
    let profile: UserProfile

    var id: String { match.id }
}
