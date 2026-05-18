import Foundation
import Observation
import Supabase

@Observable
final class ValuesViewModel {
    var profile: UserProfile?
    var valuesBrought: [Value] = []
    var valuesSought: [Value] = []

    var isLoading = false
    var isGeneratingBlurb = false
    var loadError: String?
    var blurbError: String?
    var toggleError: String?

    private let valuesService = ValuesService()
    private let profileService = ProfileService()
    private let blurbService = BlurbService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = profileService.getProfile(userId: userId)
            async let broughtTask = valuesService.getUserValuesBrought(userId: userId)
            async let soughtTask = valuesService.getUserValuesSought(userId: userId)

            profile = try await profileTask
            valuesBrought = (try? await broughtTask) ?? []
            valuesSought = (try? await soughtTask) ?? []
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func generateBlurb(userId: String) async {
        guard !valuesBrought.isEmpty || !valuesSought.isEmpty else {
            blurbError = "Pick at least one value first."
            return
        }

        isGeneratingBlurb = true
        defer { isGeneratingBlurb = false }
        blurbError = nil

        do {
            let blurb = try await blurbService.generateBlurb(brought: valuesBrought, sought: valuesSought)
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: ["values_blurb": .string(blurb)]
            )
            if let updated {
                profile = updated
            } else {
                profile?.valuesBlurb = blurb
            }
        } catch {
            blurbError = error.localizedDescription
        }
    }

    func setDisplayToggle(userId: String, key: DisplayToggle, isOn: Bool) async {
        let previous = profile
        applyToggleLocally(key: key, isOn: isOn)

        do {
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: [key.column: .bool(isOn)]
            )
            if let updated { profile = updated }
            toggleError = nil
        } catch {
            profile = previous
            toggleError = error.localizedDescription
        }
    }

    private func applyToggleLocally(key: DisplayToggle, isOn: Bool) {
        switch key {
        case .brought: profile?.showValuesBrought = isOn
        case .sought: profile?.showValuesSought = isOn
        case .blurb: profile?.showValuesBlurb = isOn
        case .graph: profile?.showValuesGraph = isOn
        }
    }

    enum DisplayToggle {
        case brought, sought, blurb, graph

        var column: String {
            switch self {
            case .brought: return "show_values_brought"
            case .sought: return "show_values_sought"
            case .blurb: return "show_values_blurb"
            case .graph: return "show_values_graph"
            }
        }
    }
}
