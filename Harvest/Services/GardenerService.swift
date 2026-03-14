import Foundation
import Supabase

struct GardenerService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let openAI = OpenAIService()

    private static let systemPrompt = """
        You are The Gardener, a warm, insightful AI dating coach for the Harvest dating app. \
        Your personality is nurturing and growth-oriented, using gardening metaphors naturally \
        (not forcefully). You help users navigate dating with empathy, practical advice, and \
        gentle accountability. You focus on: building authentic connections, healthy communication \
        patterns, self-awareness in relationships, setting and respecting boundaries, and growing \
        from dating experiences. Keep responses concise (2-3 paragraphs max), warm but honest, \
        and action-oriented. Never give medical or legal advice. If someone expresses distress, \
        encourage professional support.
        """

    static let welcomeMessage = "Welcome to The Gardener! I'm your personal dating coach, here to help you grow authentic connections. Think of me as the friend who always gives you the honest (but kind) truth about your dating life. What's on your mind today?"

    private static let fallbackResponses = [
        "Every connection starts with a single seed of courage. What's on your mind today?",
        "Growth takes time, and that's perfectly okay. I'm here whenever you need to talk about your dating journey.",
        "Remember, the strongest relationships grow from authentic roots. How can I help you cultivate yours?",
        "Sometimes the best thing we can do is pause, reflect, and tend to our own garden before reaching out to others.",
        "Dating can feel overwhelming at times. Let's break it down together — what specific challenge are you facing?",
        "The best relationships bloom when both people are willing to be vulnerable. What does vulnerability look like for you?",
        "A healthy relationship is like a well-tended garden — it needs sunlight, water, and patience. Which of those feels hardest for you right now?",
        "One thing I've learned: the way someone treats a server or barista tells you more than any dating profile ever could.",
        "Compatibility isn't about finding someone identical to you — it's about finding someone whose differences complement your strengths.",
        "Before you can grow with someone else, it helps to know what season you're in yourself. How would you describe where you are right now?",
        "Trust your gut. If something feels off, it probably is. What's your instinct telling you?",
        "Great conversations start with genuine curiosity. Try asking your match about something they're passionate about — you might be surprised.",
        "Rejection isn't a reflection of your worth — it's just a sign that particular garden wasn't meant to grow. What other seeds have you planted?",
        "Setting boundaries isn't selfish — it's essential. Healthy roots need firm soil. Is there a boundary you've been hesitant to set?",
        "Remember: you're not just looking for someone to like you. You're looking for someone you genuinely like too. What qualities matter most to you?"
    ]

    func sendMessage(userId: String, message: String, history: [GardenerMessage]) async throws -> String {
        // Build messages array
        var chatMessages: [OpenAIService.ChatMessage] = [
            .init(role: "system", content: Self.systemPrompt)
        ]

        // Add last 10 history messages
        let recentHistory = history.suffix(10)
        for msg in recentHistory {
            chatMessages.append(.init(role: msg.role, content: msg.content))
        }

        chatMessages.append(.init(role: "user", content: message))

        let response: String
        do {
            response = try await openAI.sendChat(
                messages: chatMessages,
                temperature: 0.7,
                maxTokens: 200
            )
        } catch {
            response = Self.fallbackResponses.randomElement() ?? Self.fallbackResponses[0]
        }

        // Persist chat history
        let now = ISO8601DateFormatter().string(from: Date())

        // Persist user message
        do {
            try await client
                .from("gardener_chats")
                .insert([
                    "user_id": userId,
                    "role": "user",
                    "content": message,
                    "created_at": now
                ])
                .execute()
        } catch {
            print("Warning: Failed to persist user message to gardener_chats: \(error)")
            // Non-critical - continue with response even if persistence fails
        }

        // Persist assistant response
        do {
            try await client
                .from("gardener_chats")
                .insert([
                    "user_id": userId,
                    "role": "assistant",
                    "content": response,
                    "created_at": now
                ])
            .execute()

        return response
    }

    func getChatHistory(userId: String) async throws -> [GardenerMessage] {
        let messages: [GardenerMessage] = try await client
            .from("gardener_chats")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return messages
    }

    func generateDailyQuiz(userId: String) async throws -> DailyQuiz? {
        // Check if quiz exists for today
        if try await hasQuizToday(userId: userId) {
            return nil
        }

        let messages: [OpenAIService.ChatMessage] = [
            .init(role: "system", content: """
                Generate a dating self-reflection quiz question. Return JSON: \
                {"question": "...", "options": ["A", "B", "C", "D"], "category": "dating_style|values|communication|relationship_goals|personality"}
                """),
            .init(role: "user", content: "Generate a thoughtful quiz question about dating and relationships.")
        ]

        do {
            let responseData = try await openAI.sendChatJSON(
                messages: messages,
                temperature: 0.8,
                maxTokens: 500
            )

            // Parse the response to extract JSON content
            struct AIResponse: Codable {
                struct Choice: Codable {
                    struct Msg: Codable { let content: String? }
                    let message: Msg
                }
                let choices: [Choice]
            }

            let aiResponse = try JSONDecoder().decode(AIResponse.self, from: responseData)
            guard let content = aiResponse.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else { return nil }

            struct QuizPayload: Codable {
                let question: String
                let options: [String]
                let category: String
            }

            let payload = try JSONDecoder().decode(QuizPayload.self, from: jsonData)
            let now = ISO8601DateFormatter().string(from: Date())

            let quizzes: [DailyQuiz] = try await client
                .from("daily_quizzes")
                .insert([
                    "user_id": AnyJSON.string(userId),
                    "question": AnyJSON.string(payload.question),
                    "options": AnyJSON.array(payload.options.map { AnyJSON.string($0) }),
                    "category": AnyJSON.string(payload.category),
                    "created_at": AnyJSON.string(now)
                ])
                .select()
                .execute()
                .value

            return quizzes.first
        } catch {
            return nil
        }
    }

    func hasQuizToday(userId: String) async throws -> Bool {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        struct QuizCount: Decodable { let id: String }
        let quizzes: [QuizCount] = try await client
            .from("daily_quizzes")
            .select("id")
            .eq("user_id", value: userId)
            .gte("created_at", value: today)
            .execute()
            .value

        return !quizzes.isEmpty
    }

    func saveQuizAnswer(quizId: String, answer: String, insight: String?) async throws {
        var updates: [String: AnyJSON] = [
            "selected_answer": .string(answer)
        ]
        if let insight {
            updates["insight"] = .string(insight)
        }

        try await client
            .from("daily_quizzes")
            .update(updates)
            .eq("id", value: quizId)
            .execute()
    }

    func getTodayCharacterUsage(userId: String) async throws -> Int {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        struct ChatContent: Decodable { let content: String }
        let chats: [ChatContent] = try await client
            .from("gardener_chats")
            .select("content")
            .eq("user_id", value: userId)
            .eq("role", value: "user")
            .gte("created_at", value: today)
            .execute()
            .value

        return chats.reduce(0) { $0 + $1.content.count }
    }
}
