# Push Notifications — Design

**Date:** 2026-05-24
**Goal:** Deliver four kinds of notifications to the Harvest iOS app: new messages, new matches, inbound likes (Gold-tier), and a daily Gardener reflection reminder. Three are APNs pushes triggered from Supabase via Postgres triggers; the daily reminder is a local notification scheduled on-device. Settings toggles, currently UI placeholders, become real user preferences stored in `users`.

## 1. Scope

In:
- iOS Push Notifications + Background Modes capabilities; `aps-environment = production`.
- New `Harvest/AppDelegate.swift` + `Harvest/Services/NotificationService.swift`.
- Permission prompt after onboarding completes.
- DB tables / columns: `user_devices`, `users.notif_*`.
- Postgres triggers on `messages`, `matches`, `swipes`.
- New Supabase Edge Function `send-push` calling APNs HTTP/2 with a `.p8` auth key.
- Local notification for daily Gardener reminder.
- Wiring the existing `SettingsView` toggles to the new preference columns.

Out:
- Android / FCM.
- Notification action buttons ("Reply", "Mark read").
- Silent background pushes for unread-count sync.
- Rich-media notifications.
- Quiet hours, digests, weekly summaries.
- Retry queue for failed APNs sends.
- Notification analytics.

## 2. Data Model

### 2.1 `user_devices` table

```sql
create table user_devices (
  user_id     uuid not null references users(id) on delete cascade,
  apns_token  text not null,
  platform    text not null default 'ios' check (platform in ('ios')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  primary key (user_id, apns_token)
);

alter table user_devices enable row level security;
create policy "devices_self_rw" on user_devices
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

- One user can have multiple devices (iPad + iPhone).
- A single physical device only stores one row per signed-in user; if user A signs out and user B signs in on the same device, A's row is deleted and B's is upserted.
- APNs token rotation: app calls `persistDeviceToken` on every cold launch, which upserts and updates `updated_at`. Stale tokens are eventually deleted by the Edge Function when APNs returns 410.

### 2.2 `users` notification preference columns

```sql
alter table users
  add column notif_messages_enabled        boolean default true,
  add column notif_matches_enabled         boolean default true,
  add column notif_likes_enabled           boolean default true,
  add column notif_gardener_local_enabled  boolean default true,
  add column notif_gardener_local_hour     int default 9 check (notif_gardener_local_hour between 0 and 23);
```

Defaults are `true` so that a user who grants iOS permission gets all four notification types unless they explicitly opt out in Settings. `notif_gardener_local_*` columns control on-device scheduling; the backend never reads them. The other three are read by the DB triggers to gate `send-push` calls.

### 2.3 `UserProfile.swift` additions

```swift
var notifMessagesEnabled: Bool?
var notifMatchesEnabled: Bool?
var notifLikesEnabled: Bool?
var notifGardenerLocalEnabled: Bool?
var notifGardenerLocalHour: Int?
```

CodingKeys map straight from `notif_messages_enabled` etc. Reads use `?? true` defaults so older rows behave as fully opted-in.

`ProfileService` select projection and upsert payload include the new fields.

## 3. Edge Function `send-push`

### 3.1 Location and trigger

`supabase/functions/send-push/index.ts` (new directory under the existing `supabase/functions/` tree).

Not user-facing. Called only from DB triggers via `pg_net.http_post`. Authentication: the trigger sends a `service_role` JWT in the `Authorization` header; the function verifies it on entry.

### 3.2 Input contract

```ts
type SendPushRequest = {
  recipient_user_id: string;          // uuid
  type: 'message' | 'match' | 'like';
  payload: {
    title: string;
    body: string;
    deepLink: string;                 // "chat:<id>" | "match:<id>" | "likes"
    threadId?: string;                // for iOS collapsing; for messages this is conversation_id
    badgeCount?: number;
  };
};
```

### 3.3 APNs request shape

For each `user_devices` row matching `recipient_user_id`:

```
POST https://api.push.apple.com/3/device/<apns_token>
Authorization: bearer <ES256 JWT signed with .p8>
apns-topic: <APNS_BUNDLE_ID>
apns-push-type: alert
apns-priority: 10
apns-collapse-id: <threadId or "<type>:<recipient_user_id>">
content-type: application/json

