import Foundation
import Supabase

struct MatchService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let chatService = ChatService()
    private let profileService = ProfileService()

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
        for conversation in conversations {
            guard seenConversationIds.insert(conversation.id).inserted else { continue }

            let otherUserId =
                conversation.otherUserId(currentUserId: userId) ??
                conversation.matchId.flatMap { matchesById[$0]?.otherUserId(currentUserId: userId) }

            guard let otherUserId else { continue }
            if let profile = try await profileService.getProfile(userId: otherUserId) {
                let hydratedConversation = try await hydrateConversationPreviewIfNeeded(conversation)
                guard hydratedConversation.lastMessagePreview != nil else { continue }
                let hasReplyHighlight = try await shouldHighlightConversation(
                    hydratedConversation,
                    currentUserId: userId
                )
                conversationsWithProfiles.append(
                    ConversationWithProfile(
                        conversation: hydratedConversation,
                        profile: profile,
                        hasReplyHighlight: hasReplyHighlight
                    )
                )
            }
        }

        return conversationsWithProfiles
    }

    func getInboundLikes(userId: String) async throws -> [InboundLikeWithProfile] {
        let inboundSwipes: [Swipe] = try await client
            .from("swipes")
            .select()
            .eq("swiped_id", value: userId)
            .in("action", values: [SwipeAction.like.rawValue, SwipeAction.superLike.rawValue])
            .order("created_at", ascending: false)
            .execute()
            .value

        let matches: [Match] = try await client
            .from("matches")
            .select()
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .eq("is_active", value: true)
            .execute()
            .value

        let matchedUserIds = Set(matches.compactMap { $0.otherUserId(currentUserId: userId)?.lowercased() })
        var seenSwiperIds = Set<String>()
        var inboundLikes: [InboundLikeWithProfile] = []

        for swipe in inboundSwipes {
            let swiperId = swipe.swiperId.lowercased()
            guard !matchedUserIds.contains(swiperId) else { continue }
            guard seenSwiperIds.insert(swiperId).inserted else { continue }

            if let profile = try await profileService.getProfile(userId: swipe.swiperId) {
                inboundLikes.append(
                    InboundLikeWithProfile(
                        swipe: swipe,
                        profile: profile
                    )
                )
            }
        }

        return inboundLikes
    }

    private func hydrateConversationPreviewIfNeeded(_ conversation: Conversation) async throws -> Conversation {
        if conversation.lastMessagePreview != nil {
            return conversation
        }

        let latestMessages: [Message] = try await client
            .from("messages")
            .select("content, created_at, id, conversation_id, sender_id, message_type, media_url, is_read, read_at")
            .eq("conversation_id", value: conversation.id)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let latestMessage = latestMessages.first, let content = latestMessage.content, !content.isEmpty else {
            return conversation
        }

        try await client
            .from("conversations")
            .update([
                "last_message_at": AnyJSON.string(latestMessage.createdAt ?? ISO8601DateFormatter().string(from: Date())),
                "last_message_preview": AnyJSON.string(String(content.prefix(100)))
            ])
            .eq("id", value: conversation.id)
            .execute()

        var hydratedConversation = conversation
        hydratedConversation.lastMessageAt = latestMessage.createdAt
        hydratedConversation.lastMessagePreview = String(content.prefix(100))
        return hydratedConversation
    }

    private func shouldHighlightConversation(_ conversation: Conversation, currentUserId: String) async throws -> Bool {
        let latestMessages: [Message] = try await client
            .from("messages")
            .select("content, created_at, id, conversation_id, sender_id, message_type, media_url, is_read, read_at")
            .eq("conversation_id", value: conversation.id)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let latestMessage = latestMessages.first else { return false }
        return !latestMessage.isSentBy(currentUserId)
    }
}
