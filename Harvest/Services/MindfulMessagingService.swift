import Foundation

struct MindfulMessagingService {
    struct MindfulAnalysis: Sendable {
        let category: String?
        let needsReview: Bool
        let severity: Severity
        let reason: String
        let growthLesson: GrowthLesson?
        let flaggedWords: [String]

        enum Severity: String, Sendable {
            case low, medium, high
        }

        struct GrowthLesson: Sendable {
            let title: String
            let reflection: String
        }
    }

    /// One category's vocabulary, split by how much context a term needs.
    ///
    /// `standalone` terms are concerning wherever they appear. `directed`
    /// terms are only concerning when aimed at the other person, so they
    /// require a second-person word in the same clause — that is what keeps
    /// "I need to kill some time" apart from "I'll kill you", and what stops
    /// a gardening app flagging "my new hoe".
    private struct Lexicon {
        let category: String
        let weight: Int
        let standalone: Set<String>
        let directed: Set<String>
    }

    private static let aggressiveStandalone: Set<String> = [
        "fuck", "fucking", "fuckin", "fuck you", "fuck off", "motherfucker",
        "mother fucker", "shit", "bullshit", "dipshit", "eat shit",
        "piece of shit", "piece of crap", "asshole", "ass hole", "arsehole",
        "arse hole", "jackass", "dickhead", "prick", "cunt", "twat", "bitch",
        "bastard", "douche", "douchebag", "scumbag", "slut", "whore", "skank",
        "retard", "moron", "wtf", "shut up", "shut the fuck up", "screw you",
        "screw off", "piss off", "fk you", "f off", "f u",
        "hate you", "you suck", "you're nothing", "nobody likes you",
        "waste of space", "sick of you", "can't stand you",
        "hurt you", "kill you", "kill yourself", "kys"
    ]

    /// Insults and threats — harmless as ordinary vocabulary, concerning when
    /// pointed at someone.
    private static let aggressiveDirected: Set<String> = [
        "stupid", "idiot", "dumb", "ugly", "fat", "disgusting", "pathetic",
        "loser", "worthless", "useless", "freak", "psycho", "annoying",
        "trash", "garbage", "scum", "hoe", "pussy",
        "kill", "murder", "stab", "choke", "strangle", "suffocate", "drown",
        "punch", "slap", "destroy", "ruin", "torture", "die"
    ]

    private static let possessiveStandalone: Set<String> = [
        "you're mine", "belong to me", "my property", "i own you", "control you",
        "won't let you", "you need me", "only mine", "can't leave me",
        "i forbid you", "not allowed to talk"
    ]

    private static let pressuringStandalone: Set<String> = [
        "don't be scared", "what are you afraid of", "why won't you",
        "nothing will happen", "no one will know", "man up", "prove it"
    ]

    private static let manipulativeStandalone: Set<String> = [
        "if you loved me", "if you really loved me", "no one will ever",
        "you'll never find", "lucky to have me", "you owe me", "nobody else will",
        "after everything i did", "you made me", "all your fault", "i blame you",
        "guilt trip", "ungrateful"
    ]

    private static let sexualPressureStandalone: Set<String> = [
        "send pics", "send nudes", "send me pics", "nudes", "dick pic", "dick pics",
        "show me your body", "show me your tits", "what are you wearing",
        "take it off", "undress", "get naked", "strip for me"
    ]

    private static let sexualPressureDirected: Set<String> = ["naked"]

    /// Love-bombing markers only. Ordinary affection ("I love you", "forever")
    /// was removed: warning people for saying it, and blurring it for the
    /// person receiving it, is worse than missing the rare early over-step.
    private static let excessiveIntensityStandalone: Set<String> = [
        "marry me", "can't live without you", "addicted to you", "obsessed with you",
        "soul mate", "soulmate", "you're my everything", "meant to be together"
    ]

    private static let personalInfoStandalone: Set<String> = [
        "social security", "ssn", "bank account", "credit card", "routing number",
        "password", "login credentials", "venmo me", "cashapp", "send money",
        "wire transfer", "bitcoin", "cryptocurrency", "crypto wallet", "gift card"
    ]

