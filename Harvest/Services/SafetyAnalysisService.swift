import Foundation
import Supabase

struct SafetyAnalysisService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private static let redFlagKeywords: [RedFlagCategory: Set<String>] = [
        .financial: ["send money", "wire transfer", "bank account", "western union", "moneygram",
                     "gift card", "bitcoin", "crypto", "venmo me", "cashapp", "paypal me",
                     "investment opportunity", "financial help", "loan", "borrow money"],
        .personalInfo: ["social security", "ssn", "credit card number", "routing number",
                        "password", "login credentials", "home address", "work address"],
        .catfishing: ["can't video call", "camera broken", "too shy for video", "deployed overseas",
                      "oil rig", "military deployment", "can't meet yet"],
        .manipulation: ["if you loved me", "nobody else will", "you owe me", "after everything",
                        "you're nothing without", "no one will ever", "lucky to have me"],
        .harassment: ["kill", "hurt you", "find you", "stalk", "revenge", "destroy you",
                      "ruin your life", "expose you", "tell everyone"],
        .inappropriate: ["send nudes", "explicit photos", "what are you wearing",
                         "take it off", "show me your body"],
        .spam: ["click this link", "free money", "you've won", "act now",
                "limited time offer", "subscribe to", "follow my"]
    ]

    func getOrCreateAnalysis(matchId: String, userId: String, otherUserId: String) async throws -> SafetyAnalysis {
        let existing: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("match_id", value: matchId)
            .eq("user_id", value: userId)
            .execute()
            .value

        if let analysis = existing.first {
            return analysis
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let created: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .insert([
                "match_id": matchId,
                "user_id": userId,
                "other_user_id": otherUserId,
                "safety_score": "100",
                "total_messages": "0",
                "red_flag_count": "0",
                "first_message_at": now,
                "last_analyzed_at": now
            ])
            .select()
            .execute()
            .value

        return created.first ?? SafetyAnalysis(
            id: UUID().uuidString,
            matchId: matchId,
            userId: userId,
            otherUserId: otherUserId,
            safetyScore: 100,
            totalMessages: 0,
            firstMessageAt: now,
            redFlagCount: 0,
            lastAnalyzedAt: now
        )
    }

    func analyzeMessage(_ message: String, analysisId: String) async throws -> [RedFlagReport] {
        let lowered = message.lowercased()
        var reports: [RedFlagReport] = []

        for (category, keywords) in Self.redFlagKeywords {
            for keyword in keywords {
                if lowered.contains(keyword) {
                    let now = ISO8601DateFormatter().string(from: Date())
                    let report = RedFlagReport(
                        id: UUID().uuidString,
                        analysisId: analysisId,
                        category: category,
                        severity: category.weight,
                        detail: "Message contains: \(keyword)",
                        messageId: nil,
                        createdAt: now
                    )
                    reports.append(report)

                    // Persist red flag report
                    do {
                        try await client
                            .from("red_flag_reports")
                            .insert([
                                "analysis_id": analysisId,
                                "category": category.rawValue,
                                "severity": "\(category.weight)",
                                "detail": "Message contains: \(keyword)"
                            ])
                            .execute()
                    } catch {
                        print("Warning: Failed to persist red flag report: \(error)")
                        // Continue analyzing other keywords
                    }
                    break // One flag per category per message
                }
            }
        }

        if !reports.isEmpty {
            let totalWeight = reports.reduce(0) { $0 + $1.severity }
            let scoreReduction = min(totalWeight, 30) // Cap reduction per message

            do {
                try await client
                    .from("safety_analyses")
                    .update([
                        "safety_score": AnyJSON.double(Double(max(0, 100 - scoreReduction))),
                        "red_flag_count": AnyJSON.double(Double(reports.count)),
                        "last_analyzed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                    ])
                    .eq("id", value: analysisId)
                    .execute()
            } catch {
                print("Error: Failed to update safety score (critical): \(error)")
                // This is critical - safety score should be updated
                throw error
            }
        }

        return reports
    }

    func getSafetyDashboard(userId: String) async throws -> [SafetyAnalysis] {
        let analyses: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("user_id", value: userId)
            .order("last_analyzed_at", ascending: false)
            .execute()
            .value
        return analyses
    }

    func getRedFlags(analysisId: String) async throws -> [RedFlagReport] {
        let flags: [RedFlagReport] = try await client
            .from("red_flag_reports")
            .select()
            .eq("analysis_id", value: analysisId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return flags
    }

    func isReadyToMove(analysisId: String) async throws -> (ready: Bool, reason: String?) {
        let analyses: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("id", value: analysisId)
            .execute()
            .value

        guard let analysis = analyses.first else {
            return (false, "Analysis not found")
        }

        if analysis.safetyScore < 70 {
            return (false, "Safety score is below the threshold")
        }
        if analysis.totalMessages < 20 {
            return (false, "Need at least 20 messages exchanged")
        }

        return (true, nil)
    }

    func reportRedFlag(analysisId: String, category: RedFlagCategory, detail: String, messageId: String?) async throws {
        try await client
            .from("red_flag_reports")
            .insert([
                "analysis_id": analysisId,
                "category": category.rawValue,
                "severity": "\(category.weight)",
                "detail": detail,
                "message_id": messageId ?? ""
            ])
            .execute()
    }

    // MARK: - Retroactive Analysis

    /// Analyze entire conversation history retroactively
    /// This is useful for conversations that existed before safety analysis was implemented,
    /// or to re-analyze conversations with updated red flag keywords
    func analyzeConversationHistory(conversationId: String, matchId: String, userId: String, otherUserId: String) async throws -> SafetyAnalysis {
        print("Starting retroactive safety analysis for conversation: \(conversationId)")

        // Get or create safety analysis
        let analysis = try await getOrCreateAnalysis(matchId: matchId, userId: userId, otherUserId: otherUserId)

        // Fetch all messages from this conversation sent by the other user
        let messages: [Message] = try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .eq("sender_id", value: otherUserId) // Only analyze messages from the other person
            .order("created_at", ascending: true)
            .execute()
            .value

        guard !messages.isEmpty else {
            print("No messages found to analyze")
            return analysis
        }

        print("Analyzing \(messages.count) messages from other user")

        // Clear existing red flag reports for this analysis
        do {
            try await client
                .from("red_flag_reports")
                .delete()
                .eq("analysis_id", value: analysis.id)
                .execute()
        } catch {
            print("Warning: Failed to clear existing red flag reports: \(error)")
        }

        // Analyze each message and collect red flags
        var allRedFlags: [RedFlagReport] = []
        var totalWeight = 0

        for (index, message) in messages.enumerated() {
            guard let content = message.content, !content.isEmpty else { continue }

            let lowered = content.lowercased()
            var foundInMessage: Set<RedFlagCategory> = []

            // Check for red flags (one per category per message)
            for (category, keywords) in Self.redFlagKeywords {
                guard !foundInMessage.contains(category) else { continue }

                for keyword in keywords {
                    if lowered.contains(keyword) {
                        let now = ISO8601DateFormatter().string(from: Date())
                        let report = RedFlagReport(
                            id: UUID().uuidString,
                            analysisId: analysis.id,
                            category: category,
                            severity: category.weight,
                            detail: "Message contains: \(keyword)",
                            messageId: message.id,
                            createdAt: now
                        )
                        allRedFlags.append(report)
                        foundInMessage.insert(category)
                        totalWeight += category.weight

                        // Persist red flag report
                        do {
                            try await client
                                .from("red_flag_reports")
                                .insert([
                                    "analysis_id": AnyJSON.string(analysis.id),
                                    "category": AnyJSON.string(category.rawValue),
                                    "severity": AnyJSON.string("\(category.weight)"),
                                    "detail": AnyJSON.string("Message contains: \(keyword)"),
                                    "message_id": AnyJSON.string(message.id)
                                ])
                                .execute()
                        } catch {
                            print("Warning: Failed to persist red flag report: \(error)")
                        }

                        break // One flag per category per message
                    }
                }
            }

            // Log progress every 10 messages
            if (index + 1) % 10 == 0 {
                print("Analyzed \(index + 1)/\(messages.count) messages, found \(allRedFlags.count) red flags")
            }
        }

        // Calculate final safety score
        // Start at 100, reduce by total weight, but cap individual message impact
        let maxReductionPerMessage = 30
        let messageCount = messages.count
        let cappedWeight = min(totalWeight, maxReductionPerMessage * messageCount)
        let finalScore = max(0, 100 - Int(Double(cappedWeight) / max(Double(messageCount), 1.0) * 2.0))

        print("Retroactive analysis complete: \(allRedFlags.count) red flags found, safety score: \(finalScore)")

        // Update safety analysis with results
        do {
            try await client
                .from("safety_analyses")
                .update([
                    "safety_score": AnyJSON.double(Double(finalScore)),
                    "total_messages": AnyJSON.double(Double(messageCount)),
                    "red_flag_count": AnyJSON.double(Double(allRedFlags.count)),
                    "last_analyzed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: analysis.id)
                .execute()
        } catch {
            print("Error: Failed to update safety analysis: \(error)")
            throw error
        }

        // Return updated analysis
        return SafetyAnalysis(
            id: analysis.id,
            matchId: analysis.matchId,
            userId: analysis.userId,
            otherUserId: analysis.otherUserId,
            safetyScore: finalScore,
            totalMessages: messageCount,
            firstMessageAt: analysis.firstMessageAt,
            redFlagCount: allRedFlags.count,
            lastAnalyzedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Analyze all conversations for a user retroactively
    /// Useful for bulk analysis of existing conversations
    func analyzeAllUserConversations(userId: String) async throws -> Int {
        print("Starting bulk retroactive analysis for user: \(userId)")

        // Get all matches for this user
        struct MatchInfo: Decodable {
            let id: String
            let user1_id: String
            let user2_id: String
        }

        let matches: [MatchInfo] = try await client
            .from("matches")
            .select("id, user1_id, user2_id")
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .execute()
            .value

        print("Found \(matches.count) matches to analyze")

        var analyzedCount = 0

        for match in matches {
            let otherUserId = match.user1_id == userId ? match.user2_id : match.user1_id

            // Get conversation for this match
            struct ConversationInfo: Decodable {
                let id: String
            }

            let conversations: [ConversationInfo] = try await client
                .from("conversations")
                .select("id")
                .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
                .or("user1_id.eq.\(otherUserId),user2_id.eq.\(otherUserId)")
                .execute()
                .value

            guard let conversation = conversations.first else { continue }

            do {
                _ = try await analyzeConversationHistory(
                    conversationId: conversation.id,
                    matchId: match.id,
                    userId: userId,
                    otherUserId: otherUserId
                )
                analyzedCount += 1
            } catch {
                print("Warning: Failed to analyze conversation \(conversation.id): \(error)")
            }
        }

        print("Bulk retroactive analysis complete: \(analyzedCount)/\(matches.count) conversations analyzed")
        return analyzedCount
    }
}
