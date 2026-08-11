import Foundation
import Observation

@Observable
final class RoomMembersViewModel {
    var members: [UserProfile] = []
    var filter = RoomMemberFilter()
    var userTier: TierName = .seed
    var filterLevel: FieldFilterLevel = .none
    var isLoading = false
    var error: String?

    private let service = CommunityService()
    private let subscriptionService = SubscriptionService()

    /// Mirrors FiltersViewModel — both read the level off the tier row.
    var canAccessAdvanced: Bool { filterLevel.unlocksAdvanced }
    var canAccessFull: Bool { filterLevel.unlocksFull }

    /// Members matching the filter, excluding the viewer, alphabetical.
    func visibleMembers(excluding currentUserId: String) -> [UserProfile] {
        members
            .filter { $0.id != currentUserId }
            .filter { filter.matches($0) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func load(communityId: String, userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await service.memberProfiles(communityId: communityId)
        } catch {
            self.error = error.localizedDescription
        }
        // Tier is non-critical: a failure here just leaves the paid filters
        // locked, which is the safe default.
        if let sub = try? await subscriptionService.getUserSubscription(userId: userId),
           let tiers = try? await subscriptionService.getSubscriptionTiers(),
           let tier = tiers.first(where: { $0.id == sub.tierId }) {
            userTier = tier.name
            filterLevel = tier.fieldFilterLevel
        }
    }

    func resetFilter() {
        // Search is deliberately preserved — clearing filters shouldn't wipe
        // what someone is actively typing.
        let search = filter.search
        filter = RoomMemberFilter()
        filter.search = search
    }
}
