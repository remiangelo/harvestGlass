import Foundation
import Observation

@Observable
final class FieldViewModel {
    var available: [Community] = []
    var joinedIds: Set<String> = []
    var isLoading = false
    var error: String?

    private let service = CommunityService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let avail = service.availableCommunities(userId: userId)
            async let joined = service.joinedCommunityIds(userId: userId)
            self.available = try await avail
            self.joinedIds = try await joined
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleJoin(_ community: Community, userId: String) async {
        do {
            if joinedIds.contains(community.id) {
                try await service.leave(communityId: community.id, userId: userId)
                joinedIds.remove(community.id)
            } else {
                try await service.join(communityId: community.id, userId: userId)
                joinedIds.insert(community.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isJoined(_ community: Community) -> Bool { joinedIds.contains(community.id) }
}
