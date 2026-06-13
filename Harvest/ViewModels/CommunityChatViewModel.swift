import Foundation
import Observation
import Realtime

@Observable
final class CommunityChatViewModel {
    var messages: [CommunityMessage] = []
    var prompts: [CommunityPrompt] = []
    var senders: [String: CommunitySender] = [:]
    var draft: String = ""
    var error: String?

    // Mindful messaging — outgoing pre-send warning (mirrors 1:1 chat).
    var mindfulAnalysis: MindfulMessagingService.MindfulAnalysis?
    var showMindfulWarning = false
    private var pendingDraft = ""

    private let service = CommunityService()
    private let mindfulService = MindfulMessagingService()
    private var channel: RealtimeChannelV2?

    func start(communityId: String) async {
        do {
            async let msgs = service.messages(communityId: communityId)
            async let pr = service.prompts(communityId: communityId)
            self.messages = try await msgs
            self.prompts = try await pr
        } catch {
            self.error = error.localizedDescription
        }
        await loadSenders(for: Set(messages.map(\.senderId)))
        channel = service.subscribe(communityId: communityId) { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == msg.id }) && !msg.isRemoved {
                    self.messages.append(msg)
                    await self.loadSenders(for: [msg.senderId])
                }
            }
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
            let sent = try await service.post(communityId: communityId, senderId: senderId, content: text)
            draft = ""
            pendingDraft = ""
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
