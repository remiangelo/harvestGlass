import Foundation
import Supabase

struct QuestionsService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Returns the full question pool, options included. Falls back to the
    /// hard-coded defaults below on DB error / empty result (mirrors ValuesService).
    func getAllQuestions() async throws -> [Question] {
        do {
            let questions: [Question] = try await client
                .from("questions")
                .select("id, prompt, weighting, display_order, options:question_options(*)")
                .order("display_order", ascending: true)
                .execute()
                .value

            if !questions.isEmpty { return questions.map(Self.sortingOptions) }
        } catch {
            // DB unavailable or decode error — fall through to defaults
        }

        return Self.defaultQuestions
    }

    /// Returns a map of questionId -> optionId for the given user.
    func getUserAnswers(userId: String) async throws -> [String: String] {
        let rows: [UserQuestionAnswer] = try await client
            .from("user_question_answers")
            .select("user_id, question_id, option_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.questionId, $0.optionId) })
    }

    func saveAnswer(userId: String, questionId: String, optionId: String) async throws {
        let row: [String: AnyJSON] = [
            "user_id":     .string(userId),
            "question_id": .string(questionId),
            "option_id":   .string(optionId)
        ]
        try await client
            .from("user_question_answers")
            .upsert(row, onConflict: "user_id,question_id")
            .execute()
    }

    func saveAnswers(userId: String, answers: [String: String]) async throws {
        guard !answers.isEmpty else { return }
        let rows: [[String: AnyJSON]] = answers.map { (questionId, optionId) in
            [
                "user_id":     .string(userId),
                "question_id": .string(questionId),
                "option_id":   .string(optionId)
            ]
        }
        try await client
            .from("user_question_answers")
            .upsert(rows, onConflict: "user_id,question_id")
            .execute()
    }

    private static func sortingOptions(_ q: Question) -> Question {
        var copy = q
        copy.options.sort { $0.displayOrder < $1.displayOrder }
        return copy
    }

    // MARK: - Hard-coded defaults (mirrors values seed)

    static let defaultQuestions: [Question] = [
        Self.makeQuestion(
            id: "q1",
            prompt: "After a hard day, what would help you feel most cared for?",
            weighting: .need,
            options: [
                ("a", "They really listen before responding.",          .emotionalIntelligence),
                ("b", "They stay calm and steady with me.",             .stability),
                ("c", "They make it feel safe to be fully myself.",     .integrity),
                ("d", "They pull me close and make time for me.",       .connection),
                ("e", "They help me see a way forward.",                .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q2",
            prompt: "Someone disappoints you. What helps repair the moment most?",
            weighting: .need,
            options: [
                ("a", "They understand why it hurt.",     .emotionalIntelligence),
                ("b", "They show up better next time.",   .stability),
                ("c", "They own their part clearly.",     .integrity),
                ("d", "They make time to reconnect.",     .connection),
                ("e", "They want to learn from it.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q3",
            prompt: "You are starting to trust someone. What makes that trust grow?",
            weighting: .both,
            options: [
                ("a", "They notice what you feel.",       .emotionalIntelligence),
                ("b", "Their energy stays steady.",       .stability),
                ("c", "Their actions match their words.", .integrity),
                ("d", "You feel close and wanted.",       .connection),
                ("e", "They keep growing through life.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q4",
            prompt: "During conflict, what matters most to you?",
            weighting: .need,
            options: [
                ("a", "They try to understand you.",                     .emotionalIntelligence),
                ("b", "They slow the moment down.",                      .stability),
                ("c", "They take ownership.",                            .integrity),
                ("d", "They come back toward you emotionally.",          .connection),
                ("e", "They care more about growing than winning.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q5",
            prompt: "When you picture long-term love, what feels most important?",
            weighting: .need,
            options: [
                ("a", "Feeling emotionally known.",                       .emotionalIntelligence),
                ("b", "Knowing I can count on how they show up.",         .stability),
                ("c", "Feeling secure in their character.",               .integrity),
                ("d", "Feeling wanted and close.",                        .connection),
                ("e", "Feeling like you are building something meaningful.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q6",
            prompt: "Someone you care about is stressed. What feels most natural to you?",
            weighting: .bring,
            options: [
                ("a", "Help them feel understood.",            .emotionalIntelligence),
                ("b", "Help steady the situation.",            .stability),
                ("c", "Help them face the situation honestly.",.integrity),
                ("d", "Offer warmth and closeness.",           .connection),
                ("e", "Encourage their next step.",            .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q7",
            prompt: "What makes someone feel emotionally mature to you?",
            weighting: .both,
            options: [
                ("a", "They can read the room emotionally.",                .emotionalIntelligence),
                ("b", "They stay steady under pressure.",                   .stability),
                ("c", "They admit when they were wrong.",                   .integrity),
                ("d", "They keep reaching toward the people they love.",    .connection),
                ("e", "They reflect and adjust.",                           .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q8",
            prompt: "What keeps you invested when dating gets real?",
            weighting: .need,
            options: [
                ("a", "They care about your inner world.",            .emotionalIntelligence),
                ("b", "Their effort stays steady.",                   .stability),
                ("c", "The way they handle people feels trustworthy.",.integrity),
                ("d", "The bond feels alive.",                        .connection),
                ("e", "You see shared direction.",                    .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q9",
            prompt: "What makes a relationship feel safe enough to deepen?",
            weighting: .need,
            options: [
                ("a", "You feel emotionally understood.",             .emotionalIntelligence),
                ("b", "Their presence feels steady over time.",       .stability),
                ("c", "You trust how they handle hard things.",       .integrity),
                ("d", "You feel wanted in their life.",               .connection),
                ("e", "You feel like the relationship has purpose.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q10",
            prompt: "What would make you feel proud to choose someone?",
            weighting: .both,
            options: [
                ("a", "Their care for people is genuine.",                          .emotionalIntelligence),
                ("b", "Their life feels steady and dependable.",                    .stability),
                ("c", "Their character shows when things are hard.",                .integrity),
                ("d", "They make love feel warm and alive.",                        .connection),
                ("e", "They keep becoming a better version of themselves.",         .growth)
            ]
        )
    ]

    private static func makeQuestion(
        id: String,
        prompt: String,
        weighting: QuestionWeighting,
        options: [(String, String, ValueAxis)]
    ) -> Question {
        let opts = options.enumerated().map { i, t in
            QuestionOption(
                id: "\(id)_\(t.0)",
                questionId: id,
                label: t.1,
                axis: t.2,
                displayOrder: i
            )
        }
        return Question(
            id: id,
            prompt: prompt,
            weighting: weighting,
            displayOrder: Int(id.dropFirst()) ?? 0,    // "q3" -> 3
            options: opts
        )
    }
}
