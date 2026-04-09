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
    var lookingFor: String?
    var heightCm: Int?
    var smoking: String?
    var drinking: String?
    var cannabis: String?
    var spiritualOrientation: String?
    var childrenStatus: String?
    var onboardingCompleted: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, age, bio, location, gender, preferences, goals, hobbies, photos
        case distancePreference = "distance_preference"
        case interestedIn = "interested_in"
        case lookingFor = "looking_for"
        case heightCm = "height_cm"
        case smoking
        case drinking
        case cannabis
        case spiritualOrientation = "spiritual_orientation"
        case childrenStatus = "children_status"
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

        let trimmedGoals = goals.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedGoals.isEmpty { return [] }

        if trimmedGoals.hasPrefix("["),
           let data = trimmedGoals.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
                .map { Self.normalizeGoalLabel($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.isEmpty }
        }

        if trimmedGoals.contains(",") {
            return trimmedGoals
                .components(separatedBy: ",")
                .map { Self.normalizeGoalLabel($0.trimmingCharacters(in: CharacterSet(charactersIn: "\"[] ").union(.whitespacesAndNewlines))) }
                .filter { !$0.isEmpty }
        }

        let normalizedGoal = Self.normalizeGoalLabel(
            trimmedGoals.trimmingCharacters(in: CharacterSet(charactersIn: "\"[] ").union(.whitespacesAndNewlines))
        )
        return normalizedGoal.isEmpty ? [] : [normalizedGoal]
    }

    var lifestyleDetails: [(label: String, value: String)] {
        var details: [(label: String, value: String)] = []

        if let lookingFor = lookingForDisplayValue {
            details.append(("Looking For", lookingFor))
        }
        if let height = heightDisplayValue {
            details.append(("Height", height))
        }
        if let smoking = smokingDisplayValue {
            details.append(("Smoking", smoking))
        }
        if let drinking = drinkingDisplayValue {
            details.append(("Drinking", drinking))
        }
        if let cannabis = cannabisDisplayValue {
            details.append(("Cannabis", cannabis))
        }
        if let spiritualOrientation = spiritualOrientationDisplayValue {
            details.append(("Spiritual Orientation", spiritualOrientation))
        }
        if let childrenStatus = childrenStatusDisplayValue {
            details.append(("Children", childrenStatus))
        }

        return details
    }

    private var lookingForDisplayValue: String? {
        guard let lookingFor else { return nil }
        let normalized = Self.normalizeGoalLabel(lookingFor.trimmingCharacters(in: .whitespacesAndNewlines))
        return normalized.isEmpty ? nil : normalized
    }

    private var heightDisplayValue: String? {
        guard let heightCm else { return nil }
        return HeightFormatter.string(from: heightCm)
    }

    private var smokingDisplayValue: String? {
        Self.formatLifestyleValue(smoking)
    }

    private var drinkingDisplayValue: String? {
        Self.formatLifestyleValue(drinking)
    }

    private var cannabisDisplayValue: String? {
        Self.formatLifestyleValue(cannabis)
    }

    private var spiritualOrientationDisplayValue: String? {
        Self.formatLifestyleValue(spiritualOrientation)
    }

    private var childrenStatusDisplayValue: String? {
        Self.formatLifestyleValue(childrenStatus)
    }

    private static func normalizeGoalLabel(_ value: String) -> String {
        switch value.lowercased() {
        case "short-term dating", "casual":
            return "Dating"
        case "long-term relationship", "long-term commitment", "long_term_commitment":
            return "Long-term Commitment"
        case "relationship":
            return "Relationship"
        case "marriage":
            return "Marriage"
        case "not sure yet", "not sure":
            return "Dating"
        default:
            return value
        }
    }

    private static func formatLifestyleValue(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return trimmed
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if ["and", "to", "not"].contains(lower) {
                    return lower
                }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
