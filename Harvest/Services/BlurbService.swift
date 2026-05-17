import Foundation

struct BlurbService {
    typealias ChatProvider = (_ messages: [OpenAIService.ChatMessage]) async throws -> String

    private static let maxLength = 280
    private static let systemPrompt = """
    You write short, warm, first-person dating-profile blurbs based on the values someone brings and the values they seek.

    Rules:
    - 2 to 3 sentences, max 280 characters total.
    - First person ("I bring...", "I'm drawn to...").
    - No preamble, no quotes, no markdown. Plain prose only.
    - Reference the values naturally — do not list them like a bullet list.
    """

    private let chat: ChatProvider

    init(chat: @escaping ChatProvider = { messages in
        try await OpenAIService().sendChat(messages: messages)
    }) {
        self.chat = chat
    }

    func generateBlurb(brought: [Value], sought: [Value]) async throws -> String {
        let broughtList = brought.map(\.name).joined(separator: ", ")
        let soughtList = sought.map(\.name).joined(separator: ", ")

        let userPrompt = """
        Values I bring: \(broughtList.isEmpty ? "(none selected)" : broughtList)
        Values I seek: \(soughtList.isEmpty ? "(none selected)" : soughtList)

        Write the blurb now.
        """

        let messages: [OpenAIService.ChatMessage] = [
            .init(role: "system", content: Self.systemPrompt),
            .init(role: "user", content: userPrompt)
        ]

        let response = try await chat(messages)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= Self.maxLength {
            return trimmed
        }
        return String(trimmed.prefix(Self.maxLength))
    }
}
