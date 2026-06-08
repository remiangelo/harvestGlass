import Foundation
import Observation
import Realtime

@Observable
final class CommunityChatViewModel {
    var messages: [CommunityMessage] = []
    var prompts: [CommunityPrompt] = []
    var draft: String = ""
    var error: String?

    private let service = CommunityService()
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
        channel = service.subscribe(communityId: communityId) { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == msg.id }) && !msg.isRemoved {
                    self.messages.append(msg)
                }
            }
        }
    }

    func send(communityId: String, senderId: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await service.post(communityId: communityId, senderId: senderId, content: text)
            draft = ""
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
}
