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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plant a Seed with \(recipientName) 🌱")
                    .font(.headline)
                Text("Start with something intentional — a question or a shared value.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                Text("\(sentToday) of \(limit) Seeds sent today")
                    .font(.caption)
                    .foregroundStyle(sentToday >= limit ? .red : .secondary)
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
                Spacer()
            }
            .padding()
            .navigationTitle("Send a Seed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || sentToday >= limit)
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
