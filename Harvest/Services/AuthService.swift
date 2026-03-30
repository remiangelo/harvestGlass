import Foundation
import Supabase
import Auth

struct AuthService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func signUp(email: String, password: String) async throws -> Auth.User {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["app_name": .string("Harvest")],
            redirectTo: URL(string: "\(Config.appScheme)://auth/callback")
        )
        return response.user
    }

    func signIn(email: String, password: String) async throws -> Auth.Session {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return session
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount(userId: String) async throws {
        struct DeleteAccountResponse: Decodable {
            let success: Bool
            let message: String?
        }

        let session = try await client.auth.session
        let endpoint = Config.supabaseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("delete-account")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AuthService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Account deletion failed because the backend response was invalid."]
            )
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let backendMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let friendlyMessage: String

            if httpResponse.statusCode == 404 {
                friendlyMessage = "Account deletion is not available yet because the delete-account Edge Function has not been deployed."
            } else if let backendMessage, !backendMessage.isEmpty {
                friendlyMessage = backendMessage
            } else {
                friendlyMessage = "Account deletion failed. Please try again or contact support."
            }

            throw NSError(
                domain: "AuthService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: friendlyMessage]
            )
        }

        if let decoded = try? JSONDecoder().decode(DeleteAccountResponse.self, from: data),
           decoded.success == false {
            throw NSError(
                domain: "AuthService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: decoded.message ?? "Account deletion failed."]
            )
        }
    }

    func getCurrentSession() async throws -> Auth.Session? {
        try await client.auth.session
    }

    func getCurrentUser() async throws -> Auth.User? {
        try await client.auth.session.user
    }

    func authStateChanges() -> AsyncStream<(AuthChangeEvent, Auth.Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    continuation.yield((event, session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

enum AuthError: LocalizedError {
    case signUpFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .signUpFailed: return "Failed to create account"
        case .notAuthenticated: return "Not authenticated"
        }
    }
}
