import Foundation
import SwiftUI

struct SafetyAnalysis: Codable, Identifiable, Sendable {
    let id: String
    let conversationId: String
    let userId: String
    let matchId: String
    var safetyScore: Int
    var redFlags: [SafetyFlagSnapshot]
    var recommendations: [String]
    var allowContactSharing: Bool
    var createdAt: String?

    // Derived app-side fields populated by the service.
    var otherUserId: String = ""
    var totalMessages: Int = 0
    var firstMessageAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case matchId = "match_id"
        case safetyScore = "safety_score"
        case redFlags = "red_flags"
        case recommendations
        case allowContactSharing = "allow_contact_sharing"
        case createdAt = "created_at"
    }

    var redFlagCount: Int {
        redFlags.count
    }

    var has24HourHistory: Bool {
        let reference = firstMessageAt ?? createdAt
        guard let reference,
              let date = ISO8601DateFormatter().date(from: reference) ??
                  ISO8601DateFormatter.fractionalSeconds.date(from: reference)
        else {
            return false
        }

        return Date().timeIntervalSince(date) >= 24 * 60 * 60
    }

    var safetyLevel: SafetyLevel {
        if safetyScore < 20 { return .block }
        if safetyScore < 50 { return .warning }
        if safetyScore < 70 { return .caution }
        if safetyScore < 80 { return .safe }
        return .verified
    }
}

struct SafetyFlagSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let category: RedFlagCategory
    let severity: RedFlagSeverity
    let evidence: String
    let messageId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, category, severity, evidence
        case messageId = "message_id"
        case createdAt = "created_at"
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
    let reporterId: String?
    let reportedUserId: String?
    let conversationId: String?
    let flagType: String
    let severity: RedFlagSeverity?
    let evidence: String?
    let aiDetected: Bool
    let userReported: Bool
    let reviewed: Bool
    let actionTaken: String?
    let reviewedBy: String?
    let reviewedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case conversationId = "conversation_id"
        case flagType = "flag_type"
        case severity
        case evidence
        case aiDetected = "ai_detected"
        case userReported = "user_reported"
        case reviewed
        case actionTaken = "action_taken"
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
    }

    var category: RedFlagCategory {
        RedFlagCategory(rawValue: flagType) ?? .spam
    }

    var detail: String {
        evidence ?? ""
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
        severity.weight
    }

    var severity: RedFlagSeverity {
        switch self {
        case .financial: return .critical
        case .personalInfo: return .critical
        case .catfishing: return .high
        case .manipulation: return .medium
        case .harassment: return .high
        case .inappropriate: return .medium
        case .spam: return .low
        }
    }
}

enum RedFlagSeverity: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical

    var weight: Int {
        switch self {
        case .low: return 10
        case .medium: return 20
        case .high: return 25
        case .critical: return 30
        }
    }
}

private extension ISO8601DateFormatter {
    static let fractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
