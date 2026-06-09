import Foundation
import Supabase

enum SeedError: LocalizedError {
    case dailyLimitReached
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "You've reached today's Seed limit. Upgrade or try again tomorrow."
        case .underlying(let m):
            return m
        }
    }
}

struct SeedService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Send a Seed (opening message) to another user.
    func sendSeed(senderId: String, recipientId: String, openingMessage: String) async throws {
        do {
            try await client
                .from("seeds")
                .insert([
                    "sender_id": senderId,
                    "recipient_id": recipientId,
                    "opening_message": openingMessage
                ])
                .execute()
        } catch {
            // Surface the daily-limit Postgres exception as a typed error.
            if "\(error)".contains("SEED_LIMIT_REACHED") {
                throw SeedError.dailyLimitReached
            }
            throw SeedError.underlying("\(error)")
        }
    }

    /// Accept a Seed via the RPC; returns the new conversation id.
    /// The function returns a scalar uuid; decode defensively in case the
    /// transport wraps it (scalar string vs single-element array).
    func acceptSeed(seedId: String) async throws -> String {
        let response = try await client
            .rpc("accept_seed", params: ["p_seed_id": seedId])
            .execute()
        let data = response.data
        if let scalar = try? JSONDecoder().decode(String.self, from: data) {
            return scalar
        }
        if let array = try? JSONDecoder().decode([String].self, from: data), let first = array.first {
            return first
        }
        // Last resort: trim quotes/whitespace from the raw body.
        let raw = String(data: data, encoding: .utf8) ?? ""
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r "))
        if trimmed.isEmpty { throw SeedError.underlying("accept_seed returned no conversation id") }
        return trimmed
    }

    func declineSeed(seedId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("seeds")
            .update(["status": AnyJSON.string("declined"),
                     "responded_at": AnyJSON.string(now)])
            .eq("id", value: seedId)
            .execute()
    }

    /// Pending Seeds received by the user (incoming requests).
    func receivedPending(userId: String) async throws -> [Seed] {
        try await client
            .from("seeds")
            .select()
            .eq("recipient_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Pending Seeds the user has sent (outgoing requests).
    func sentPending(userId: String) async throws -> [Seed] {
        try await client
            .from("seeds")
            .select()
            .eq("sender_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// How many Seeds the user has sent since local midnight UTC (matches the
    /// server trigger's date_trunc('day', now())).
    func sentTodayCount(userId: String) async throws -> Int {
        let startOfDay = ISO8601DateFormatter().string(
            from: Calendar(identifier: .gregorian).startOfDay(for: Date()))
        let rows: [Seed] = try await client
            .from("seeds")
            .select("id, created_at, sender_id, recipient_id, opening_message, status, conversation_id, responded_at")
            .eq("sender_id", value: userId)
            .gte("created_at", value: startOfDay)
            .execute()
            .value
        return rows.count
    }
}
