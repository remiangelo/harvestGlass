import Foundation
import Observation

@Observable
final class SubscriptionViewModel {
    var tiers: [SubscriptionTier] = []
    var currentSubscription: UserSubscription?
    var currentTier: SubscriptionTier?
    var isLoading = false
    var error: String?

    private let subscriptionService = SubscriptionService()

    func loadSubscriptionData(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let tiersTask = subscriptionService.getSubscriptionTiers()
            async let subTask = subscriptionService.getUserSubscription(userId: userId)

            let (loadedTiers, loadedSub) = try await (tiersTask, subTask)
            tiers = loadedTiers
            currentSubscription = loadedSub

            if let sub = loadedSub {
                currentTier = loadedTiers.first { $0.id == sub.tierId }
            } else {
                currentTier = loadedTiers.first { $0.name == .seed }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isCurrentTier(_ tier: SubscriptionTier) -> Bool {
        currentTier?.id == tier.id
    }

    func canAccess(_ feature: TierName) -> Bool {
        guard let current = currentTier else { return false }
        let hierarchy: [TierName] = [.seed, .green, .gold]
        guard let currentLevel = hierarchy.firstIndex(of: current.name),
              let requiredLevel = hierarchy.firstIndex(of: feature) else { return false }
        return currentLevel >= requiredLevel
    }

    var currentTierName: String {
        currentTier?.displayName ?? "Seed"
    }
}
