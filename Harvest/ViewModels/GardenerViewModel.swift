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
    var characterLimit = 2000
    var screenshotsUsedToday = 0
    var screenshotLimit = 1
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

    var remainingScreenshots: Int {
        max(0, screenshotLimit - screenshotsUsedToday)
    }

    var isAtScreenshotLimit: Bool {
        remainingScreenshots == 0
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

    /// The images staged in the composer, awaiting send. Never persisted.
    var pendingScreenshots: [UIImage] = []

    /// Encoded images from the last send, kept so a follow-up in the same
    /// sitting can be answered by looking again. Dies with the view model;
    /// never uploaded, never written to chat history.
    var retainedImageURLs: [String] = []

    /// Images allowed per message on the current tier.
    var imageCap = 1

    var hasPendingScreenshot: Bool { !pendingScreenshots.isEmpty }

    /// Total encoded budget for one request, in characters of base64.
    static let payloadBudgetCharacters = 6_000_000

    /// The images actually sent. The picker is opened with the cap, but a
    /// picker limit is an affordance rather than a guarantee — and a cap of
    /// zero from a malformed tier row must still let one image through.
    static func clampSelection<Item>(_ picked: [Item], cap: Int) -> [Item] {
        Array(picked.prefix(max(cap, 1)))
    }

    /// Nil when the encoded selection fits, otherwise the message to show.
    /// Scaling bounds each image; nothing bounds the sum, and a transport
    /// error tells the user nothing about what to do differently.
    static func payloadRejection(_ dataURLs: [String]) -> String? {
        let total = dataURLs.reduce(0) { $0 + $1.count }
        guard total > payloadBudgetCharacters else { return nil }
        return "Those \(dataURLs.count) images are too large to send together. "
            + "Try sending fewer at a time."
    }

    /// A fresh selection replaces whatever was staged, and drops any images
    /// retained from a previous review — the view model outlives a single
    /// review, so without this a review from an hour ago would silently keep
    /// answering an unrelated new question.
    func stageScreenshots(_ images: [UIImage]) {
        pendingScreenshots = Self.clampSelection(images, cap: imageCap)
        retainedImageURLs = []
    }

    /// Drops one staged image, e.g. from a thumbnail's remove button.
    func unstageScreenshot(at index: Int) {
        guard pendingScreenshots.indices.contains(index) else { return }
        pendingScreenshots.remove(at: index)
    }

    func clearScreenshots() {
        pendingScreenshots = []
    }

    /// Ends the current follow-up sitting: retained images are dropped, and the
    /// next question goes through the metered chat path like any other message.
    /// Wired to the dismissible "following up on N images" chip.
    func clearRetainedImages() {
        retainedImageURLs = []
    }

    /// Sends the staged images for review. They are encoded inline and dropped
    /// — nothing is uploaded to storage. The encoded data URLs are retained in
    /// memory afterwards so a same-sitting follow-up question can reuse them
    /// without spending another daily review.
    func sendImages(userId: String) async {
        guard !isSending else { return }
        let images = pendingScreenshots
        guard !images.isEmpty else { return }

        guard let tier = currentTier else {
            error = "Unable to verify subscription tier"
            return
        }

        // Screenshot reviews have their own daily allowance — they no longer
        // spend the chat character budget.
        do {
            let limitCheck = try await rateLimitService.checkScreenshotLimit(
                userId: userId,
                userTier: tier
            )
            if !limitCheck.canSend {
                error = limitCheck.reason
                rateLimitWarning = limitCheck.reason
                return
            }
        } catch {
            print("Warning: Screenshot limit check failed: \(error)")
            // Continue with send - don't block user due to rate limit check failure
        }

        let caption = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        // The spinner goes up before the encode rather than after it: ten
        // screenshots take long enough that a still composer reads as a hang.
        // The composer's own contents are left exactly as the user arranged
        // them until the encode has succeeded, so a bad image costs nothing.
        isSending = true
        defer { isSending = false }

        // Encoded off the main actor — every `ScreenshotEncoder` member is
        // `nonisolated` for this, and Android does the same in
        // `Dispatchers.IO`. On the main actor this freezes the UI for the
        // length of the whole batch.
        let target = ScreenshotEncoder.targetDimension(imageCount: images.count)
        let dataURLs: [String]
        do {
            dataURLs = try await Task.detached(priority: .userInitiated) {
                try images.map { try ScreenshotEncoder.dataURL(from: $0, target: target) }
            }.value
        } catch {
            self.error = error.localizedDescription
            return
        }

        if let rejection = Self.payloadRejection(dataURLs) {
            self.error = rejection
            return
        }

        messageText = ""
        pendingScreenshots = []
        retainedImageURLs = dataURLs
        error = nil

        let placeholder = GardenerService.screenshotPlaceholder(
            caption: caption,
            imageCount: images.count
        )
        messages.append(
            GardenerMessage(
                id: UUID().uuidString,
                userId: userId,
                role: "user",
                content: placeholder,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        screenshotsUsedToday += 1
        do {
            try await rateLimitService.trackScreenshotReview(userId: userId)
        } catch {
            print("Warning: Failed to record screenshot review usage: \(error)")
        }

        do {
            let response = try await gardenerService.sendImages(
                userId: userId,
                imageDataURLs: dataURLs,
                caption: caption,
                // A fresh review is persisted as the camera placeholder.
                userTurn: placeholder,
                history: Array(messages.dropLast())
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

    /// A follow-up question about images already in hand this sitting. Sends
    /// the user's real text (not a placeholder) alongside the retained images,
    /// and deliberately calls neither `checkScreenshotLimit` nor
    /// `trackScreenshotReview` — this is a second question about one review,
    /// not a new one. The caller has already run it past `checkGardenerLimit`,
    /// so this still spends and tracks the chat character budget exactly as
    /// `sendMessage` would: the exemption is for the review, not the
    /// conversation that follows it.
    private func sendRetained(userId: String, retained: [String], text: String) async {
        isSending = true
        defer { isSending = false }
        messageText = ""
        error = nil

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
            let response = try await gardenerService.sendImages(
                userId: userId,
                imageDataURLs: retained,
                caption: text,
                // A follow-up is persisted as the plain question. Composing a
                // camera placeholder here would rewrite the user's own words on
                // reload and read back as another review for one that was
                // spent — and that transcript is what feeds the next window.
                userTurn: text,
                history: Array(messages.dropLast())
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
            try? await rateLimitService.trackGardenerConversation(
                userId: userId,
                characterCount: text.count
            )
        } catch {
            // Hand the text back and take the optimistic bubble down, so a
            // failed follow-up isn't a lost question. Matches Android's
            // send() and its sendRetained().
            messages.removeAll { $0.id == userMsg.id }
            messageText = text
            todayCharUsage = max(0, todayCharUsage - text.count)
            self.error = "I couldn't read that screenshot just now. Try sending it again."
        }
    }

    func sendMessage(userId: String) async {
        guard !isSending else { return }
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

        // A follow-up while images are still in hand goes back through the
        // image call so the Gardener can look again rather than guess — but
        // only after the character-limit check above, so the conversation that
        // follows a review is still metered like any other message. It is not a
        // new review though: trackScreenshotReview and checkScreenshotLimit are
        // deliberately not called for it.
        let retained = retainedImageURLs
        if !retained.isEmpty {
            await sendRetained(userId: userId, retained: retained, text: text)
            return
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

    /// Adopts a tier's allowances and reads today's usage back for both budgets.
    private func applyTierLimits(_ tier: SubscriptionTier, userId: String) async throws {
        currentTier = tier
        characterLimit = tier.gardenerCharacterLimit
        screenshotLimit = tier.gardenerScreenshotsPerDay
        imageCap = tier.gardenerImagesPerReview

        let limitCheck = try await rateLimitService.checkGardenerLimit(
            userId: userId,
            messageLength: 0,
            userTier: tier
        )
        todayCharUsage = max(0, limitCheck.characterLimit - limitCheck.remainingCharacters)
        screenshotsUsedToday = try await rateLimitService.screenshotsUsedToday(userId: userId)
    }

    private func loadTierLimits(userId: String) async {
        do {
            if let sub = try await subscriptionService.getUserSubscription(userId: userId) {
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let tier = tiers.first(where: { $0.id == sub.tierId }) {
                    try await applyTierLimits(tier, userId: userId)
                    return
                }
            } else {
                // No subscription - load seed tier
                let tiers = try await subscriptionService.getSubscriptionTiers()
                if let seedTier = tiers.first(where: { $0.name == .seed }) {
                    try await applyTierLimits(seedTier, userId: userId)
                    return
                }
            }
        } catch {
            print("Warning: Failed to load tier limits: \(error)")
        }

        // Offline fallback: the free tier's allowances, so the composer stays
        // usable rather than locking someone out on a failed lookup.
        let fallback = SubscriptionTier(
            id: "",
            name: .seed,
            displayName: "Seed",
            description: "",
            priceMonthly: 0,
            priceWeekly: 0,
            gardenerConversationsPerDay: nil,
            gardenerCharacterLimit: 2000,
            gardenerScreenshotsPerDay: 1,
            fieldFilterLevel: .none,
            hasDeepSoilInsights: false,
            hasGrowthFeatures: false,
            canDisableMindfulMessaging: false,
            sortOrder: 0
        )
        currentTier = fallback
        characterLimit = fallback.gardenerCharacterLimit
        screenshotLimit = fallback.gardenerScreenshotsPerDay
        imageCap = fallback.gardenerImagesPerReview
        todayCharUsage = 0
        screenshotsUsedToday = 0
    }
}
