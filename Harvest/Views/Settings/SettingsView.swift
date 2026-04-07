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

    @State private var showLocation = UserDefaults.standard.object(forKey: "showLocation") as? Bool ?? true
    @State private var showAge = UserDefaults.standard.object(forKey: "showAge") as? Bool ?? true
    @State private var showActiveStatus = UserDefaults.standard.object(forKey: "showActiveStatus") as? Bool ?? true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                sectionTitle("Account")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        row(title: "Email", trailing: authViewModel.profile?.email ?? "")
                        dividerRow()
                        NavigationLink {
                            SubscriptionView(authViewModel: authViewModel)
                        } label: {
                            HStack {
                                Text("Subscription")
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                Spacer()
                                GlassBadge(text: subscriptionViewModel.currentTierName, color: HarvestTheme.Colors.accent)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionTitle("Notifications")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        toggleRow("Enable Notifications", isOn: $notificationsEnabled)
                        if notificationsEnabled {
                            dividerRow()
                            toggleRow("New Matches", isOn: $matchNotifications)
                            dividerRow()
                            toggleRow("Messages", isOn: $messageNotifications)
                        }
                    }
                }

                sectionTitle("Privacy")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        toggleRow("Show Location", isOn: $showLocation)
                            .onChange(of: showLocation) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "showLocation")
                            }
                        dividerRow()
                        toggleRow("Show Age", isOn: $showAge)
                            .onChange(of: showAge) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "showAge")
                            }
                        dividerRow()
                        toggleRow("Show Active Status", isOn: $showActiveStatus)
                            .onChange(of: showActiveStatus) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "showActiveStatus")
                            }
                    }
                }

                sectionTitle("Legal")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        navRow("Privacy Policy") { PrivacyPolicyView() }
                        dividerRow()
                        navRow("Terms of Service") { TermsOfServiceView() }
                        dividerRow()
                        navRow("Community Guidelines") { CommunityGuidelinesView() }
                    }
                }

                sectionTitle("Safety")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        navRow("Safety Dashboard") { SafetyDashboardView(authViewModel: authViewModel) }
                        dividerRow()
                        toggleRow("Mindful Messaging", isOn: $mindfulMessagingEnabled)
                            .onChange(of: mindfulMessagingEnabled) { _, newValue in
                                MindfulMessagingService().setEnabled(newValue)
                            }
                    }
                }

                sectionTitle("Support")
                GlassCard(style: .light) {
                    navRow("Help Center") { HelpCenterView(authViewModel: authViewModel) }
                }

                sectionTitle("About")
                GlassCard(style: .light) {
                    row(title: "Version", trailing: "1.0.0")
                }

                GlassCard(style: .light) {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .fontWeight(.semibold)
                                .foregroundStyle(HarvestTheme.Colors.formAccent)
                            Spacer()
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }

                GlassCard(style: .light) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .fontWeight(.semibold)
                                .foregroundStyle(HarvestTheme.Colors.formAccent)
                            Spacer()
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
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
                Task { await authViewModel.logout() }
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
        .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
    }

    private func dividerRow() -> some View {
        Divider().overlay(HarvestTheme.Colors.formBorder)
    }

    private func row(title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            Spacer()
            Text(trailing)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(HarvestTheme.Colors.formAccent)
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .padding(.vertical, HarvestTheme.Spacing.xs)
    }

    private func navRow<Destination: View>(_ title: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Text(title)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
            .padding(.vertical, HarvestTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}
