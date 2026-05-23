import Foundation

enum ValueAxis: String, Codable, CaseIterable, Sendable {
    case emotionalIntelligence = "emotional_intelligence"
    case stability
    case integrity
    case connection
    case growth

    var displayName: String {
        switch self {
        case .emotionalIntelligence: return "Emotional Intelligence"
        case .stability:             return "Stability"
        case .integrity:             return "Integrity"
        case .connection:            return "Connection"
        case .growth:                return "Growth"
        }
    }
}

enum QuestionWeighting: String, Codable, Sendable {
    case need, bring, both
}

struct QuestionOption: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let questionId: String
    let label: String
    let axis: ValueAxis
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label, axis
        case questionId = "question_id"
        case displayOrder = "display_order"
    }
}

struct Question: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let prompt: String
    let weighting: QuestionWeighting
    let displayOrder: Int
    var options: [QuestionOption]

    enum CodingKeys: String, CodingKey {
        case id, prompt, weighting, options
        case displayOrder = "display_order"
    }
}

struct UserQuestionAnswer: Codable, Sendable, Equatable {
    let userId: String
    let questionId: String
    let optionId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionId = "question_id"
        case optionId = "option_id"
    }
}
