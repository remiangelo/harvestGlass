package com.harvestglass.harvest.ui.field

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.model.CommunityPrompt
import com.harvestglass.harvest.data.model.CommunityReaction
import com.harvestglass.harvest.data.model.CommunitySender
import com.harvestglass.harvest.data.service.CommunityService
import com.harvestglass.harvest.data.service.MatchService
import com.harvestglass.harvest.data.service.MindfulAnalysis
import com.harvestglass.harvest.data.service.MindfulMessagingService
import com.harvestglass.harvest.data.service.ReactionEvent
import com.harvestglass.harvest.ui.components.chat.MessageGrouping
import com.harvestglass.harvest.ui.components.chat.MessagePosition
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CommunityChatUiState(
    val messages: List<CommunityMessage> = emptyList(),
    val prompts: List<CommunityPrompt> = emptyList(),
    val senders: Map<String, CommunitySender> = emptyMap(),
    val members: List<CommunitySender> = emptyList(),
    val referenced: Map<String, CommunityMessage> = emptyMap(),
    /** message id → reactions on it. */
    val reactions: Map<String, List<CommunityReaction>> = emptyMap(),
    val draft: String = "",
    val replyTarget: CommunityMessage? = null,
    val hasMore: Boolean = false,
    val isLoadingOlder: Boolean = false,
    val isSending: Boolean = false,
    /** Set when the pre-send check flags a message; drives the warning sheet. */
    val mindfulWarning: MindfulAnalysis? = null,
    /** The flagged text, held so "Send Anyway" posts exactly what was typed. */
    val pendingSend: String? = null,
    val error: String? = null
) {
    /**
     * Grouping metadata for every loaded message, keyed by message id.
     * Computed once per state read rather than per bubble redraw.
     */
    val positions: Map<String, MessagePosition>
        get() {
            val dates = messages.map { MessageGrouping.date(it.createdAt) }
            return messages.mapIndexed { i, message ->
                message.id to MessageGrouping.position(
                    previousSender = if (i > 0) messages[i - 1].senderId else null,
                    previousDate = if (i > 0) dates[i - 1] else null,
                    currentSender = message.senderId,
                    currentDate = dates[i],
                    nextSender = if (i + 1 < messages.size) messages[i + 1].senderId else null,
                    nextDate = if (i + 1 < messages.size) dates[i + 1] else null
                )
            }.toMap()
        }

    /**
     * The original message a reply points at, from loaded pages or the
     * referenced cache. null while it loads (the bubble hides the quote).
     */
    fun quotedMessage(for_: CommunityMessage): CommunityMessage? {
        val id = for_.replyToId ?: return null
        return messages.firstOrNull { it.id == id } ?: referenced[id]
    }

    /** Nicknames to highlight in a bubble, resolved from the mentions array. */
    fun mentionedNicknames(message: CommunityMessage): List<String> =
        message.mentions.orEmpty().mapNotNull { id ->
            senders[id]?.nickname ?: members.firstOrNull { it.id == id }?.nickname
        }
}

/**
 * Mirrors Harvest/ViewModels/CommunityChatViewModel.swift.
 *
 * The mindful-messaging pre-send warning that the Swift version runs before
 * posting is NOT ported here: MindfulMessagingService is an OpenAI-backed
 * service scoped to the P2 chat phase. Everything else — paging, realtime
 * merge, echo de-duplication, sender hydration, reaction toggling and
 * reply backfill — is reproduced.
 */