{
  "aps": {
    "alert": { "title": payload.title, "body": payload.body },
    "thread-id": payload.threadId,
    "badge": payload.badgeCount,
    "sound": "default"
  },
  "deepLink": payload.deepLink
}
```

### 3.4 JWT signing

ES256 with the `.p8` private key. Header `{ alg: "ES256", kid: APNS_KEY_ID }`. Claims `{ iss: APNS_TEAM_ID, iat: now }`. JWT is cached in memory inside the Edge Function for up to 50 minutes (APNs requires re-issuing at least every 60 minutes). Cold-start cost is one ES256 sign; subsequent invocations within the warm window reuse the same JWT.

Implementation uses Web Crypto API (`crypto.subtle.importKey` with PKCS#8 PEM, `crypto.subtle.sign` with ECDSA + SHA-256) — no external npm dependencies needed.

### 3.5 Response handling

Per APNs response status for a token:

| Status | Action |
|---|---|
| 200 | Success; log nothing |
| 400 with `BadDeviceToken` | `delete from user_devices where apns_token = ?` |
| 410 (Unregistered) | Same as 400 BadDeviceToken |
| 429 / 5xx | Log and move on; no retry queue in v1 |
| 403 (auth) | Log loudly — secrets are misconfigured |

The function never returns errors to the caller (the DB trigger). Failures are silent from the trigger's POV.

### 3.6 Secrets required (Supabase Dashboard → Edge Functions → Secrets)

| Secret | Source |
|---|---|
| `APNS_KEY_ID` | Apple Developer → Keys → the 10-char Key ID |
| `APNS_TEAM_ID` | Apple Developer → top-right of portal |
| `APNS_BUNDLE_ID` | `HarvestGlass.Harvest` (`PRODUCT_BUNDLE_IDENTIFIER` from `project.pbxproj`) |
| `APNS_AUTH_KEY` | Full contents of the `.p8` file with `-----BEGIN PRIVATE KEY-----` and newlines preserved |
| `APNS_ENVIRONMENT` | `production` |

## 4. Postgres Triggers

All three triggers use `pg_net.http_post` to invoke `send-push`. `pg_net` extension must be enabled on the project.

### 4.1 `messages_after_insert`

After insert on `messages`. Looks up the conversation's two participants from the existing `conversations` table; if the recipient is different from `NEW.sender_id` AND the recipient's `notif_messages_enabled` is true, calls `send-push` with:
- `title = sender.nickname`
- `body = substr(NEW.content, 0, 80)` (truncated; future "hide preview" toggle is out of scope)
- `deepLink = 'chat:' || NEW.conversation_id`
- `threadId = NEW.conversation_id`
- `badgeCount` — best-effort count of conversations with at least one unread message addressed to the recipient. The exact query depends on how read state is tracked in the existing `conversations` / `messages` tables (the spec doesn't fix the column names because they're not verified yet). The implementation plan reads the live schema and either writes the right `select count(...)` or falls back to omitting the badge field (APNs leaves the current badge unchanged).

If the message is an image-only message (text is empty / null), body is `"Sent you a photo"`.

### 4.2 `matches_after_insert`

After insert on `matches`. Calls `send-push` twice — once for `user1_id`, once for `user2_id`. Each call gated on that user's `notif_matches_enabled`. Body is `"You matched with " || other.nickname || " 🌱"`. `deepLink = 'match:' || NEW.id`. No threadId.

### 4.3 `swipes_after_insert_like`

After insert on `swipes` where `NEW.action in ('like','super_like')`. Looks up the target user's `subscription_tier`. If `tier = 'gold'` (or whatever the Gold identifier is in this schema) AND `notif_likes_enabled` is true, calls `send-push` with:
- `title = "Harvest"`
- `body = "Someone likes you"` (deliberately no name or photo, consistent with the Gold-tier reveal-gate)
- `deepLink = 'likes'`
- `threadId = "likes:" || target_user_id` (so multiple inbound likes collapse into one banner)

If the target is not Gold, no push is sent — the inbound-likes screen behind the existing paywall is the only way to learn.

### 4.4 Trigger implementation note

`pg_net.http_post` is fire-and-forget from the trigger's perspective. Triggers must not block the insert. If `pg_net` is misconfigured the message/match/like still succeeds; only the notification is lost.

The triggers run in a `SECURITY DEFINER` function so they can read `users.notif_*` regardless of the inserting user's RLS context.

## 5. iOS Application

### 5.1 New `Harvest/AppDelegate.swift`

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await NotificationService.shared.persistDeviceToken(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
    }
}
```

