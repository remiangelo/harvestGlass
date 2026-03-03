import SwiftUI

struct SettingsView: View {
    let authViewModel: AuthViewModel

    @State private var notificationsEnabled = true
    @State private var matchNotifications = true
    @State private var messageNotifications = true
    @State private var showLogoutAlert = false
    @State private var subscriptionViewModel = SubscriptionViewModel()
    @State private var mindfulMessagingEnabled = MindfulMessagingService().isEnabled

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authViewModel.profile?.email ?? "")
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }

                NavigationLink {
                    SubscriptionView(authViewModel: authViewModel)
                } label: {
                    HStack {
                        Text("Subscription")
                        Spacer()
                        GlassBadge(text: subscriptionViewModel.currentTierName)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .tint(HarvestTheme.Colors.primary)

                if notificationsEnabled {
                    Toggle("New Matches", isOn: $matchNotifications)
                        .tint(HarvestTheme.Colors.primary)

                    Toggle("Messages", isOn: $messageNotifications)
                        .tint(HarvestTheme.Colors.primary)
                }
            }

            Section("Privacy") {
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }

                NavigationLink("Terms of Service") {
                    TermsOfServiceView()
                }

                NavigationLink("Community Guidelines") {
                    CommunityGuidelinesView()
                }
            }

            Section("Safety") {
                NavigationLink("Safety Dashboard") {
                    SafetyDashboardView(authViewModel: authViewModel)
                }

                Toggle("Mindful Messaging", isOn: $mindfulMessagingEnabled)
                    .tint(HarvestTheme.Colors.primary)
                    .onChange(of: mindfulMessagingEnabled) { _, newValue in
                        MindfulMessagingService().setEnabled(newValue)
                    }
            }

            Section("Support") {
                NavigationLink("Help Center") {
                    HelpCenterView(authViewModel: authViewModel)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Log Out")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = authViewModel.currentUserId {
                await subscriptionViewModel.loadSubscriptionData(userId: userId)
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task {
                    await authViewModel.logout()
                }
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}
