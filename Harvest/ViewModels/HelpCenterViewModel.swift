import Foundation
import Observation
import Supabase

@Observable
final class HelpCenterViewModel {
    struct FAQ: Identifiable {
        let id = UUID().uuidString
        let question: String
        let answer: String
        let category: String
    }

    var selectedCategory: String?
    var expandedFAQId: String?
    var ticketCategory = "General"
    var ticketSubject = ""
    var ticketMessage = ""
    var isSubmitting = false
    var showSuccess = false
    var error: String?

    static let categories = ["Matching", "Billing", "Safety", "Features", "Account"]

    static let faqs: [FAQ] = [
        FAQ(question: "How does matching work?", answer: "When you and another user both swipe right (Like) on each other, it's a match! You can then start a conversation. Super Likes let the other person know you're especially interested.", category: "Matching"),
        FAQ(question: "Why am I not getting matches?", answer: "Try updating your photos with clear, recent images. Write a detailed bio that shows your personality. Expand your distance and age preferences. Being active on the app regularly also helps.", category: "Matching"),
        FAQ(question: "How do I cancel my subscription?", answer: "Go to Settings > Subscription to view your current plan. Subscriptions are managed through the Apple App Store. You can cancel anytime in your iPhone Settings > Apple ID > Subscriptions.", category: "Billing"),
        FAQ(question: "What should I do if I feel unsafe?", answer: "Use the report or block features in the chat menu immediately. You can also visit the Safety Dashboard in Settings to review safety scores. If you're in immediate danger, contact local emergency services.", category: "Safety"),
        FAQ(question: "What is Mindful Messaging?", answer: "Mindful Messaging analyzes your messages before sending to flag potentially concerning language. It provides reflections to help build healthier communication habits. Gold subscribers can disable this feature.", category: "Features"),
        FAQ(question: "How do I delete my account?", answer: "Go to Settings and scroll to the bottom. Contact support to request account deletion. We'll process your request and remove all associated data within 30 days.", category: "Account")
    ]

    var filteredFAQs: [FAQ] {
        guard let category = selectedCategory else { return Self.faqs }
        return Self.faqs.filter { $0.category == category }
    }

    func submitTicket(userId: String) async {
        guard !ticketSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ticketMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await SupabaseManager.shared.client
                .from("support_tickets")
                .insert([
                    "user_id": userId,
                    "category": ticketCategory,
                    "subject": ticketSubject,
                    "message": ticketMessage
                ])
                .execute()

            ticketSubject = ""
            ticketMessage = ""
            showSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
