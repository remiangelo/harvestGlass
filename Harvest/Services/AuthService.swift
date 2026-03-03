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
