import Foundation

struct CompatibilityService {
    /// Calculate compatibility score between two users
    /// Returns a score from 0-100 based on multiple factors
    func calculateCompatibility(
        currentUser: UserProfile,
        otherUser: UserProfile,
        currentUserValuesBrought: [Value] = [],
        currentUserValuesSought: [Value] = [],
        otherUserValuesBrought: [Value] = [],
        otherUserValuesSought: [Value] = []
    ) -> CompatibilityScore {
        var totalScore = 0.0
        var breakdown: [String: Double] = [:]

        // 1. Shared Interests/Hobbies (40 points max)
        let interestsScore = calculateInterestsScore(
            userHobbies: currentUser.hobbies ?? [],
            otherHobbies: otherUser.hobbies ?? []
        )
        breakdown["interests"] = interestsScore
        totalScore += interestsScore

        // 2. Values Alignment (30 points max)
        let valuesScore = calculateValuesScore(
            userBrought: currentUserValuesBrought,
            userSought: currentUserValuesSought,
            otherBrought: otherUserValuesBrought,
            otherSought: otherUserValuesSought
        )
        breakdown["values"] = valuesScore
        totalScore += valuesScore

        // 3. Goals Alignment (15 points max)
        let goalsScore = calculateGoalsScore(
            userGoals: currentUser.goals ?? [],
            otherGoals: otherUser.goals ?? []
        )
        breakdown["goals"] = goalsScore
        totalScore += goalsScore

        // 4. Age Compatibility (10 points max)
        let ageScore = calculateAgeScore(
            userAge: currentUser.age,
            otherAge: otherUser.age
        )
        breakdown["age"] = ageScore
        totalScore += ageScore

        // 5. Distance Bonus (5 points max)
        // Note: Would need location data to calculate actual distance
        // For now, give full points as placeholder
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
        userBrought: [Value],
        userSought: [Value],
        otherBrought: [Value],
        otherSought: [Value]
    ) -> Double {
        guard !userSought.isEmpty, !otherBrought.isEmpty else {
            return 15.0 // Neutral score if values not filled
        }

        let userSoughtIds = Set(userSought.map { $0.id })
        let otherBroughtIds = Set(otherBrought.map { $0.id })

        // How many values I seek does the other person bring?
        let matchCount = userSoughtIds.intersection(otherBroughtIds).count
        let matchRatio = Double(matchCount) / Double(userSoughtIds.count)

        // Reverse: How many values they seek do I bring?
        let otherSoughtIds = Set(otherSought.map { $0.id })
        let userBroughtIds = Set(userBrought.map { $0.id })
        let reverseMatchCount = otherSoughtIds.intersection(userBroughtIds).count
        let reverseMatchRatio = otherSoughtIds.isEmpty ? 0 : Double(reverseMatchCount) / Double(otherSoughtIds.count)

        // Average both directions
        let averageMatch = (matchRatio + reverseMatchRatio) / 2.0

        // Scale to 0-30 points
        return averageMatch * 30.0
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
        currentUserValuesBrought: [Value],
        currentUserValuesSought: [Value],
        otherUsersValues: [String: (brought: [Value], sought: [Value])]
    ) -> [(profile: UserProfile, score: CompatibilityScore)] {
        var scoredProfiles: [(profile: UserProfile, score: CompatibilityScore)] = []

        for profile in profiles {
            let otherValues = otherUsersValues[profile.id] ?? (brought: [], sought: [])

            let score = calculateCompatibility(
                currentUser: currentUser,
                otherUser: profile,
                currentUserValuesBrought: currentUserValuesBrought,
                currentUserValuesSought: currentUserValuesSought,
                otherUserValuesBrought: otherValues.brought,
                otherUserValuesSought: otherValues.sought
            )

            scoredProfiles.append((profile: profile, score: score))
        }

        // Sort by total score descending
        return scoredProfiles.sorted { $0.score.total > $1.score.total }
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
