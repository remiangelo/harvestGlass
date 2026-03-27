import Foundation
import Observation

@Observable
final class GardenerViewModel {
    var messages: [GardenerMessage] = []
    var messageText = ""
    var isLoading = false
    var isSending = false
    var dailyQuiz: DailyQuiz?
    var showDailyQuiz = false
    var todayCharUsage = 0
    var characterLimit = 1000
    var conversationsPerDay: Int? = 1
    var remainingConversations = 0
    var currentTier: SubscriptionTier?
    var error: String?
    var rateLimitWarning: String?

    private let gardenerService = GardenerService()
    private let subscriptionService = SubscriptionService()
    private let rateLimitService = RateLimitService()

    var isAtLimit: Bool {
        todayCharUsage >= characterLimit
    }

    var remainingChars: Int {
        max(0, characterLimit - todayCharUsage)
    }

    func loadChat(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        await loadTierLimits(userId: userId)

        do {
            messages = try await gardenerService.getChatHistory(userId: userId)
            todayCharUsage = try await gardenerService.getTodayCharacterUsage(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage(userId: String) async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check rate limits before sending
        guard let tier = currentTier else {
            error = "Unable to verify subscription tier"
            return
        }

        do {
            let limitCheck = try await rateLimitService.checkGardenerLimit(
                userId: userId,
                messageLength: text.count,
                userTier: tier
            )

            if !limitCheck.canSend {
                error = limitCheck.reason
                rateLimitWarning = limitCheck.reason
                return
            }

            // Update remaining counts for UI
            remainingConversations = limitCheck.remainingConversations
        } catch {
            print("Warning: Rate limit check failed: \(error)")
            // Continue with send - don't block user due to rate limit check failure
        }

        isSending = true
        messageText = ""

        // Optimistic local user message
        let userMsg = GardenerMessage(
            id: UUID().uuidString,
            userId: userId,
            role: "user",
            content: text,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(userMsg)
        todayCharUsage += text.count

        do {
            let response = try await gardenerService.sendMessage(
                userId: userId,
                message: text,
                history: messages
            )

            let assistantMsg = GardenerMessage(
                id: UUID().uuidString,
                userId: userId,
                role: "assistant",
                content: response,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            messages.append(assistantMsg)

            // Track conversation for rate limiting
            try? await rateLimitService.trackGardenerConversation(userId: userId, characterCount: text.count)

        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }

    func checkDailyQuiz(userId: String) async {
        // Delay slightly for better UX
        try? await Task.sleep(for: .seconds(2))

        do {
            let quiz = try await gardenerService.generateDailyQuiz(userId: userId)
            if let quiz {
                dailyQuiz = quiz
                showDailyQuiz = true
            }
        } catch {
            // Non-critical
        }
    }

    func submitQuizAnswer(answer: String) async {
        guard let quiz = dailyQuiz else { return }

        // Generate insight via OpenAI
        let openAI = OpenAIService()
        var insight: String?

        do {
            let aiMessages: [OpenAIService.ChatMessage] = [
                .init(role: "system", content: "You are a dating coach. Give a brief 1-2 sentence insight based on this quiz answer."),
                .init(role: "user", content: "Question: \(quiz.question)\nAnswer: \(answer)")
            ]
            insight = try await openAI.sendChat(messages: aiMessages, temperature: 0.7, maxTokens: 100)
        } catch {
            insight = "Interesting choice! Self-awareness is the first step to meaningful connections."
        }

        try? await gardenerService.saveQuizAnswer(quizId: quiz.id, answer: answer, insight: insight)
        dailyQuiz?.selectedAnswer = answer
        dailyQuiz?.insight = insight
    }

    private func loadTierLimits(userId: String) async {
        do {
            if let sub = try await subscriptionService.getUserSubscription(userId: userId) {
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let tier = tiers.first(where: { $0.id == sub.tierId }) {
                    currentTier = tier
                    characterLimit = tier.gardenerCharacterLimit
                    conversationsPerDay = tier.gardenerConversationsPerDay

                    // Get current rate limit status
                    let limitCheck = try await rateLimitService.checkGardenerLimit(
                        userId: userId,
                        messageLength: 0,
                        userTier: tier
                    )
                    remainingConversations = limitCheck.remainingConversations
                    return
                }
            } else {
                // No subscription - load seed tier
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let seedTier = tiers.first(where: { $0.name == .seed }) {
                    currentTier = seedTier
                    characterLimit = seedTier.gardenerCharacterLimit
                    conversationsPerDay = seedTier.gardenerConversationsPerDay
                    let limitCheck = try await rateLimitService.checkGardenerLimit(
                        userId: userId,
                        messageLength: 0,
                        userTier: seedTier
                    )
                    remainingConversations = limitCheck.remainingConversations
                    return
                }
            }
        } catch {
            print("Warning: Failed to load tier limits: \(error)")
        }

        currentTier = SubscriptionTier(
            id: "",
            name: .seed,
            displayName: "Seed",
            description: "",
            priceMonthly: 0,
            priceYearly: 0,
            matchesPerWeek: 10,
            maxDistanceMiles: 25,
            gardenerConversationsPerDay: 1,
            gardenerCharacterLimit: 1000,
            hasValuesMatching: false,
            hasBasicFilters: true,
            hasAdvancedFilters: false,
            hasFullFilters: false,
            canSeeLikes: false,
            canDisableMindfulMessaging: false,
            sortOrder: 0
        )
        characterLimit = 1000
        conversationsPerDay = 1
        remainingConversations = 1
    }
}
