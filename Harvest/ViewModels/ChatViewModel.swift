import Foundation
import Observation
import Realtime

@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var partnerProfile: UserProfile?
    var isLoading = false
    var messageText = "" {
        didSet {
            if !messageText.isEmpty {
                scheduleTypingIndicator()
            }
        }
    }
    var error: String?

    // Typing indicator
    var isPartnerTyping = false
    private var typingChannel: RealtimeChannelV2?
    private var typingDebounceTask: Task<Void, Never>?
    private var typingDismissTask: Task<Void, Never>?
    private var activeConversationId = ""
    private var activeUserId = ""
    private var activeMatchId = ""
    private var activePartnerUserId = ""

    // Mindful messaging
    var mindfulAnalysis: MindfulMessagingService.MindfulAnalysis?
    var showMindfulWarning = false
    private var pendingMessageText = ""
    private var pendingConversationId = ""
    private var pendingSenderId = ""

    // Safety
    var safetyAnalysis: SafetyAnalysis?
    var safetyWarning: String?
    var showReadyToMoveGate = false
    var isReadyToMove = false
    var readyToMoveReason: String?
    var readyToMoveActionMessage: String?
    var showReadyToMoveActionAlert = false

    // Report/Block/Unmatch
    var showReportSheet = false
    var showBlockAlert = false
    var showUnmatchAlert = false

    private let chatService = ChatService()
    private let profileService = ProfileService()
    private let mindfulService = MindfulMessagingService()
    private let safetyService = SafetyAnalysisService()
    private let matchService = MatchService()
    private var channel: RealtimeChannelV2?

    func loadMessages(conversationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await chatService.getMessages(conversationId: conversationId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPartnerProfile(userId: String) async {
        do {
            partnerProfile = try await profileService.getProfile(userId: userId)
        } catch {
            // Non-critical
        }
    }

    func loadSafetyAnalysis(matchId: String, userId: String, otherUserId: String) async {
        do {
            activeMatchId = matchId
            activeUserId = userId
            activePartnerUserId = otherUserId

            safetyAnalysis = try await safetyService.getOrCreateAnalysis(
                matchId: matchId,
                userId: userId,
                otherUserId: otherUserId
            )

            let hasPartnerHistory = messages.contains {
                !$0.isSentBy(userId) && !($0.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }

            if hasPartnerHistory, safetyAnalysis?.redFlagCount == 0, !activeConversationId.isEmpty {
                safetyAnalysis = try await safetyService.analyzeConversationHistory(
                    conversationId: activeConversationId,
                    matchId: matchId,
                    userId: userId,
                    otherUserId: otherUserId
                )
            }

            refreshSafetyWarning()
            await refreshReadyToMoveStatus()
        } catch {
            // Non-critical
        }
    }

    func sendMessage(conversationId: String, senderId: String) async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Mindful messaging check
        if mindfulService.isEnabled {
            let analysis = await mindfulService.analyzeMessage(text)
            if analysis.needsReview {
                mindfulAnalysis = analysis
                pendingMessageText = text
                pendingConversationId = conversationId
                pendingSenderId = senderId
                showMindfulWarning = true
                return
            }
        }

        await performSend(text: text, conversationId: conversationId, senderId: senderId)
    }

    func confirmSendDespiteWarning() async {
        showMindfulWarning = false
        mindfulAnalysis = nil
        await performSend(
            text: pendingMessageText,
            conversationId: pendingConversationId,
            senderId: pendingSenderId
        )
    }

    func dismissMindfulWarning() {
        showMindfulWarning = false
        mindfulAnalysis = nil
    }

    private func performSend(text: String, conversationId: String, senderId: String) async {
        messageText = ""

        do {
            if let message = try await chatService.sendMessage(
                conversationId: conversationId,
                senderId: senderId,
                content: text
            ) {
                // Only add if not already added by realtime
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
        } catch {
            self.error = error.localizedDescription
            messageText = text // Restore on failure
        }
    }

    func subscribeToRealtime(conversationId: String) {
        channel = chatService.subscribeToMessages(conversationId: conversationId) { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                }
                await self.analyzeMessageForSafetyIfNeeded(message)
            }
        }
    }

    func subscribeToTyping(conversationId: String, currentUserId: String) {
        activeConversationId = conversationId
        activeUserId = currentUserId
        typingChannel = chatService.subscribeToTyping(conversationId: conversationId) { [weak self] userId in
            Task { @MainActor [weak self] in
                guard let self, userId != currentUserId else { return }
                self.isPartnerTyping = true
                self.typingDismissTask?.cancel()
                self.typingDismissTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    self.isPartnerTyping = false
                }
            }
        }
    }

    private func scheduleTypingIndicator() {
        typingDebounceTask?.cancel()
        typingDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if !activeConversationId.isEmpty, !activeUserId.isEmpty {
                await chatService.sendTypingIndicator(
                    conversationId: activeConversationId,
                    userId: activeUserId
                )
            }
        }
    }

    func markMessagesAsRead(currentUserId: String) async {
        let unreadMessages = messages.filter { !$0.isRead && !$0.isSentBy(currentUserId) }
        for message in unreadMessages {
            do {
                try await chatService.markAsRead(messageId: message.id)
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[index].isRead = true
                }
            } catch {
                // Non-critical
            }
        }
    }

    func unsubscribe() {
        if let channel {
            chatService.unsubscribe(channel: channel)
        }
        channel = nil
        if let typingChannel {
            chatService.unsubscribe(channel: typingChannel)
        }
        typingChannel = nil
        typingDebounceTask?.cancel()
        typingDismissTask?.cancel()
        activeMatchId = ""
        activePartnerUserId = ""
    }

    func ensureConversation(matchId: String, user1Id: String, user2Id: String) async -> String? {
        do {
            return try await chatService.ensureConversation(
                matchId: matchId,
                user1Id: user1Id,
                user2Id: user2Id
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Report/Block/Unmatch

    func reportUser(reporterId: String, reportedUserId: String, category: String, description: String) async {
        do {
            try await matchService.reportUser(
                reporterId: reporterId,
                reportedUserId: reportedUserId,
                category: category,
                description: description
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func blockUser(userId: String, blockedUserId: String) async -> Bool {
        do {
            try await matchService.blockUser(userId: userId, blockedUserId: blockedUserId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unmatchUser(matchId: String) async -> Bool {
        do {
            try await matchService.unmatchUser(matchId: matchId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Retroactive Safety Analysis

    func runRetroactiveSafetyAnalysis(conversationId: String, matchId: String, userId: String, otherUserId: String) async {
        do {
            let analysis = try await safetyService.analyzeConversationHistory(
                conversationId: conversationId,
                matchId: matchId,
                userId: userId,
                otherUserId: otherUserId
            )
            safetyAnalysis = analysis
            refreshSafetyWarning()
            await refreshReadyToMoveStatus()
            print("Retroactive analysis complete. Safety score: \(analysis.safetyScore), Red flags: \(analysis.redFlagCount)")
        } catch {
            print("Error running retroactive safety analysis: \(error)")
            self.error = "Failed to analyze conversation history"
        }
    }

    @MainActor
    private func analyzeMessageForSafetyIfNeeded(_ message: Message) async {
        guard
            let analysis = safetyAnalysis,
            !activeMatchId.isEmpty,
            !activeUserId.isEmpty,
            !activePartnerUserId.isEmpty,
            !message.isSentBy(activeUserId),
            let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
            !content.isEmpty
        else {
            return
        }

        do {
            _ = try await safetyService.analyzeMessage(content, analysisId: analysis.id)
            safetyAnalysis = try await safetyService.getOrCreateAnalysis(
                matchId: activeMatchId,
                userId: activeUserId,
                otherUserId: activePartnerUserId
            )
            refreshSafetyWarning()
            await refreshReadyToMoveStatus()
        } catch {
            print("Warning: Failed to analyze message for safety: \(error)")
        }
    }

    func presentReadyToMoveGate() async {
        await refreshReadyToMoveStatus()
        showReadyToMoveGate = true
    }

    func markPreferredContactShared() async {
        guard isReadyToMove, let analysis = safetyAnalysis else { return }

        do {
            try await safetyService.recordReadyToMoveDecision(
                analysisId: analysis.id,
                userId: activeUserId,
                approved: true,
                contactShared: true,
                contactMethod: "social"
            )
            readyToMoveActionMessage = "You're clear to share your preferred contact details in the chat."
            showReadyToMoveActionAlert = true
            showReadyToMoveGate = false
        } catch {
            readyToMoveActionMessage = "We couldn't record your sharing action. Please try again."
            showReadyToMoveActionAlert = true
        }
    }

    private func refreshSafetyWarning() {
        if let score = safetyAnalysis?.safetyScore, score < 50 {
            safetyWarning = "Safety concern detected. Be cautious in this conversation."
        } else {
            safetyWarning = nil
        }
    }

    private func refreshReadyToMoveStatus() async {
        guard var analysis = safetyAnalysis else {
            isReadyToMove = false
            readyToMoveReason = "No safety analysis available yet."
            return
        }

        do {
            if !activeMatchId.isEmpty, !activeUserId.isEmpty, !activePartnerUserId.isEmpty {
                analysis = try await safetyService.getOrCreateAnalysis(
                    matchId: activeMatchId,
                    userId: activeUserId,
                    otherUserId: activePartnerUserId
                )
                safetyAnalysis = analysis
            }

            let result = try await safetyService.isReadyToMove(analysisId: analysis.id)
            isReadyToMove = result.ready
            readyToMoveReason = result.reason
        } catch {
            isReadyToMove = false
            readyToMoveReason = "Couldn't determine whether this conversation is ready yet."
        }
    }
}

