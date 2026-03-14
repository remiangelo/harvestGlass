import Foundation
import SwiftUI

struct SafetyAnalysis: Codable, Identifiable, Sendable {
    let id: String
    let matchId: String
    let userId: String
    let otherUserId: String
    var safetyScore: Int
    var totalMessages: Int
    var firstMessageAt: String?
    var redFlagCount: Int
    var lastAnalyzedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, totalMessages = "total_messages"
        case matchId = "match_id"
        case userId = "user_id"
        case otherUserId = "other_user_id"
        case safetyScore = "safety_score"
        case firstMessageAt = "first_message_at"
        case redFlagCount = "red_flag_count"
        case lastAnalyzedAt = "last_analyzed_at"
    }

    var safetyLevel: SafetyLevel {
        if safetyScore < 20 { return .block }
        if safetyScore < 50 { return .warning }
        if safetyScore < 70 { return .caution }
        if safetyScore < 80 { return .safe }
        return .verified
    }
}

enum SafetyLevel: String, Sendable {
    case block, warning, caution, safe, verified

    var color: Color {
        switch self {
        case .block: return Color(hex: "DC2626")
        case .warning: return Color(hex: "F59E0B")
        case .caution: return Color(hex: "F97316")
        case .safe: return Color(hex: "27CF8A")
        case .verified: return Color(hex: "3B82F6")
        }
    }

    var icon: String {
        switch self {
        case .block: return "xmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .safe: return "checkmark.shield.fill"
        case .verified: return "checkmark.seal.fill"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct RedFlagReport: Codable, Identifiable, Sendable {
    let id: String
    let analysisId: String
    let category: RedFlagCategory
    let severity: Int
    let detail: String
    let messageId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, category, severity, detail
        case analysisId = "analysis_id"
        case messageId = "message_id"
        case createdAt = "created_at"
    }
}

enum RedFlagCategory: String, Codable, Sendable {
    case financial
    case personalInfo = "personal_info"
    case catfishing
    case manipulation
    case harassment
    case inappropriate
    case spam

    var weight: Int {
        switch self {
        case .financial: return 30
        case .personalInfo: return 30
        case .catfishing: return 25
        case .manipulation: return 20
        case .harassment: return 20
        case .inappropriate: return 15
        case .spam: return 10
        }
    }
}
