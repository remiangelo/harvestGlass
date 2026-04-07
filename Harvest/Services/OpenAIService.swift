import Foundation
import Auth
import Supabase

struct OpenAIService {
    struct ChatMessage: Codable, Sendable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct ResponseMessage: Codable {
                let content: String?
            }
            let message: ResponseMessage
        }
        let choices: [Choice]
    }

    enum OpenAIError: LocalizedError {
        case notAuthenticated
        case requestFailed(statusCode: Int)
        case noResponse

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to use AI features"
            case .requestFailed(let code):
                return "OpenAI request failed with status \(code)"
            case .noResponse:
                return "No response from OpenAI"
            }
        }
    }

    func sendChat(
        messages: [ChatMessage],
        model: String = "gpt-4-turbo-preview",
        temperature: Double = 0.7,
        maxTokens: Int = 200
    ) async throws -> String {
        let data = try await performRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw OpenAIError.noResponse
        }
        return content
    }

    func sendChatJSON(
        messages: [ChatMessage],
        model: String = "gpt-4-turbo-preview",
        temperature: Double = 0.7,
        maxTokens: Int = 500
    ) async throws -> Data {
        return try await performRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    private func performRequest(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> Data {
        let session: Session
        do {
            session = try await SupabaseManager.shared.client.auth.session
        } catch {
            throw OpenAIError.notAuthenticated
        }

        let url = Config.supabaseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("openai-chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.noResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return data
    }
}
