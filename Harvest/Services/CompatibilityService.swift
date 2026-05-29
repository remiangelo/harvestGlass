import Foundation

struct CompatibilityService {
    /// Calculate compatibility score between two users
    /// Returns a score from 0-100 based on multiple factors
    func calculateCompatibility(
        currentUser: UserProfile,
        otherUser: UserProfile,
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)? = nil,
        otherUserAxisScores: (need: AxisScores, bring: AxisScores)? = nil
    ) -> CompatibilityScore {
        var totalScore = 0.0
        var breakdown: [String: Double] = [:]

        let interestsScore = calculateInterestsScore(
            userHobbies: currentUser.hobbies ?? [],
            otherHobbies: otherUser.hobbies ?? []
        )
        breakdown["interests"] = interestsScore
        totalScore += interestsScore

        let valuesScore = calculateValuesScore(
            currentUserAxisScores: currentUserAxisScores,
            otherUserAxisScores: otherUserAxisScores
        )
        breakdown["values"] = valuesScore
        totalScore += valuesScore

        let goalsScore = calculateGoalsScore(
            userGoals: currentUser.goalsList,
            otherGoals: otherUser.goalsList
        )
        breakdown["goals"] = goalsScore
        totalScore += goalsScore

        let ageScore: Double
        if let userAge = currentUser.age, let otherAge = otherUser.age {
            ageScore = calculateAgeScore(userAge: userAge, otherAge: otherAge)
        } else {
            ageScore = 5.0
        }
        breakdown["age"] = ageScore
        totalScore += ageScore

        breakdown["distance"] = 5.0
        totalScore += 5.0

        return CompatibilityScore(
            total: Int(min(100, totalScore)),
            breakdown: breakdown
        )
    }

    // MARK: - Interest/Hobby Scoring

    private func calculateInterestsScore(userHobbies: [String], otherHobbies: [String]) -> Double {
        guard !userHobbies.isEmpty, !otherHobbies.isEmpty else {
            return 20.0 // Neutral score if no hobbies listed
        }

        let userSet = Set(userHobbies.map { $0.lowercased() })
        let otherSet = Set(otherHobbies.map { $0.lowercased() })
        let sharedCount = userSet.intersection(otherSet).count

        // Calculate Jaccard similarity
        let unionCount = userSet.union(otherSet).count
        let similarity = Double(sharedCount) / Double(unionCount)

        // Scale to 0-40 points
        // 0% shared = 0 points
        // 25% shared = 20 points
        // 50%+ shared = 40 points
        let score = min(40.0, similarity * 80.0)

        return score
    }

    // MARK: - Values Scoring

    private func calculateValuesScore(
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)?,
        otherUserAxisScores: (need: AxisScores, bring: AxisScores)?
    ) -> Double {
        guard let me = currentUserAxisScores,
              let them = otherUserAxisScores,
              !me.need.isZero, !me.bring.isZero,
              !them.need.isZero, !them.bring.isZero else {
            return 15.0
        }
        let avgCosine =
            (AxisScores.cosine(me.need, them.bring) + AxisScores.cosine(me.bring, them.need)) / 2.0
        // Cosine on non-negative vectors is in [0, 1] -> scale to 0...30
        return max(0, avgCosine) * 30.0
    }

    // MARK: - Goals Scoring

    private func calculateGoalsScore(userGoals: [String], otherGoals: [String]) -> Double {
        guard !userGoals.isEmpty, !otherGoals.isEmpty else {
            return 7.5 // Neutral score
        }

        let userSet = Set(userGoals.map { $0.lowercased() })
        let otherSet = Set(otherGoals.map { $0.lowercased() })
        let sharedCount = userSet.intersection(otherSet).count

        // Having even one shared goal is significant
        // 0 shared = 0 points
        // 1 shared = 10 points
        // 2+ shared = 15 points
        if sharedCount == 0 {
            return 0
        } else if sharedCount == 1 {
            return 10.0
        } else {
            return 15.0
        }
    }

    // MARK: - Age Scoring

    private func calculateAgeScore(userAge: Int, otherAge: Int) -> Double {
        let ageDifference = abs(userAge - otherAge)

        // Age difference scoring:
        // 0-2 years: 10 points
        // 3-5 years: 7 points
        // 6-10 years: 4 points
        // 11+ years: 2 points
        switch ageDifference {
        case 0...2:
            return 10.0
        case 3...5:
            return 7.0
        case 6...10:
            return 4.0
        default:
            return 2.0
        }
    }

    // MARK: - Ranking Profiles

    /// Sort profiles by compatibility score (highest first)
    func rankProfiles(
        currentUser: UserProfile,
        profiles: [UserProfile],
        currentUserAxisScores: (need: AxisScores, bring: AxisScores)?,
        otherUsersAxisScores: [String: (need: AxisScores, bring: AxisScores)]
    ) -> [(profile: UserProfile, score: CompatibilityScore)] {
        var scoredProfiles: [(profile: UserProfile, score: CompatibilityScore)] = []

        for profile in profiles {
            let otherAxis = otherUsersAxisScores[profile.id]
            let score = calculateCompatibility(
                currentUser: currentUser,
                otherUser: profile,
                currentUserAxisScores: currentUserAxisScores,
                otherUserAxisScores: otherAxis
            )
            scoredProfiles.append((profile: profile, score: score))
        }

        return scoredProfiles.sorted { $0.score.total > $1.score.total }
    }

    // MARK: - Value-pick overlap

    /// Intersection of value picks between two users on each side.
    /// `theyBringForMyNeeds`: which of their Bring picks satisfy my Need picks.
    /// `iBringForTheirNeeds`: which of my Bring picks satisfy their Need picks.
    struct ValueOverlap: Sendable {
        let theyBringForMyNeeds: [Value]
        let iBringForTheirNeeds: [Value]
    }

    func valueOverlap(
        myNeeds: [Value],
        myBrings: [Value],
        theirNeeds: [Value],
        theirBrings: [Value]
    ) -> ValueOverlap {
        let myNeedIds = Set(myNeeds.map(\.id))
        let theirNeedIds = Set(theirNeeds.map(\.id))
        let theyForMe = theirBrings.filter { myNeedIds.contains($0.id) }
        let meForThem = myBrings.filter { theirNeedIds.contains($0.id) }
        return ValueOverlap(
            theyBringForMyNeeds: theyForMe,
            iBringForTheirNeeds: meForThem
        )
    }

    // MARK: - Compatibility blurb

    /// One- or two-sentence blurb summarizing how two users align on the 5 axes
    /// plus how their selected value picks line up. Template-driven, no LLM.
    func compatibilityBlurb(
        otherName: String,
        bringCosine: Double,
        needCosine: Double,
        topSharedAxis: ValueAxis?,
        overlap: ValueOverlap,
        myNeedsCount: Int
    ) -> String {
        let strongAlignment = (bringCosine + needCosine) / 2.0 >= 0.6
        let theyForMe = overlap.theyBringForMyNeeds.count

        if let axis = topSharedAxis, strongAlignment, theyForMe > 0 {
            return "You and \(otherName) share a strong foundation around \(axis.displayName) — and what they bring lines up with \(theyForMe) of your \(myNeedsCount) needs."
        }
        if let axis = topSharedAxis, strongAlignment {
            return "You and \(otherName) share a strong foundation around \(axis.displayName)."
        }
        if theyForMe > 0 {
            return "\(otherName) brings \(theyForMe) of your \(myNeedsCount) selected needs."
        }
        return "Your value patterns differ — sometimes that's where growth starts."
    }

    /// Returns the axis where the lower of (myBring[i], theirNeed[i]) is highest,
    /// representing the strongest mutual alignment between bring and need.
    func topSharedAxis(
        myBring: AxisScores,
        theirNeed: AxisScores
    ) -> ValueAxis? {
        let pairs: [(ValueAxis, Double)] = ValueAxis.allCases.map { axis in
            let mine = myBring.value(for: axis)
            let theirs = theirNeed.value(for: axis)
            return (axis, min(mine, theirs))
        }
        let top = pairs.max { $0.1 < $1.1 }
        guard let top, top.1 > 0 else { return nil }
        return top.0
    }
}

// MARK: - Models

struct CompatibilityScore: Sendable {
    let total: Int
    let breakdown: [String: Double]

    var interestsScore: Int {
        Int(breakdown["interests"] ?? 0)
    }

    var valuesScore: Int {
        Int(breakdown["values"] ?? 0)
    }

    var goalsScore: Int {
        Int(breakdown["goals"] ?? 0)
    }

    var ageScore: Int {
        Int(breakdown["age"] ?? 0)
    }

    var distanceScore: Int {
        Int(breakdown["distance"] ?? 0)
    }

    var displayPercentage: String {
        "\(total)%"
    }

    var compatibilityLevel: String {
        switch total {
        case 80...100:
            return "Excellent Match"
        case 60...79:
            return "Great Match"
        case 40...59:
            return "Good Match"
        case 20...39:
            return "Fair Match"
        default:
            return "Low Match"
        }
    }
}
