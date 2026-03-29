import Foundation

struct DailyQuiz: Identifiable, Sendable {
    let id: String
    let trackingId: String
    let questionId: String
    var question: String
    var options: [QuizOption]
    var category: QuizCategory
    var selectedAnswer: String?
    var insight: String?
    let shownAt: String?
    var isAnswered: Bool
}

struct QuizOption: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let text: String
}

enum QuizCategory: String, Codable, Sendable, CaseIterable {
    case datingStyle = "dating_style"
    case values
    case communication
    case relationshipGoals = "relationship_goals"
    case personality
}
