import Foundation
import Observation

@Observable
final class SeedsViewModel {
    enum Segment { case requests, conversations }
    enum RequestKind { case received, sent }

    var segment: Segment = .requests
    var requestKind: RequestKind = .received
    var received: [Seed] = []
    var sent: [Seed] = []
    var isLoading = false
    var error: String?
    /// Set when a Seed is accepted so the view can route into the conversation.
    var openedConversationId: String?
    /// Partner user id for the opened conversation (sender of the accepted seed).
    var openedPartnerUserId: String?

    private let service = SeedService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let received = service.receivedPending(userId: userId)
            async let sent = service.sentPending(userId: userId)
            self.received = try await received
            self.sent = try await sent
        } catch {
            self.error = error.localizedDescription
        }
    }

    func accept(_ seed: Seed, userId: String) async {
        do {
            let convoId = try await service.acceptSeed(seedId: seed.id)
            received.removeAll { $0.id == seed.id }
            openedPartnerUserId = seed.senderId
            openedConversationId = convoId
        } catch {
            self.error = error.localizedDescription
        }
    }

    func decline(_ seed: Seed, userId: String) async {
        do {
            try await service.declineSeed(seedId: seed.id)
            received.removeAll { $0.id == seed.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
