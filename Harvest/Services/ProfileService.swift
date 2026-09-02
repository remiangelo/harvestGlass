import Foundation
import Supabase

struct ProfileService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getProfile(userId: String) async throws -> UserProfile? {
        let response: [UserProfile] = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard let profile = response.first else { return nil }

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
        let sessionEmail = try? await client.auth.session.user.email

        let response: [UserProfile] = try await client
            .from("users")
            .upsert(
                Self.upsertPayload(
                    userId: userId,
                    email: sessionEmail,
                    updates: updates,
                    nowISO: ISO8601DateFormatter().string(from: Date())
                ),
                onConflict: "id"
            )
            .select()
            .execute()
            .value
        return response.first
    }

    /// The row an upsert proposes.
    ///
    /// `users.email` is NOT NULL with no default, and Postgres validates the
    /// proposed tuple *before* it resolves ON CONFLICT — so leaving email out
    /// raises 23502 whether or not the row already exists, which is what
    /// stranded users at the last step of onboarding.
    ///
    /// The session's address goes in first so an explicit one in `updates`
    /// still wins, and an unknown one is left out rather than written as null.
    static func upsertPayload(
        userId: String,
        email: String?,
        updates: [String: AnyJSON],
        nowISO: String
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [:]
        if let email { payload["email"] = .string(email) }
        payload.merge(updates) { _, new in new }
        payload["id"] = .string(userId)
        payload["updated_at"] = .string(nowISO)
        return payload
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
    }
}
