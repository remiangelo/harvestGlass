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

    func otherUserId(currentUserId: String) -> String {
        user1Id == currentUserId ? user2Id : user1Id
    }
}

struct MatchWithProfile: Identifiable, Sendable {
    let match: Match
    let profile: UserProfile

    var id: String { match.id }
}
