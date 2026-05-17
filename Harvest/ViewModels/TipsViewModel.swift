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
            title: "Lead With Your Values",
            body: "Don't open with 'how was your day' — open with a question about something you actually value. 'What's a value you live by lately?' tells you more in one message than ten about logistics.",
            category: .conversation,
            icon: "bubble.left.and.bubble.right"
        ),
        Tip(
            title: "Show the Values You Bring",
            body: "Instead of saying 'I'm honest,' share a story that demonstrates the value. Your profile lands when your photos and bio together show what you stand for, not just what you do.",
            category: .profile,
            icon: "person.text.rectangle"
        ),
        Tip(
            title: "Trust Misalignment Signals",
            body: "When someone's actions don't match the values they claim, that's data. Slow down, ask one direct question, and trust what you hear back. Misalignment early is a gift.",
            category: .safety,
            icon: "shield.checkered"
        ),
        Tip(
            title: "Depth Over Volume",
            body: "Better to have one conversation rooted in shared values than five surface chats. Invest where the values overlap; let the rest fade without guilt.",
            category: .mindfulness,
            icon: "heart.text.clipboard"
        ),
        Tip(
            title: "Photos That Show Your Values",
            body: "One clear face shot, one full-body, and one photo of you doing something that reflects what matters to you — a meal you cooked, a place that grounds you, a project you finished.",
            category: .profile,
            icon: "photo.stack"
        ),
        Tip(
            title: "Meet in Public First",
            body: "First dates in public are about value alignment in low-stakes settings, and they're also about safety. Pick a place you'd happily go alone, and tell someone where you'll be.",
            category: .safety,
            icon: "mappin.and.ellipse"
        )
    ]

    static let faqs: [FAQ] = [
        FAQ(
            question: "How do I lead with values without sounding stiff?",
            answer: "Anchor a value in a story or a small detail. 'I value honesty — last week I had to tell a friend a hard truth and we're closer for it' lands warmer than the abstract version."
        ),
        FAQ(
            question: "When should I suggest meeting in person?",
            answer: "Move to meeting once you've heard enough to know your values aren't going to actively clash. Usually 5–10 days of consistent messaging. Pick a low-pressure activity that lets you see who they are, not who they perform as."
        ),
        FAQ(
            question: "How do I handle rejection from someone whose values I liked?",
            answer: "Compatibility is more than overlap — it's also fit, timing, and a hundred things you can't control. Thank them, wish them well, and let the values you valued in them sharpen your sense of what's next."
        )
    ]

    var filteredTips: [Tip] {
        guard let category = selectedCategory else { return Self.tips }
        return Self.tips.filter { $0.category == category }
    }
}