### 5.2 `HarvestApp.swift` changes

```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
```

In the existing `.task`:
```swift
UNUserNotificationCenter.current().delegate = NotificationService.shared
```

### 5.3 New `Harvest/Services/NotificationService.swift`

A singleton conforming to `NSObject, UNUserNotificationCenterDelegate`. Public surface:

```swift
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    /// Idempotent. Checks the current `UNNotificationSettings.authorizationStatus`:
    ///   - `.notDetermined` → request authorization; on grant, register for
    ///     remote notifications.
    ///   - `.authorized` / `.provisional` → register for remote notifications
    ///     (refreshes the device token without re-prompting).
    ///   - `.denied` → no-op; SettingsView is responsible for linking to
    ///     iOS Settings.
    /// Safe to call on every sign-in.
    func requestPermissionAndRegister(userId: String) async

    /// Called from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    /// Upserts (user_id, apns_token) into user_devices.
    func persistDeviceToken(_ token: String) async

    /// Called from AuthViewModel.logout before the session is cleared.
    /// Deletes this device's token row for the given user and calls
    /// UIApplication.shared.unregisterForRemoteNotifications().
    func unregisterCurrentDevice(userId: String) async

    /// Schedules the daily Gardener UNCalendarNotificationTrigger at the given
    /// local hour. If enabled is false, removes the pending request with
    /// identifier "gardener-daily".
    func scheduleGardenerLocalNotification(hour: Int, enabled: Bool) async

    /// UNUserNotificationCenterDelegate — show banner + sound even when
    /// foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                  @escaping (UNNotificationPresentationOptions) -> Void)

    /// UNUserNotificationCenterDelegate — handle tap by posting a
    /// Notification.Name.harvestDeepLink with userInfo["deepLink"].
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
                                  @escaping () -> Void)
}

extension Notification.Name {
    static let harvestDeepLink = Notification.Name("harvestDeepLink")
}
```

Internal helpers:
- A `private var lastPersistedToken: String?` to avoid redundant upserts when the OS hands back the same token on every cold launch.
- A `private let supabase: SupabaseClient { SupabaseManager.shared.client }` accessor.

### 5.4 Permission prompt — `CompleteView.swift` and re-entry

The post-onboarding "you're set up" screen (`Harvest/Views/Onboarding/CompleteView.swift`) currently signals onboarding done. Add a small "Stay in the loop" card immediately above its existing CTA:

- Body text: "We'll let you know about new matches, messages, and likes — and a gentle daily reflection from your Gardener."
- "Turn on notifications" button that calls `requestPermissionAndRegister`, then `scheduleGardenerLocalNotification(hour: 9, enabled: true)` if permission was granted. Default Gardener hour is 9 (local time); user can change in Settings.
- A "Maybe later" text button that dismisses the card without prompting. UserDefaults stores `notifications_prompted_at_onboarding` so we don't re-show this card on subsequent visits to the screen.

