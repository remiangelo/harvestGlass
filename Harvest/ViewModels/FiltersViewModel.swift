import Foundation
import Observation

@Observable
final class FiltersViewModel {
    var filters = FilterPreferences()
    var userTier: TierName = .seed
    /// Comes from the tier row, not from the tier's name — the table decides
    /// what a plan buys.
    var filterLevel: FieldFilterLevel = .none
    var isLoading = false
    var error: String?
    var isSaved = false

    private let filterService = FilterService()
    private let subscriptionService = SubscriptionService()

    var canAccessAdvanced: Bool { filterLevel.unlocksAdvanced }

    var canAccessFull: Bool { filterLevel.unlocksFull }

    func loadFilters(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            filters = try await filterService.getFilters(userId: userId)
            if let sub = try await subscriptionService.getUserSubscription(userId: userId) {
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let tier = tiers.first(where: { $0.id == sub.tierId }) {
                    userTier = tier.name
                    filterLevel = tier.fieldFilterLevel
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveFilters(userId: String) async -> Bool {
        do {
            try await filterService.saveFilters(userId: userId, filters: filters)
            isSaved = true
            return true
        } catch {
            self.error = error.localizedDescription
            return false
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