    private static let lexicons: [Lexicon] = [
        Lexicon(category: "aggressive", weight: 20,
                standalone: aggressiveStandalone, directed: aggressiveDirected),
        Lexicon(category: "possessive", weight: 25,
                standalone: possessiveStandalone, directed: []),
        Lexicon(category: "pressuring", weight: 15,
                standalone: pressuringStandalone, directed: []),
        Lexicon(category: "manipulative", weight: 20,
                standalone: manipulativeStandalone, directed: []),
        Lexicon(category: "sexual_pressure", weight: 25,
                standalone: sexualPressureStandalone, directed: sexualPressureDirected),
        Lexicon(category: "excessive_intensity", weight: 10,
                standalone: excessiveIntensityStandalone, directed: []),
        Lexicon(category: "personal_info", weight: 30,
                standalone: personalInfoStandalone, directed: [])
    ]

    private static let phonePatterns: [String] = [
        "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",
        "\\b\\(\\d{3}\\)\\s?\\d{3}[-.]?\\d{4}\\b",
        "\\b\\+?1?\\s?\\d{3}\\s?\\d{3}\\s?\\d{4}\\b",
        "\\b\\d{10,11}\\b"
    ]

    private static let growthLessons: [String: MindfulAnalysis.GrowthLesson] = [
        "aggressive": .init(
            title: "Mindful Communication",
            reflection: "Pause & reflect — how do you think this might land on the other side?"
        ),
        "possessive": .init(
            title: "Respecting Autonomy",
            reflection: "Quick check-in — how might this come across from their point of view?"
        ),
        "pressuring": .init(
            title: "Consent & Choice",
            reflection: "Growth nudge — what options does this leave on their end?"
        ),
        "manipulative": .init(
            title: "Authentic Expression",
            reflection: "Reflection moment — what do you think this communicates beneath the words?"
        ),
        "sexual_pressure": .init(
            title: "Respecting Boundaries",
            reflection: "Heads up — how might this be received at this point in the conversation?"
        ),
        "excessive_intensity": .init(
            title: "Balanced Connection",
            reflection: "Real quick — how does this fit the stage you’re in right now?"
        ),
        "general": .init(
            title: "Pause & Reflect",
            reflection: "Quick reflection — how do you imagine this being received?"
        ),
        "personal_info": .init(
            title: "Stay Safe",
            reflection: "Heads up — is this the level of sharing you want at this moment?"
        ),
        "phone_number": .init(
            title: "Stay Safe",
            reflection: "Heads up — is this the level of sharing you want at this moment?"
        )
    ]

