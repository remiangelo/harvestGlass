import Foundation
import Supabase

struct RateLimitService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Gardener Rate Limiting

    /// Check if user can send a Gardener message based on the daily character budget.
    func checkGardenerLimit(
        userId: String,
        messageLength: Int,
        userTier: SubscriptionTier
    ) async throws -> GardenerLimitCheck {
        let usage = try await getOrCreateUsageRow(userId: userId)
        let normalizedUsage = try await normalizedDailyGardenerUsage(for: usage)

        let remainingCharactersBeforeSend = max(0, userTier.gardenerCharacterLimit - normalizedUsage.gardenerCharactersUsedToday)
        if messageLength > remainingCharactersBeforeSend {
            return GardenerLimitCheck(
                canSend: false,
                reason: "Daily character limit reached (\(userTier.gardenerCharacterLimit) characters per day)",
                remainingConversations: -1,
                remainingCharacters: remainingCharactersBeforeSend,
                characterLimit: userTier.gardenerCharacterLimit
            )
        }

        return GardenerLimitCheck(
            canSend: true,
            reason: nil,
            remainingConversations: -1,
            remainingCharacters: max(0, remainingCharactersBeforeSend - messageLength),
            characterLimit: userTier.gardenerCharacterLimit
        )
    }

    /// Track daily Gardener character usage in user_usage
    func trackGardenerConversation(userId: String, characterCount: Int) async throws {
        let usage = try await getOrCreateUsageRow(userId: userId)
        let normalizedUsage = try await normalizedDailyGardenerUsage(for: usage)

        try await client
            .from("user_usage")
            .update([
                "gardener_conversations_today": AnyJSON.double(Double(normalizedUsage.gardenerConversationsToday)),
                "gardener_characters_used_today": AnyJSON.double(Double(normalizedUsage.gardenerCharactersUsedToday + characterCount)),
                "gardener_last_reset_date": AnyJSON.string(Self.dateFormatter.string(from: Date())),
                "updated_at": AnyJSON.string(Self.timestampFormatter.string(from: Date()))
            ])
            .eq("id", value: usage.id)
            .execute()
    }

    // MARK: - Match Rate Limiting

    /// Check if user can perform more swipes this week
    func checkMatchLimit(userId: String, userTier: SubscriptionTier) async throws -> MatchLimitCheck {
        guard let matchLimit = userTier.matchesPerWeek else {
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
        let weekStart = Self.startOfWeek(for: Date())
        let weekStartISO = Self.timestampFormatter.string(from: weekStart)

        struct MatchCount: Decodable {
            let count: Int
        }

        let result: [MatchCount] = try await client
            .from("matches")
            .select("count", head: false, count: .exact)
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .gte("matched_at", value: weekStartISO)
            .execute()
            .value

        return result.first?.count ?? 0
    }

    // MARK: - Distance Limiting

    /// Check if user can see profiles at a certain distance
    func checkDistanceLimit(distance: Double, userTier: SubscriptionTier) -> Bool {
        guard let maxDistance = userTier.maxDistanceMiles else {
            return true
        }

        return distance <= Double(maxDistance)
    }

    // MARK: - Usage Helpers

    private func getOrCreateUsageRow(userId: String) async throws -> UserUsageRow {
        let weekStartDate = Self.dateFormatter.string(from: Self.startOfWeek(for: Date()))

        let existingRows: [UserUsageRow] = try await client
            .from("user_usage")
            .select()
            .eq("user_id", value: userId)
            .eq("week_start_date", value: weekStartDate)
            .limit(1)
            .execute()
            .value

        if let existing = existingRows.first {
            return existing
        }

        let createdRows: [UserUsageRow] = try await client
            .from("user_usage")
            .insert([
                "user_id": AnyJSON.string(userId),
                "week_start_date": AnyJSON.string(weekStartDate),
                "matches_count": AnyJSON.double(0),
                "gardener_conversations_today": AnyJSON.double(0),
                "gardener_last_reset_date": AnyJSON.string(Self.dateFormatter.string(from: Date())),
                "gardener_characters_used_today": AnyJSON.double(0),
                "updated_at": AnyJSON.string(Self.timestampFormatter.string(from: Date()))
            ])
            .select()
            .execute()
            .value

        guard let created = createdRows.first else {
            throw RateLimitError.usageRowCreationFailed
        }

        return created
    }

    private func normalizedDailyGardenerUsage(for usage: UserUsageRow) async throws -> UserUsageRow {
        let today = Self.dateFormatter.string(from: Date())
        guard usage.gardenerLastResetDate != today else { return usage }

        try await client
            .from("user_usage")
            .update([
                "gardener_conversations_today": AnyJSON.double(0),
                "gardener_characters_used_today": AnyJSON.double(0),
                "gardener_last_reset_date": AnyJSON.string(today),
                "updated_at": AnyJSON.string(Self.timestampFormatter.string(from: Date()))
            ])
            .eq("id", value: usage.id)
            .execute()

        var resetUsage = usage
        resetUsage.gardenerConversationsToday = 0
        resetUsage.gardenerCharactersUsedToday = 0
        resetUsage.gardenerLastResetDate = today
        return resetUsage
    }
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func startOfWeek(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

private struct UserUsageRow: Decodable {
    let id: String
    let userId: String
    let weekStartDate: String
    let matchesCount: Int
    var gardenerConversationsToday: Int
    var gardenerLastResetDate: String
    var gardenerCharactersUsedToday: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weekStartDate = "week_start_date"
        case matchesCount = "matches_count"
        case gardenerConversationsToday = "gardener_conversations_today"
        case gardenerLastResetDate = "gardener_last_reset_date"
        case gardenerCharactersUsedToday = "gardener_characters_used_today"
    }
}

// MARK: - Result Models

struct GardenerLimitCheck: Sendable {
    let canSend: Bool
    let reason: String?
    let remainingConversations: Int
    let remainingCharacters: Int
    let characterLimit: Int

    var isUnlimited: Bool {
        remainingConversations == -1
    }

    var usageDisplayText: String {
        remainingCharacters == -1
            ? "Unlimited characters"
            : "\(remainingCharacters) characters remaining today"
    }
}

struct MatchLimitCheck: Sendable {
    let canSwipe: Bool
    let reason: String?
    let remainingMatches: Int

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
    case weeklyMatchLimitReached(limit: Int)
    case distanceLimitExceeded(maxDistance: Int, actual: Double)
    case usageRowCreationFailed

    var errorDescription: String? {
        switch self {
        case .characterLimitExceeded(let limit, let actual):
            return "Message too long. Limit: \(limit) characters, yours: \(actual)"
        case .weeklyMatchLimitReached(let limit):
            return "You've reached your weekly limit of \(limit) matches. Upgrade for unlimited matches!"
        case .distanceLimitExceeded(let maxDistance, let actual):
            return "This profile is \(Int(actual)) miles away. Your plan supports up to \(maxDistance) miles."
        case .usageRowCreationFailed:
            return "Unable to create usage tracking row"
        }
    }
}
