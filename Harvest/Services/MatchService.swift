import Foundation
import Supabase

struct MatchService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getMatches(userId: String) async throws -> [MatchWithProfile] {
        let matches: [Match] = try await client
            .from("matches")
            .select()
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .eq("is_active", value: true)
            .order("matched_at", ascending: false)
            .execute()
            .value

        var matchesWithProfiles: [MatchWithProfile] = []
        let profileService = ProfileService()

        for match in matches {
            let otherUserId = match.otherUserId(currentUserId: userId)
            if let profile = try await profileService.getProfile(userId: otherUserId) {
                matchesWithProfiles.append(MatchWithProfile(match: match, profile: profile))
            }
        }

        return matchesWithProfiles
    }

    func unmatchUser(matchId: String) async throws {
        try await client
            .from("matches")
            .update([
                "is_active": AnyJSON.bool(false),
                "unmatched_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: matchId)
            .execute()
    }

    func blockUser(userId: String, blockedUserId: String) async throws {
        try await client
            .from("user_blocks")
            .insert([
                "blocker_id": userId,
                "blocked_id": blockedUserId
            ])
            .execute()
    }

    func reportUser(reporterId: String, reportedUserId: String, category: String, description: String) async throws {
        try await client
            .from("user_reports")
            .insert([
                "reporter_id": reporterId,
                "reported_id": reportedUserId,
                "reason": category,
                "description": description
            ])
            .execute()
    }

    func getConversations(userId: String) async throws -> [ConversationWithProfile] {
        let conversations: [Conversation] = try await client
            .from("conversations")
            .select()
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .order("last_message_at", ascending: false)
            .execute()
            .value

        var conversationsWithProfiles: [ConversationWithProfile] = []
        let profileService = ProfileService()

        for conversation in conversations {
            guard let otherUserId = conversation.otherUserId(currentUserId: userId) else { continue }
            if let profile = try await profileService.getProfile(userId: otherUserId) {
                conversationsWithProfiles.append(ConversationWithProfile(conversation: conversation, profile: profile))
            }
        }

        return conversationsWithProfiles
    }
}
