import Foundation
import Observation

@Observable
final class TipsViewModel {
    enum TipCategory: String, CaseIterable {
        case conversation = "Conversation"
        case profile = "Profile"
        case safety = "Safety"
        case mindfulness = "Mindfulness"
    }

    struct Tip: Identifiable {
        let id = UUID().uuidString
        let title: String
        let body: String
        let category: TipCategory
        let icon: String
    }

    struct FAQ: Identifiable {
        let id = UUID().uuidString
        let question: String
        let answer: String
    }

    var selectedCategory: TipCategory?
    var expandedFAQId: String?

    static let tips: [Tip] = [
        Tip(
            title: "Ask Open-Ended Questions",
            body: "Instead of yes/no questions, ask about experiences and opinions. 'What's the best trip you've ever taken?' sparks better conversation than 'Do you like traveling?'",
            category: .conversation,
            icon: "bubble.left.and.bubble.right"
        ),
        Tip(
            title: "Show, Don't Tell",
            body: "Instead of saying 'I'm funny,' share a story that shows your humor. Your profile should demonstrate your qualities through examples and specifics.",
            category: .profile,
            icon: "person.text.rectangle"
        ),
        Tip(
            title: "Trust Your Instincts",
            body: "If something feels off about a conversation, trust that feeling. It's always okay to slow down, ask questions, or stop communicating entirely.",
            category: .safety,
            icon: "shield.checkered"
        ),
        Tip(
            title: "Quality Over Quantity",
            body: "Focus on meaningful conversations with fewer matches rather than surface-level chats with many. Deeper connections come from invested attention.",
            category: .mindfulness,
            icon: "heart.text.clipboard"
        ),
        Tip(
            title: "Use Variety in Photos",
            body: "Include a clear headshot, a full-body photo, and pictures doing activities you enjoy. Avoid group photos as your first image.",
            category: .profile,
            icon: "photo.stack"
        ),
        Tip(
            title: "Meet in Public First",
            body: "Always meet in a public place for your first date. Tell a friend where you'll be and check in with them during and after.",
            category: .safety,
            icon: "mappin.and.ellipse"
        )
    ]

    static let faqs: [FAQ] = [
        FAQ(
            question: "How do I make a great first impression?",
            answer: "Be genuine and specific. Reference something from their profile to show you actually read it. Keep your opening message friendly and ask a question to encourage a response."
        ),
        FAQ(
            question: "When should I suggest meeting in person?",
            answer: "There's no perfect timeline, but generally after 5-10 days of consistent messaging when you feel comfortable. Suggest a low-pressure activity like coffee or a walk."
        ),
        FAQ(
            question: "How do I handle rejection gracefully?",
            answer: "Remember it's not personal — compatibility is complex. Thank them for their honesty, wish them well, and keep your focus forward. Every 'no' brings you closer to the right 'yes.'"
        )
    ]

    var filteredTips: [Tip] {
        guard let category = selectedCategory else { return Self.tips }
        return Self.tips.filter { $0.category == category }
    }
}
