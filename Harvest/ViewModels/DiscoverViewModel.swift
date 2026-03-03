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

    private let swipeService = SwipeService()
    private let profileService = ProfileService()
    private let filterService = FilterService()

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

    func loadProfiles(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let swipedIds = try await swipeService.getSwipeHistory(userId: userId)
            let filters = try? await filterService.getFilters(userId: userId)
            profiles = try await swipeService.getDiscoverProfiles(userId: userId, excludeIds: swipedIds, filters: filters)
            currentIndex = 0
        } catch {
            self.error = error.localizedDescription
        }
    }

    func swipe(action: SwipeAction, userId: String) async {
        guard let profile = currentProfile else { return }

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
