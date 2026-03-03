import Foundation

struct DailyQuiz: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    var question: String
    var options: [String]
    var category: QuizCategory
    var selectedAnswer: String?
    var insight: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, question, options, category, insight
        case userId = "user_id"
        case selectedAnswer = "selected_answer"
        case createdAt = "created_at"
    }
}

enum QuizCategory: String, Codable, Sendable, CaseIterable {
    case datingStyle = "dating_style"
    case values
    case communication
    case relationshipGoals = "relationship_goals"
    case personality
}
