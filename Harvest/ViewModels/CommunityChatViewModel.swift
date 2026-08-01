import Foundation
import Observation
import Realtime

@Observable
final class CommunityChatViewModel {
    var messages: [CommunityMessage] = []
    var prompts: [CommunityPrompt] = []
    var senders: [String: CommunitySender] = [:]
    var members: [CommunitySender] = []
    var referenced: [String: CommunityMessage] = [:]
    var draft: String = ""
    var error: String?
    var hasMore = false
    var isLoadingOlder = false
    var replyTarget: CommunityMessage?

    /// message id → reactions on it.
    var reactions: [String: [CommunityReaction]] = [:]
    private var reactionChannel: RealtimeChannelV2?

    /// Blocks overlapping toggles of the same (message, emoji) — a rapid
    /// double-tap would otherwise race two opposite requests.
    private var inFlightReactions: Set<String> = []

    /// nickname (lowercased) → user id, accumulated as the sender picks
    /// suggestions. Filtered against the final text at send time.
    private var draftMentions: [String: String] = [:]

    let pageSize = 50

    // Mindful messaging — outgoing pre-send warning (mirrors 1:1 chat).
    var mindfulAnalysis: MindfulMessagingService.MindfulAnalysis?
    var showMindfulWarning = false
    private var pendingDraft = ""

    private let service = CommunityService()
    private let mindfulService = MindfulMessagingService()
    private var channel: RealtimeChannelV2?

