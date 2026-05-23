import Foundation
import UIKit
import UserNotifications
import Supabase

@MainActor
final class NotificationService: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var currentUserId: String? {
        supabase.auth.currentUser?.id.uuidString
    }
    private var lastPersistedToken: String?

    private override init() {
        super.init()
    }

    // MARK: - Permission + registration

    /// Idempotent. Checks the current `UNNotificationSettings.authorizationStatus`:
    ///   - .notDetermined → request authorization; on grant, register for remote notifications.
    ///   - .authorized / .provisional → register for remote notifications
    ///     (refreshes the device token without re-prompting).
    ///   - .denied → no-op; SettingsView is responsible for linking to iOS Settings.
    /// Safe to call on every sign-in.
    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("NotificationService: requestAuthorization failed: \(error)")
            }
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .denied:
            return
        @unknown default:
            return
        }
    }

    // MARK: - Token persistence

    /// Called from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    /// Upserts (user_id, apns_token) into user_devices.
    /// De-duplicates by remembering the last token persisted in this app session.
    func persistDeviceToken(_ token: String) async {
        guard let userId = currentUserId else {
            // Not signed in — token can't be associated; retry happens on next sign-in.
            return
        }
        if token == lastPersistedToken {
            return
        }

        do {
            try await supabase
                .from("user_devices")
                .upsert([
                    "user_id": userId,
                    "apns_token": token,
                    "platform": "ios",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id,apns_token")
                .execute()
            lastPersistedToken = token
        } catch {
            print("NotificationService: persistDeviceToken failed: \(error)")
        }
    }

    /// Called from AuthViewModel.logout() BEFORE the session is cleared.
    /// Deletes this device's token row for the given user and unregisters
    /// from APNs.
    func unregisterCurrentDevice(userId: String) async {
        guard let token = lastPersistedToken else {
            UIApplication.shared.unregisterForRemoteNotifications()
            return
        }
        do {
            try await supabase
                .from("user_devices")
                .delete()
                .eq("user_id", value: userId)
                .eq("apns_token", value: token)
                .execute()
        } catch {
            print("NotificationService: unregisterCurrentDevice failed: \(error)")
        }
        lastPersistedToken = nil
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    // MARK: - Local Gardener notification

    private let gardenerIdentifier = "gardener-daily"

    /// Schedules a repeating daily UNCalendarNotificationTrigger at the given local hour.
    /// If `enabled` is false, removes the pending request.
    func scheduleGardenerLocalNotification(hour: Int, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [gardenerIdentifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your Gardener"
        content.body = "Your daily reflection is ready 🌿"
        content.sound = .default
        content.userInfo = ["deepLink": "gardener"]

        var components = DateComponents()
        components.hour = max(0, min(23, hour))
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: gardenerIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("NotificationService: scheduleGardenerLocalNotification failed: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner + sound even when foregrounded.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle tap by posting Notification.Name.harvestDeepLink with the deepLink string.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let deepLink = response.notification.request.content.userInfo["deepLink"] as? String {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .harvestDeepLink,
                    object: nil,
                    userInfo: ["deepLink": deepLink]
                )
            }
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let harvestDeepLink = Notification.Name("harvestDeepLink")
}
