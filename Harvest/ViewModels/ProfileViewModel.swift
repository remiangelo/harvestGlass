import Foundation
import Observation
import Supabase

@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    var isEditing = false
    var isLoading = false
    var error: String?

    // Editable fields
    var editNickname = ""
    var editBio = ""
    var editLocation = ""
    var editHobbies: [String] = []
    var editAge: Int = 18

    var valuesBrought: [Value]?
    var valuesSought: [Value]?

    private let profileService = ProfileService()
    private let valuesService = ValuesService()

    func loadProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await profileService.getProfile(userId: userId)
            syncEditableFields()
            valuesBrought = try? await valuesService.getUserValuesBrought(userId: userId)
            valuesSought = try? await valuesService.getUserValuesSought(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startEditing() {
        syncEditableFields()
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        syncEditableFields()
    }

    func saveChanges(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        var updates: [String: AnyJSON] = [:]

        if editNickname != profile?.nickname ?? "" {
            updates["nickname"] = .string(editNickname)
        }
        if editBio != profile?.bio ?? "" {
            updates["bio"] = .string(editBio)
        }
        if editLocation != profile?.location ?? "" {
            updates["location"] = .string(editLocation)
        }
        if editHobbies != profile?.hobbies ?? [] {
            updates["hobbies"] = .array(editHobbies.map { .string($0) })
        }
        if editAge != profile?.age ?? 18 {
            updates["age"] = .double(Double(editAge))
        }

        guard !updates.isEmpty else {
            isEditing = false
            return
        }

        do {
            profile = try await profileService.updateProfile(userId: userId, updates: updates)
            isEditing = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uploadPhoto(userId: String, imageData: Data) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let currentCount = profile?.photos?.count ?? 0
            let url = try await profileService.uploadPhoto(
                userId: userId,
                imageData: imageData,
                photoIndex: currentCount
            )

            var currentPhotos = profile?.photos ?? []
            currentPhotos.append(url)

            profile = try await profileService.updateProfile(
                userId: userId,
                updates: ["photos": .array(currentPhotos.map { .string($0) })]
            )
        } catch {
            self.error = "Failed to upload photo: \(error.localizedDescription)"
        }
    }

    func deletePhoto(userId: String, at index: Int) async {
        guard var photos = profile?.photos, index < photos.count else { return }
        let url = photos[index]

        do {
            try await profileService.deletePhoto(photoUrl: url)
            photos.remove(at: index)

            profile = try await profileService.updateProfile(
                userId: userId,
                updates: ["photos": .array(photos.map { .string($0) })]
            )
        } catch {
            self.error = "Failed to delete photo: \(error.localizedDescription)"
        }
    }

    private func syncEditableFields() {
        editNickname = profile?.nickname ?? ""
        editBio = profile?.bio ?? ""
        editLocation = profile?.location ?? ""
        editHobbies = profile?.hobbies ?? []
        editAge = profile?.age ?? 18
    }
}
