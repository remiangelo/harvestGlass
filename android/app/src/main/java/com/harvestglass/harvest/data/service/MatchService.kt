package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.Conversation
import com.harvestglass.harvest.data.model.ConversationWithProfile
import com.harvestglass.harvest.data.model.InboundLikeWithProfile
import com.harvestglass.harvest.data.model.Match
import com.harvestglass.harvest.data.model.MatchWithProfile
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.data.model.Swipe
import com.harvestglass.harvest.data.model.SwipeAction
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/**
 * The slice of Harvest/Services/MatchService.swift the app still reaches: the
 * conversation list, active matches, inbound likes, and the safety actions.
 *
 * The swipe deck itself stayed behind with Discover — nothing creates a new
 * swipe now except replying to an inbound like.
 */
class MatchService(
    private val client: SupabaseClient,
    private val profileService: ProfileService
) {

    // MARK: - Conversation list

    suspend fun getConversations(userId: String): List<ConversationWithProfile> {
        val blocked = getBlockedUserIds(userId)

        val matches = client.postgrest.from("matches")
            .select {
                filter {
                    or {
                        eq("user1_id", userId)
                        eq("user2_id", userId)
                    }
                    eq("is_active", true)
                }
            }
            .decodeList<Match>()

        if (matches.isEmpty()) return emptyList()

        val matchesById = matches.associateBy { it.id }
        val conversations = client.postgrest.from("conversations")
            .select {
                filter { isIn("match_id", matches.map { it.id }) }
                order("last_message_at", Order.DESCENDING)
            }
            .decodeList<Conversation>()
            .distinctBy { it.id }
            // Newest activity first, falling back to creation time.
            .sortedByDescending { it.lastMessageAt ?: it.createdAt ?: "" }

        val result = mutableListOf<ConversationWithProfile>()
        for (conversation in conversations) {
            val otherUserId = conversation.otherUserId(userId)
                ?: conversation.matchId?.let { matchesById[it]?.otherUserId(userId) }
                ?: continue

            if (blocked.contains(otherUserId.lowercase())) continue

            val profile = profileService.getProfile(otherUserId) ?: continue
            val hydrated = hydrateConversationPreviewIfNeeded(conversation)
            // A conversation with nothing said in it stays out of the list.
            if (hydrated.lastMessagePreview == null) continue

            result += ConversationWithProfile(
                conversation = hydrated,
                profile = profile,
                hasReplyHighlight = shouldHighlightConversation(hydrated, userId)
            )
        }
        return result
    }

    /**
     * Fills in `last_message_preview` for conversations created before the
     * column existed, so they don't silently vanish from the list.
     */
    private suspend fun hydrateConversationPreviewIfNeeded(conversation: Conversation): Conversation {
        if (conversation.lastMessagePreview != null) return conversation

        val latest = latestMessage(conversation.id) ?: return conversation
        val content = latest.content?.takeIf { it.isNotEmpty() } ?: return conversation

        val at = latest.createdAt ?: Instant.now().toString()
        val preview = content.take(PREVIEW_LENGTH)

        client.postgrest.from("conversations").update(
            buildJsonObject {
                put("last_message_at", at)
                put("last_message_preview", preview)
            }
        ) { filter { eq("id", conversation.id) } }

        return conversation.copy(lastMessageAt = at, lastMessagePreview = preview)
    }

    /** True when the newest message came from the other person. */
    private suspend fun shouldHighlightConversation(
        conversation: Conversation,
        currentUserId: String
    ): Boolean {
        val latest = latestMessage(conversation.id) ?: return false
        return !latest.isSentBy(currentUserId)
    }

    private suspend fun latestMessage(conversationId: String): Message? =
        client.postgrest.from("messages")
            .select {
                filter { eq("conversation_id", conversationId) }
                order("created_at", Order.DESCENDING)
                limit(1)
            }
            .decodeList<Message>()
            .firstOrNull()

    // MARK: - Safety actions

    // MARK: - Matches and inbound likes

    /**
     * Active matches with the other person's profile, newest first.
     *
     * Blocked users and duplicate pairings are dropped, so a pair that somehow
     * matched twice shows once.
     */
    suspend fun getMatches(userId: String): List<MatchWithProfile> {
        val blocked = getBlockedUserIds(userId)

        val matches = client.postgrest.from("matches")
            .select {
                filter {
                    or {
                        eq("user1_id", userId)
                        eq("user2_id", userId)
                    }
                    eq("is_active", true)
                }
                order("matched_at", Order.DESCENDING)
            }
            .decodeList<Match>()

        val result = mutableListOf<MatchWithProfile>()
        val seen = mutableSetOf<String>()

        for (match in matches) {
            val otherId = match.otherUserId(userId) ?: continue
            if (blocked.contains(otherId.lowercase())) continue
            if (!seen.add(otherId)) continue

            val profile = runCatching { profileService.getProfile(otherId) }.getOrNull() ?: continue
            result.add(MatchWithProfile(match, profile))
        }

        return result
    }

    /**
     * People who liked this user and are still waiting on an answer.
     *
     * Anyone already matched, already swiped on, or blocked is filtered out —
     * the list is only the ones a reply would still change something for.
     */
    suspend fun getInboundLikes(userId: String): List<InboundLikeWithProfile> {
        val blocked = getBlockedUserIds(userId)

        val inbound = client.postgrest.from("swipes")
            .select {
                filter {
                    eq("swiped_id", userId)
                    isIn("action", listOf(SwipeAction.LIKE.raw, SwipeAction.SUPER_LIKE.raw))
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Swipe>()

        if (inbound.isEmpty()) return emptyList()

        val matches = client.postgrest.from("matches")
            .select {
                filter {
                    or {
                        eq("user1_id", userId)
                        eq("user2_id", userId)
                    }
                }
            }
            .decodeList<Match>()

        val outgoing = client.postgrest.from("swipes")
            .select { filter { eq("swiper_id", userId) } }
            .decodeList<Swipe>()

        val matchedUserIds = matches.mapNotNull { it.otherUserId(userId)?.lowercase() }.toSet()
        val actedOnUserIds = outgoing.map { it.swipedId.lowercase() }.toSet()

        val result = mutableListOf<InboundLikeWithProfile>()
        val seen = mutableSetOf<String>()

        for (swipe in inbound) {
            val swiperId = swipe.swiperId.lowercase()
            if (matchedUserIds.contains(swiperId)) continue
            if (actedOnUserIds.contains(swiperId)) continue
            if (blocked.contains(swiperId)) continue
            if (!seen.add(swiperId)) continue

            val profile = runCatching { profileService.getProfile(swipe.swiperId) }.getOrNull()
                ?: continue
            result.add(InboundLikeWithProfile(swipe, profile))
        }

        return result
    }

    /**
     * Answers an inbound like. Returns the match id when the answer created a
     * match, which only a like or super-like can do.
     *
     * Mirrors `saveSwipe` in Harvest/Services/SwipeService.swift, including its
     * duplicate-key tolerance: swiping twice is a no-op, not an error.
     */
    suspend fun saveSwipe(swiperId: String, swipedId: String, action: SwipeAction): String? {
        try {
            client.postgrest.from("swipes").insert(
                buildJsonObject {
                    put("swiper_id", swiperId)
                    put("swiped_id", swipedId)
                    put("action", action.raw)
                }
            )
        } catch (e: Exception) {
            // 23505 is the unique violation: already swiped, nothing to do.
            if (e.message?.contains("23505") != true) throw e
            return null
        }

        if (action == SwipeAction.NOPE) return null

        @Serializable
        data class MatchStatus(
            @SerialName("is_matched") val isMatched: Boolean = false,
            @SerialName("match_id") val matchId: String? = null
        )

        val status = runCatching {
            client.postgrest.rpc(
                "get_match_status",
                buildJsonObject {
                    put("user_a", swiperId)
                    put("user_b", swipedId)
                }
            ).decodeList<MatchStatus>().firstOrNull()
        }.getOrNull()

        return if (status?.isMatched == true) status.matchId else null
    }

    suspend fun unmatchUser(matchId: String) {
        client.postgrest.from("matches").update(
            buildJsonObject {
                put("is_active", false)
                put("unmatched_at", Instant.now().toString())
            }
        ) { filter { eq("id", matchId) } }
    }

    suspend fun reportUser(
        reporterId: String,
        reportedUserId: String,
        category: String,
        description: String,
        targetType: String = "profile",
        targetId: String? = null
    ) {
        client.postgrest.from("user_reports").insert(
            buildJsonObject {
                put("reporter_id", reporterId)
                put("reported_id", reportedUserId)
                put("reason", category)
                put("description", description)
                put("target_type", targetType)
                if (targetId != null) put("target_id", targetId)
            }
        )
    }

    suspend fun blockUser(
        userId: String,
        blockedUserId: String,
        reason: String = "Blocked",
        description: String = "User blocked — auto-filed for moderator review."
    ) {
        client.postgrest.from("user_blocks").insert(
            buildJsonObject {
                put("blocker_id", userId)
                put("blocked_id", blockedUserId)
            }
        )

        // Apple 1.2: blocking must also notify the developer of the content so
        // it can be reviewed within 24h. File a report alongside; a failure
        // here must not undo the block, which is why it is swallowed.
        runCatching {
            reportUser(
                reporterId = userId,
                reportedUserId = blockedUserId,
                category = reason,
                description = description
            )
        }

        // Deactivate any live match between the two.
        val matches = client.postgrest.from("matches")
            .select {
                filter {
                    or {
                        eq("user1_id", userId)
                        eq("user2_id", userId)
                    }
                    eq("is_active", true)
                }
            }
            .decodeList<Match>()

        matches.filter { it.otherUserId(userId)?.lowercase() == blockedUserId.lowercase() }
            .forEach { unmatchUser(it.id) }
    }

    /**
     * Every user id in a block relationship with [userId], either direction,
     * lowercased, so callers can exclude them from feeds instantly.
     */
    suspend fun getBlockedUserIds(userId: String): Set<String> {
        @Serializable
        data class UserBlockRow(
            @SerialName("blocker_id") val blockerId: String? = null,
            @SerialName("blocked_id") val blockedId: String? = null
        )

        val rows = client.postgrest.from("user_blocks")
            .select {
                filter {
                    or {
                        eq("blocker_id", userId)
                        eq("blocked_id", userId)
                    }
                }
            }
            .decodeList<UserBlockRow>()

        val me = userId.lowercase()
        return rows
            .flatMap { listOfNotNull(it.blockerId, it.blockedId) }
            .map { it.lowercase() }
            .filterNot { it == me }
            .toSet()
    }

    companion object {
        private const val PREVIEW_LENGTH = 100
    }
}