@HiltViewModel
class CommunityChatViewModel @Inject constructor(
    private val service: CommunityService,
    private val matchService: MatchService,
    private val mindful: MindfulMessagingService
) : ViewModel() {

    private val _state = MutableStateFlow(CommunityChatUiState())
    val state: StateFlow<CommunityChatUiState> = _state.asStateFlow()

    private var communityId: String = ""
    private var userId: String = ""
    private var messageJob: Job? = null
    private var reactionJob: Job? = null

    /**
     * Blocks overlapping toggles of the same (message, emoji) — a rapid
     * double-tap would otherwise race two opposite requests.
     */
    private val inFlightReactions = mutableSetOf<String>()

    /** nickname (lowercased) → user id, accumulated as the sender picks suggestions. */
    private val draftMentions = mutableMapOf<String, String>()

    private val pageSize = 50

    fun start(communityId: String, userId: String) {
        this.communityId = communityId
        this.userId = userId

        viewModelScope.launch {
            try {
                coroutineScope {
                    val pageDeferred = async { service.messagesPage(communityId, null, pageSize) }
                    val promptsDeferred = async { service.prompts(communityId) }
                    val membersDeferred = async { service.members(communityId) }

                    val newest = pageDeferred.await()
                    _state.update {
                        it.copy(
                            // Service returns newest-first; render oldest-first.
                            messages = newest.reversed(),
                            hasMore = newest.size == pageSize,
                            prompts = promptsDeferred.await(),
                            members = membersDeferred.await()
                        )
                    }
                }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.userMessage()) }
            }

            loadSenders(_state.value.messages.map { it.senderId }.toSet())
            loadReferenced()
            loadReactions(_state.value.messages.map { it.id })

            subscribe()
        }
    }

    private fun subscribe() {
        messageJob?.cancel()
        messageJob = viewModelScope.launch {
            service.subscribeMessages(communityId).collect { msg ->
                val known = _state.value.messages.any { it.id == msg.id }
                if (!known && !msg.isRemoved) {
                    _state.update { it.copy(messages = it.messages + msg) }
                    loadSenders(setOf(msg.senderId))
                    loadReferenced()
                }
            }
        }

        reactionJob?.cancel()
        reactionJob = viewModelScope.launch {
            service.subscribeReactions(communityId).collect { event ->
                when (event) {
                    is ReactionEvent.Added -> applyReaction(event.reaction)
                    is ReactionEvent.Removed -> dropReaction(event.reaction)
                }
            }
        }
    }

    fun loadOlder() = viewModelScope.launch {
        val s = _state.value
        val oldest = s.messages.firstOrNull()?.createdAt
        if (!s.hasMore || s.isLoadingOlder || oldest == null) return@launch

        _state.update { it.copy(isLoadingOlder = true) }
        try {
            val older = service.messagesPage(communityId, oldest, pageSize)
            val existing = _state.value.messages.map { it.id }.toSet()
            val fresh = older.reversed().filterNot { existing.contains(it.id) }
            _state.update {
                it.copy(messages = fresh + it.messages, hasMore = older.size == pageSize)
            }
            loadSenders(older.map { it.senderId }.toSet())
            loadReferenced()
            loadReactions(older.map { it.id })
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoadingOlder = false) }
        }
    }

    fun updateDraft(text: String) = _state.update { it.copy(draft = text) }

    fun setReplyTarget(message: CommunityMessage?) = _state.update { it.copy(replyTarget = message) }

    /**
     * Files a report against one message. The message id rides along so a
     * moderator lands on what was said, not just on the account.
     */
    fun reportMessage(
        reportedUserId: String,
        messageId: String,
        category: String,
        description: String
    ) = viewModelScope.launch {
        try {
            matchService.reportUser(
                reporterId = userId,
                reportedUserId = reportedUserId,
                category = category,
                description = description,
                targetType = "community_message",
                targetId = messageId
            )
            _state.update { it.copy(error = null) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        }
    }

    /**
     * Runs the mindful check before posting. A flagged message opens the
     * warning instead — the send is deferred, not cancelled.
     */
    fun send(content: String = _state.value.draft) = viewModelScope.launch {
        // Commit 72f4202: gate re-entry so a double tap can't insert twice.
        if (_state.value.isSending) return@launch
        val text = content.trim()
        if (text.isEmpty()) return@launch

        if (mindful.isEnabled) {
            val analysis = mindful.analyzeMessage(text)
            if (analysis.needsReview) {
                _state.update { it.copy(mindfulWarning = analysis, pendingSend = text) }
                return@launch
            }
        }

        deliver(text)
    }

    /** Dismisses the warning and puts the text back in the composer. */
    fun editFlaggedMessage() = _state.update {
        it.copy(mindfulWarning = null, pendingSend = null, draft = it.pendingSend ?: it.draft)
    }

    /** The nudge is not a block: this posts the message as typed. */
    fun sendAnyway() = viewModelScope.launch {
        val text = _state.value.pendingSend ?: return@launch
        _state.update { it.copy(mindfulWarning = null, pendingSend = null) }
        deliver(text)
    }

    private suspend fun deliver(text: String) {
        // Clear up front. Leaving the text in place during the network call
        // is what made a second tap possible on iOS.
        _state.update { it.copy(isSending = true, draft = "", error = null) }

        val replyToId = _state.value.replyTarget?.id
        try {
            val sent = service.post(
                communityId = communityId,
                senderId = userId,
                content = text,
                replyToId = replyToId,
                mentions = mentionsIn(text)
            )
            draftMentions.clear()
            _state.update { s ->
                val alreadyThere = sent == null || s.messages.any { it.id == sent.id }
                s.copy(
                    replyTarget = null,
                    messages = if (alreadyThere) s.messages else s.messages + sent!!
                )
            }
            loadSenders(setOf(userId))
        } catch (e: Exception) {
            val message = e.toString()
            _state.update {
                it.copy(
                    // Hand the text back so a failed send isn't a lost message.
                    draft = text,
                    error = if (message.contains("CONTACT_INFO_BLOCKED")) {
                        "Keep contact sharing to private Seed conversations 🌱"
                    } else {
                        e.userMessage()
                    }
                )
            }
        } finally {
            _state.update { it.copy(isSending = false) }
        }
    }

    fun toggleReaction(messageId: String, emoji: String) = viewModelScope.launch {
        val key = messageId + emoji
        if (inFlightReactions.contains(key)) return@launch
        inFlightReactions.add(key)

        val mine = CommunityReaction(
            messageId = messageId,
            userId = userId,
            emoji = emoji,
            communityId = communityId
        )
        val alreadyMine = _state.value.reactions[messageId].orEmpty()
            .any { it.userId == userId && it.emoji == emoji }

        // Optimistic; the realtime echo is deduped by apply/dropReaction.
        if (alreadyMine) dropReaction(mine) else applyReaction(mine)

        try {
            if (alreadyMine) {
                service.removeReaction(messageId, userId, emoji)
            } else {
                service.addReaction(messageId, userId, emoji)
            }
        } catch (e: Exception) {
            // Roll back.
            if (alreadyMine) applyReaction(mine) else dropReaction(mine)
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            inFlightReactions.remove(key)
        }
    }

    /** Non-empty while the draft ends in an "@query" token that matches members. */
    fun mentionSuggestions(): List<CommunitySender> {
        val query = currentMentionQuery() ?: return emptyList()
        return _state.value.members.filter { member ->
            val nick = member.nickname
            !nick.isNullOrEmpty() && (query.isEmpty() || nick.lowercase().startsWith(query))
        }
    }

    fun pickMention(member: CommunitySender) {
        val nick = member.nickname ?: return
        val draft = _state.value.draft
        val atIndex = draft.lastIndexOf('@')
        if (atIndex < 0) return
        _state.update { it.copy(draft = draft.substring(0, atIndex) + "@" + nick + " ") }
        draftMentions[nick.lowercase()] = member.id
    }

    /** The trailing "@..." token of the draft, lowercased, or null. */
    private fun currentMentionQuery(): String? {
        val draft = _state.value.draft
        val atIndex = draft.lastIndexOf('@')
        if (atIndex < 0) return null
        // A space before "@" (or "@" at the start) begins a mention;
        // a space after it ends one.
        if (atIndex > 0) {
            val before = draft[atIndex - 1]
            if (before != ' ' && before != '\n') return null
        }
        val after = draft.substring(atIndex + 1)
        if (after.contains(' ') || after.contains('\n')) return null
        return after.lowercase()
    }

    /**
     * User ids whose "@nickname" is still present in the text.
     * Boundary-checked so "@al" never matches inside "@alex".
     */
    private fun mentionsIn(text: String): List<String> {
        val lower = text.lowercase()
        return draftMentions.mapNotNull { (nick, id) ->
            if (containsMentionToken(lower, "@$nick")) id else null
        }
    }

    private fun applyReaction(r: CommunityReaction) = _state.update { s ->
        if (s.messages.none { it.id == r.messageId }) return@update s
        val list = s.reactions[r.messageId].orEmpty()
        if (list.any { it.userId == r.userId && it.emoji == r.emoji }) return@update s
        s.copy(reactions = s.reactions + (r.messageId to list + r))
    }

    private fun dropReaction(r: CommunityReaction) = _state.update { s ->
        val list = s.reactions[r.messageId] ?: return@update s
        s.copy(
            reactions = s.reactions + (
                r.messageId to list.filterNot { it.userId == r.userId && it.emoji == r.emoji }
                )
        )
    }

    /** Fetch originals for any quoted replies whose parent isn't loaded. */
    private suspend fun loadReferenced() {
        val s = _state.value
        val loaded = s.messages.map { it.id }.toSet()
        val missing = s.messages.mapNotNull { it.replyToId }.toSet() - loaded - s.referenced.keys
        if (missing.isEmpty()) return
        val rows = runCatching { service.messagesByIds(missing.toList()) }.getOrNull() ?: return
        _state.update { it.copy(referenced = it.referenced + rows.associateBy { r -> r.id }) }
        loadSenders(rows.map { it.senderId }.toSet())
    }

    private suspend fun loadReactions(messageIds: List<String>) {
        if (messageIds.isEmpty()) return
        val rows = runCatching { service.reactions(messageIds) }.getOrNull() ?: return
        _state.update { s ->
            val grouped = s.reactions.toMutableMap()
            messageIds.forEach { grouped[it] = emptyList() }
            rows.forEach { grouped[it.messageId] = grouped[it.messageId].orEmpty() + it }
            s.copy(reactions = grouped)
        }
    }

    private suspend fun loadSenders(ids: Set<String>) {
        val missing = ids - _state.value.senders.keys
        if (missing.isEmpty()) return
        val rows = runCatching { service.senderProfiles(missing.toList()) }.getOrNull() ?: return
        _state.update { it.copy(senders = it.senders + rows.associateBy { r -> r.id }) }
    }

    override fun onCleared() {
        super.onCleared()
        // Cancelling collection unsubscribes the realtime channels.
        messageJob?.cancel()
        reactionJob?.cancel()
    }

    companion object {
        /** True when [needle] occurs in [haystack] ending at a word boundary. */
        fun containsMentionToken(haystack: String, needle: String): Boolean {
            var from = 0
            while (true) {
                val i = haystack.indexOf(needle, from)
                if (i < 0) return false
                val end = i + needle.length
                if (end == haystack.length) return true
                val next = haystack[end]
                if (!next.isLetterOrDigit()) return true
                from = end
            }
        }
    }
}
