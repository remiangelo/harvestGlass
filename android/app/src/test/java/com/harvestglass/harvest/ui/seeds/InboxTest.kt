package com.harvestglass.harvest.ui.seeds

import com.harvestglass.harvest.data.model.Conversation
import com.harvestglass.harvest.data.model.ConversationWithProfile
import com.harvestglass.harvest.data.model.Match
import com.harvestglass.harvest.data.model.MatchWithProfile
import com.harvestglass.harvest.data.model.UserProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The inbox merges two sources that overlap — conversations reached through a
 * match, and standalone conversations — so de-duplication and ordering are the
 * things worth locking down.
 */
class InboxTest {

    private fun profile(id: String, name: String) =
        UserProfile(id = id, nickname = name)

    private fun conversation(
        id: String,
        matchId: String? = null,
        at: String? = null,
        preview: String? = "hi"
    ) = ConversationWithProfile(
        conversation = Conversation(
            id = id,
            matchId = matchId,
            user1Id = "u1",
            user2Id = "u2",
            lastMessagePreview = preview,
            lastMessageAt = at
        ),
        profile = profile("u2", "Rae")
    )

    private fun match(id: String, profileId: String, name: String) = MatchWithProfile(
        match = Match(id = id, user1Id = "u1", user2Id = profileId),
        profile = profile(profileId, name)
    )

    @Test
    fun `a match with no conversation is a new match`() {
        val state = SeedsUiState(
            matchThreads = listOf(MatchThread(match("m1", "u2", "Rae"), null))
        )

        assertEquals(listOf("m1"), state.newMatches.map { it.id })
        assertTrue(state.unifiedMessages.isEmpty())
    }

    @Test
    fun `a match with a conversation is a message, not a new match`() {
        val convo = conversation("c1", matchId = "m1", at = "2026-08-25T10:00:00Z")
        val state = SeedsUiState(
            matchThreads = listOf(MatchThread(match("m1", "u2", "Rae"), convo))
        )

        assertTrue(state.newMatches.isEmpty())
        assertEquals(listOf("c1"), state.unifiedMessages.map { it.conversationId })
    }

    // The same conversation arrives through both sources; showing it twice
    // would be the obvious bug here.
    @Test
    fun `a conversation reachable both ways appears once`() {
        val convo = conversation("c1", matchId = "m1", at = "2026-08-25T10:00:00Z")
        val state = SeedsUiState(
            matchThreads = listOf(MatchThread(match("m1", "u2", "Rae"), convo)),
            conversations = listOf(convo)
        )

        assertEquals(1, state.unifiedMessages.size)
    }

    @Test
    fun `messages are newest first`() {
        val state = SeedsUiState(
            conversations = listOf(
                conversation("older", at = "2026-08-24T10:00:00Z"),
                conversation("newest", at = "2026-08-25T10:00:00Z"),
                conversation("middle", at = "2026-08-25T09:00:00Z")
            )
        )

        assertEquals(
            listOf("newest", "middle", "older"),
            state.unifiedMessages.map { it.conversationId }
        )
    }

    // A conversation with no messages yet has no timestamp; it must still be
    // listed, just last.
    @Test
    fun `a conversation with no timestamp sorts last rather than vanishing`() {
        val state = SeedsUiState(
            conversations = listOf(
                conversation("empty", at = null),
                conversation("recent", at = "2026-08-25T10:00:00Z")
            )
        )

        assertEquals(listOf("recent", "empty"), state.unifiedMessages.map { it.conversationId })
    }

    @Test
    fun `search filters by display name, case-insensitively`() {
        val state = SeedsUiState(
            conversations = listOf(conversation("c1", at = "2026-08-25T10:00:00Z")),
            search = "RAE"
        )

        assertEquals(1, state.unifiedMessages.size)
    }

    @Test
    fun `search with no match returns nothing`() {
        val state = SeedsUiState(
            conversations = listOf(conversation("c1", at = "2026-08-25T10:00:00Z")),
            search = "zzz"
        )

        assertTrue(state.unifiedMessages.isEmpty())
    }

    // Any paid plan sees "Likes You"; the default has to be locked so a failed
    // tier read can't hand it out.
    @Test
    fun `likes are gated by default`() {
        assertEquals(false, SeedsUiState().canSeeLikes)
    }
}