    private let openAI = OpenAIService()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "mindful_messaging_enabled") as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "mindful_messaging_enabled")
    }

    /// Lightweight synchronous filter for clearly objectionable user-generated text
    /// (profanity, slurs, violent or sexually explicit language). Used to screen
    /// profile fields (nickname, bio) before they're saved. Only the standalone
    /// terms apply: a bio has no one to direct an insult at, so context-dependent
    /// words like "trash" or "hoe" would just block innocent bios.
    static func containsObjectionableContent(_ text: String) -> Bool {
        let normalized = KeywordMatcher.normalize(text)
        let terms = aggressiveStandalone.union(sexualPressureStandalone)
        return terms.contains { KeywordMatcher.contains($0, in: normalized) }
    }

    /// Synchronous, on-device keyword flag for an *incoming* message. Returns the
    /// keyword analysis when the message should be blurred for the recipient, else nil.
    /// Callers gate on `isEnabled` (the recipient's own mindful-messaging toggle).
    func localFlag(for text: String) -> MindfulAnalysis? {
        let result = keywordAnalysis(text)
        return result.needsReview ? result : nil
    }

    func analyzeMessage(_ text: String) async -> MindfulAnalysis {
        let keywordResult = keywordAnalysis(text)
        if keywordResult.needsReview {
            return keywordResult
        }

        // Try OpenAI first
        do {
            let messages: [OpenAIService.ChatMessage] = [
                .init(role: "system", content: """
                    You are a dating safety analyst reviewing one outgoing message.

                    Flag ONLY what would concern a reasonable person on a dating app: \
                    insults, threats, coercion, sexual pressure, controlling or manipulative \
                    language, or requests for money and sensitive personal data.

                    Ordinary conversation is not a concern. Greetings ("hi", "hello", "hey!!"), \
                    small talk, compliments, jokes, flirting, emoji, repeated punctuation or \
                    capitals for emphasis, enthusiasm, plans to meet, and short or low-effort \
                    messages are all fine — return needsReview false for them.

                    You are seeing the message without its conversation, so when it reads two \
                    ways, assume the ordinary one. If you are not confident, return \
                    needsReview false: a false alarm on a harmless message costs more here \
                    than a missed borderline one.

                    Respond with JSON only: {"needsReview": bool, "severity": "low"|"medium"|"high", \
                    "reason": "brief explanation", "category": "aggressive"|"possessive"|"pressuring"|\
                    "manipulative"|"sexual_pressure"|"excessive_intensity"|"personal_info"|"none"}
                    """),
                .init(role: "user", content: text)
            ]

            let response = try await openAI.sendChat(
                messages: messages,
                temperature: 0.3,
                maxTokens: 300
            )

            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let needsReview = json["needsReview"] as? Bool,
               needsReview {
                let severity = MindfulAnalysis.Severity(rawValue: json["severity"] as? String ?? "low") ?? .low

                // The model judges a single message with no conversation around
                // it, and its low-severity calls are where the harmless ones
                // ("hi!!", an enthusiastic compliment) land. Anything genuinely
                // low-severity is already covered by the lexicons above.
                guard severity != .low else {
                    return MindfulAnalysis(
                        category: nil,
                        needsReview: false,
                        severity: .low,
                        reason: "",
                        growthLesson: nil,
                        flaggedWords: []
                    )
                }

                let reason = json["reason"] as? String ?? "This message may need review."
                let category = json["category"] as? String ?? "general"
                let lesson = Self.growthLessons[category]

                return MindfulAnalysis(
                    category: category == "none" ? nil : category,
                    needsReview: true,
                    severity: severity,
                    reason: reason,
                    growthLesson: lesson,
                    flaggedWords: []
                )
            }

            return MindfulAnalysis(category: nil, needsReview: false, severity: .low, reason: "", growthLesson: nil, flaggedWords: [])
        } catch {
            // Fall back to keyword scanning
            return keywordAnalysis(text)
        }
    }

    private func keywordAnalysis(_ text: String) -> MindfulAnalysis {
        let normalized = KeywordMatcher.normalize(text)
        let clauses = KeywordMatcher.clauses(text)
        var flaggedWords: [String] = []
        var highestCategory: String?
        var highestWeight = 0

        for lexicon in Self.lexicons {
            var matched = false

            for keyword in lexicon.standalone where KeywordMatcher.contains(keyword, in: normalized) {
                flaggedWords.append(keyword)
                matched = true
            }

            for keyword in lexicon.directed
            where KeywordMatcher.containsDirected(keyword, inClauses: clauses) {
                flaggedWords.append(keyword)
                matched = true
            }

            if matched, lexicon.weight > highestWeight {
                highestWeight = lexicon.weight
                highestCategory = lexicon.category
            }
        }

        // Check phone patterns
        for pattern in Self.phonePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                flaggedWords.append("[phone number]")
                if 30 > highestWeight {
                    highestWeight = 30
                    highestCategory = "phone_number"
                }
            }
        }

        guard !flaggedWords.isEmpty, let category = highestCategory else {
            return MindfulAnalysis(category: nil, needsReview: false, severity: .low, reason: "", growthLesson: nil, flaggedWords: [])
        }

        let severity: MindfulAnalysis.Severity = highestWeight >= 25 ? .high : highestWeight >= 15 ? .medium : .low
        let lesson = Self.growthLessons[category]

        return MindfulAnalysis(
            category: category,
            needsReview: true,
            severity: severity,
            reason: "Your message contains language that may be concerning.",
            growthLesson: lesson,
            flaggedWords: flaggedWords
        )
    }
}
