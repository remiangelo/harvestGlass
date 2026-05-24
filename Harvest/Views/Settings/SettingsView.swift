import SwiftUI
import UserNotifications
import Supabase

struct SettingsView: View {
    let authViewModel: AuthViewModel

    @State private var profile: UserProfile?
    @State private var savingError: String?
    @State private var osNotificationsEnabled: Bool = true

    private let profileService = ProfileService()

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
                SectionHeader(title: "Account")
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

                SectionHeader(title: "Notifications")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        toggleRow(
                            "Enable Notifications",
                            isOn: Binding(
                                get: { osNotificationsEnabled },
                                set: { handleMasterToggle($0) }
                            )
                        )
                        if osNotificationsEnabled {
                            dividerRow()
                            toggleRow(
                                "New Matches",
                                isOn: prefBinding(\.notifMatchesEnabled, column: "notif_matches_enabled")
                            )
                            dividerRow()
                            toggleRow(
                                "Messages",
                                isOn: prefBinding(\.notifMessagesEnabled, column: "notif_messages_enabled")
                            )
                            dividerRow()
                            toggleRow(
                                "Inbound Likes (Gold)",
                                isOn: prefBinding(\.notifLikesEnabled, column: "notif_likes_enabled")
                            )
                            dividerRow()
                            toggleRow(
                                "Gardener Daily Reminder",
                                isOn: Binding(
                                    get: { profile?.notifGardenerLocalEnabled ?? true },
                                    set: { newValue in
                                        updateBoolPref(\.notifGardenerLocalEnabled, to: newValue, column: "notif_gardener_local_enabled")
                                        Task {
                                            await NotificationService.shared.scheduleGardenerLocalNotification(
                                                hour: profile?.notifGardenerLocalHour ?? 9,
                                                enabled: newValue
                                            )
                                        }
                                    }
                                )
                            )
                            if profile?.notifGardenerLocalEnabled ?? true {
                                dividerRow()
                                HStack {
                                    Text("Gardener time")
                                        .font(HarvestTheme.Typography.bodyRegular)
                                    Spacer()
                                    Picker("", selection: gardenerHourBinding) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(formatHour(h)).tag(h)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.vertical, HarvestTheme.Spacing.sm)
                            }
                        }
                        if let error = savingError {
                            Text(error)
                                .font(HarvestTheme.Typography.caption)
                                .foregroundStyle(HarvestTheme.Colors.warning)
                                .padding(.horizontal, HarvestTheme.Spacing.md)
                                .padding(.bottom, HarvestTheme.Spacing.sm)
                        }
                    }
                }

                SectionHeader(title: "Privacy")
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

                SectionHeader(title: "Legal")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        navRow("Privacy Policy") { PrivacyPolicyView() }
                        dividerRow()
                        navRow("Terms of Service") { TermsOfServiceView() }
                        dividerRow()
                        navRow("Community Guidelines") { CommunityGuidelinesView() }
                    }
                }

                SectionHeader(title: "Safety")
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

                SectionHeader(title: "Support")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        navRow("Help Center") { HelpCenterView(authViewModel: authViewModel) }
                        dividerRow()
                        row(title: "Version", trailing: "1.0.0")
                    }
                }

                GlassCard(style: .light) {
                    VStack(spacing: 0) {
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

                        dividerRow()

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
            }
            .padding()
            .padding(.top, HarvestTheme.Spacing.sm)
        }
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = authViewModel.currentUserId {
                await subscriptionViewModel.loadSubscriptionData(userId: userId)
            }
            await loadProfile()
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

    private func loadProfile() async {
        guard let userId = authViewModel.currentUserId else { return }
        profile = try? await profileService.getProfile(userId: userId)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        osNotificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    private func handleMasterToggle(_ newValue: Bool) {
        if newValue {
            Task {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()
                if settings.authorizationStatus == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                    return
                }
                await NotificationService.shared.requestPermissionAndRegister()
                let after = await center.notificationSettings()
                osNotificationsEnabled = after.authorizationStatus == .authorized
                    || after.authorizationStatus == .provisional
            }
        } else {
            Task {
                if let userId = authViewModel.currentUserId {
                    await NotificationService.shared.unregisterCurrentDevice(userId: userId)
                }
                await NotificationService.shared.scheduleGardenerLocalNotification(
                    hour: profile?.notifGardenerLocalHour ?? 9,
                    enabled: false
                )
                osNotificationsEnabled = false
            }
        }
    }

    private func prefBinding(
        _ keyPath: WritableKeyPath<UserProfile, Bool?>,
        column: String
    ) -> Binding<Bool> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? true },
            set: { newValue in updateBoolPref(keyPath, to: newValue, column: column) }
        )
    }

    private var gardenerHourBinding: Binding<Int> {
        Binding(
            get: { profile?.notifGardenerLocalHour ?? 9 },
            set: { newValue in
                updateIntPref(\.notifGardenerLocalHour, to: newValue, column: "notif_gardener_local_hour")
                Task {
                    await NotificationService.shared.scheduleGardenerLocalNotification(
                        hour: newValue,
                        enabled: profile?.notifGardenerLocalEnabled ?? true
                    )
                }
            }
        )
    }

    private func updateBoolPref(
        _ keyPath: WritableKeyPath<UserProfile, Bool?>,
        to newValue: Bool,
        column: String
    ) {
        guard let userId = authViewModel.currentUserId else { return }
        let previous = profile
        profile?[keyPath: keyPath] = newValue
        Task {
            do {
                _ = try await profileService.updateProfile(
                    userId: userId,
                    updates: [column: .bool(newValue)]
                )
                savingError = nil
            } catch {
                profile = previous
                savingError = error.localizedDescription
            }
        }
    }

    private func updateIntPref(
        _ keyPath: WritableKeyPath<UserProfile, Int?>,
        to newValue: Int,
        column: String
    ) {
        guard let userId = authViewModel.currentUserId else { return }
        let previous = profile
        profile?[keyPath: keyPath] = newValue
        Task {
            do {
                _ = try await profileService.updateProfile(
                    userId: userId,
                    updates: [column: .double(Double(newValue))]
                )
                savingError = nil
            } catch {
                profile = previous
                savingError = error.localizedDescription
            }
        }
    }

    private func formatHour(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h; c.minute = 0
        let cal = Calendar.current
        let date = cal.date(from: c) ?? Date()
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
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
            .padding(.vertical, HarvestTheme.Spacing.sm)
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
