import Foundation
import Supabase

struct ProfileService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct PhotoRecord: Codable {
        let id: String?
        let userId: String
        let url: String
        let orderIndex: Int

        enum CodingKeys: String, CodingKey {
            case id, url
            case userId = "user_id"
            case orderIndex = "order_index"
        }
    }

    private struct PhotoInsertPayload: Encodable {
        let user_id: String
        let url: String
        let order_index: Int
        let is_primary: Bool
    }

    func getProfile(userId: String) async throws -> UserProfile? {
        let response: [UserProfile] = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard var profile = response.first else { return nil }

        let photoRows: [PhotoRecord] = (try? await client
            .from("photos")
            .select("id, user_id, url, order_index")
            .eq("user_id", value: userId)
            .order("order_index", ascending: true)
            .execute()
            .value) ?? []

        if !photoRows.isEmpty {
            profile.photos = photoRows.map(\.url)
        }

        return profile
    }

    func createProfile(userId: String, email: String) async throws -> UserProfile? {
        let defaultNickname = email.components(separatedBy: "@").first ?? "User"
        let now = ISO8601DateFormatter().string(from: Date())

        let values: [String: String] = [
            "id": userId,
            "email": email,
            "nickname": defaultNickname,
            "bio": "I'm new here!",
            "created_at": now,
            "updated_at": now
        ]

        let response: [UserProfile] = try await client
            .from("users")
            .upsert(values, onConflict: "id")
            .select()
            .execute()
            .value
        return response.first
    }

    func upsertProfile(userId: String, updates: [String: AnyJSON]) async throws -> UserProfile? {
        var mutableUpdates = updates
        mutableUpdates["id"] = .string(userId)
        mutableUpdates["updated_at"] = .string(ISO8601DateFormatter().string(from: Date()))

        let response: [UserProfile] = try await client
            .from("users")
            .upsert(mutableUpdates, onConflict: "id")
            .select()
            .execute()
            .value
        return response.first
    }

    func updateProfile(userId: String, updates: [String: AnyJSON]) async throws -> UserProfile? {
        var mutableUpdates = updates
        mutableUpdates["updated_at"] = AnyJSON.string(ISO8601DateFormatter().string(from: Date()))

        let response: [UserProfile] = try await client
            .from("users")
            .update(mutableUpdates)
            .eq("id", value: userId)
            .select()
            .execute()
            .value
        return response.first
    }

    func updatePhotos(userId: String, photoUrls: [String]) async throws -> UserProfile? {
        try await client
            .from("photos")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        if !photoUrls.isEmpty {
            for (index, url) in photoUrls.enumerated() {
                let photoRow = PhotoInsertPayload(
                    user_id: userId,
                    url: url,
                    order_index: index,
                    is_primary: index == 0
                )

                try await client
                    .from("photos")
                    .insert(photoRow)
                    .execute()
            }
        }

        // Keep legacy array column in sync for screens that still read it directly.
        let payload: [String: AnyJSON] = [
            "photos": .array(photoUrls.map { .string($0) }),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]

        _ = try await client
            .from("users")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .execute()
            .value as [UserProfile]

        return try await getProfile(userId: userId)
    }

    func appendPhoto(userId: String, photoUrl: String) async throws -> UserProfile? {
        let currentPhotos = (try await getProfile(userId: userId))?.photos ?? []

        let photoRow = PhotoInsertPayload(
            user_id: userId,
            url: photoUrl,
            order_index: currentPhotos.count,
            is_primary: currentPhotos.isEmpty
        )

        try await client
            .from("photos")
            .insert(photoRow)
            .execute()

        let updatedPhotos = currentPhotos + [photoUrl]
        let payload: [String: AnyJSON] = [
            "photos": .array(updatedPhotos.map { .string($0) }),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]

        _ = try await client
            .from("users")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .execute()
            .value as [UserProfile]

        return try await getProfile(userId: userId)
    }

    func checkOnboardingStatus(userId: String) async throws -> Bool {
        struct OnboardingCheck: Decodable {
            let bio: String?
            let age: Int?
            let gender: String?
            let photos: [String]?
        }

        let response: [OnboardingCheck] = try await client
            .from("users")
            .select("bio, age, gender, photos")
            .eq("id", value: userId)
            .execute()
            .value

        guard let data = response.first else { return false }
        return data.bio != nil && data.age != nil && data.gender != nil && (data.photos?.isEmpty == false)
    }

    func uploadPhoto(userId: String, imageData: Data, photoIndex: Int) async throws -> String {
        let fileName = "\(userId)/photo_\(photoIndex)_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"

        let response = try await client.storage
            .from(Config.storageBucket)
            .upload(
                fileName,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        return "\(Config.supabaseURL)/storage/v1/object/public/\(response.fullPath)"
    }

    func deletePhoto(userId: String, photoUrl: String) async throws {
        guard let url = URL(string: photoUrl),
              let pathComponent = url.path.components(separatedBy: "/storage/v1/object/public/\(Config.storageBucket)/").last
        else { return }

        try await client.storage
            .from(Config.storageBucket)
            .remove(paths: [pathComponent])

        try? await client
            .from("photos")
            .delete()
            .eq("user_id", value: userId)
            .eq("url", value: photoUrl)
            .execute()
    }
}