If the user previously denied notification permission, the "Turn on" button instead opens iOS Settings via `UIApplication.openSettingsURLString` and shows a brief explainer ("Open Settings → Harvest → Notifications").

### 5.5 `SettingsView` — wire toggles to preferences

The three existing local `@State` toggles get replaced with bindings into a new `SettingsViewModel` that owns:
- `profile: UserProfile?` — fetched on appear via `ProfileService.getProfile`.
- `setPreference(_ key: NotificationPrefKey, isOn: Bool) async` — optimistic write to `users.notif_*` via `ProfileService.updateProfile`, revert on failure.
- `setGardenerHour(_ hour: Int) async` — same pattern, plus re-call `NotificationService.shared.scheduleGardenerLocalNotification`.

UI changes:

| Row | Bound to |
|---|---|
| "Enable Notifications" (master) | OS permission state; flipping ON re-runs `requestPermissionAndRegister`; flipping OFF calls `unregisterCurrentDevice` and writes `false` to all four `notif_*_enabled` columns |
| "New Matches" | `notif_matches_enabled` |
| "Messages" | `notif_messages_enabled` |
| "Inbound Likes" (NEW) | `notif_likes_enabled`; visible to all users; non-Gold users can flip it but the trigger won't fire for them |
| "Gardener Daily Reminder" (NEW) | `notif_gardener_local_enabled`; flipping calls `scheduleGardenerLocalNotification` |
| DatePicker (.hourAndMinute) under Gardener row | `notif_gardener_local_hour` — only the hour component is read from the picker and persisted; minutes are ignored in v1. The local trigger fires at HH:00 |

When the master toggle is OFF or OS permission is denied, the sub-toggles are still visible but disabled with explainer text.

### 5.6 `AuthViewModel` hooks

In the existing `logout()`:

```swift
if let userId = currentUserId {
    await NotificationService.shared.unregisterCurrentDevice(userId: userId)
}
// then existing logout logic
```

In the existing post-sign-in path (after `checkSession` confirms a session):

```swift
// Re-register the device with the (possibly new) user_id. Safe to call even
// if permission has not been granted — the call short-circuits.
if let userId = currentUserId, !needsOnboarding {
    await NotificationService.shared.requestPermissionAndRegister(userId: userId)
}
```

### 5.7 Deep-link handling — `MainTabView`

Listens for `Notification.Name.harvestDeepLink`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .harvestDeepLink)) { note in
    guard let link = note.userInfo?["deepLink"] as? String else { return }
    handleDeepLink(link)
}
```

`handleDeepLink` switch:

| Prefix | Action |
|---|---|
| `"chat:<conversationId>"` | switch to Mindful Messages tab (tag 0); push `ChatDetailView` for that conversation via `NavigationPath` |
| `"match:<matchId>"` | switch to Mindful Messages tab (tag 0); the new-matches carousel is already at the top |
| `"likes"` | switch to Mindful Messages tab; the Likes-You section is already there |
| `"gardener"` | switch to Gardener tab (tag 1) |

A `@State private var path = NavigationPath()` is added to the Mindful Messages tab so chat deep-links can push onto it. Other tabs reset to root when switched to via deep-link.

### 5.8 Entitlement file

Xcode generates `Harvest/Harvest.entitlements` when Push Notifications + Background Modes capabilities are ticked. Final contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

`UIBackgroundModes = ['remote-notification']` is set via the `INFOPLIST_KEY_UIBackgroundModes` build setting on the target (since this project uses auto-generated Info.plist — `GENERATE_INFOPLIST_FILE = YES`).

## 6. Apple Developer Setup (manual, by the user)

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → select the Harvest App ID → **Capabilities** → enable **Push Notifications** → Save.
2. **Keys** → **+** → name "Harvest APNs" → tick **Apple Push Notifications service (APNs)** → Continue → Register → download `.p8`. Note the Key ID and Team ID.
3. In Xcode, project → Harvest target → **Signing & Capabilities** → **+ Capability** → add **Push Notifications**; **+ Capability** → add **Background Modes** → tick *Remote notifications*.

## 7. Migration & Seeding

Single SQL file under `supabase/migrations/<timestamp>_push_notifications.sql`, where the timestamp is later than `20260523120000_values_questionnaire.sql`:

```sql
-- 1. user_devices table

