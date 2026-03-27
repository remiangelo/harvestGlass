import Foundation
import Observation
import Supabase
import UIKit

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
    var editPhotoUrls: [String] = []
    var editHobbies: [String] = []
    var editAge: Int = 18
    var editLookingFor = ""
    var editHeightCm: Int = 170
    var editSmoking = ""
    var editDrinking = ""
    var editCannabis = ""
    var editSpiritualOrientation = ""
    var editChildrenStatus = ""
    var editInterestedIn: [String] = []

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

            // Load values
            do {
                valuesBrought = try await valuesService.getUserValuesBrought(userId: userId)
            } catch {
                print("Warning: Failed to load values brought: \(error)")
                valuesBrought = [] // Default to empty array
            }

            do {
                valuesSought = try await valuesService.getUserValuesSought(userId: userId)
            } catch {
                print("Warning: Failed to load values sought: \(error)")
                valuesSought = [] // Default to empty array
            }
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

    func saveChanges(userId: String) async -> Bool {
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
        if editPhotoUrls != profile?.photos ?? [] {
            updates["photos"] = .array(editPhotoUrls.map { .string($0) })
        }
        if editHobbies != profile?.hobbies ?? [] {
            updates["hobbies"] = .array(editHobbies.map { .string($0) })
        }
        if editAge != profile?.age ?? 18 {
            updates["age"] = .double(Double(editAge))
        }
        if normalizedStringArray(editInterestedIn) != normalizedStringArray(profile?.interestedIn ?? []) {
            updates["interested_in"] = .array(editInterestedIn.map { .string($0) })
        }
        if normalizedOptional(editLookingFor) != profile?.lookingFor {
            updates["looking_for"] = anyJSONStringOrNull(editLookingFor)
        }
        if editHeightCm != profile?.heightCm ?? 170 {
            updates["height_cm"] = .double(Double(editHeightCm))
        }
        if normalizedOptional(editSmoking) != profile?.smoking {
            updates["smoking"] = anyJSONStringOrNull(editSmoking)
        }
        if normalizedOptional(editDrinking) != profile?.drinking {
            updates["drinking"] = anyJSONStringOrNull(editDrinking)
        }
        if normalizedOptional(editCannabis) != profile?.cannabis {
            updates["cannabis"] = anyJSONStringOrNull(editCannabis)
        }
        if normalizedOptional(editSpiritualOrientation) != profile?.spiritualOrientation {
            updates["spiritual_orientation"] = anyJSONStringOrNull(editSpiritualOrientation)
        }
        if normalizedOptional(editChildrenStatus) != profile?.childrenStatus {
            updates["children_status"] = anyJSONStringOrNull(editChildrenStatus)
        }

        guard !updates.isEmpty else {
            isEditing = false
            return true
        }

        do {
            if let updated = try await profileService.updateProfile(userId: userId, updates: updates) {
                profile = updated
            } else {
                // Server accepted but returned empty — patch local state
                applyEditsLocally()
            }
            isEditing = false
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func applyEditsLocally() {
        profile?.nickname = editNickname
        profile?.bio = editBio
        profile?.location = editLocation
        profile?.photos = editPhotoUrls
        profile?.hobbies = editHobbies
        profile?.age = editAge
        profile?.interestedIn = editInterestedIn
        profile?.lookingFor = normalizedOptional(editLookingFor)
        profile?.heightCm = editHeightCm
        profile?.smoking = normalizedOptional(editSmoking)
        profile?.drinking = normalizedOptional(editDrinking)
        profile?.cannabis = normalizedOptional(editCannabis)
        profile?.spiritualOrientation = normalizedOptional(editSpiritualOrientation)
        profile?.childrenStatus = normalizedOptional(editChildrenStatus)
    }

    func uploadPhoto(userId: String, imageData: Data) async {
        isLoading = true
        self.error = nil
        defer { isLoading = false }

        guard let uiImage = UIImage(data: imageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            self.error = "Could not process the selected image"
            return
        }

        do {
            let currentCount = editPhotoUrls.count
            let url = try await profileService.uploadPhoto(
                userId: userId,
                imageData: jpegData,
                photoIndex: currentCount
            )
            editPhotoUrls.append(url)
            profile?.photos = editPhotoUrls
        } catch {
            self.error = "Failed to upload photo: \(error.localizedDescription)"
        }
    }

    func deletePhoto(userId: String, at index: Int) async {
        guard index < editPhotoUrls.count else { return }
        let url = editPhotoUrls[index]

        do {
            try await profileService.deletePhoto(photoUrl: url)
            editPhotoUrls.remove(at: index)
            profile?.photos = editPhotoUrls
        } catch {
            self.error = "Failed to delete photo: \(error.localizedDescription)"
        }
    }

    private func syncEditableFields() {
        editNickname = profile?.nickname ?? ""
        editBio = profile?.bio ?? ""
        editLocation = profile?.location ?? ""
        editPhotoUrls = profile?.photos ?? []
        editHobbies = profile?.hobbies ?? []
        editAge = profile?.age ?? 18
        editInterestedIn = profile?.interestedIn ?? []
        editLookingFor = profile?.lookingFor ?? ""
        editHeightCm = profile?.heightCm ?? 170
        editSmoking = profile?.smoking ?? ""
        editDrinking = profile?.drinking ?? ""
        editCannabis = profile?.cannabis ?? ""
        editSpiritualOrientation = profile?.spiritualOrientation ?? ""
        editChildrenStatus = profile?.childrenStatus ?? ""
    }

    private func anyJSONStringOrNull(_ value: String) -> AnyJSON {
        guard let normalized = normalizedOptional(value) else { return .null }
        return .string(normalized)
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedStringArray(_ values: [String]) -> [String] {
        values.map { $0.lowercased() }.sorted()
    }
}