    func start(communityId: String) async {
        do {
            async let page = service.messagesPage(communityId: communityId, before: nil, limit: pageSize)
            async let pr = service.prompts(communityId: communityId)
            async let mem = service.members(communityId: communityId)
            let newest = try await page
            self.messages = newest.reversed()
            self.hasMore = newest.count == pageSize
            self.prompts = try await pr
            self.members = try await mem
        } catch {
            self.error = error.localizedDescription
        }
        await loadSenders(for: Set(messages.map(\.senderId)))
        await loadReferenced()
        await loadReactions(for: messages.map(\.id))
        channel = service.subscribe(communityId: communityId) { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == msg.id }) && !msg.isRemoved {
                    self.messages.append(msg)
                    await self.loadSenders(for: [msg.senderId])
                    await self.loadReferenced()
                }
            }
        }
        reactionChannel = service.subscribeReactions(
            communityId: communityId,
            onInsert: { [weak self] r in
                Task { @MainActor in self?.applyReaction(r) }
            },
            onDelete: { [weak self] r in
                Task { @MainActor in self?.dropReaction(r) }
            }
        )
    }

    func loadOlder(communityId: String) async {
        guard hasMore, !isLoadingOlder, let oldest = messages.first?.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older = try await service.messagesPage(communityId: communityId, before: oldest, limit: pageSize)
            hasMore = older.count == pageSize
            let existing = Set(messages.map(\.id))
            messages.insert(contentsOf: older.reversed().filter { !existing.contains($0.id) }, at: 0)
            await loadSenders(for: Set(older.map(\.senderId)))
            await loadReferenced()
            await loadReactions(for: older.map(\.id))
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The original message a reply points at, from loaded pages or the
    /// referenced cache. nil while it loads (bubble hides the quote briefly).
    func quotedMessage(for message: CommunityMessage) -> CommunityMessage? {
        guard let id = message.replyToId else { return nil }
        return messages.first(where: { $0.id == id }) ?? referenced[id]
    }

    /// Fetch originals for any quoted replies whose parent isn't loaded.
    private func loadReferenced() async {
        let loaded = Set(messages.map(\.id))
        let missing = Set(messages.compactMap(\.replyToId))
            .subtracting(loaded)
            .subtracting(referenced.keys)
        guard !missing.isEmpty else { return }
        if let rows = try? await service.messagesByIds(Array(missing)) {
            for row in rows { referenced[row.id] = row }
            await loadSenders(for: Set(rows.map(\.senderId)))
        }
    }

    private func loadReactions(for messageIds: [String]) async {
        guard !messageIds.isEmpty else { return }
        if let rows = try? await service.reactions(messageIds: messageIds) {
            var grouped = reactions
            for id in messageIds { grouped[id] = [] }
            for row in rows { grouped[row.messageId, default: []].append(row) }
            reactions = grouped
        }
    }

    private func applyReaction(_ r: CommunityReaction) {
        guard messages.contains(where: { $0.id == r.messageId }) else { return }
        var list = reactions[r.messageId] ?? []
        guard !list.contains(where: { $0.userId == r.userId && $0.emoji == r.emoji }) else { return }
        list.append(r)
        reactions[r.messageId] = list
    }

    private func dropReaction(_ r: CommunityReaction) {
        guard var list = reactions[r.messageId] else { return }
        list.removeAll { $0.userId == r.userId && $0.emoji == r.emoji }
        reactions[r.messageId] = list
    }

    func toggleReaction(emoji: String, message: CommunityMessage, userId: String) async {
        let key = message.id + emoji
        guard !inFlightReactions.contains(key) else { return }
        inFlightReactions.insert(key)
        defer { inFlightReactions.remove(key) }
        let mine = CommunityReaction(messageId: message.id, userId: userId, emoji: emoji, communityId: message.communityId)
        let alreadyMine = (reactions[message.id] ?? [])
            .contains(where: { $0.userId == userId && $0.emoji == emoji })
        // Optimistic; realtime echo is deduped by applyReaction/dropReaction.
        if alreadyMine {
            dropReaction(mine)
        } else {
            applyReaction(mine)
        }
        do {
            if alreadyMine {
                try await service.removeReaction(messageId: message.id, userId: userId, emoji: emoji)
            } else {
                try await service.addReaction(messageId: message.id, userId: userId, emoji: emoji)
            }
        } catch {
            // Roll back
            if alreadyMine { applyReaction(mine) } else { dropReaction(mine) }
            self.error = error.localizedDescription
        }
    }

    /// Non-empty while the draft ends in an "@query" token that matches members.
    var mentionSuggestions: [CommunitySender] {
        guard let query = currentMentionQuery() else { return [] }
        return members.filter { member in
            guard let nick = member.nickname, !nick.isEmpty else { return false }
            return query.isEmpty || nick.lowercased().hasPrefix(query)
        }
    }

    /// The trailing "@..." token of the draft, lowercased, or nil.
    private func currentMentionQuery() -> String? {
        guard let atIndex = draft.lastIndex(of: "@") else { return nil }
        let after = draft[draft.index(after: atIndex)...]
        // A space before "@" (or "@" at the start) begins a mention; a space
        // after it ends one.
        if atIndex != draft.startIndex {
            let before = draft[draft.index(before: atIndex)]
            guard before == " " || before == "\n" else { return nil }
        }
        guard !after.contains(" "), !after.contains("\n") else { return nil }
        return after.lowercased()
    }

    func pickMention(_ member: CommunitySender) {
        guard let nick = member.nickname, let atIndex = draft.lastIndex(of: "@") else { return }
        draft = String(draft[..<atIndex]) + "@" + nick + " "
        draftMentions[nick.lowercased()] = member.id
    }

    /// User ids whose "@nickname" is still present in the given text.
    /// Boundary-checked so "@al" never matches inside "@alex".
    private func mentions(in text: String) -> [String] {
        let lower = text.lowercased()
        return draftMentions.compactMap { nick, id in
            Self.containsMentionToken(lower, "@" + nick) ? id : nil
        }
    }

    /// True when `needle` occurs in `haystack` ending at a word boundary.
    static func containsMentionToken(_ haystack: String, _ needle: String) -> Bool {
        var searchStart = haystack.startIndex
        while let r = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            if r.upperBound == haystack.endIndex {
                return true
            }
            let next = haystack[r.upperBound]
            if !next.isLetter && !next.isNumber {
                return true
            }
            searchStart = r.upperBound
        }
        return false
    }

    /// Nicknames to highlight in a message bubble, resolved from the
    /// mentions id array via the sender/member caches.
    func mentionedNicknames(for message: CommunityMessage) -> [String] {
        guard let ids = message.mentions, !ids.isEmpty else { return [] }
        return ids.compactMap { id in
            senders[id]?.nickname ?? members.first(where: { $0.id == id })?.nickname
        }
    }

    func send(communityId: String, senderId: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Mindful messaging check — warn the sender before posting concerning content.
        if mindfulService.isEnabled {
            let analysis = await mindfulService.analyzeMessage(text)
            if analysis.needsReview {
                mindfulAnalysis = analysis
                pendingDraft = text
                showMindfulWarning = true
                return
            }
        }

        await performSend(communityId: communityId, senderId: senderId, text: text)
    }

    func confirmSendDespiteWarning(communityId: String, senderId: String) async {
        showMindfulWarning = false
        mindfulAnalysis = nil
        let text = pendingDraft
        guard !text.isEmpty else { return }
        await performSend(communityId: communityId, senderId: senderId, text: text)
    }

    func dismissMindfulWarning() {
        showMindfulWarning = false
        mindfulAnalysis = nil
    }

    private func performSend(communityId: String, senderId: String, text: String) async {
        do {
            let sent = try await service.post(
                communityId: communityId,
                senderId: senderId,
                content: text,
                replyToId: replyTarget?.id,
                mentions: mentions(in: text)
            )
            draft = ""
            draftMentions = [:]
            pendingDraft = ""
            replyTarget = nil
            if let sent, !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            await loadSenders(for: [senderId])
        } catch {
            // Phase 6: contact-info block surfaces here as a friendly nudge.
            if "\(error)".contains("CONTACT_INFO_BLOCKED") {
                self.error = "Keep contact sharing to private Seed conversations 🌱"
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    func stop() {
        if let channel { service.unsubscribe(channel) }
        channel = nil
        if let reactionChannel { service.unsubscribe(reactionChannel) }
        reactionChannel = nil
    }

    private func loadSenders(for ids: Set<String>) async {
        let missing = ids.subtracting(senders.keys)
        guard !missing.isEmpty else { return }
        if let rows = try? await service.senderProfiles(ids: Array(missing)) {
            for row in rows {
                senders[row.id] = row
            }
        }
    }
}
