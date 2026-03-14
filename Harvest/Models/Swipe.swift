import Foundation

enum SwipeAction: String, Codable, Sendable {
    case like
    case nope
    case superLike = "super_like"
}

struct Swipe: Codable, Identifiable, Sendable {
    let id: String
    let swiperId: String
    let swipedId: String
    let action: SwipeAction
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, action
        case swiperId = "swiper_id"
        case swipedId = "swiped_id"
        case createdAt = "created_at"
    }
}

struct SwipeResult: Sendable {
    let success: Bool
    var isMatch: Bool = false
    var matchId: String?
    var error: String?
}
