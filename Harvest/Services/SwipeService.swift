import Foundation
import Supabase

struct SwipeService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let compatibilityService = CompatibilityService()
    private let valuesService = ValuesService()
    private let profileService = ProfileService()

    func saveSwipe(swiperId: String, swipedId: String, action: SwipeAction) async throws -> SwipeResult {
        do {
            let _: [Swipe] = try await client
                .from("swipes")
                .insert([
                    "swiper_id": swiperId,
                    "swiped_id": swipedId,
                    "action": action.rawValue
                ])
                .select()
                .execute()
                .value

            if action == .like || action == .superLike {
                struct MatchStatus: Decodable {
                    let isMatched: Bool
                    let matchId: String?
                    enum CodingKeys: String, CodingKey {
                        case isMatched = "is_matched"
                        case matchId = "match_id"
                    }
                }

                let result: [MatchStatus] = try await client
                    .rpc("get_match_status", params: [
                        "user_a": swiperId,
                        "user_b": swipedId
                    ])
                    .execute()
                    .value

                if let status = result.first, status.isMatched {
                    return SwipeResult(success: true, isMatch: true, matchId: status.matchId)
                }
            }

            return SwipeResult(success: true)
        } catch {
            let nsError = error as NSError
            if nsError.localizedDescription.contains("23505") {
                return SwipeResult(success: false, error: "You have already swiped on this profile")
            }
            throw error
        }
    }

    func getSwipeHistory(userId: String) async throws -> [String] {
        struct SwipeRecord: Decodable {
            let swipedId: String
            enum CodingKeys: String, CodingKey {
                case swipedId = "swiped_id"
            }
        }

        let records: [SwipeRecord] = try await client
            .from("swipes")
            .select("swiped_id")
            .eq("swiper_id", value: userId)
            .execute()
            .value

        return records.map(\.swipedId)
    }

    func getDiscoverProfiles(userId: String, excludeIds: [String], filters: FilterPreferences? = nil) async throws -> [UserProfile] {
        // Fetch basic filtered profiles
        var query = client
            .from("users")
            .select()
            .neq("id", value: userId)

        for excludeId in excludeIds {
            query = query.neq("id", value: excludeId)
        }

        if let filters {
            query = query
                .gte("age", value: filters.ageMin)
                .lte("age", value: filters.ageMax)

            if !filters.showMe.isEmpty && !filters.showMe.contains("Everyone") {
                query = query.in("gender", values: filters.showMe)
            }
        }

        let profiles: [UserProfile] = try await query
            .not("photos", operator: .is, value: "null")
            .limit(50) // Fetch more to rank by compatibility
            .execute()
            .value

        // Get current user's profile and values for compatibility calculation
        guard let currentUser = try? await profileService.getProfile(userId: userId) else {
            return profiles // Fallback to unranked if can't get current user
        }

        let currentUserValuesBrought = (try? await valuesService.getUserValuesBrought(userId: userId)) ?? []
        let currentUserValuesSought = (try? await valuesService.getUserValuesSought(userId: userId)) ?? []

        // Fetch values for all candidate profiles
        var otherUsersValues: [String: (brought: [Value], sought: [Value])] = [:]
        for profile in profiles {
            let brought = (try? await valuesService.getUserValuesBrought(userId: profile.id)) ?? []
            let sought = (try? await valuesService.getUserValuesSought(userId: profile.id)) ?? []
            otherUsersValues[profile.id] = (brought: brought, sought: sought)
        }

        // Rank profiles by compatibility
        let rankedProfiles = compatibilityService.rankProfiles(
            currentUser: currentUser,
            profiles: profiles,
            currentUserValuesBrought: currentUserValuesBrought,
            currentUserValuesSought: currentUserValuesSought,
            otherUsersValues: otherUsersValues
        )

        // Return top 20 by compatibility
        return rankedProfiles.prefix(20).map { $0.profile }
    }

    /// Get compatibility score between current user and another user
    func getCompatibilityScore(currentUserId: String, otherUserId: String) async throws -> CompatibilityScore {
        guard let currentUser = try await profileService.getProfile(userId: currentUserId) else {
            throw NSError(domain: "SwipeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Current user profile not found"])
        }
        guard let otherUser = try await profileService.getProfile(userId: otherUserId) else {
            throw NSError(domain: "SwipeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Other user profile not found"])
        }

        let currentUserValuesBrought = (try? await valuesService.getUserValuesBrought(userId: currentUserId)) ?? []
        let currentUserValuesSought = (try? await valuesService.getUserValuesSought(userId: currentUserId)) ?? []
        let otherUserValuesBrought = (try? await valuesService.getUserValuesBrought(userId: otherUserId)) ?? []
        let otherUserValuesSought = (try? await valuesService.getUserValuesSought(userId: otherUserId)) ?? []

        return compatibilityService.calculateCompatibility(
            currentUser: currentUser,
            otherUser: otherUser,
            currentUserValuesBrought: currentUserValuesBrought,
            currentUserValuesSought: currentUserValuesSought,
            otherUserValuesBrought: otherUserValuesBrought,
            otherUserValuesSought: otherUserValuesSought
        )
    }
}
