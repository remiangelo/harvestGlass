package com.harvestglass.harvest.ui.seeds

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.ConversationWithProfile
import com.harvestglass.harvest.data.model.InboundLikeWithProfile
import com.harvestglass.harvest.data.model.MatchWithProfile
import com.harvestglass.harvest.data.model.Seed
import com.harvestglass.harvest.data.model.SwipeAction
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.SeedService
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class SeedsSegment { REQUESTS, CONVERSATIONS }

enum class RequestKind { RECEIVED, SENT }

/** A match paired with its conversation, if one has started. */
data class MatchThread(
    val match: MatchWithProfile,
    val conversation: ConversationWithProfile?
) {
    val id: String get() = match.id
}

/**
 * One row of the merged inbox. Matches and standalone conversations both
 * flatten into this, so the list has a single shape to sort and filter.
 */
data class InboxRow(
    val conversationId: String,
    val profile: UserProfile,
    val matchId: String?,
    val lastMessagePreview: String?,
    val lastMessageAt: String?,
    val hasReplyHighlight: Boolean
)

data class SeedsUiState(
    val segment: SeedsSegment = SeedsSegment.REQUESTS,
    val requestKind: RequestKind = RequestKind.RECEIVED,
    val received: List<Seed> = emptyList(),
    val sent: List<Seed> = emptyList(),
    val conversations: List<ConversationWithProfile> = emptyList(),
    val matchThreads: List<MatchThread> = emptyList(),
    val inboundLikes: List<InboundLikeWithProfile> = emptyList(),
    /**
     * "Likes You" predates Seeds and has no gate of its own now that
     * `can_see_likes` is gone. Any paid plan sees it, which is what the old
     * column encoded. Defaults to hidden so a failed tier read can't leak it.
     */
    val canSeeLikes: Boolean = false,
    val search: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    /** Set when a Seed is accepted so the view can route into the conversation. */
    val openedConversationId: String? = null,
    /** Partner user id for the opened conversation (the sender of the accepted seed). */
    val openedPartnerUserId: String? = null
) {
    val visibleRequests: List<Seed>
        get() = if (requestKind == RequestKind.RECEIVED) received else sent

    /** Matches that haven't become a conversation yet. */
    val newMatches: List<MatchThread>
        get() = matchThreads.filter { it.conversation == null }

    /**
     * Conversations from matches and standalone conversations merged, newest
     * first, de-duplicated by conversation id and filtered by [search].
     */
    val unifiedMessages: List<InboxRow>
        get() {
            val fromMatches = matchThreads.mapNotNull { thread ->
                val convo = thread.conversation ?: return@mapNotNull null
                InboxRow(
                    conversationId = convo.conversation.id,
                    profile = thread.match.profile,
                    matchId = thread.match.match.id,
                    lastMessagePreview = convo.conversation.lastMessagePreview,
                    lastMessageAt = convo.conversation.lastMessageAt,
                    hasReplyHighlight = convo.hasReplyHighlight
                )
            }

            val standalone = conversations.map { convo ->
                InboxRow(
                    conversationId = convo.conversation.id,
                    profile = convo.profile,
                    matchId = convo.conversation.matchId,
                    lastMessagePreview = convo.conversation.lastMessagePreview,
                    lastMessageAt = convo.conversation.lastMessageAt,
                    hasReplyHighlight = convo.hasReplyHighlight
                )
            }

            val seen = mutableSetOf<String>()
            val merged = (fromMatches + standalone)
                .filter { seen.add(it.conversationId) }
                .sortedByDescending { it.lastMessageAt.orEmpty() }

            if (search.isBlank()) return merged
            return merged.filter { it.profile.displayName.contains(search, ignoreCase = true) }
        }
}

/** Mirrors Harvest/ViewModels/SeedsViewModel.swift, plus the conversation list. */
@HiltViewModel
class SeedsViewModel @Inject constructor(
    private val seedService: SeedService,
    private val matchService: MatchService,
    private val subscriptionService: SubscriptionService
) : ViewModel() {

    private val _state = MutableStateFlow(SeedsUiState())
    val state: StateFlow<SeedsUiState> = _state.asStateFlow()

    fun setSegment(segment: SeedsSegment) = _state.update { it.copy(segment = segment) }

    fun setRequestKind(kind: RequestKind) = _state.update { it.copy(requestKind = kind) }

    fun setSearch(query: String) = _state.update { it.copy(search = query) }

    fun clearOpenedConversation() = _state.update {
        it.copy(openedConversationId = null, openedPartnerUserId = null)
    }

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val received = async { seedService.receivedPending(userId) }
                val sent = async { seedService.sentPending(userId) }
                // Everything below the requests half degrades to empty rather
                // than failing the whole tab — requests are still useful alone.
                val conversations = async {
                    runCatching { matchService.getConversations(userId) }.getOrNull()
                }
                val matches = async {
                    runCatching { matchService.getMatches(userId) }.getOrNull()
                }
                val likes = async {
                    runCatching { matchService.getInboundLikes(userId) }.getOrNull()
                }
                // Fail-closed: an unreadable tier keeps "Likes You" gated.
                val paid = async {
                    runCatching { subscriptionService.currentTier(userId)?.isPaid }.getOrNull()
                }

                val loadedConversations = conversations.await().orEmpty()
                val byMatchId = loadedConversations
                    .mapNotNull { convo -> convo.conversation.matchId?.let { it to convo } }
                    .toMap()

                _state.update {
                    it.copy(
                        received = received.await(),
                        sent = sent.await(),
                        conversations = loadedConversations,
                        matchThreads = matches.await().orEmpty().map { match ->
                            MatchThread(match, byMatchId[match.match.id])
                        },
                        inboundLikes = likes.await().orEmpty(),
                        canSeeLikes = paid.await() ?: false,
                        error = null
                    )
                }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun accept(seed: Seed, userId: String) = viewModelScope.launch {
        try {
            val conversationId = seedService.acceptSeed(seed.id)
            _state.update {
                it.copy(
                    received = it.received.filterNot { s -> s.id == seed.id },
                    // The partner is whoever SENT the seed we just accepted.
                    openedPartnerUserId = seed.senderId,
                    openedConversationId = conversationId,
                    error = null
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    /**
     * Answers an inbound like. A like back can create a match, so the whole
     * tab reloads rather than trying to patch the lists in place.
     */
    fun answerInboundLike(
        like: InboundLikeWithProfile,
        userId: String,
        action: SwipeAction
    ) = viewModelScope.launch {
        try {
            matchService.saveSwipe(userId, like.profile.id, action)
            _state.update {
                it.copy(
                    inboundLikes = it.inboundLikes.filterNot { l -> l.id == like.id },
                    error = null
                )
            }
            load(userId)
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    fun decline(seed: Seed, userId: String) = viewModelScope.launch {
        try {
            seedService.declineSeed(seed.id)
            _state.update {
                it.copy(received = it.received.filterNot { s -> s.id == seed.id }, error = null)
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }
}
