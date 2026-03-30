import SwiftUI

struct SettingsView: View {
    let authViewModel: AuthViewModel

    @State private var notificationsEnabled = true
    @State private var matchNotifications = true
    @State private var messageNotifications = true
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showDeleteErrorAlert = false
    @State private var subscriptionViewModel = SubscriptionViewModel()
    @State private var mindfulMessagingEnabled = MindfulMessagingService().isEnabled
    @State private var deleteErrorMessage = ""

    // Privacy toggles
    @State private var showLocation = UserDefaults.standard.object(forKey: "showLocation") as? Bool ?? true
    @State private var showAge = UserDefaults.standard.object(forKey: "showAge") as? Bool ?? true
    @State private var showActiveStatus = UserDefaults.standard.object(forKey: "showActiveStatus") as? Bool ?? true

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authViewModel.profile?.email ?? "")
                        .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
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
                Toggle("Show Location", isOn: $showLocation)
                    .tint(HarvestTheme.Colors.primary)
                    .onChange(of: showLocation) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showLocation")
                    }

                Toggle("Show Age", isOn: $showAge)
                    .tint(HarvestTheme.Colors.primary)
                    .onChange(of: showAge) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showAge")
                    }

                Toggle("Show Active Status", isOn: $showActiveStatus)
                    .tint(HarvestTheme.Colors.primary)
                    .onChange(of: showActiveStatus) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showActiveStatus")
                    }
            }

            Section("Legal") {
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
                        .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)
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

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Account")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.white.ignoresSafeArea())
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
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    if let userId = authViewModel.currentUserId {
                        let authService = AuthService()
                        do {
                            try await authService.deleteAccount(userId: userId)
                            await authViewModel.logout()
                        } catch {
                            deleteErrorMessage = error.localizedDescription
                            showDeleteErrorAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("This will permanently delete your account, profile, matches, and all messages. This action cannot be undone.")
        }
        .alert("Account Deletion Failed", isPresented: $showDeleteErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .listSectionSpacing(20)
        .listStyle(.insetGrouped)
    }
}
