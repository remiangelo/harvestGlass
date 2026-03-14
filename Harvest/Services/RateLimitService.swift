import Foundation
import Supabase

struct RateLimitService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Gardener Rate Limiting

    /// Check if user can send a Gardener message
    /// Returns (canSend: Bool, reason: String?, remainingConversations: Int, remainingCharacters: Int)
    func checkGardenerLimit(
        userId: String,
        messageLength: Int,
        userTier: SubscriptionTier
    ) async throws -> GardenerLimitCheck {
        // Check character limit
        if messageLength > userTier.gardenerCharacterLimit {
            return GardenerLimitCheck(
                canSend: false,
                reason: "Message exceeds character limit of \(userTier.gardenerCharacterLimit). Current: \(messageLength)",
                remainingConversations: 0,
                remainingCharacters: 0,
                characterLimit: userTier.gardenerCharacterLimit
            )
        }

        // Check daily conversation limit (if tier has a limit)
        if let conversationLimit = userTier.gardenerConversationsPerDay {
            let usageToday = try await getGardenerUsageToday(userId: userId)

            if usageToday >= conversationLimit {
                return GardenerLimitCheck(
                    canSend: false,
                    reason: "Daily conversation limit reached (\(conversationLimit) conversations per day)",
                    remainingConversations: 0,
                    remainingCharacters: userTier.gardenerCharacterLimit - messageLength,
                    characterLimit: userTier.gardenerCharacterLimit
                )
            }

            return GardenerLimitCheck(
                canSend: true,
                reason: nil,
                remainingConversations: conversationLimit - usageToday,
                remainingCharacters: userTier.gardenerCharacterLimit - messageLength,
                characterLimit: userTier.gardenerCharacterLimit
            )
        }

        // No conversation limit (unlimited tier)
        return GardenerLimitCheck(
            canSend: true,
            reason: nil,
            remainingConversations: -1, // -1 = unlimited
            remainingCharacters: userTier.gardenerCharacterLimit - messageLength,
            characterLimit: userTier.gardenerCharacterLimit
        )
    }

    /// Get number of Gardener conversations today
    private func getGardenerUsageToday(userId: String) async throws -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let todayISO = ISO8601DateFormatter().string(from: today)

        struct ConversationCount: Decodable {
            let count: Int
        }

        // Count distinct conversation pairs (user message + AI response = 1 conversation)
        // We'll count user messages sent today
        let result: [ConversationCount] = try await client
            .from("gardener_chats")
            .select("count", head: false, count: .exact)
            .eq("user_id", value: userId)
            .eq("role", value: "user")
            .gte("created_at", value: todayISO)
            .execute()
            .value

        return result.first?.count ?? 0
    }

    /// Track a Gardener conversation
    func trackGardenerConversation(userId: String) async throws {
        // Usage is already tracked via gardener_chats table insertions
        // This method is here for future enhancements like analytics
        print("Gardener conversation tracked for user: \(userId)")
    }

    // MARK: - Match Rate Limiting

    /// Check if user can perform more swipes this week
    func checkMatchLimit(userId: String, userTier: SubscriptionTier) async throws -> MatchLimitCheck {
        guard let matchLimit = userTier.matchesPerWeek else {
            // Unlimited matches
            return MatchLimitCheck(canSwipe: true, reason: nil, remainingMatches: -1)
        }

        let matchesThisWeek = try await getMatchesThisWeek(userId: userId)

        if matchesThisWeek >= matchLimit {
            return MatchLimitCheck(
                canSwipe: false,
                reason: "Weekly match limit reached (\(matchLimit) matches per week)",
                remainingMatches: 0
            )
        }

        return MatchLimitCheck(
            canSwipe: true,
            reason: nil,
            remainingMatches: matchLimit - matchesThisWeek
        )
    }

    private func getMatchesThisWeek(userId: String) async throws -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekAgoISO = ISO8601DateFormatter().string(from: weekAgo)

        struct MatchCount: Decodable {
            let count: Int
        }

        let result: [MatchCount] = try await client
            .from("matches")
            .select("count", head: false, count: .exact)
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .gte("created_at", value: weekAgoISO)
            .execute()
            .value

        return result.first?.count ?? 0
    }

    // MARK: - Distance Limiting

    /// Check if user can see profiles at a certain distance
    func checkDistanceLimit(distance: Double, userTier: SubscriptionTier) -> Bool {
        guard let maxDistance = userTier.maxDistanceMiles else {
            return true // Unlimited distance
        }

        return distance <= Double(maxDistance)
    }
}

// MARK: - Result Models

struct GardenerLimitCheck: Sendable {
    let canSend: Bool
    let reason: String?
    let remainingConversations: Int // -1 = unlimited
    let remainingCharacters: Int
    let characterLimit: Int

    var isUnlimited: Bool {
        remainingConversations == -1
    }

    var usageDisplayText: String {
        if isUnlimited {
            return "Unlimited conversations"
        } else {
            return "\(remainingConversations) conversation\(remainingConversations == 1 ? "" : "s") remaining today"
        }
    }
}

struct MatchLimitCheck: Sendable {
    let canSwipe: Bool
    let reason: String?
    let remainingMatches: Int // -1 = unlimited

    var isUnlimited: Bool {
        remainingMatches == -1
    }

    var usageDisplayText: String {
        if isUnlimited {
            return "Unlimited matches"
        } else {
            return "\(remainingMatches) match\(remainingMatches == 1 ? "" : "es") remaining this week"
        }
    }
}

// MARK: - Errors

enum RateLimitError: LocalizedError {
    case characterLimitExceeded(limit: Int, actual: Int)
    case dailyConversationLimitReached(limit: Int)
    case weeklyMatchLimitReached(limit: Int)
    case distanceLimitExceeded(maxDistance: Int, actual: Double)

    var errorDescription: String? {
        switch self {
        case .characterLimitExceeded(let limit, let actual):
            return "Message too long. Limit: \(limit) characters, yours: \(actual)"
        case .dailyConversationLimitReached(let limit):
            return "You've reached your daily limit of \(limit) Gardener conversations. Upgrade for more!"
        case .weeklyMatchLimitReached(let limit):
            return "You've reached your weekly limit of \(limit) matches. Upgrade for unlimited matches!"
        case .distanceLimitExceeded(let maxDistance, let actual):
            return "This profile is \(Int(actual)) miles away. Your plan supports up to \(maxDistance) miles."
        }
    }
}
