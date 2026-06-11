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

    func messages(communityId: String) async throws -> [CommunityMessage] {
        try await client
            .from("community_messages")
            .select()
            .eq("community_id", value: communityId)
            .eq("is_removed", value: false)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Throws ContactInfoBlocked when server-side detection rejects the message (Phase 6).
    /// Returns the inserted row so the sender sees the message immediately,
    /// without waiting for the realtime echo.
    @discardableResult
    func post(communityId: String, senderId: String, content: String) async throws -> CommunityMessage? {
        let inserted: [CommunityMessage] = try await client
            .from("community_messages")
            .insert([
                "community_id": communityId,
                "sender_id": senderId,
                "content": content
            ])
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

    func unsubscribe(_ channel: RealtimeChannelV2) {
        Task { await channel.unsubscribe() }
    }
}
