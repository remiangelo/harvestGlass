import Foundation
import Observation

@Observable
final class SafetyDashboardViewModel {
    var analyses: [SafetyAnalysis] = []
    var selectedAnalysis: SafetyAnalysis?
    var redFlags: [RedFlagReport] = []
    var profiles: [String: UserProfile] = [:]
    var isLoading = false
    var error: String?

    private let safetyService = SafetyAnalysisService()
    private let profileService = ProfileService()

    func loadDashboard(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            analyses = try await safetyService.getSafetyDashboard(userId: userId)

            // Load profiles for each analysis
            for analysis in analyses {
                if profiles[analysis.otherUserId] == nil {
                    if let profile = try? await profileService.getProfile(userId: analysis.otherUserId) {
                        profiles[analysis.otherUserId] = profile
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadRedFlags(analysisId: String) async {
        do {
            redFlags = try await safetyService.getRedFlags(analysisId: analysisId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
