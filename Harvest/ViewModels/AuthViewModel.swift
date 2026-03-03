import Foundation
import Observation
import Supabase
import Auth

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var profile: UserProfile?
    var error: String?
    var currentUserId: String?

    private let authService = AuthService()
    private let profileService = ProfileService()
    private let subscriptionService = SubscriptionService()

    var needsOnboarding: Bool {
        guard let profile else { return true }
        return profile.onboardingCompleted != true &&
               (profile.age == nil || profile.gender == nil || (profile.photos?.isEmpty ?? true))
    }

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let session = try await authService.getCurrentSession() {
                currentUserId = session.user.id.uuidString
                isAuthenticated = true
                await loadProfile()
            }
        } catch {
            isAuthenticated = false
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        self.error = nil

        do {
            let session = try await authService.signIn(email: email, password: password)
            currentUserId = session.user.id.uuidString
            isAuthenticated = true
            await loadProfile()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func register(email: String, password: String) async {
        isLoading = true
        self.error = nil

        do {
            let user = try await authService.signUp(email: email, password: password)
            currentUserId = user.id.uuidString

            // Create profile
            _ = try await profileService.createProfile(userId: user.id.uuidString, email: email)

            // Initialize subscription
            try? await subscriptionService.initializeUserSubscription(userId: user.id.uuidString)

            isAuthenticated = true
            await loadProfile()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        do {
            try await authService.signOut()
        } catch {
            // Ignore signout errors
        }
        isAuthenticated = false
        currentUserId = nil
        profile = nil
    }

    func loadProfile() async {
        guard let userId = currentUserId else { return }
        do {
            profile = try await profileService.getProfile(userId: userId)
        } catch {
            // Profile may not exist yet
        }
    }

    func listenToAuthChanges() {
        Task {
            for await (event, session) in authService.authStateChanges() {
                switch event {
                case .signedIn:
                    if let user = session?.user {
                        currentUserId = user.id.uuidString
                        isAuthenticated = true
                        await loadProfile()
                    }
                case .signedOut:
                    isAuthenticated = false
                    currentUserId = nil
                    profile = nil
                default:
                    break
                }
            }
        }
    }
}
