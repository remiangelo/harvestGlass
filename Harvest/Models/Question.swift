import Foundation

enum ValueAxis: String, Codable, CaseIterable, Sendable {
    case emotionalIntelligence = "emotional_intelligence"
    case stability
    case integrity
    case connection
    case growth

    var displayName: String {
        switch self {
        case .emotionalIntelligence: return "Emotional Intelligence"
        case .stability:             return "Stability"
        case .integrity:             return "Integrity"
        case .connection:            return "Connection"
        case .growth:                return "Growth"
        }
    }
}

enum QuestionWeighting: String, Codable, Sendable {
    case need, bring, both
}

struct QuestionOption: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let questionId: String
    let label: String
    let axis: ValueAxis
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label, axis
        case questionId = "question_id"
        case displayOrder = "display_order"
    }
}

struct Question: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let prompt: String
    let weighting: QuestionWeighting
    let displayOrder: Int
    var options: [QuestionOption]

    enum CodingKeys: String, CodingKey {
        case id, prompt, weighting, options
        case displayOrder = "display_order"
    }
}

struct UserQuestionAnswer: Codable, Sendable, Equatable {
    let userId: String
    let questionId: String
    let optionId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionId = "question_id"
        case optionId = "option_id"
    }
}

struct AxisScores: Equatable, Sendable {
    var emotionalIntelligence: Double = 0
    var stability: Double = 0
    var integrity: Double = 0
    var connection: Double = 0
    var growth: Double = 0

    var sum: Double {
        emotionalIntelligence + stability + integrity + connection + growth
    }

    var isZero: Bool { sum == 0 }

    func value(for axis: ValueAxis) -> Double {
        switch axis {
        case .emotionalIntelligence: return emotionalIntelligence
        case .stability:             return stability
        case .integrity:             return integrity
        case .connection:            return connection
        case .growth:                return growth
        }
    }

    mutating func add(_ delta: Double, to axis: ValueAxis) {
        switch axis {
        case .emotionalIntelligence: emotionalIntelligence += delta
        case .stability:             stability += delta
        case .integrity:             integrity += delta
        case .connection:            connection += delta
        case .growth:                growth += delta
        }
    }

    func normalized() -> AxisScores {
        let total = sum
        guard total > 0 else { return self }
        var n = AxisScores()
        n.emotionalIntelligence = emotionalIntelligence / total
        n.stability             = stability / total
        n.integrity             = integrity / total
        n.connection            = connection / total
        n.growth                = growth / total
        return n
    }

    /// Standard cosine similarity in [-1, 1]; returns 0 when either is a zero vector.
    static func cosine(_ a: AxisScores, _ b: AxisScores) -> Double {
        let dot =
            a.emotionalIntelligence * b.emotionalIntelligence +
            a.stability * b.stability +
            a.integrity * b.integrity +
            a.connection * b.connection +
            a.growth * b.growth
        let magA = (a.emotionalIntelligence * a.emotionalIntelligence +
                    a.stability * a.stability +
                    a.integrity * a.integrity +
                    a.connection * a.connection +
                    a.growth * a.growth).squareRoot()
        let magB = (b.emotionalIntelligence * b.emotionalIntelligence +
                    b.stability * b.stability +
                    b.integrity * b.integrity +
                    b.connection * b.connection +
                    b.growth * b.growth).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}

enum AxisScoring {
    /// Returns (needSideWeight, bringSideWeight) for a question with the given weighting.
    /// Pure NEED and pure BRING questions contribute to one side only. BOTH splits evenly.
    static func weights(for weighting: QuestionWeighting) -> (need: Double, bring: Double) {
        switch weighting {
        case .need:  return (2.0, 0.0)
        case .bring: return (0.0, 2.0)
        case .both:  return (1.0, 1.0)
        }
    }

    /// Build the user's RAW (un-normalized) (need, bring) axis vectors — the actual
    /// per-category point totals (0–28 possible per axis). The matching algorithm and
    /// the radar's tiered display both work from these raw scores.
    static func computeRawVectors(
        answers: [String: String],          // questionId -> optionId
        questions: [Question]
    ) -> (need: AxisScores, bring: AxisScores) {
        var rawNeed = AxisScores()
        var rawBring = AxisScores()

        let byId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })

        for (questionId, optionId) in answers {
            guard let q = byId[questionId] else { continue }
            guard let option = q.options.first(where: { $0.id == optionId }) else { continue }
            let (nW, bW) = weights(for: q.weighting)
            rawNeed.add(nW, to: option.axis)
            rawBring.add(bW, to: option.axis)
        }

        return (rawNeed, rawBring)
    }

    /// Build the user's normalized (need, bring) axis vectors from their answers.
    static func computeVectors(
        answers: [String: String],          // questionId -> optionId
        questions: [Question]
    ) -> (need: AxisScores, bring: AxisScores) {
        let raw = computeRawVectors(answers: answers, questions: questions)
        return (raw.need.normalized(), raw.bring.normalized())
    }
}

/// Visual display tier for the values radar.
///
/// The matching algorithm always works from raw category scores; the radar maps
/// each raw score (0–28 possible) into one of four tiers so the chart communicates
/// the *shape* of a values profile rather than plotting raw points. Tier names are
/// not shown on the chart (yet) — this is purely a visualization mapping.
enum ValuesTier: Int, CaseIterable, Sendable {
    case lowPresence = 1       // raw 0–5   → 1st ring
    case growingPresence = 2   // raw 6–10  → 2nd ring
    case strongPresence = 3    // raw 11–17 → 3rd ring
    case coreValue = 4         // raw 18–28 → outer ring

    init(rawScore: Double) {
        switch rawScore {
        case ..<6:  self = .lowPresence
        case ..<11: self = .growingPresence
        case ..<18: self = .strongPresence
        default:    self = .coreValue
        }
    }

    var displayName: String {
        switch self {
        case .lowPresence:     return "Low Presence"
        case .growingPresence: return "Growing Presence"
        case .strongPresence:  return "Strong Presence"
        case .coreValue:       return "Core Value"
        }
    }

    /// "Level N" label.
    var levelLabel: String { "Level \(rawValue)" }

    /// Human-readable raw score range for this tier.
    var rangeLabel: String {
        switch self {
        case .lowPresence:     return "0 – 5"
        case .growingPresence: return "6 – 10"
        case .strongPresence:  return "11 – 17"
        case .coreValue:       return "18 – 28"
        }
    }

    /// "Nth ring" label.
    var ringLabel: String {
        switch self {
        case .lowPresence:     return "1st ring"
        case .growingPresence: return "2nd ring"
        case .strongPresence:  return "3rd ring"
        case .coreValue:       return "4th ring"
        }
    }

    /// Growth-metaphor SF Symbol (sprout → leaf → tree → harvest).
    /// Level 4 has no "apple fruit" SF Symbol; swap in a custom asset later if desired.
    var iconName: String {
        switch self {
        case .lowPresence:     return "leaf"
        case .growingPresence: return "leaf.fill"
        case .strongPresence:  return "tree.fill"
        case .coreValue:       return "tree.circle.fill"
        }
    }

    /// Position on the radar as a fraction of the full radius (1st…outer ring).
    var radiusFraction: Double {
        Double(rawValue) / Double(ValuesTier.allCases.count)
    }
}
