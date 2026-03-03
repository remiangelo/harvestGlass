import Foundation
import Supabase
import Realtime

struct ChatService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getMessages(conversationId: String) async throws -> [Message] {
        let messages: [Message] = try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return messages
    }

    func sendMessage(conversationId: String, senderId: String, content: String) async throws -> Message? {
        let now = ISO8601DateFormatter().string(from: Date())

        let messages: [Message] = try await client
            .from("messages")
            .insert([
                "conversation_id": conversationId,
                "sender_id": senderId,
                "content": content,
                "message_type": "text",
                "created_at": now
            ])
            .select()
            .execute()
            .value

        // Update conversation's last message
        try await client
            .from("conversations")
            .update([
                "last_message_at": now,
                "last_message_preview": String(content.prefix(100))
            ])
            .eq("id", value: conversationId)
            .execute()

        return messages.first
    }

    func ensureConversation(matchId: String, user1Id: String, user2Id: String) async throws -> String? {
        // Check existing
        let existing: [Conversation] = try await client
            .from("conversations")
            .select("id")
            .eq("match_id", value: matchId)
            .execute()
            .value

        if let existingId = existing.first?.id {
            return existingId
        }

        // Create new
        let created: [Conversation] = try await client
            .from("conversations")
            .insert([
                "match_id": matchId,
                "user1_id": user1Id,
                "user2_id": user2Id
            ])
            .select("id")
            .execute()
            .value

        return created.first?.id
    }

    @available(*, deprecated, message: "Update to new Realtime filter syntax when available")
    func subscribeToMessages(conversationId: String, onMessage: @escaping @Sendable (Message) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("messages:\(conversationId)")

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        Task {
            for await change in changes {
                if let message = try? change.decodeRecord(as: Message.self, decoder: JSONDecoder()) {
                    onMessage(message)
                }
            }
        }

        Task {
            await channel.subscribe()
        }

        return channel
    }

    func unsubscribe(channel: RealtimeChannelV2) {
        Task {
            await channel.unsubscribe()
        }
    }
}
