import Foundation
import Observation

struct MatchThread: Identifiable {
    let match: MatchWithProfile
    let conversation: ConversationWithProfile?

    var id: String { match.id }
}

@Observable
final class MatchesViewModel {
    var matchThreads: [MatchThread] = []
    var conversations: [ConversationWithProfile] = []
    var isLoading = false
    var error: String?

    private let matchService = MatchService()

    func loadMatches(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let matchesTask = matchService.getMatches(userId: userId)
            async let conversationsTask = matchService.getConversations(userId: userId)

            let loadedMatches = try await matchesTask
            let loadedConversations = try await conversationsTask

            let conversationsByMatchId = Dictionary(
                uniqueKeysWithValues: loadedConversations.compactMap { conversation in
                    guard let matchId = conversation.conversation.matchId else { return nil }
                    return (matchId, conversation)
                }
            )

            matchThreads = loadedMatches.map { match in
                MatchThread(
                    match: match,
                    conversation: conversationsByMatchId[match.match.id]
                )
            }

            conversations = loadedConversations
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadConversations(userId: String) async {
        do {
            conversations = try await matchService.getConversations(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startConversation(matchWithProfile: MatchWithProfile, currentUserId: String) async -> String? {
        do {
            return try await matchService.ensureConversation(
                match: matchWithProfile.match,
                currentUserId: currentUserId
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
