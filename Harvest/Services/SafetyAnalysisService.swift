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

                    // Persist
                    _ = try? await client
                        .from("red_flag_reports")
                        .insert([
                            "analysis_id": analysisId,
                            "category": category.rawValue,
                            "severity": "\(category.weight)",
                            "detail": "Message contains: \(keyword)"
                        ])
                        .execute()
                    break // One flag per category per message
                }
            }
        }

        if !reports.isEmpty {
            let totalWeight = reports.reduce(0) { $0 + $1.severity }
            let scoreReduction = min(totalWeight, 30) // Cap reduction per message

            _ = try? await client
                .from("safety_analyses")
                .update([
                    "safety_score": AnyJSON.double(Double(max(0, 100 - scoreReduction))),
                    "red_flag_count": AnyJSON.double(Double(reports.count)),
                    "last_analyzed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: analysisId)
                .execute()
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
}
