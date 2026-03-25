import Foundation
import UIKit
import Observation
import Supabase
import MapKit

enum OnboardingStep: Int, CaseIterable {
    case age
    case nickname
    case photos
    case goals
    case genderIdentity
    case interestedIn
    case location
    case terms
    case complete
}

@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .age
    var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var nickname = ""
    var photos: [Data] = []
    var photoUrls: [String] = []
    var selectedGoals: Set<String> = []
    var gender = ""
    var interestedIn: Set<String> = []
    var location = ""
    var termsAccepted = false
    var isLoading = false
    var error: String?
    var resolvedLocation: String?
    var isValidatingLocation = false

    private let profileService = ProfileService()

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var isAgeValid: Bool {
        age >= 18
    }

    var canProceed: Bool {
        switch currentStep {
        case .age: return isAgeValid
        case .nickname: return !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        case .photos: return !photoUrls.isEmpty
        case .goals: return !selectedGoals.isEmpty
        case .genderIdentity: return !gender.isEmpty
        case .interestedIn: return !interestedIn.isEmpty
        case .location: return resolvedLocation != nil
        case .terms: return termsAccepted
        case .complete: return true
        }
    }

    var progress: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        return Double(currentStep.rawValue) / total
    }

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
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
            let url = try await profileService.uploadPhoto(
                userId: userId,
                imageData: jpegData,
                photoIndex: photoUrls.count
            )
            photoUrls.append(url)
        } catch {
            self.error = "Failed to upload photo: \(error.localizedDescription)"
        }
    }

    func removePhoto(at index: Int) {
        guard index < photoUrls.count else { return }
        let url = photoUrls[index]
        photoUrls.remove(at: index)
        Task {
            do {
                try await profileService.deletePhoto(photoUrl: url)
            } catch {
                print("Warning: Failed to delete photo from storage: \(error)")
                // Photo removed from UI, but may remain in storage
            }
        }
    }

    func validateLocation() async {
        let query = location.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            resolvedLocation = nil
            return
        }

        guard let request = MKGeocodingRequest(addressString: query) else {
            resolvedLocation = nil
            return
        }

        isValidatingLocation = true
        defer { isValidatingLocation = false }

        do {
            let mapItems = try await request.mapItems
            if let address = mapItems.first?.address {
                resolvedLocation = address.shortAddress ?? address.fullAddress
            } else {
                resolvedLocation = nil
            }
        } catch {
            resolvedLocation = nil
        }
    }

    func completeOnboarding(userId: String) async -> UserProfile? {
        isLoading = true
        defer { isLoading = false }

        let updates: [String: AnyJSON] = [
            "nickname": .string(nickname),
            "age": .double(Double(age)),
            "bio": .string("I'm new here!"),
            "gender": .string(gender),
            "goals": .string(Array(selectedGoals).joined(separator: ",")),
            "photos": .array(photoUrls.map { .string($0) }),
            "location": .string(location),
            "interested_in": .array(Array(interestedIn).map { .string($0) }),
            "onboarding_completed": .bool(true)
        ]

        do {
            let result = try await profileService.updateProfile(userId: userId, updates: updates)
            if result == nil {
                self.error = "Profile update returned empty response. Please try again."
            }
            return result
        } catch {
            self.error = "Failed to save profile: \(error.localizedDescription)"
            return nil
        }
    }
}
