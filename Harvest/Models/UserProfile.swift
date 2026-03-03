import Foundation

struct UserProfile: Codable, Identifiable, Sendable {
    let id: String
    var email: String
    var nickname: String?
    var age: Int?
    var bio: String?
    var location: String?
    var gender: String?
    var preferences: String?
    var goals: String?
    var hobbies: [String]?
    var photos: [String]?
    var distancePreference: Int?
    var interestedIn: [String]?
    var onboardingCompleted: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, age, bio, location, gender, preferences, goals, hobbies, photos
        case distancePreference = "distance_preference"
        case interestedIn = "interested_in"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayName: String {
        nickname ?? email.components(separatedBy: "@").first ?? "User"
    }

    var primaryPhoto: String? {
        photos?.first
    }

    var goalsList: [String] {
        guard let goals else { return [] }
        if goals.contains(",") {
            return goals.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return [goals]
    }
}
