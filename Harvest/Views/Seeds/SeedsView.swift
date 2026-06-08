// Harvest/Views/Seeds/SeedsView.swift
import SwiftUI

struct SeedsView: View {
    let authViewModel: AuthViewModel
    @Binding var pendingChatDeepLink: String?

    var body: some View {
        // Phase 2 replaces this body with the Requests / Conversations segments.
        MindfulMessagesView(
            authViewModel: authViewModel,
            pendingChatDeepLink: $pendingChatDeepLink
        )
    }
}
