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
                mentions: []
            )
            draft = ""
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
