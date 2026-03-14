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
        // Delete user data from tables in order (respecting foreign keys)
        let tablesToClean = [
            "gardener_chats", "daily_quizzes", "safety_analyses",
            "red_flag_reports", "user_values_brought", "user_values_sought",
            "user_blocks", "reports", "support_tickets", "user_preferences",
            "user_subscriptions"
        ]

        // Track failed deletions for error reporting
        var deletionErrors: [String: Error] = [:]

        // Delete from all related tables
        for table in tablesToClean {
            do {
                try await client
                    .from(table)
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
            } catch {
                print("Warning: Failed to delete from \(table): \(error)")
                deletionErrors[table] = error
            }
        }

        // Delete messages sent by user
        do {
            try await client
                .from("messages")
                .delete()
                .eq("sender_id", value: userId)
                .execute()
        } catch {
            print("Warning: Failed to delete messages: \(error)")
            deletionErrors["messages"] = error
        }

        // Delete swipes
        do {
            try await client
                .from("swipes")
                .delete()
                .eq("swiper_id", value: userId)
                .execute()
        } catch {
            print("Warning: Failed to delete swipes: \(error)")
            deletionErrors["swipes"] = error
        }

        // Delete user profile (critical - throw if this fails)
        do {
            try await client
                .from("users")
                .delete()
                .eq("id", value: userId)
                .execute()
        } catch {
            print("Error: Failed to delete user profile: \(error)")
            throw error // Critical failure - don't sign out if profile deletion fails
        }

        // Log any deletion errors but proceed with sign out
        if !deletionErrors.isEmpty {
            print("Account deletion completed with \(deletionErrors.count) non-critical errors")
        }

        // Sign out
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
