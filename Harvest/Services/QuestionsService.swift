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
        // Onboarding (Q1-Q10): 5 NEED, 5 BRING
        Self.makeQuestion(
            id: "q1",
            prompt: "After a hard day, what would help you feel most cared for?",
            weighting: .need,
            options: [
                ("a", "They really listen before responding.",                              .emotionalIntelligence),
                ("b", "They stay calm and steady with me.",                                 .stability),
                ("c", "They are honest, respectful, and present with what I am feeling.",   .integrity),
                ("d", "They pull me close and make time for me.",                           .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q2",
            prompt: "Someone disappoints you. What helps repair the moment most?",
            weighting: .need,
            options: [
                ("a", "They understand why it hurt.",                              .emotionalIntelligence),
                ("b", "They show up more consistently afterward.",                 .stability),
                ("c", "They own their part clearly.",                              .integrity),
                ("d", "They reflect on what happened and try to grow from it.",    .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q3",
            prompt: "Someone you care about is stressed. What feels most natural for you to offer?",
            weighting: .bring,
            options: [
                ("a", "I help them feel understood.",          .emotionalIntelligence),
                ("b", "I help steady the situation.",          .stability),
                ("c", "I offer warmth, affection, or closeness.", .connection),
                ("d", "I encourage their next step forward.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q4",
            prompt: "When conflict happens, what do you naturally try to bring into the moment?",
            weighting: .bring,
            options: [
                ("a", "I try to understand what the other person is really feeling.",  .emotionalIntelligence),
                ("b", "I try to own my part honestly.",                                .integrity),
                ("c", "I try to protect the bond and come back toward closeness.",     .connection),
                ("d", "I try to learn from it and find a better way forward.",         .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q5",
            prompt: "You are starting to trust someone. What makes that trust grow most for you?",
            weighting: .need,
            options: [
                ("a", "Their energy stays steady over time.",   .stability),
                ("b", "Their actions match their words.",       .integrity),
                ("c", "You feel wanted and close.",             .connection),
                ("d", "You can see shared direction and growth.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q6",
            prompt: "When you picture what you bring to long-term love, what feels most true?",
            weighting: .bring,
            options: [
                ("a", "I bring emotional care and understanding.",  .emotionalIntelligence),
                ("b", "I bring steadiness and dependability.",      .stability),
                ("c", "I bring honesty, loyalty, and respect.",     .integrity),
                ("d", "I bring warmth, affection, and connection.", .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q7",
            prompt: "You are nervous before something important. What kind of support would help most?",
            weighting: .need,
            options: [
                ("a", "They notice how I am feeling and comfort me.", .emotionalIntelligence),
                ("b", "They help me feel grounded and steady.",       .stability),
                ("c", "They help me face the situation honestly.",    .integrity),
                ("d", "They remind me what I am capable of.",         .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q8",
            prompt: "When you realize you may have hurt or disappointed someone, what do you most want to do?",
            weighting: .bring,
            options: [
                ("a", "I want to understand how it affected them.",        .emotionalIntelligence),
                ("b", "I want to show up better and be more consistent.",  .stability),
                ("c", "I want to reconnect and help them feel cared for.", .connection),
                ("d", "I want to reflect, adjust, and grow from it.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q9",
            prompt: "What makes you feel respected in a relationship?",
            weighting: .need,
            options: [
                ("a", "They consider my feelings.",            .emotionalIntelligence),
                ("b", "They honor my boundaries.",             .integrity),
                ("c", "They make space for me in their life.", .connection),
                ("d", "They take my goals seriously.",         .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q10",
            prompt: "During a quiet evening together, what do you most naturally hope to bring?",
            weighting: .bring,
            options: [
                ("a", "A peaceful, steady presence.",                                  .stability),
                ("b", "A space where honesty feels safe.",                             .integrity),
                ("c", "Warmth, closeness, or playfulness.",                            .connection),
                ("d", "Meaningful conversation about dreams, purpose, or direction.", .growth)
            ]
        ),

        // Deep-dive (Q11-Q35): 12 NEED, 12 BRING, 1 BOTH
        Self.makeQuestion(
            id: "q11",
            prompt: "Someone shares something vulnerable with you. What do you naturally try to offer?",
            weighting: .bring,
            options: [
                ("a", "I try to understand what they are feeling.",            .emotionalIntelligence),
                ("b", "I stay steady and present with them.",                  .stability),
                ("c", "I treat their honesty with respect.",                   .integrity),
                ("d", "I move closer emotionally so they do not feel alone.",  .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q12",
            prompt: "Plans change at the last minute. What matters most to you?",
            weighting: .need,
            options: [
                ("a", "They care how the change affects me.",            .emotionalIntelligence),
                ("b", "They communicate early and follow through later.", .stability),
                ("c", "They handle the change with respect.",            .integrity),
                ("d", "They try to handle it better next time.",         .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q13",
            prompt: "You feel misunderstood. What helps most?",
            weighting: .need,
            options: [
                ("a", "They ask questions before assuming.", .emotionalIntelligence),
                ("b", "They keep the conversation calm.",    .stability),
                ("c", "They speak plainly and fairly.",      .integrity),
                ("d", "They reassure me through closeness.", .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q14",
            prompt: "When you make a mistake, what do you naturally try to do afterward?",
            weighting: .bring,
            options: [
                ("a", "I try to understand the impact.",            .emotionalIntelligence),
                ("b", "I try to show steadier behavior over time.", .stability),
                ("c", "I own my part clearly.",                     .integrity),
                ("d", "I reflect on what I can learn from it.",     .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q15",
            prompt: "When you imagine building a life with someone, what do you most need to feel secure?",
            weighting: .need,
            options: [
                ("a", "They are dependable in daily life.", .stability),
                ("b", "They live by strong character.",     .integrity),
                ("c", "They keep closeness active.",        .connection),
                ("d", "They move toward purpose with me.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q16",
            prompt: "Someone you love is nervous before something important. What feels most natural for you to offer?",
            weighting: .bring,
            options: [
                ("a", "I notice what they are feeling and try to comfort them.", .emotionalIntelligence),
                ("b", "I help them face the moment honestly.",                   .integrity),
                ("c", "I stay close and present.",                               .connection),
                ("d", "I remind them what they are capable of.",                 .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q17",
            prompt: "What makes you feel respected?",
            weighting: .need,
            options: [
                ("a", "They consider my feelings.",   .emotionalIntelligence),
                ("b", "They treat my time with care.", .stability),
                ("c", "They honor my boundaries.",     .integrity),
                ("d", "They take my goals seriously.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q18",
            prompt: "When life gets stressful, what do you hope someone can count on you for?",
            weighting: .bring,
            options: [
                ("a", "I try to be emotionally aware and caring.",        .emotionalIntelligence),
                ("b", "I try to stay steady under pressure.",             .stability),
                ("c", "I try to act with character even when it is hard.", .integrity),
                ("d", "I try to keep warmth alive between us.",           .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q19",
            prompt: "You are excited about a personal goal. What response would mean the most?",
            weighting: .need,
            options: [
                ("a", "They understand why it matters to me.",      .emotionalIntelligence),
                ("b", "They help me stay grounded.",                .stability),
                ("c", "They celebrate with me.",                    .connection),
                ("d", "They encourage me toward my potential.",     .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q20",
            prompt: "When attraction starts feeling more serious, what do you most want to bring into the connection?",
            weighting: .bring,
            options: [
                ("a", "I want to be emotionally present and aware.",  .emotionalIntelligence),
                ("b", "I want my actions to reflect my character.",   .integrity),
                ("c", "I want the spark to feel mutual and alive.",   .connection),
                ("d", "I want to build toward something meaningful.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q21",
            prompt: "A conversation gets tense. What do you need most from the other person?",
            weighting: .need,
            options: [
                ("a", "They listen beneath the words.", .emotionalIntelligence),
                ("b", "They keep the tone steady.",     .stability),
                ("c", "They stay fair and truthful.",   .integrity),
                ("d", "They reach for closeness after.", .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q22",
            prompt: "What do you most naturally do to help someone feel chosen?",
            weighting: .bring,
            options: [
                ("a", "I remember what matters to them.",            .emotionalIntelligence),
                ("b", "I try to show up consistently over time.",    .stability),
                ("c", "I make real time for them.",                  .connection),
                ("d", "I build toward the future with them.",        .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q23",
            prompt: "You share a concern. What response builds the most confidence?",
            weighting: .need,
            options: [
                ("a", "They receive it with care.",        .emotionalIntelligence),
                ("b", "They answer honestly.",             .integrity),
                ("c", "They soften toward me.",            .connection),
                ("d", "They look for a better way forward.", .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q24",
            prompt: "What do you most want to be dependable for in a relationship?",
            weighting: .bring,
            options: [
                ("a", "Doing what I said I would do.",              .stability),
                ("b", "Handling responsibility with character.",    .integrity),
                ("c", "Continuing to invest in closeness.",         .connection),
                ("d", "Learning how to show up better over time.",  .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q25",
            prompt: "You are spending a quiet evening together. What feels most meaningful to you?",
            weighting: .need,
            options: [
                ("a", "The conversation feels emotionally real.", .emotionalIntelligence),
                ("b", "The peace feels easy and steady.",         .stability),
                ("c", "I feel safe being truthful.",              .integrity),
                ("d", "The closeness feels warm and natural.",    .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q26",
            prompt: "When you are under pressure, what do you hope your character shows?",
            weighting: .bring,
            options: [
                ("a", "I still care about people's feelings.", .emotionalIntelligence),
                ("b", "I can remain steady.",                  .stability),
                ("c", "My values hold even when it is hard.",  .integrity),
                ("d", "I can respond, reflect, and grow.",     .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q27",
            prompt: "What kind of apology means the most to you?",
            weighting: .need,
            options: [
                ("a", "One that shows they understand my heart.", .emotionalIntelligence),
                ("b", "One that takes full ownership.",           .integrity),
                ("c", "One that brings us close again.",          .connection),
                ("d", "One that leads to new growth.",            .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q28",
            prompt: "What do you most want to offer so someone feels free to be themselves?",
            weighting: .bring,
            options: [
                ("a", "I try to understand their emotions.",                       .emotionalIntelligence),
                ("b", "I treat their truth with respect.",                         .integrity),
                ("c", "I enjoy their personality.",                                .connection),
                ("d", "I give them room to become more fully themselves.",         .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q29",
            prompt: "What makes love feel alive to you?",
            weighting: .need,
            options: [
                ("a", "Feeling safe in the rhythm.",         .stability),
                ("b", "Feeling secure in trust.",            .integrity),
                ("c", "Feeling wanted, playful, and close.", .connection),
                ("d", "Feeling inspired together.",          .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q30",
            prompt: "When you disagree about something important, what do you naturally try to bring?",
            weighting: .bring,
            options: [
                ("a", "I try to care about their perspective.",         .emotionalIntelligence),
                ("b", "I try to handle the disagreement with respect.", .integrity),
                ("c", "I try to protect the bond while talking.",       .connection),
                ("d", "I try to search for a wiser path forward.",      .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q31",
            prompt: "What makes someone feel like a safe long-term choice?",
            weighting: .need,
            options: [
                ("a", "Their emotional care feels real.", .emotionalIntelligence),
                ("b", "Their patterns are dependable.",   .stability),
                ("c", "Their character is clear.",        .integrity),
                ("d", "Their love feels warm and active.", .connection)
            ]
        ),
        Self.makeQuestion(
            id: "q32",
            prompt: "Shared spiritual or philosophical values feel meaningful when they shape what?",
            weighting: .both,
            options: [
                ("a", "The way we make life decisions.",      .stability),
                ("b", "The way we treat people.",             .integrity),
                ("c", "The depth of closeness between us.",   .connection),
                ("d", "The meaning we build together.",       .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q33",
            prompt: "What makes you feel supportive in a relationship?",
            weighting: .bring,
            options: [
                ("a", "I can sense what someone may need emotionally.", .emotionalIntelligence),
                ("b", "I protect their dignity.",                       .integrity),
                ("c", "I make them feel loved in real time.",           .connection),
                ("d", "I believe in where they are going.",             .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q34",
            prompt: "What do you hope someone notices about what you bring?",
            weighting: .bring,
            options: [
                ("a", "How deeply I care.",         .emotionalIntelligence),
                ("b", "How steady I try to be.",    .stability),
                ("c", "How seriously I take trust.", .integrity),
                ("d", "How much I am growing.",     .growth)
            ]
        ),
        Self.makeQuestion(
            id: "q35",
            prompt: "When you imagine healthy love, what feels most like home?",
            weighting: .need,
            options: [
                ("a", "Being understood with care.",                  .emotionalIntelligence),
                ("b", "Feeling steady and safe.",                     .stability),
                ("c", "Feeling close, wanted, and joyful.",           .connection),
                ("d", "Growing into something meaningful together.",  .growth)
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
