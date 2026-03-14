import Foundation
import Observation
import UIKit

@Observable
final class DiscoverViewModel {
    var profiles: [UserProfile] = []
    var currentIndex = 0
    var isLoading = false
    var showMatchModal = false
    var matchedProfile: UserProfile?
    var matchId: String?
    var error: String?
    var compatibilityScores: [String: CompatibilityScore] = [:] // Profile ID -> Score

    private let swipeService = SwipeService()
    private let profileService = ProfileService()
    private let filterService = FilterService()
    private let rateLimitService = RateLimitService()
    private let subscriptionService = SubscriptionService()

    var currentProfile: UserProfile? {
        guard currentIndex < profiles.count else { return nil }
        return profiles[currentIndex]
    }

    var hasProfiles: Bool {
        currentIndex < profiles.count
    }

    var remainingCount: Int {
        max(0, profiles.count - currentIndex)
    }

    var currentCompatibilityScore: CompatibilityScore? {
        guard let profile = currentProfile else { return nil }
        return compatibilityScores[profile.id]
    }

    func loadProfiles(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let swipedIds = try await swipeService.getSwipeHistory(userId: userId)
            let filters = try? await filterService.getFilters(userId: userId)
            profiles = try await swipeService.getDiscoverProfiles(userId: userId, excludeIds: swipedIds, filters: filters)
            currentIndex = 0

            // Load compatibility scores for first few profiles
            await loadCompatibilityScores(for: userId, profileCount: min(5, profiles.count))
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadCompatibilityScores(for userId: String, profileCount: Int) async {
        let profilesToScore = profiles.prefix(profileCount)

        for profile in profilesToScore {
            do {
                let score = try await swipeService.getCompatibilityScore(
                    currentUserId: userId,
                    otherUserId: profile.id
                )
                compatibilityScores[profile.id] = score
            } catch {
                print("Warning: Failed to load compatibility score for profile \(profile.id): \(error)")
            }
        }
    }

    func swipe(action: SwipeAction, userId: String) async {
        guard let profile = currentProfile else { return }

        // Check match limits for likes/super likes
        if action == .like || action == .superLike {
            do {
                let sub = try await subscriptionService.getUserSubscription(userId: userId)
                let tiers = try await subscriptionService.getSubscriptionTiers()

                let tier: SubscriptionTier
                if let sub = sub, let userTier = tiers.first(where: { $0.id == sub.tierId }) {
                    tier = userTier
                } else if let seedTier = tiers.first(where: { $0.name == .seed }) {
                    tier = seedTier
                } else {
                    // Fallback - allow swipe
                    tier = tiers.first ?? SubscriptionTier(
                        id: "",
                        name: .seed,
                        displayName: "Seed",
                        description: "",
                        priceMonthly: 0,
                        priceYearly: 0,
                        matchesPerWeek: 10,
                        maxDistanceMiles: 25,
                        gardenerConversationsPerDay: 1,
                        gardenerCharacterLimit: 1000,
                        hasValuesMatching: false,
                        hasBasicFilters: true,
                        hasAdvancedFilters: false,
                        hasFullFilters: false,
                        canSeeLikes: false,
                        canDisableMindfulMessaging: false,
                        sortOrder: 0
                    )
                }

                let limitCheck = try await rateLimitService.checkMatchLimit(userId: userId, userTier: tier)

                if !limitCheck.canSwipe {
                    error = limitCheck.reason
                    return
                }
            } catch {
                print("Warning: Match limit check failed: \(error)")
                // Continue with swipe - don't block user
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            let result = try await swipeService.saveSwipe(
                swiperId: userId,
                swipedId: profile.id,
                action: action
            )

            if result.isMatch {
                matchedProfile = profile
                matchId = result.matchId
                showMatchModal = true

                let notificationGenerator = UINotificationFeedbackGenerator()
                notificationGenerator.notificationOccurred(.success)
            }
        } catch {
            self.error = error.localizedDescription
        }

        currentIndex += 1

        // Load more if running low
        if remainingCount < 3 {
            await loadProfiles(userId: userId)
        }
    }

    func dismissMatchModal() {
        showMatchModal = false
        matchedProfile = nil
        matchId = nil
    }
}
