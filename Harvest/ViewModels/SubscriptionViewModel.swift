import Foundation
import Observation
import StoreKit

@Observable
final class SubscriptionViewModel {
    var tiers: [SubscriptionTier] = []
    var currentSubscription: UserSubscription?
    var currentTier: SubscriptionTier?
    var isLoading = false
    var error: String?
    var successMessage: String?
    var products: [Product] = []
    var isPurchasing = false

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
        currentTier?.marketingDisplayName ?? "Seed"
    }

    // MARK: - StoreKit Purchase Methods

    func loadProducts() async {
        error = nil
        do {
            products = try await subscriptionService.fetchProducts()
            if products.isEmpty {
                self.error = "No subscription products were returned by StoreKit."
            }
        } catch {
            self.error = "Failed to load products: \(error.localizedDescription)"
            print("Error loading products: \(error)")
        }
    }

    func purchase(product: Product, userId: String) async {
        isPurchasing = true
        error = nil
        successMessage = nil
        defer { isPurchasing = false }

        do {
            _ = try await subscriptionService.purchase(product: product, userId: userId)

            // Reload subscription data after successful purchase
            await loadSubscriptionData(userId: userId)
            successMessage = "Your subscription is now active."

        } catch SubscriptionError.userCancelled {
            // Don't show error for user cancellation
            return

        } catch SubscriptionError.purchasePending {
            error = "Your purchase is pending approval. Please check back later."

        } catch {
            self.error = error.localizedDescription
            print("Error during purchase: \(error)")
        }
    }

    func restorePurchases(userId: String) async {
        isLoading = true
        error = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            try await subscriptionService.restorePurchases(userId: userId)

            // Reload subscription data after restore
            await loadSubscriptionData(userId: userId)
            successMessage = "Your purchases have been restored."

        } catch SubscriptionError.noPurchasesToRestore {
            error = "No previous purchases found to restore."

        } catch {
            self.error = "Failed to restore purchases: \(error.localizedDescription)"
            print("Error restoring purchases: \(error)")
        }
    }

    func checkSubscriptionStatus(userId: String) async {
        do {
            try await subscriptionService.checkSubscriptionStatus(userId: userId)

            // Reload subscription data to reflect any changes
            await loadSubscriptionData(userId: userId)

        } catch {
            print("Error checking subscription status: \(error)")
        }
    }

    func getProduct(for tier: SubscriptionTier, billingPeriod: BillingPeriod) -> Product? {
        let productId: String

        switch (tier.name, billingPeriod) {
        case (.green, .weekly):
            productId = SubscriptionService.ProductID.growWeekly.rawValue
        case (.green, .monthly):
            productId = SubscriptionService.ProductID.growMonthly.rawValue
        case (.gold, .weekly):
            productId = SubscriptionService.ProductID.goldWeekly.rawValue
        case (.gold, .monthly):
            productId = SubscriptionService.ProductID.goldMonthly.rawValue
        default:
            return nil
        }

        return products.first { $0.id == productId }
    }
}

enum BillingPeriod {
    case weekly
    case monthly
}
