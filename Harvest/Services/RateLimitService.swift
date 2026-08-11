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

    // MARK: - Screenshot Review Limiting

    /// Screenshot reviews have their own daily allowance. They used to be
    /// charged a flat 1,000 characters against the chat budget, which meant one
    /// review could swallow a free user's entire day of Gardener chat.
    func checkScreenshotLimit(
        userId: String,
        userTier: SubscriptionTier
    ) async throws -> ScreenshotLimitCheck {
        let usage = try await getOrCreateUsageRow(userId: userId)
        let normalizedUsage = try await normalizedDailyGardenerUsage(for: usage)
        let limit = userTier.gardenerScreenshotsPerDay
        let remaining = max(0, limit - normalizedUsage.gardenerScreenshotsToday)

        guard remaining > 0 else {
            return ScreenshotLimitCheck(
                canSend: false,
                reason: limit == 1
                    ? "That's your screenshot review for today. Your plan includes 1 per day."
                    : "You've used all \(limit) screenshot reviews for today.",
                remaining: 0,
                limit: limit
            )
        }

        return ScreenshotLimitCheck(canSend: true, reason: nil, remaining: remaining, limit: limit)
    }

    /// Record one screenshot review against today's allowance.
    func trackScreenshotReview(userId: String) async throws {
        let usage = try await getOrCreateUsageRow(userId: userId)
        let normalizedUsage = try await normalizedDailyGardenerUsage(for: usage)

        try await client
            .from("user_usage")
            .update([
                "gardener_screenshots_today": AnyJSON.double(Double(normalizedUsage.gardenerScreenshotsToday + 1)),
                "gardener_last_reset_date": AnyJSON.string(Self.dateFormatter.string(from: Date())),
                "updated_at": AnyJSON.string(Self.timestampFormatter.string(from: Date()))
            ])
            .eq("id", value: usage.id)
            .execute()
    }

    /// Screenshot reviews used so far today.
    func screenshotsUsedToday(userId: String) async throws -> Int {
        let usage = try await getOrCreateUsageRow(userId: userId)
        return try await normalizedDailyGardenerUsage(for: usage).gardenerScreenshotsToday
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
                // gardener_screenshots_today is deliberately not written here:
                // it arrives with migration 20260811100000 and defaults to 0.
                // Naming it before that migration lands fails the whole insert,
                // which would silently drop every user to free-tier limits.
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
                "gardener_screenshots_today": AnyJSON.double(0),
                "gardener_last_reset_date": AnyJSON.string(today),
                "updated_at": AnyJSON.string(Self.timestampFormatter.string(from: Date()))
            ])
            .eq("id", value: usage.id)
            .execute()

        var resetUsage = usage
        resetUsage.gardenerConversationsToday = 0
        resetUsage.gardenerCharactersUsedToday = 0
        resetUsage.gardenerScreenshotsToday = 0
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
    var gardenerScreenshotsToday: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weekStartDate = "week_start_date"
        case matchesCount = "matches_count"
        case gardenerConversationsToday = "gardener_conversations_today"
        case gardenerLastResetDate = "gardener_last_reset_date"
        case gardenerCharactersUsedToday = "gardener_characters_used_today"
        case gardenerScreenshotsToday = "gardener_screenshots_today"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        weekStartDate = try container.decode(String.self, forKey: .weekStartDate)
        matchesCount = try container.decodeIfPresent(Int.self, forKey: .matchesCount) ?? 0
        gardenerConversationsToday = try container.decodeIfPresent(Int.self, forKey: .gardenerConversationsToday) ?? 0
        gardenerLastResetDate = try container.decodeIfPresent(String.self, forKey: .gardenerLastResetDate) ?? ""
        gardenerCharactersUsedToday = try container.decodeIfPresent(Int.self, forKey: .gardenerCharactersUsedToday) ?? 0
        // Tolerated as absent so the app keeps working between shipping this
        // build and applying the migration that adds the column.
        gardenerScreenshotsToday = try container.decodeIfPresent(Int.self, forKey: .gardenerScreenshotsToday) ?? 0
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

struct ScreenshotLimitCheck: Sendable {
    let canSend: Bool
    let reason: String?
    let remaining: Int
    let limit: Int

    var usageDisplayText: String {
        "\(remaining) of \(limit) screenshot review\(limit == 1 ? "" : "s") left today"
    }
}

// MARK: - Errors

enum RateLimitError: LocalizedError {
    case characterLimitExceeded(limit: Int, actual: Int)
    case screenshotLimitReached(limit: Int)
    case usageRowCreationFailed

    var errorDescription: String? {
        switch self {
        case .characterLimitExceeded(let limit, let actual):
            return "Message too long. Limit: \(limit) characters, yours: \(actual)"
        case .screenshotLimitReached(let limit):
            return "You've used all \(limit) screenshot review\(limit == 1 ? "" : "s") for today."
        case .usageRowCreationFailed:
            return "Unable to create usage tracking row"
        }
    }
}
