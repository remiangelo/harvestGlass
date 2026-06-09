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
    case values
    case reflections
    case genderIdentity
    case interestedIn
    case relationshipStatus
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
    var allValues: [Value] = []
    var selectedValuesBrought: Set<String> = []
    var selectedValuesSought: Set<String> = []
    var isLoadingValues = false
    var allQuestions: [Question] = []
    var reflectionAnswers: [String: String] = [:]   // questionId -> optionId
    var currentReflectionIndex: Int = 0
    var isLoadingQuestions = false
    var gender = ""
    var interestedIn: Set<String> = []
    var relationshipStatus = ""   // single|dating|in_relationship|engaged|married
    var location = ""
    var termsAccepted = false
    var isLoading = false
    var error: String?
    var resolvedLocation: String?
    var locationSuggestions: [String] = []
    var isValidatingLocation = false

    private let profileService = ProfileService()
    private let valuesService = ValuesService()
    private let questionsService = QuestionsService()

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var isAgeValid: Bool {
        age >= 18
    }

    var canProceed: Bool {
        switch currentStep {
        case .age: return isAgeValid
        case .nickname:
            let trimmed = nickname.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !MindfulMessagingService.containsObjectionableContent(trimmed)
        case .photos: return !photoUrls.isEmpty
        case .goals: return !selectedGoals.isEmpty
        case .values: return !selectedValuesBrought.isEmpty && !selectedValuesSought.isEmpty
        case .reflections:
            return !allQuestions.isEmpty && reflectionAnswers.count >= allQuestions.count
        case .genderIdentity: return !gender.isEmpty
        case .interestedIn: return !interestedIn.isEmpty
        case .relationshipStatus: return !relationshipStatus.isEmpty
        case .location: return resolvedLocation != nil
        case .terms: return termsAccepted
        case .complete: return true
        }
    }

    func loadValuesIfNeeded() async {
        guard allValues.isEmpty, !isLoadingValues else { return }
        isLoadingValues = true
        defer { isLoadingValues = false }
        do {
            allValues = try await valuesService.getAllValues()
        } catch {
            self.error = "Failed to load values: \(error.localizedDescription)"
        }
    }

    func loadQuestionsIfNeeded() async {
        guard allQuestions.isEmpty, !isLoadingQuestions else { return }
        isLoadingQuestions = true
        defer { isLoadingQuestions = false }
        do {
            // Onboarding only presents the first 10 questions; deep-dive Q11-Q35
            // is reached via the "More questions" button in the Values tab.
            allQuestions = try await questionsService.getAllQuestions()
                .sorted { $0.displayOrder < $1.displayOrder }
                .prefix(10)
                .map { $0 }
        } catch {
            self.error = "Failed to load questions: \(error.localizedDescription)"
        }
    }

    var progress: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        if currentStep == .reflections, !allQuestions.isEmpty {
            let subProgress = Double(currentReflectionIndex) / Double(allQuestions.count)
            return (Double(currentStep.rawValue) + subProgress) / total
        }
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

    func removePhoto(userId: String, at index: Int) {
        guard index < photoUrls.count else { return }
        let url = photoUrls[index]
        photoUrls.remove(at: index)
        Task {
            do {
                try await profileService.deletePhoto(userId: userId, photoUrl: url)
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
            locationSuggestions = []
            return
        }

        guard let request = MKGeocodingRequest(addressString: query) else {
            resolvedLocation = nil
            locationSuggestions = []
            return
        }

        isValidatingLocation = true
        defer { isValidatingLocation = false }

        do {
            let mapItems = try await request.mapItems
            let suggestions = mapItems
                .compactMap { item -> String? in
                    guard let address = item.address else { return nil }
                    return address.shortAddress ?? address.fullAddress
                }
            let uniqueSuggestions = Array(NSOrderedSet(array: suggestions)) as? [String] ?? suggestions
            locationSuggestions = Array(uniqueSuggestions.prefix(5))
            resolvedLocation = locationSuggestions.first
        } catch {
            resolvedLocation = nil
            locationSuggestions = []
        }
    }

    func selectLocationSuggestion(_ suggestion: String) {
        location = suggestion
        resolvedLocation = suggestion
        locationSuggestions = [suggestion]
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
            "location": .string(resolvedLocation ?? location),
            "interested_in": .array(Array(interestedIn).map { .string($0) }),
            "relationship_status": .string(relationshipStatus),
            "onboarding_completed": .bool(true)
        ]

        do {
            let savedProfile: UserProfile?
            // Try update first
            if let result = try await profileService.updateProfile(userId: userId, updates: updates) {
                savedProfile = result
            } else if let result = try await profileService.upsertProfile(userId: userId, updates: updates) {
                // Profile row doesn't exist — create it via upsert
                savedProfile = result
            } else {
                self.error = "Failed to save profile. Please try again."
                return nil
            }

            // Best-effort: persist selected values. A failure here shouldn't
            // strand the user at onboarding — they can re-edit values later.
            do {
                try await valuesService.saveUserValuesBrought(userId: userId, valueIds: Array(selectedValuesBrought))
                try await valuesService.saveUserValuesSought(userId: userId, valueIds: Array(selectedValuesSought))
            } catch {
                print("Warning: Failed to save values during onboarding: \(error)")
            }

            do {
                try await questionsService.saveAnswers(
                    userId: userId,
                    answers: reflectionAnswers
                )
            } catch {
                print("Warning: Failed to save reflection answers during onboarding: \(error)")
            }

            return savedProfile
        } catch {
            self.error = "Failed to save profile: \(error.localizedDescription)"
            return nil
        }
    }
}
