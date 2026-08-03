import Foundation
import Auth
import Supabase

struct OpenAIService {
    struct ChatMessage: Codable, Sendable {
        /// One piece of a message. OpenAI accepts either a bare string or an
        /// array of these; images can only be sent the second way.
        enum ContentPart: Sendable, Equatable {
            case text(String)
            case imageURL(String)   // a data: URL or an https: URL
        }

        let role: String
        let parts: [ContentPart]

        /// Text-only. Every pre-existing call site uses this and encodes
        /// exactly as it did before.
        init(role: String, content: String) {
            self.role = role
            self.parts = [.text(content)]
        }

        init(role: String, parts: [ContentPart]) {
            self.role = role
            self.parts = parts
        }

        /// Convenience for the common text case.
        var content: String {
            parts.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
                .joined(separator: "\n")
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey { case role, content }
        private enum PartKeys: String, CodingKey { case type, text, image_url }
        private enum ImageURLKeys: String, CodingKey { case url }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)

            // A lone text part encodes as a bare string — byte-identical to
            // what this type produced before images existed.
            if parts.count == 1, case .text(let only) = parts[0] {
                try container.encode(only, forKey: .content)
                return
            }

            var array = container.nestedUnkeyedContainer(forKey: .content)
            for part in parts {
                var partContainer = array.nestedContainer(keyedBy: PartKeys.self)
                switch part {
                case .text(let value):
                    try partContainer.encode("text", forKey: .type)
                    try partContainer.encode(value, forKey: .text)
                case .imageURL(let url):
                    try partContainer.encode("image_url", forKey: .type)
                    var image = partContainer.nestedContainer(
                        keyedBy: ImageURLKeys.self, forKey: .image_url
                    )
                    try image.encode(url, forKey: .url)
                }
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = try container.decode(String.self, forKey: .role)

            if let flat = try? container.decode(String.self, forKey: .content) {
                parts = [.text(flat)]
                return
            }

            var array = try container.nestedUnkeyedContainer(forKey: .content)
            var decoded: [ContentPart] = []
            while !array.isAtEnd {
                let partContainer = try array.nestedContainer(keyedBy: PartKeys.self)
                let type = try partContainer.decode(String.self, forKey: .type)
                switch type {
                case "text":
                    decoded.append(.text(try partContainer.decode(String.self, forKey: .text)))
                case "image_url":
                    let image = try partContainer.nestedContainer(
                        keyedBy: ImageURLKeys.self, forKey: .image_url
                    )
                    decoded.append(.imageURL(try image.decode(String.self, forKey: .url)))
                default:
                    break   // forward compatible: skip part types we don't model
                }
            }
            parts = decoded
        }
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
        case requestFailed(statusCode: Int, body: String?)
        case noResponse

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to use AI features"
            case .requestFailed(let code, let body):
                if let body, !body.isEmpty {
                    return "OpenAI request failed with status \(code): \(body)"
                }
                return "OpenAI request failed with status \(code)"
            case .noResponse:
                return "No response from OpenAI"
            }
        }
    }

    func sendChat(
        messages: [ChatMessage],
        model: String = "gpt-4.1-mini",
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
        model: String = "gpt-4.1-mini",
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
            let responseBody = String(data: data, encoding: .utf8)
            throw OpenAIError.requestFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }

        return data
    }
}
