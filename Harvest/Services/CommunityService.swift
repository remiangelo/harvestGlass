import Foundation
import Supabase
import Realtime

struct CommunityService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Rooms the user is allowed to join (via the access-rules RPC).
    func availableCommunities(userId: String) async throws -> [Community] {
        try await client
            .rpc("available_communities", params: ["p_user": userId])
            .execute()
            .value
    }

    /// Community ids the user has actively joined.
    func joinedCommunityIds(userId: String) async throws -> Set<String> {
        struct Row: Decodable { let community_id: String }
        let rows: [Row] = try await client
            .from("community_members")
            .select("community_id")
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .execute()
            .value
        return Set(rows.map(\.community_id))
    }

    func join(communityId: String, userId: String) async throws {
        try await client
            .from("community_members")
            .upsert([
                "community_id": communityId,
                "user_id": userId,
                "status": "active"
            ])
            .execute()
    }

    func leave(communityId: String, userId: String) async throws {
        try await client
            .from("community_members")
            .update(["status": "left"])
            .eq("community_id", value: communityId)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Latest page of messages, newest-first. Pass the oldest loaded
    /// created_at as `before` to fetch the next older page.
    func messagesPage(communityId: String, before: String? = nil, limit: Int = 50) async throws -> [CommunityMessage] {
        var query = client
            .from("community_messages")
            .select()
            .eq("community_id", value: communityId)
            .eq("is_removed", value: false)
        if let before {
            query = query.lt("created_at", value: before)
        }
        return try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Fetch specific messages by id — used for quoted-reply previews whose
    /// originals fell outside the loaded pages. Includes removed rows so the
    /// UI can render "Message removed".
    func messagesByIds(_ ids: [String]) async throws -> [CommunityMessage] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("community_messages")
            .select()
            .in("id", values: ids)
            .execute()
            .value
    }

    private struct NewCommunityMessage: Encodable {
        let community_id: String
        let sender_id: String
        let content: String
        let reply_to_id: String?
        let mentions: [String]
    }

    /// Throws ContactInfoBlocked when server-side detection rejects the message.
    /// Returns the inserted row so the sender sees the message immediately,
    /// without waiting for the realtime echo.
    @discardableResult
    func post(
        communityId: String,
        senderId: String,
        content: String,
        replyToId: String? = nil,
        mentions: [String] = []
    ) async throws -> CommunityMessage? {
        let inserted: [CommunityMessage] = try await client
            .from("community_messages")
            .insert(NewCommunityMessage(
                community_id: communityId,
                sender_id: senderId,
                content: content,
                reply_to_id: replyToId,
                mentions: mentions
            ))
            .select()
            .execute()
            .value
        return inserted.first
    }

    /// Name + avatar for the given user ids (for chat bubbles).
    func senderProfiles(ids: [String]) async throws -> [CommunitySender] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("users")
            .select("id, nickname, photos")
            .in("id", values: ids)
            .execute()
            .value
    }

    /// All reactions for the given messages (bulk, one query per page load).
    func reactions(messageIds: [String]) async throws -> [CommunityReaction] {
        guard !messageIds.isEmpty else { return [] }
        return try await client
            .from("community_message_reactions")
            .select()
            .in("message_id", values: messageIds)
            .execute()
            .value
    }

    func addReaction(messageId: String, userId: String, emoji: String) async throws {
        // community_id is filled by a DB trigger — never send it.
        try await client
            .from("community_message_reactions")
            .upsert([
                "message_id": messageId,
                "user_id": userId,
                "emoji": emoji
            ])
            .execute()
    }

    func removeReaction(messageId: String, userId: String, emoji: String) async throws {
        try await client
            .from("community_message_reactions")
            .delete()
            .eq("message_id", value: messageId)
            .eq("user_id", value: userId)
            .eq("emoji", value: emoji)
            .execute()
    }

    /// Active members of a room (for @mention autocomplete).
    func members(communityId: String) async throws -> [CommunitySender] {
        struct Row: Decodable { let users: CommunitySender }
        let rows: [Row] = try await client
            .from("community_members")
            .select("users(id, nickname, photos)")
            .eq("community_id", value: communityId)
            .eq("status", value: "active")
            .execute()
            .value
        return rows.map(\.users)
    }

    func prompts(communityId: String) async throws -> [CommunityPrompt] {
        // Room-specific OR global (community_id is null).
        try await client
            .from("community_prompts")
            .select("id, text")
            .or("community_id.eq.\(communityId),community_id.is.null")
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value
    }

    func subscribe(communityId: String, onMessage: @escaping @Sendable (CommunityMessage) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("community:\(communityId)")
        let changes = channel.postgresChange(
            InsertAction.self,
            table: "community_messages",
            filter: .eq("community_id", value: communityId)
        )
        Task {
            for await change in changes {
                if let msg = try? change.decodeRecord(as: CommunityMessage.self, decoder: JSONDecoder()) {
                    onMessage(msg)
                }
            }
        }
        Task { try? await channel.subscribeWithError() }
        return channel
    }

    /// Live reaction add/remove events for one room. DELETE events carry the
    /// full old row because the table has replica identity full.
    func subscribeReactions(
        communityId: String,
        onInsert: @escaping @Sendable (CommunityReaction) -> Void,
        onDelete: @escaping @Sendable (CommunityReaction) -> Void
    ) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("community-reactions:\(communityId)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            table: "community_message_reactions",
            filter: .eq("community_id", value: communityId)
        )
        let deletes = channel.postgresChange(
            DeleteAction.self,
            table: "community_message_reactions",
            filter: .eq("community_id", value: communityId)
        )
        Task {
            for await change in inserts {
                if let r = try? change.decodeRecord(as: CommunityReaction.self, decoder: JSONDecoder()) {
                    onInsert(r)
                }
            }
        }
        Task {
            for await change in deletes {
                if let r = try? change.decodeOldRecord(as: CommunityReaction.self, decoder: JSONDecoder()) {
                    onDelete(r)
                }
            }
        }
        Task { try? await channel.subscribeWithError() }
        return channel
    }

    func unsubscribe(_ channel: RealtimeChannelV2) {
        Task { await channel.unsubscribe() }
    }
}
