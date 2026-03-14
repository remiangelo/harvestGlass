import Foundation
import Observation

@Observable
final class FiltersViewModel {
    var filters = FilterPreferences()
    var userTier: TierName = .seed
    var isLoading = false
    var error: String?
    var isSaved = false

    private let filterService = FilterService()
    private let subscriptionService = SubscriptionService()

    var canAccessAdvanced: Bool {
        userTier == .green || userTier == .gold
    }

    var canAccessFull: Bool {
        userTier == .gold
    }

    func loadFilters(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            filters = try await filterService.getFilters(userId: userId)
            if let sub = try await subscriptionService.getUserSubscription(userId: userId) {
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let tier = tiers.first(where: { $0.id == sub.tierId }) {
                    userTier = tier.name
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveFilters(userId: String) async {
        do {
            try await filterService.saveFilters(userId: userId, filters: filters)
            isSaved = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resetFilters(userId: String) async {
        do {
            try await filterService.resetFilters(userId: userId)
            filters = FilterPreferences()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
