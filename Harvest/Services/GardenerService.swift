import Foundation
import Supabase

struct GardenerService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let openAI = OpenAIService()

    private static let systemPrompt = """
        You are The Gardener, a warm and insightful AI dating coach for the Harvest dating app.
        Give clear, practical, emotionally intelligent advice.
        Priorities:
        - Answer the user's actual question directly in the first 1-2 sentences.
        - Be specific and useful, not vague or overly poetic.
        - Use warmth and empathy, but avoid filler, generic platitudes, or forced gardening metaphors.
        - When helpful, give 2-4 concrete suggestions, examples, or next steps.
        - Ask at most one follow-up question, and only if it meaningfully helps.
        - Keep the response concise: usually 1 short paragraph or a short paragraph plus bullets.
        - Break longer replies into short paragraphs of 1-3 sentences, with a blank line between each thought.
        - Never give medical or legal advice. If someone expresses distress or risk, encourage professional or trusted human support.
        """

    static let welcomeMessage = "Welcome to The Gardener! I'm your personal dating coach, here to help you grow authentic connections. Think of me as the friend who always gives you the honest (but kind) truth about your dating life. What's on your mind today?"

    private static let fallbackResponses = [
        "Every connection starts with a single seed of courage. What's on your mind today?",
        "Growth takes time, and that's perfectly okay. I'm here whenever you need to talk about your dating journey.",
        "Remember, the strongest relationships grow from authentic roots. How can I help you cultivate yours?",
        "Sometimes the best thing we can do is pause, reflect, and tend to our own garden before reaching out to others.",
        "Dating can feel overwhelming at times. Let's break it down together - what specific challenge are you facing?",
        "The best relationships bloom when both people are willing to be vulnerable. What does vulnerability look like for you?",
        "A healthy relationship is like a well-tended garden - it needs sunlight, water, and patience. Which of those feels hardest for you right now?",
        "One thing I've learned: the way someone treats a server or barista tells you more than any dating profile ever could.",
        "Compatibility isn't about finding someone identical to you - it's about finding someone whose differences complement your strengths.",
        "Before you can grow with someone else, it helps to know what season you're in yourself. How would you describe where you are right now?",
        "Trust your gut. If something feels off, it probably is. What's your instinct telling you?",
        "Great conversations start with genuine curiosity. Try asking your match about something they're passionate about - you might be surprised.",
        "Rejection isn't a reflection of your worth - it's just a sign that particular garden wasn't meant to grow. What other seeds have you planted?",
        "Setting boundaries isn't selfish - it's essential. Healthy roots need firm soil. Is there a boundary you've been hesitant to set?",
        "Remember: you're not just looking for someone to like you. You're looking for someone you genuinely like too. What qualities matter most to you?"
    ]

    func sendMessage(userId: String, message: String, history: [GardenerMessage]) async throws -> String {
        var chatMessages: [OpenAIService.ChatMessage] = [
            .init(role: "system", content: Self.systemPrompt)
        ]

        let recentHistory = history.suffix(10)
        for msg in recentHistory {
            let role = msg.role == "assistant" ? "assistant" : "user"
            chatMessages.append(.init(role: role, content: msg.content))
        }

        chatMessages.append(.init(role: "user", content: message))

        let rawResponse: String
        do {
            rawResponse = try await openAI.sendChat(
                messages: chatMessages,
                temperature: 0.55,
                maxTokens: 280
            )
        } catch {
            print("Warning: OpenAI gardener request failed, using fallback: \(error)")
            rawResponse = Self.fallbackResponses.randomElement() ?? Self.fallbackResponses[0]
        }
        let response = Self.formatResponse(rawResponse)

        let now = ISO8601DateFormatter().string(from: Date())

        do {
            try await client
                .from("gardener_chat_history")
                .insert([
                    "user_id": AnyJSON.string(userId),
                    "sender": AnyJSON.string("user"),
                    "message": AnyJSON.string(message),
                    "created_at": AnyJSON.string(now)
                ])
                .execute()
        } catch {
            print("Warning: Failed to persist user message to gardener_chat_history: \(error)")
        }

        do {
            try await client
                .from("gardener_chat_history")
                .insert([
                    "user_id": AnyJSON.string(userId),
                    "sender": AnyJSON.string("gardener"),
                    "message": AnyJSON.string(response),
                    "created_at": AnyJSON.string(now)
                ])
                .execute()
        } catch {
            print("Warning: Failed to persist assistant response to gardener_chat_history: \(error)")
        }

        return response
    }

    private static func formatResponse(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return text }

        if cleaned.contains("\n\n") {
            return cleaned
        }

        let lines = cleaned
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count > 1 {
            return lines.joined(separator: "\n\n")
        }

        let sentences = splitIntoSentences(cleaned)
        guard sentences.count > 3 else { return cleaned }

        var paragraphs: [String] = []
        var index = 0

        while index < sentences.count {
            let remaining = sentences.count - index
            let chunkSize = remaining <= 3 ? remaining : 2
            let paragraph = sentences[index..<min(index + chunkSize, sentences.count)]
                .joined(separator: " ")
            paragraphs.append(paragraph)
            index += chunkSize
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for character in text {
            current.append(character)

            if character == "." || character == "!" || character == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            if sentences.isEmpty {
                sentences.append(trailing)
            } else {
                let lastIndex = sentences.index(before: sentences.endIndex)
                sentences[lastIndex] += " " + trailing
            }
        }

        return sentences
    }

    func getChatHistory(userId: String) async throws -> [GardenerMessage] {
        let rows: [GardenerChatHistoryRow] = try await client
            .from("gardener_chat_history")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            GardenerMessage(
                id: row.id,
                userId: row.userId,
                role: row.sender == "gardener" ? "assistant" : "user",
                content: row.message,
                createdAt: row.createdAt
            )
        }
    }

    func generateDailyQuiz(userId: String) async throws -> DailyQuiz? {
        if let existingQuiz = try await getTodayQuiz(userId: userId) {
            return existingQuiz
        }

        let questions = try await fetchQuestionBank()
        guard !questions.isEmpty else { return nil }

        let question = selectQuestion(from: questions, userId: userId)
        let shownAt = ISO8601DateFormatter().string(from: Date())
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId),
            "quiz_date": .string(Self.dateFormatter.string(from: Date())),
            "question_id": .string(question.id),
            "shown_at": .string(shownAt),
            "answered": .bool(false)
        ]

        let trackingRows: [GardenerQuizTrackingRow] = try await client
            .from("gardener_daily_quiz_tracking")
            .insert(payload)
            .select()
            .execute()
            .value

        guard let tracking = trackingRows.first else { return nil }
        return makeDailyQuiz(question: question, tracking: tracking, response: nil)
    }

    func hasQuizToday(userId: String) async throws -> Bool {
        try await getTodayQuiz(userId: userId) != nil
    }

    func saveQuizAnswer(userId: String, quiz: DailyQuiz, answer: String) async throws {
        guard let option = quiz.options.first(where: { $0.text == answer }) else {
            throw NSError(domain: "GardenerService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Quiz answer does not match available options"
            ])
        }

        let existingResponses: [GardenerQuizResponseRow] = try await client
            .from("gardener_quiz_responses")
            .select()
            .eq("user_id", value: userId)
            .eq("question_id", value: quiz.questionId)
            .execute()
            .value

        if existingResponses.isEmpty {
            try await client
                .from("gardener_quiz_responses")
                .insert([
                    "user_id": AnyJSON.string(userId),
                    "question_id": AnyJSON.string(quiz.questionId),
                    "selected_option_id": AnyJSON.string(option.id),
                    "selected_value": AnyJSON.string(option.text),
                    "answered_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .execute()
        } else {
            try await client
                .from("gardener_quiz_responses")
                .update([
                    "selected_option_id": AnyJSON.string(option.id),
                    "selected_value": AnyJSON.string(option.text),
                    "answered_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: existingResponses[0].id)
                .execute()
        }

        try await client
            .from("gardener_daily_quiz_tracking")
            .update([
                "answered": AnyJSON.bool(true)
            ])
            .eq("id", value: quiz.trackingId)
            .execute()
    }

    func getTodayCharacterUsage(userId: String) async throws -> Int {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        struct ChatContent: Decodable { let message: String }
        let chats: [ChatContent] = try await client
            .from("gardener_chat_history")
            .select("message")
            .eq("user_id", value: userId)
            .eq("sender", value: "user")
            .gte("created_at", value: today)
            .execute()
            .value

        return chats.reduce(0) { $0 + $1.message.count }
    }

    private func getTodayQuiz(userId: String) async throws -> DailyQuiz? {
        let today = Self.dateFormatter.string(from: Date())
        let trackingRows: [GardenerQuizTrackingRow] = try await client
            .from("gardener_daily_quiz_tracking")
            .select()
            .eq("user_id", value: userId)
            .eq("quiz_date", value: today)
            .order("shown_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let tracking = trackingRows.first else { return nil }
        guard let question = try await fetchQuestion(id: tracking.questionId) else { return nil }
        let response = try await fetchQuizResponse(userId: userId, questionId: tracking.questionId)
        return makeDailyQuiz(question: question, tracking: tracking, response: response)
    }

    private func fetchQuestionBank() async throws -> [GardenerQuizQuestionRow] {
        try await client
            .from("gardener_quiz_questions")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    private func fetchQuestion(id: String) async throws -> GardenerQuizQuestionRow? {
        let rows: [GardenerQuizQuestionRow] = try await client
            .from("gardener_quiz_questions")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func fetchQuizResponse(userId: String, questionId: String) async throws -> GardenerQuizResponseRow? {
        let rows: [GardenerQuizResponseRow] = try await client
            .from("gardener_quiz_responses")
            .select()
            .eq("user_id", value: userId)
            .eq("question_id", value: questionId)
            .order("answered_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func selectQuestion(from questions: [GardenerQuizQuestionRow], userId: String) -> GardenerQuizQuestionRow {
        let index = abs(userId.hashValue) % questions.count
        return questions[index]
    }

    private func makeDailyQuiz(
        question: GardenerQuizQuestionRow,
        tracking: GardenerQuizTrackingRow,
        response: GardenerQuizResponseRow?
    ) -> DailyQuiz {
        DailyQuiz(
            id: tracking.id,
            trackingId: tracking.id,
            questionId: question.id,
            question: question.question,
            options: question.optionValues,
            category: QuizCategory(rawValue: question.category) ?? .datingStyle,
            selectedAnswer: response?.selectedValue,
            insight: nil,
            shownAt: tracking.shownAt,
            isAnswered: tracking.answered
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private struct GardenerChatHistoryRow: Decodable {
    let id: String
    let userId: String
    let message: String
    let sender: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case message
        case sender
        case createdAt = "created_at"
    }
}

private struct GardenerQuizTrackingRow: Decodable {
    let id: String
    let userId: String
    let quizDate: String
    let questionId: String
    let shownAt: String?
    let answered: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case quizDate = "quiz_date"
        case questionId = "question_id"
        case shownAt = "shown_at"
        case answered
    }
}

private struct GardenerQuizResponseRow: Decodable {
    let id: String
    let userId: String
    let questionId: String
    let selectedOptionId: String
    let selectedValue: String
    let answeredAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case questionId = "question_id"
        case selectedOptionId = "selected_option_id"
        case selectedValue = "selected_value"
        case answeredAt = "answered_at"
    }
}

private struct GardenerQuizQuestionRow: Decodable {
    let id: String
    let question: String
    let options: [QuizOptionPayload]
    let category: String

    struct QuizOptionPayload: Codable {
        let id: String?
        let text: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                id = nil
                text = stringValue
                return
            }

            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            id = try keyed.decodeIfPresent(String.self, forKey: .id)
            text = try keyed.decodeIfPresent(String.self, forKey: .text)
        }

        private enum CodingKeys: String, CodingKey {
            case id, text
        }
    }

    var optionValues: [QuizOption] {
        options.enumerated().map { index, option in
            QuizOption(
                id: option.id ?? "option_\(index)",
                text: option.text ?? ""
            )
        }
        .filter { !$0.text.isEmpty }
    }
}
