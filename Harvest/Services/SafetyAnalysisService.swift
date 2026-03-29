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

    private struct ConversationLookup: Decodable {
        let id: String
        let user1_id: String?
        let user2_id: String?
    }

    private struct MessageTimestampRow: Decodable {
        let created_at: String?
    }

    private struct MatchLookup: Decodable {
        let id: String
        let user1_id: String?
        let user2_id: String?
    }

    private struct AnalysisUpdatePayload: Encodable {
        let safety_score: Int
        let red_flags: [SafetyFlagSnapshot]
        let recommendations: [String]
        let allow_contact_sharing: Bool
    }

    private struct AnalysisInsertPayload: Encodable {
        let conversation_id: String
        let user_id: String
        let match_id: String
        let safety_score: Int
        let red_flags: [SafetyFlagSnapshot]
        let recommendations: [String]
        let allow_contact_sharing: Bool
    }

    private struct RedFlagInsertPayload: Encodable {
        let reporter_id: String?
        let reported_user_id: String?
        let conversation_id: String
        let flag_type: String
        let severity: String
        let evidence: String
        let ai_detected: Bool
        let user_reported: Bool
    }

    func getOrCreateAnalysis(matchId: String, userId: String, otherUserId: String) async throws -> SafetyAnalysis {
        guard let conversation = try await fetchConversation(matchId: matchId) else {
            throw NSError(domain: "SafetyAnalysisService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Conversation not found for match"
            ])
        }

        let existing: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("conversation_id", value: conversation.id)
            .eq("user_id", value: userId)
            .execute()
            .value

        if let analysis = existing.first {
            return try await hydrateAnalysis(
                analysis,
                userId: userId,
                otherUserId: otherUserId,
                conversationId: conversation.id
            )
        }

        let payload = AnalysisInsertPayload(
            conversation_id: conversation.id,
            user_id: userId,
            match_id: matchId,
            safety_score: 100,
            red_flags: [],
            recommendations: [],
            allow_contact_sharing: false
        )

        let created: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .insert(payload)
            .select()
            .execute()
            .value

        guard let analysis = created.first else {
            throw NSError(domain: "SafetyAnalysisService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create safety analysis"
            ])
        }

        return try await hydrateAnalysis(
            analysis,
            userId: userId,
            otherUserId: otherUserId,
            conversationId: conversation.id
        )
    }

    func analyzeMessage(_ message: String, analysisId: String) async throws -> [RedFlagReport] {
        guard var analysis = try await getAnalysisById(analysisId) else { return [] }

        let reports = detectFlags(in: message)
        guard !reports.isEmpty else { return [] }

        analysis.redFlags += reports
        analysis.safetyScore = computeSafetyScore(from: analysis.redFlags)
        analysis.totalMessages = try await fetchMessageCount(conversationId: analysis.conversationId)
        analysis.recommendations = recommendations(for: analysis.safetyScore, totalMessages: analysis.totalMessages)
        analysis.allowContactSharing = canShareContact(analysis: analysis)

        do {
            try await replaceAIDetectedFlags(
                conversationId: analysis.conversationId,
                reportedUserId: analysis.otherUserId,
                reports: analysis.redFlags
            )
        } catch {
            print("Warning: Failed to persist AI red flag reports: \(error)")
        }

        try await persistAnalysis(analysis)
        return try await getRedFlags(analysisId: analysisId)
    }

    func getSafetyDashboard(userId: String) async throws -> [SafetyAnalysis] {
        let analyses: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return try await withThrowingTaskGroup(of: SafetyAnalysis.self) { group in
            for analysis in analyses {
                group.addTask {
                    let otherUserId = try await self.fetchOtherUserId(
                        matchId: analysis.matchId,
                        conversationId: analysis.conversationId,
                        currentUserId: userId
                    )
                    return try await self.hydrateAnalysis(
                        analysis,
                        userId: userId,
                        otherUserId: otherUserId ?? "",
                        conversationId: analysis.conversationId
                    )
                }
            }

            var hydrated: [SafetyAnalysis] = []
            for try await analysis in group {
                hydrated.append(analysis)
            }
            return hydrated.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        }
    }

    func getRedFlags(analysisId: String) async throws -> [RedFlagReport] {
        guard let analysis = try await getAnalysisById(analysisId) else { return [] }

        let flags: [RedFlagReport] = try await client
            .from("red_flag_reports")
            .select()
            .eq("conversation_id", value: analysis.conversationId)
            .eq("reported_user_id", value: analysis.otherUserId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return flags
    }

    func isReadyToMove(analysisId: String) async throws -> (ready: Bool, reason: String?) {
        guard let analysis = try await getAnalysisById(analysisId) else {
            return (false, "Analysis not found")
        }

        if !analysis.has24HourHistory {
            return (false, "At least 24 hours of conversation history are required")
        }
        if analysis.totalMessages < 20 {
            return (false, "Need at least 20 messages exchanged")
        }
        if analysis.safetyScore < 70 {
            return (false, "Safety score is below the threshold")
        }

        return (true, nil)
    }

    func reportRedFlag(analysisId: String, category: RedFlagCategory, detail: String, messageId: String?) async throws {
        guard let analysis = try await getAnalysisById(analysisId) else { return }

        let evidence: String
        if let messageId, !messageId.isEmpty {
            evidence = "[\(messageId)] \(detail)"
        } else {
            evidence = detail
        }

        let payload = RedFlagInsertPayload(
            reporter_id: analysis.userId,
            reported_user_id: analysis.otherUserId.isEmpty ? nil : analysis.otherUserId,
            conversation_id: analysis.conversationId,
            flag_type: category.rawValue,
            severity: category.severity.rawValue,
            evidence: evidence,
            ai_detected: false,
            user_reported: true
        )

        try await client
            .from("red_flag_reports")
            .insert(payload)
            .execute()
    }

    func analyzeConversationHistory(conversationId: String, matchId: String, userId: String, otherUserId: String) async throws -> SafetyAnalysis {
        var analysis = try await getOrCreateAnalysis(matchId: matchId, userId: userId, otherUserId: otherUserId)

        let messages: [Message] = try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .eq("sender_id", value: otherUserId)
            .order("created_at", ascending: true)
            .execute()
            .value

        var snapshots: [SafetyFlagSnapshot] = []

        for message in messages {
            guard let content = message.content, !content.isEmpty else { continue }
            let detected = detectFlags(in: content, messageId: message.id)
            snapshots.append(contentsOf: detected)
        }

        analysis.redFlags = snapshots
        analysis.totalMessages = try await fetchMessageCount(conversationId: conversationId)
        analysis.safetyScore = computeSafetyScore(from: snapshots)
        analysis.recommendations = recommendations(for: analysis.safetyScore, totalMessages: analysis.totalMessages)
        analysis.allowContactSharing = canShareContact(analysis: analysis)

        do {
            try await replaceAIDetectedFlags(
                conversationId: conversationId,
                reportedUserId: otherUserId,
                reports: snapshots
            )
        } catch {
            print("Warning: Failed to persist retroactive AI red flag reports: \(error)")
        }
        try await persistAnalysis(analysis)

        return analysis
    }

    func analyzeAllUserConversations(userId: String) async throws -> Int {
        let matches: [MatchLookup] = try await client
            .from("matches")
            .select("id, user1_id, user2_id")
            .eq("is_active", value: true)
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .execute()
            .value

        var analyzedCount = 0

        for match in matches {
            let otherUserId = normalized(match.user1_id) == normalized(userId) ? match.user2_id : match.user1_id
            guard let otherUserId, let conversation = try await fetchConversation(matchId: match.id) else { continue }

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

        return analyzedCount
    }

    private func getAnalysisById(_ analysisId: String) async throws -> SafetyAnalysis? {
        let analyses: [SafetyAnalysis] = try await client
            .from("safety_analyses")
            .select()
            .eq("id", value: analysisId)
            .execute()
            .value

        guard let analysis = analyses.first else { return nil }
        let otherUserId = try await fetchOtherUserId(
            matchId: analysis.matchId,
            conversationId: analysis.conversationId,
            currentUserId: analysis.userId
        ) ?? ""
        return try await hydrateAnalysis(
            analysis,
            userId: analysis.userId,
            otherUserId: otherUserId,
            conversationId: analysis.conversationId
        )
    }

    private func hydrateAnalysis(
        _ analysis: SafetyAnalysis,
        userId: String,
        otherUserId: String,
        conversationId: String
    ) async throws -> SafetyAnalysis {
        var hydrated = analysis
        hydrated.otherUserId = otherUserId
        hydrated.totalMessages = try await fetchMessageCount(conversationId: conversationId)
        hydrated.firstMessageAt = try await fetchFirstMessageAt(conversationId: conversationId)
        hydrated.recommendations = analysis.recommendations.isEmpty
            ? recommendations(for: analysis.safetyScore, totalMessages: hydrated.totalMessages)
            : analysis.recommendations
        hydrated.allowContactSharing = analysis.allowContactSharing || canShareContact(analysis: hydrated)
        return hydrated
    }

    private func fetchConversation(matchId: String) async throws -> ConversationLookup? {
        let conversations: [ConversationLookup] = try await client
            .from("conversations")
            .select("id, user1_id, user2_id")
            .eq("match_id", value: matchId)
            .limit(1)
            .execute()
            .value

        return conversations.first
    }

    private func fetchOtherUserId(matchId: String, conversationId: String, currentUserId: String) async throws -> String? {
        let matches: [MatchLookup] = try await client
            .from("matches")
            .select("id, user1_id, user2_id")
            .eq("id", value: matchId)
            .limit(1)
            .execute()
            .value

        if let match = matches.first {
            if normalized(match.user1_id) == normalized(currentUserId) {
                return match.user2_id
            }
            if normalized(match.user2_id) == normalized(currentUserId) {
                return match.user1_id
            }
        }

        let conversations: [ConversationLookup] = try await client
            .from("conversations")
            .select("id, user1_id, user2_id")
            .eq("id", value: conversationId)
            .limit(1)
            .execute()
            .value

        guard let conversation = conversations.first else { return nil }
        if normalized(conversation.user1_id) == normalized(currentUserId) {
            return conversation.user2_id
        }
        if normalized(conversation.user2_id) == normalized(currentUserId) {
            return conversation.user1_id
        }
        return nil
    }

    private func fetchMessageCount(conversationId: String) async throws -> Int {
        let messages: [Message] = try await client
            .from("messages")
            .select("id, conversation_id, sender_id, content, message_type, media_url, is_read, read_at, created_at")
            .eq("conversation_id", value: conversationId)
            .execute()
            .value
        return messages.count
    }

    private func fetchFirstMessageAt(conversationId: String) async throws -> String? {
        let rows: [MessageTimestampRow] = try await client
            .from("messages")
            .select("created_at")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .limit(1)
            .execute()
            .value

        return rows.first?.created_at
    }

    private func detectFlags(in text: String, messageId: String? = nil) -> [SafetyFlagSnapshot] {
        let lowered = text.lowercased()
        var reports: [SafetyFlagSnapshot] = []

        for (category, keywords) in Self.redFlagKeywords {
            for keyword in keywords where lowered.contains(keyword) {
                reports.append(
                    SafetyFlagSnapshot(
                        id: UUID().uuidString,
                        category: category,
                        severity: category.severity,
                        evidence: "Message contains: \(keyword)",
                        messageId: messageId,
                        createdAt: isoNow()
                    )
                )
                break
            }
        }

        return reports
    }

    private func computeSafetyScore(from flags: [SafetyFlagSnapshot]) -> Int {
        let totalWeight = flags.reduce(0) { $0 + $1.severity.weight }
        return max(0, 100 - min(totalWeight, 90))
    }

    private func recommendations(for score: Int, totalMessages: Int) -> [String] {
        var output: [String] = []

        if totalMessages < 20 {
            output.append("Keep chatting in-app before sharing contact details.")
        }
        if score < 70 {
            output.append("Proceed cautiously and avoid moving off-platform yet.")
        }
        if score < 50 {
            output.append("Consider reporting or blocking this user if the behavior continues.")
        }
        if output.isEmpty {
            output.append("This conversation currently looks safe. Stay mindful and trust your instincts.")
        }

        return output
    }

    private func canShareContact(analysis: SafetyAnalysis) -> Bool {
        analysis.safetyScore >= 70 && analysis.totalMessages >= 20 && analysis.has24HourHistory
    }

    private func replaceAIDetectedFlags(
        conversationId: String,
        reportedUserId: String,
        reports: [SafetyFlagSnapshot]
    ) async throws {
        try await client
            .from("red_flag_reports")
            .delete()
            .eq("conversation_id", value: conversationId)
            .eq("reported_user_id", value: reportedUserId)
            .eq("ai_detected", value: true)
            .execute()

        guard !reports.isEmpty else { return }

        let payloads = reports.map {
            RedFlagInsertPayload(
                reporter_id: nil,
                reported_user_id: reportedUserId,
                conversation_id: conversationId,
                flag_type: $0.category.rawValue,
                severity: $0.severity.rawValue,
                evidence: $0.evidence,
                ai_detected: true,
                user_reported: false
            )
        }

        try await client
            .from("red_flag_reports")
            .insert(payloads)
            .execute()
    }

    private func persistAnalysis(_ analysis: SafetyAnalysis) async throws {
        let payload = AnalysisUpdatePayload(
            safety_score: analysis.safetyScore,
            red_flags: analysis.redFlags,
            recommendations: analysis.recommendations,
            allow_contact_sharing: analysis.allowContactSharing
        )

        try await client
            .from("safety_analyses")
            .update(payload)
            .eq("id", value: analysis.id)
            .execute()
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func normalized(_ value: String?) -> String? {
        value?.lowercased()
    }
}
