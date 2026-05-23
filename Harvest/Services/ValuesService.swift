import Foundation
import Supabase

struct ValuesService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func getAllValues() async throws -> [Value] {
        do {
            let values: [Value] = try await client
                .from("values")
                .select()
                .order("category", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value

            if !values.isEmpty { return values }
        } catch {
            // DB unavailable or decode error — fall through to defaults
        }

        return Self.defaultValues
    }

    private static let defaultValues: [Value] = {
        var values: [Value] = []
        let categories: [(String, [String])] = [
            ("communication", [
                "Honesty", "Active Listening", "Openness", "Directness",
                "Vulnerability", "Empathy", "Patience"
            ]),
            ("relationship", [
                "Commitment", "Trust", "Loyalty", "Independence",
                "Partnership", "Quality Time", "Physical Affection",
                "Words of Affirmation", "Acts of Service"
            ]),
            ("lifestyle", [
                "Adventure", "Stability", "Ambition", "Work-Life Balance",
                "Health & Wellness", "Spontaneity", "Routine",
                "Financial Responsibility", "Minimalism"
            ]),
            ("personal growth", [
                "Self-Awareness", "Continuous Learning", "Resilience",
                "Accountability", "Gratitude", "Mindfulness",
                "Emotional Intelligence", "Courage"
            ]),
            ("social", [
                "Family", "Friendship", "Community", "Inclusivity",
                "Generosity", "Humor", "Respect", "Kindness",
                "Cultural Awareness"
            ]),
            ("core beliefs", [
                "Authenticity", "Integrity", "Compassion", "Faith",
                "Justice", "Freedom", "Creativity", "Purpose"
            ])
        ]

        for (category, names) in categories {
            for (index, name) in names.enumerated() {
                values.append(Value(
                    id: "\(category)-\(index)",
                    name: name,
                    category: category,
                    displayOrder: index
                ))
            }
        }
        return values
    }()

    func getUserValuesBrought(userId: String) async throws -> [Value] {
        struct JoinedValue: Decodable {
            let valueId: String
            let values: Value

            enum CodingKeys: String, CodingKey {
                case valueId = "value_id"
                case values
            }
        }

        let joined: [JoinedValue] = try await client
            .from("user_values_brought")
            .select("value_id, values(*)")
            .eq("user_id", value: userId)
            .execute()
            .value

        return joined.map(\.values)
    }

    func getUserValuesSought(userId: String) async throws -> [Value] {
        struct JoinedValue: Decodable {
            let valueId: String
            let values: Value

            enum CodingKeys: String, CodingKey {
                case valueId = "value_id"
                case values
            }
        }

        let joined: [JoinedValue] = try await client
            .from("user_values_sought")
            .select("value_id, values(*)")
            .eq("user_id", value: userId)
            .execute()
            .value

        return joined.map(\.values)
    }

    func saveUserValuesBrought(userId: String, valueIds: [String]) async throws {
        // Delete existing
        try await client
            .from("user_values_brought")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // Insert new
        if !valueIds.isEmpty {
            let rows = valueIds.enumerated().map { index, valueId in
                [
                    "user_id": AnyJSON.string(userId),
                    "value_id": AnyJSON.string(valueId),
                    "ranking": AnyJSON.double(Double(index + 1))
                ]
            }
            try await client
                .from("user_values_brought")
                .insert(rows)
                .execute()
        }
    }

    func saveUserValuesSought(userId: String, valueIds: [String]) async throws {
        // Delete existing
        try await client
            .from("user_values_sought")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // Insert new
        if !valueIds.isEmpty {
            let rows = valueIds.enumerated().map { index, valueId in
                [
                    "user_id": AnyJSON.string(userId),
                    "value_id": AnyJSON.string(valueId),
                    "ranking": AnyJSON.double(Double(index + 1))
                ]
            }
            try await client
                .from("user_values_sought")
                .insert(rows)
                .execute()
        }
    }

    /// New signature: returns nil if either user has fewer than 5 total answers.
    /// On success, returns radar-based score and the axes that are in the top 2
    /// on both sides of the pairing (may be empty).
    func calculateCompatibility(
        userId: String,
        otherUserId: String
    ) async throws -> (score: Double, sharedTopAxes: [ValueAxis])? {
        let questionsService = QuestionsService()

        async let myAnswersTask = questionsService.getUserAnswers(userId: userId)
        async let theirAnswersTask = questionsService.getUserAnswers(userId: otherUserId)
        async let questionsTask = questionsService.getAllQuestions()

        let myAnswers = try await myAnswersTask
        let theirAnswers = try await theirAnswersTask
        let questions = try await questionsTask

        let minAnswers = 5
        guard myAnswers.count >= minAnswers, theirAnswers.count >= minAnswers else {
            return nil
        }

        let mine = AxisScoring.computeVectors(answers: myAnswers, questions: questions)
        let theirs = AxisScoring.computeVectors(answers: theirAnswers, questions: questions)

        let needMatch = AxisScores.cosine(mine.need, theirs.bring)
        let bringMatch = AxisScores.cosine(mine.bring, theirs.need)
        let score = (needMatch + bringMatch) / 2.0 * 100

        let myNeedTop = Self.topAxes(in: mine.need, count: 2)
        let theirBringTop = Self.topAxes(in: theirs.bring, count: 2)
        let myBringTop = Self.topAxes(in: mine.bring, count: 2)
        let theirNeedTop = Self.topAxes(in: theirs.need, count: 2)

        let shared = Set(myNeedTop).intersection(theirBringTop)
            .union(Set(myBringTop).intersection(theirNeedTop))

        return (score, Array(shared))
    }

    private static func topAxes(in scores: AxisScores, count: Int) -> [ValueAxis] {
        ValueAxis.allCases
            .sorted { scores.value(for: $0) > scores.value(for: $1) }
            .prefix(count)
            .map { $0 }
    }
}
