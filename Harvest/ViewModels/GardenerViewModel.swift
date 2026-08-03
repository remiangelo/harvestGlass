import Foundation
import Observation
import UIKit

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

    /// The image staged in the composer, awaiting send. Never persisted.
    var pendingScreenshot: UIImage?

    var hasPendingScreenshot: Bool { pendingScreenshot != nil }

    /// Sends the staged screenshot for review. The image is encoded inline and
    /// dropped — nothing is uploaded to storage.
    func sendScreenshot(userId: String) async {
        guard !isSending, let image = pendingScreenshot else { return }

        guard let tier = currentTier else {
            error = "Unable to verify subscription tier"
            return
        }

        // A vision call is charged a flat rate, not the caption's length.
        let cost = GardenerService.screenshotCharacterCost
        do {
            let limitCheck = try await rateLimitService.checkGardenerLimit(
                userId: userId,
                messageLength: cost,
                userTier: tier
            )
            if !limitCheck.canSend {
                error = limitCheck.reason
                rateLimitWarning = limitCheck.reason
                return
            }
        } catch {
            print("Warning: Rate limit check failed: \(error)")
            // Continue with send - don't block user due to rate limit check failure
        }

        let caption = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Encode before mutating any state, so a bad image leaves the composer
        // exactly as the user left it.
        let dataURL: String
        do {
            dataURL = try ScreenshotEncoder.dataURL(from: image)
        } catch {
            self.error = error.localizedDescription
            return
        }

        isSending = true
        defer { isSending = false }
        messageText = ""
        pendingScreenshot = nil

        let placeholder = caption.isEmpty ? "📷 Screenshot" : "📷 Screenshot — \(caption)"
        messages.append(
            GardenerMessage(
                id: UUID().uuidString,
                userId: userId,
                role: "user",
                content: placeholder,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        todayCharUsage += cost

        do {
            let response = try await gardenerService.sendScreenshot(
                userId: userId,
                imageDataURL: dataURL,
                caption: caption,
                history: messages
            )
            messages.append(
                GardenerMessage(
                    id: UUID().uuidString,
                    userId: userId,
                    role: "assistant",
                    content: response,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
            )
        } catch {
            // Transport or decode failure — never presented as "not a
            // screenshot", which would blame the user for a network problem.
            self.error = "I couldn't read that screenshot just now. Try sending it again."
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
            if let quiz, !quiz.isAnswered {
                dailyQuiz = quiz
                showDailyQuiz = true
            }
        } catch {
            self.error = "Daily quiz failed to load: \(error.localizedDescription)"
            print("Error loading daily quiz: \(error)")
        }
    }

    func submitQuizAnswer(userId: String, answer: String) async {
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

        try? await gardenerService.saveQuizAnswer(userId: userId, quiz: quiz, answer: answer)
        dailyQuiz?.selectedAnswer = answer
        dailyQuiz?.insight = insight
        dailyQuiz?.isAnswered = true
    }

    private func loadTierLimits(userId: String) async {
        do {
            if let sub = try await subscriptionService.getUserSubscription(userId: userId) {
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let tier = tiers.first(where: { $0.id == sub.tierId }) {
                    currentTier = tier
                    characterLimit = tier.gardenerCharacterLimit

                    // Get current rate limit status
                    let limitCheck = try await rateLimitService.checkGardenerLimit(
                        userId: userId,
                        messageLength: 0,
                        userTier: tier
                    )
                    todayCharUsage = max(0, limitCheck.characterLimit - limitCheck.remainingCharacters)
                    return
                }
            } else {
                // No subscription - load seed tier
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let seedTier = tiers.first(where: { $0.name == .seed }) {
                    currentTier = seedTier
                    characterLimit = seedTier.gardenerCharacterLimit
                    let limitCheck = try await rateLimitService.checkGardenerLimit(
                        userId: userId,
                        messageLength: 0,
                        userTier: seedTier
                    )
                    todayCharUsage = max(0, limitCheck.characterLimit - limitCheck.remainingCharacters)
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
            priceWeekly: 0,
            matchesPerWeek: 10,
            maxDistanceMiles: 25,
            gardenerConversationsPerDay: nil,
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
        todayCharUsage = 0
    }
}
