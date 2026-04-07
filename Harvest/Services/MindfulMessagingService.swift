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

    private static let aggressive: Set<String> = [
        "stupid", "idiot", "dumb", "ugly", "fat", "disgusting", "pathetic", "loser",
        "worthless", "useless", "shut up", "hate you", "kill", "die", "trash", "garbage",
        "moron", "retard", "freak", "psycho", "crazy", "insane", "bitch", "bastard",
        "damn", "hell", "screw you", "piss off", "get lost", "nobody likes you",
        "waste of space", "piece of", "go away", "leave me alone", "don't talk to me",
        "you're nothing", "you suck", "terrible", "horrible", "disgusted", "sick of you",
        "can't stand you", "annoying", "irritating", "infuriating", "rage", "furious",
        "punch", "hit", "slap", "hurt", "destroy", "ruin", "wreck", "break",
        "smash", "crush", "obliterate", "demolish", "annihilate", "murder", "stab",
        "choke", "strangle", "suffocate", "drown", "burn", "torture", "abuse",
        "attack", "assault", "threaten", "intimidate", "bully", "harass",
        "fuck", "fuck you", "fuck off", "fucking", "motherfucker", "mother fucker",
        "shit", "bullshit", "dipshit", "asshole", "ass hole", "arsehole", "arse hole",
        "dick", "dickhead", "prick", "cock", "cunt", "twat", "pussy",
        "slut", "whore", "hoe", "skank", "trashy", "scumbag", "scum",
        "piece of shit", "piece of crap", "bastard", "jackass", "douche", "douchebag",
        "eat shit", "go to hell", "screw off", "shut the fuck up", "fuckin",
        "f off", "fk you", "f u", "wtf"
    ]

    private static let possessive: Set<String> = [
        "you're mine", "belong to me", "my property", "can't leave", "won't let you",
        "you need me", "no one else", "only mine", "i own you", "control you",
        "you can't", "not allowed", "permission", "forbid", "demand"
    ]

    private static let pressuring: Set<String> = [
        "meet now", "come over", "right now", "tonight", "hurry up", "don't be scared",
        "what are you afraid of", "prove it", "show me", "why won't you", "just do it",
        "stop being", "don't be a", "man up", "grow up", "be brave", "trust me",
        "i promise", "nothing will happen", "no one will know"
    ]

    private static let manipulative: Set<String> = [
        "if you loved me", "no one will ever", "you'll never find", "lucky to have me",
        "do this for me", "owe me", "after everything", "ungrateful", "guilt",
        "you made me", "your fault", "blame you", "responsible for"
    ]

    private static let sexualPressure: Set<String> = [
        "send pics", "send nudes", "show me your", "what are you wearing",
        "take it off", "undress", "naked", "strip"
    ]

    private static let excessiveIntensity: Set<String> = [
        "i love you", "soul mate", "meant to be", "destiny", "marry me", "forever",
        "can't live without", "obsessed", "addicted to you", "need you"
    ]

    private static let personalInfo: Set<String> = [
        "social security", "ssn", "bank account", "credit card", "routing number",
        "password", "login", "venmo me", "cashapp", "send money", "wire transfer",
        "bitcoin", "crypto wallet"
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

    func analyzeMessage(_ text: String) async -> MindfulAnalysis {
        let keywordResult = keywordAnalysis(text)
        if keywordResult.needsReview {
            return keywordResult
        }

        // Try OpenAI first
        do {
            let messages: [OpenAIService.ChatMessage] = [
                .init(role: "system", content: """
                    You are a dating safety analyst. Analyze the following message for concerning patterns. \
                    Respond with JSON: {"needsReview": bool, "severity": "low"|"medium"|"high", \
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
        let lowered = text.lowercased()
        let normalized = normalizeForMatching(text)
        var flaggedWords: [String] = []
        var highestCategory: String?
        var highestWeight = 0

        let categories: [(Set<String>, String, Int)] = [
            (Self.aggressive, "aggressive", 20),
            (Self.possessive, "possessive", 25),
            (Self.pressuring, "pressuring", 15),
            (Self.manipulative, "manipulative", 20),
            (Self.sexualPressure, "sexual_pressure", 25),
            (Self.excessiveIntensity, "excessive_intensity", 10),
            (Self.personalInfo, "personal_info", 30)
        ]

        for (keywords, category, weight) in categories {
            for keyword in keywords {
                let normalizedKeyword = normalizeForMatching(keyword)
                if lowered.contains(keyword) || normalized.contains(normalizedKeyword) {
                    flaggedWords.append(keyword)
                    if weight > highestWeight {
                        highestWeight = weight
                        highestCategory = category
                    }
                }
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

    private func normalizeForMatching(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(scalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
