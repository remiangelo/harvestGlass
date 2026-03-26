import Foundation
import Supabase

struct MatchService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let chatService = ChatService()

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
        var seenOtherUserIds = Set<String>()
        let profileService = ProfileService()

        for match in matches {
            guard let otherUserId = match.otherUserId(currentUserId: userId) else { continue }
            guard seenOtherUserIds.insert(otherUserId).inserted else { continue }
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

    func ensureConversation(match: Match, currentUserId: String) async throws -> String? {
        try await chatService.ensureConversation(
            matchId: match.id,
            user1Id: match.user1Id,
            user2Id: match.user2Id
        )
    }

    func getMatch(matchId: String) async throws -> Match? {
        let matches: [Match] = try await client
            .from("matches")
            .select()
            .eq("id", value: matchId)
            .limit(1)
            .execute()
            .value

        return matches.first
    }

    func getConversations(userId: String) async throws -> [ConversationWithProfile] {
        let directConversations: [Conversation] = try await client
            .from("conversations")
            .select()
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .order("last_message_at", ascending: false)
            .execute()
            .value

        let matches: [Match] = try await client
            .from("matches")
            .select()
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .eq("is_active", value: true)
            .execute()
            .value

        let matchIds = matches.map(\.id)
        var conversationsById = Dictionary(uniqueKeysWithValues: directConversations.map { ($0.id, $0) })

        if !matchIds.isEmpty {
            let matchLinkedConversations: [Conversation] = try await client
                .from("conversations")
                .select()
                .in("match_id", values: matchIds)
                .order("last_message_at", ascending: false)
                .execute()
                .value

            for conversation in matchLinkedConversations {
                conversationsById[conversation.id] = conversation
            }
        }

        let matchesById = Dictionary(uniqueKeysWithValues: matches.map { ($0.id, $0) })
        let conversations = conversationsById.values.sorted { lhs, rhs in
            (lhs.lastMessageAt ?? lhs.createdAt ?? "") > (rhs.lastMessageAt ?? rhs.createdAt ?? "")
        }

        var conversationsWithProfiles: [ConversationWithProfile] = []
        var seenConversationIds = Set<String>()
        let profileService = ProfileService()

        for conversation in conversations {
            guard seenConversationIds.insert(conversation.id).inserted else { continue }

            let otherUserId =
                conversation.otherUserId(currentUserId: userId) ??
                conversation.matchId.flatMap { matchesById[$0]?.otherUserId(currentUserId: userId) }

            guard let otherUserId else { continue }
            if let profile = try await profileService.getProfile(userId: otherUserId) {
                conversationsWithProfiles.append(ConversationWithProfile(conversation: conversation, profile: profile))
            }
        }

        return conversationsWithProfiles
    }
}
