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
    var inboundLikes: [InboundLikeWithProfile] = []
    var canSeeLikes = false
    var isLoading = false
    var error: String?

    private let matchService = MatchService()
    private let subscriptionService = SubscriptionService()
    private let swipeService = SwipeService()

    func loadMatches(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let matchesTask = matchService.getMatches(userId: userId)
            async let conversationsTask = matchService.getConversations(userId: userId)
            async let inboundLikesTask = matchService.getInboundLikes(userId: userId)
            async let tiersTask = subscriptionService.getSubscriptionTiers()
            async let subscriptionTask = subscriptionService.getUserSubscription(userId: userId)

            let loadedMatches = try await matchesTask
            let loadedConversations = try await conversationsTask
            let loadedInboundLikes = try await inboundLikesTask
            let tiers = try await tiersTask
            let subscription = try await subscriptionTask

            let conversationPairs: [(String, ConversationWithProfile)] = loadedConversations.compactMap { conversation in
                guard let matchId = conversation.conversation.matchId else { return nil }
                return (matchId, conversation)
            }
            let conversationsByMatchId = Dictionary(uniqueKeysWithValues: conversationPairs)

            matchThreads = loadedMatches.map { match in
                MatchThread(
                    match: match,
                    conversation: conversationsByMatchId[match.match.id]
                )
            }

            conversations = sortConversationsByRecentActivity(loadedConversations)
            inboundLikes = loadedInboundLikes

            if let subscription,
               let currentTier = tiers.first(where: { $0.id == subscription.tierId }) {
                canSeeLikes = currentTier.canSeeLikes
            } else if let seedTier = tiers.first(where: { $0.name == .seed }) {
                canSeeLikes = seedTier.canSeeLikes
            } else {
                canSeeLikes = false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadConversations(userId: String) async {
        do {
            let loadedConversations = try await matchService.getConversations(userId: userId)
            conversations = sortConversationsByRecentActivity(loadedConversations)
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

    func respondToInboundLike(
        currentUserId: String,
        inboundLike: InboundLikeWithProfile,
        action: SwipeAction
    ) async {
        do {
            _ = try await swipeService.saveSwipe(
                swiperId: currentUserId,
                swipedId: inboundLike.profile.id,
                action: action
            )
            await loadMatches(userId: currentUserId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sortConversationsByRecentActivity(_ conversations: [ConversationWithProfile]) -> [ConversationWithProfile] {
        conversations.sorted { lhs, rhs in
            conversationSortDate(lhs.conversation) > conversationSortDate(rhs.conversation)
        }
    }

    private func conversationSortDate(_ conversation: Conversation) -> Date {
        let formatter = ISO8601DateFormatter()

        if let lastMessageAt = conversation.lastMessageAt, let date = formatter.date(from: lastMessageAt) {
            return date
        }

        if let createdAt = conversation.createdAt, let date = formatter.date(from: createdAt) {
            return date
        }

        return .distantPast
    }
}
