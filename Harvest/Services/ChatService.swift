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
            .select("id, user1_id, user2_id")
            .eq("match_id", value: matchId)
            .execute()
            .value

        if let existingConversation = existing.first {
            let normalizedUser1Id = user1Id.lowercased()
            let normalizedUser2Id = user2Id.lowercased()
            let needsRepair =
                existingConversation.user1Id?.lowercased() != normalizedUser1Id ||
                existingConversation.user2Id?.lowercased() != normalizedUser2Id

            if needsRepair {
                try await client
                    .from("conversations")
                    .update([
                        "user1_id": AnyJSON.string(user1Id),
                        "user2_id": AnyJSON.string(user2Id)
                    ])
                    .eq("id", value: existingConversation.id)
                    .execute()
            }

            return existingConversation.id
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

    func subscribeToMessages(conversationId: String, onMessage: @escaping @Sendable (Message) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("messages:\(conversationId)")

        let changes = channel.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("conversation_id", value: conversationId)
        )

        Task {
            for await change in changes {
                do {
                    let message = try change.decodeRecord(as: Message.self, decoder: JSONDecoder())
                    onMessage(message)
                } catch {
                    print("Warning: Failed to decode message from realtime update: \(error)")
                }
            }
        }

        Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("Error: Failed to subscribe to messages channel: \(error)")
            }
        }

        return channel
    }

    func unsubscribe(channel: RealtimeChannelV2) {
        Task {
            await channel.unsubscribe()
        }
    }

    // MARK: - Read Receipts

    func markAsRead(messageId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("messages")
            .update([
                "is_read": AnyJSON.bool(true),
                "read_at": AnyJSON.string(now)
            ])
            .eq("id", value: messageId)
            .execute()
    }

    // MARK: - Typing Indicators

    func sendTypingIndicator(conversationId: String, userId: String) async {
        let channel = client.realtimeV2.channel("typing:\(conversationId)")

        do {
            try await channel.subscribeWithError()
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            print("Warning: Failed to setup typing indicator channel: \(error)")
            return // Don't broadcast if subscription failed
        }

        await channel.broadcast(
            event: "typing",
            message: ["user_id": AnyJSON.string(userId)]
        )

        Task {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                // Task cancelled, proceed with cleanup
            }
            await channel.unsubscribe()
        }
    }

    func subscribeToTyping(conversationId: String, onTyping: @escaping @Sendable (String) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("typing:\(conversationId)")

        let broadcasts = channel.broadcastStream(event: "typing")

        Task {
            for await message in broadcasts {
                if let userId = message["user_id"]?.stringValue {
                    onTyping(userId)
                }
            }
        }

        Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("Error: Failed to subscribe to typing indicators: \(error)")
            }
        }

        return channel
    }
}
