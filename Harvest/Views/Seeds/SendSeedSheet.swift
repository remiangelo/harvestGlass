import SwiftUI

struct SendSeedSheet: View {
    let authViewModel: AuthViewModel
    let recipientId: String
    let recipientName: String
    var onSent: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var isSending = false
    @State private var error: String?
    @State private var sentToday = 0
    @State private var limit = 3

    private let service = SeedService()
    private let subscriptionService = SubscriptionService()

    private var atLimit: Bool { sentToday >= limit }
    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !atLimit
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Plant a Seed with \(recipientName) 🌱")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                    Text("Start with something intentional — a question or a shared value.")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)

                    GlassCard {
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    }

                    HStack(spacing: HarvestTheme.Spacing.xs) {
                        Image(systemName: "leaf.fill")
                        Text("\(sentToday) of \(limit) Seeds sent today")
                    }
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(atLimit ? HarvestTheme.Colors.error : HarvestTheme.Colors.textSecondary)

                    if let error {
                        Text(error)
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.error)
                    }
                }
                .padding(HarvestTheme.Spacing.md)
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Send a Seed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(!canSend)
                        .fontWeight(.semibold)
                }
            }
            .task {
                guard let userId = authViewModel.currentUserId else { return }
                async let fetchedLimit = subscriptionService.getDailySeedLimit(userId: userId)
                async let fetchedCount = (try? service.sentTodayCount(userId: userId)) ?? 0
                limit = await fetchedLimit
                sentToday = await fetchedCount
            }
        }
    }

    private func send() async {
        guard let senderId = authViewModel.currentUserId else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await service.sendSeed(
                senderId: senderId,
                recipientId: recipientId,
                openingMessage: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSent()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