create table user_devices (
  user_id     uuid not null references users(id) on delete cascade,
  apns_token  text not null,
  platform    text not null default 'ios' check (platform in ('ios')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  primary key (user_id, apns_token)
);

alter table user_devices enable row level security;

create policy "devices_self_rw" on user_devices
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. users notification preference columns

alter table users
  add column notif_messages_enabled        boolean default true,
  add column notif_matches_enabled         boolean default true,
  add column notif_likes_enabled           boolean default true,
  add column notif_gardener_local_enabled  boolean default true,
  add column notif_gardener_local_hour     int default 9 check (notif_gardener_local_hour between 0 and 23);

-- 3. pg_net (required for triggers to call the Edge Function)

create extension if not exists pg_net;

-- 4. Trigger functions and triggers
--    (Concrete trigger function bodies are spelled out in the implementation
--    plan — they reference Supabase project URL and service_role JWT, which
--    differ by environment and are configured as DB secrets.)
```

The trigger function bodies are deferred to the implementation plan, because they require the project's Supabase URL and a `service_role` JWT stored as a database secret via `vault.create_secret` — concrete values are environment-specific and must not appear in the spec.

## 8. Testing Notes

- `NotificationService.persistDeviceToken` can be unit-tested by mocking the Supabase client and asserting that the upsert payload contains the right keys. The de-dupe-on-same-token-twice behavior is also unit-testable.
- The Edge Function can be invoked end-to-end via `supabase functions invoke send-push --body '{...}'` from a developer machine; APNs response codes are visible in the function logs.
- The DB triggers can be tested by inserting a row into `messages` and watching the Edge Function logs for the resulting invocation.
- Manual smoke test before TestFlight: sign in on a real device, complete onboarding, grant permission, sign in on a second device (or background the first), send a message — first device should receive a banner, badge increments to 1, tapping opens the chat.
- TestFlight processing time can be 5–30 minutes; the first push will only work after the build is fully processed AND the user has launched the build on-device at least once (so the token is registered).

## 9. Assumptions

- The Supabase project has the `pg_net` extension available (it is on the free tier).
- `messages.sender_id`, `messages.conversation_id`, `conversations.user1_id`, `conversations.user2_id`, `matches.user1_id`, `matches.user2_id`, `swipes.swiper_id`, `swipes.target_id`, `swipes.action`, and a Gold subscription identifier are all present in the existing schema. The implementation plan will read the actual columns from the codebase / Supabase dashboard and fix discrepancies inline.
- The user's `subscription_tier` (or equivalent) is queryable from Postgres without crossing service boundaries.
- The `.p8` key only needs to be created once and rotates only if compromised. The same key supports development + production APNs environments.
- TestFlight builds use the production APNs environment exclusively — there is no separate sandbox token. Development builds installed via Xcode use sandbox tokens which the production server will reject; this is OK because we set `APNS_ENVIRONMENT = production` and TestFlight is the lowest-tier distribution target.

## 10. Non-Goals (re-stated for clarity)

- No Android / FCM in any layer.
- No notification action buttons.
- No silent background pushes.
- No rich-media (image / video) notifications.
- No quiet hours, digests, weekly summaries.
- No retry queue for failed APNs sends.
- No notification analytics or A/B testing.
- No tests for the Edge Function in v1.
- No badge clearing on app foreground (badge resets on next push that includes a fresh badge count, or stays sticky between pushes).
