import Foundation
import Observation
import Supabase

@Observable
final class ValuesViewModel {
    enum Mode { case main, tips }
    enum Side: String { case need, bring }

    var profile: UserProfile?
    var valuesBrought: [Value] = []
    var valuesSought: [Value] = []

    var allValues: [Value] = []
    var allQuestions: [Question] = []
    var answers: [String: String] = [:]            // questionId -> optionId

    var mode: Mode = .main
    var side: Side = .need

    var isLoading = false
    var isGeneratingBlurb = false
    var loadError: String?
    var blurbError: String?
    var toggleError: String?
    var saveError: String?

    private let valuesService = ValuesService()
    private let questionsService = QuestionsService()
    private let profileService = ProfileService()
    private let blurbService = BlurbService()

    // MARK: - Derived state

    var needScores: AxisScores {
        AxisScoring.computeVectors(answers: answers, questions: allQuestions).need
    }

    var bringScores: AxisScores {
        AxisScoring.computeVectors(answers: answers, questions: allQuestions).bring
    }

    var activeScores: AxisScores {
        side == .need ? needScores : bringScores
    }

    var activeValueIds: Set<String> {
        Set((side == .need ? valuesSought : valuesBrought).map(\.id))
    }

    private let maxValueSelections = 5

    // MARK: - Load

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = profileService.getProfile(userId: userId)
            async let broughtTask = valuesService.getUserValuesBrought(userId: userId)
            async let soughtTask = valuesService.getUserValuesSought(userId: userId)
            async let allValuesTask = valuesService.getAllValues()
            async let allQuestionsTask = questionsService.getAllQuestions()
            async let answersTask = questionsService.getUserAnswers(userId: userId)

            profile = try await profileTask
            valuesBrought = (try? await broughtTask) ?? []
            valuesSought = (try? await soughtTask) ?? []
            allValues = (try? await allValuesTask) ?? []
            allQuestions = (try? await allQuestionsTask) ?? []
            answers = (try? await answersTask) ?? [:]
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Values (chip) editing

    /// Toggles the given value on the active side. Optimistic; reverts on save failure.
    func toggleValue(userId: String, valueId: String) async {
        var brought = valuesBrought
        var sought = valuesSought

        switch side {
        case .need:
            if let idx = sought.firstIndex(where: { $0.id == valueId }) {
                sought.remove(at: idx)
            } else if sought.count < maxValueSelections,
                      let v = allValues.first(where: { $0.id == valueId }) {
                sought.append(v)
            } else {
                return
            }
        case .bring:
            if let idx = brought.firstIndex(where: { $0.id == valueId }) {
                brought.remove(at: idx)
            } else if brought.count < maxValueSelections,
                      let v = allValues.first(where: { $0.id == valueId }) {
                brought.append(v)
            } else {
                return
            }
        }

        let previousBrought = valuesBrought
        let previousSought = valuesSought
        valuesBrought = brought
        valuesSought = sought

        do {
            switch side {
            case .need:
                try await valuesService.saveUserValuesSought(userId: userId, valueIds: sought.map(\.id))
            case .bring:
                try await valuesService.saveUserValuesBrought(userId: userId, valueIds: brought.map(\.id))
            }
            saveError = nil
        } catch {
            valuesBrought = previousBrought
            valuesSought = previousSought
            saveError = error.localizedDescription
        }
    }

    // MARK: - Questions (answer editing)

    func saveAnswer(userId: String, questionId: String, optionId: String) async {
        let previous = answers[questionId]
        answers[questionId] = optionId

        do {
            try await questionsService.saveAnswer(
                userId: userId,
                questionId: questionId,
                optionId: optionId
            )
            saveError = nil
        } catch {
            if let previous {
                answers[questionId] = previous
            } else {
                answers.removeValue(forKey: questionId)
            }
            saveError = error.localizedDescription
        }
    }

    var unansweredQuestionsForActiveSide: [Question] {
        let relevant = allQuestions.filter { q in
            switch side {
            case .need:  return q.weighting == .need  || q.weighting == .both
            case .bring: return q.weighting == .bring || q.weighting == .both
            }
        }
        return relevant
            .filter { answers[$0.id] == nil }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Blurb

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

    // MARK: - Display toggles

    enum DisplayToggle {
        case brought, sought, blurb, graph

        var column: String {
            switch self {
            case .brought: return "show_values_brought"
            case .sought:  return "show_values_sought"
            case .blurb:   return "show_values_blurb"
            case .graph:   return "show_values_graph"
            }
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
        case .sought:  profile?.showValuesSought = isOn
        case .blurb:   profile?.showValuesBlurb = isOn
        case .graph:   profile?.showValuesGraph = isOn
        }
    }

    // MARK: - Graph side picker

    func setGraphSide(userId: String, side: Side) async {
        let previous = profile?.profileGraphSide
        profile?.profileGraphSide = side.rawValue

        do {
            let updated = try await profileService.updateProfile(
                userId: userId,
                updates: ["profile_graph_side": .string(side.rawValue)]
            )
            if let updated { profile = updated }
            toggleError = nil
        } catch {
            profile?.profileGraphSide = previous
            toggleError = error.localizedDescription
        }
    }
}
