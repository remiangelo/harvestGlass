# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver APNs push notifications for new messages, new matches, and inbound likes (Gold-tier only), plus an on-device daily Gardener reflection reminder. Wire the existing Settings toggles to real user preferences.

**Architecture:** A new Supabase Edge Function `send-push` signs an ES256 JWT with a `.p8` auth key and calls Apple's HTTP/2 APNs API directly. Three Postgres triggers on `messages`, `matches`, and `swipes` call the Edge Function via `pg_net`. The iOS app adds an `AppDelegate`, a `NotificationService` singleton, and a `user_devices` table to persist APNs tokens per signed-in user. The Gardener daily reminder bypasses the backend entirely — `UNUserNotificationCenter` schedules it on-device at the user's chosen hour.

**Tech Stack:** Swift / SwiftUI / UNUserNotificationCenter / Supabase Edge Functions (Deno + TypeScript) / Postgres + `pg_net` extension / APNs HTTP/2 with ES256 JWT.

**Spec:** [`docs/superpowers/specs/2026-05-24-push-notifications-design.md`](../specs/2026-05-24-push-notifications-design.md)

---

## File Inventory

**New files**
- `supabase/migrations/20260524120000_push_notifications.sql`
- `supabase/migrations/20260524130000_push_notification_triggers.sql`
- `supabase/functions/send-push/index.ts`
- `supabase/functions/send-push/README.md`
- `Harvest/AppDelegate.swift`
- `Harvest/Services/NotificationService.swift`
- `Harvest/Harvest.entitlements`

**Modified**
- `Harvest/HarvestApp.swift` (UIApplicationDelegateAdaptor + delegate wire-up)
- `Harvest/Models/UserProfile.swift` (5 new notification preference fields)
- `Harvest/ViewModels/AuthViewModel.swift` (sign-in / sign-out hooks)
- `Harvest/Views/Onboarding/CompleteView.swift` (permission prompt card)
- `Harvest/Views/Settings/SettingsView.swift` (wire toggles to preferences)
- `Harvest/Views/MainTabView.swift` (deep-link handling)
- `Harvest.xcodeproj/project.pbxproj` (Push Notifications + Background Modes capabilities; `CODE_SIGN_ENTITLEMENTS = Harvest/Harvest.entitlements`; `INFOPLIST_KEY_UIBackgroundModes = remote-notification`)

**Manual external steps**
- Apple Developer → enable Push Notifications on the App ID, create APNs `.p8` key
- Supabase Dashboard → set Edge Function secrets (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_AUTH_KEY`, `APNS_ENVIRONMENT`)
- Supabase Dashboard → enable `pg_net` extension
- Supabase Database → store Edge Function URL + service role JWT in `vault` for trigger consumption

> **Build/test commands:** xcodebuild commands require macOS. Since the host is Windows, skip xcodebuild in steps and have the user run them at the end. The Edge Function can be developed and tested via `supabase functions serve` on any OS but the user's actual deploy happens from their Mac.

---

## Task 1: SQL migration — schema + preferences

**Files:**
- Create: `supabase/migrations/20260524120000_push_notifications.sql`

This migration creates the `user_devices` table, adds the 5 notification preference columns to `users`, and enables the `pg_net` extension. It does NOT create the triggers — those go in a separate later migration once the Edge Function is deployed and we have its URL.

- [ ] **Step 1.1: Write the migration**

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

create index user_devices_user_id_idx on user_devices(user_id);

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

-- 3. pg_net extension (required for triggers to call the Edge Function in Task 3)

create extension if not exists pg_net;
```

- [ ] **Step 1.2: Commit**

```
git add supabase/migrations/20260524120000_push_notifications.sql
git commit -m "db(migration): user_devices table + notification preferences + pg_net"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

The migration is applied later (Task 16) — committing the file alone does not run it against Supabase.

---

## Task 2: Edge Function `send-push` — JWT + APNs HTTP/2

**Files:**
- Create: `supabase/functions/send-push/index.ts`
- Create: `supabase/functions/send-push/README.md`

The function receives `{ recipient_user_id, type, payload }`, looks up the recipient's devices, signs an ES256 JWT against APNs, and sends one HTTP/2 request per device.

- [ ] **Step 2.1: Create `supabase/functions/send-push/index.ts`**

```typescript
// supabase/functions/send-push/index.ts
//
// Sends APNs pushes to a user's registered devices.
//
// Invoked by Postgres triggers via pg_net (see migration
// 20260524130000_push_notification_triggers.sql). Not user-facing.
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID       - 10-char Key ID from Apple Developer
//   APNS_TEAM_ID      - 10-char Team ID from Apple Developer
//   APNS_BUNDLE_ID    - e.g. "HarvestGlass.Harvest"
//   APNS_AUTH_KEY     - Full .p8 file contents with BEGIN/END lines
//   APNS_ENVIRONMENT  - "production" (TestFlight + App Store) or "development" (Xcode dev builds)
//
// Also requires the standard Supabase Edge Function env vars
// (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) which are auto-injected.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// -------- types

interface SendPushRequest {
  recipient_user_id: string;
  type: "message" | "match" | "like";
  payload: {
    title: string;
    body: string;
    deepLink: string;
    threadId?: string;
    badgeCount?: number;
  };
}

interface UserDevice {
  apns_token: string;
}

// -------- JWT cache (warm-start across invocations)

let cachedJwt: { token: string; issuedAt: number } | null = null;
const JWT_MAX_AGE_SECONDS = 50 * 60; // refresh 10 min before APNs's 60-min limit

// -------- JWT signing

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64url(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string"
      ? new TextEncoder().encode(input)
      : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function buildJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < JWT_MAX_AGE_SECONDS) {
    return cachedJwt.token;
  }

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_AUTH_KEY")!;

  const header = { alg: "ES256", kid: keyId };
  const claims = { iss: teamId, iat: now };

  const headerB64 = base64url(JSON.stringify(header));
  const claimsB64 = base64url(JSON.stringify(claims));
  const signingInput = `${headerB64}.${claimsB64}`;

  const keyData = pemToArrayBuffer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = base64url(new Uint8Array(sigBuf));

  const token = `${signingInput}.${sigB64}`;
  cachedJwt = { token, issuedAt: now };
  return token;
}

// -------- APNs delivery

function apnsHost(): string {
  const env = Deno.env.get("APNS_ENVIRONMENT") ?? "production";
  return env === "development"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
}

async function sendToDevice(
  token: string,
  body: SendPushRequest,
  jwt: string,
): Promise<{ status: number; reason?: string }> {
  const apsAlert = { title: body.payload.title, body: body.payload.body };
  const apnsPayload: Record<string, unknown> = {
    aps: {
      alert: apsAlert,
      sound: "default",
      ...(body.payload.threadId ? { "thread-id": body.payload.threadId } : {}),
      ...(body.payload.badgeCount !== undefined
        ? { badge: body.payload.badgeCount }
        : {}),
    },
    deepLink: body.payload.deepLink,
  };

  const collapseId =
    body.payload.threadId ?? `${body.type}:${body.recipient_user_id}`;

  const res = await fetch(`https://${apnsHost()}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": collapseId,
      "content-type": "application/json",
    },
    body: JSON.stringify(apnsPayload),
  });

  if (res.status === 200) return { status: 200 };

  let reason: string | undefined;
  try {
    const json = await res.json();
    reason = json?.reason;
  } catch { /* APNs may return empty body on some errors */ }

  return { status: res.status, reason };
}

// -------- main

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: SendPushRequest;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (
    !body.recipient_user_id ||
    !body.type ||
    !body.payload?.title ||
    !body.payload?.body ||
    !body.payload?.deepLink
  ) {
    return new Response("Missing required fields", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: devices, error: fetchError } = await supabase
    .from("user_devices")
    .select("apns_token")
    .eq("user_id", body.recipient_user_id);

  if (fetchError) {
    console.error("Failed to fetch devices:", fetchError);
    return new Response("Server error", { status: 500 });
  }

  if (!devices || devices.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "no_devices" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  const jwt = await buildJwt();

  let sent = 0;
  for (const device of devices as UserDevice[]) {
    const result = await sendToDevice(device.apns_token, body, jwt);

    if (result.status === 200) {
      sent++;
      continue;
    }

    // Stale token — purge so subsequent sends don't waste time on it.
    if (
      result.status === 410 ||
      (result.status === 400 && result.reason === "BadDeviceToken")
    ) {
      await supabase
        .from("user_devices")
        .delete()
        .eq("apns_token", device.apns_token);
      console.log(`Removed stale token: ${device.apns_token.substring(0, 8)}…`);
      continue;
    }

    console.error(
      `APNs error ${result.status} ${result.reason ?? ""} for token ${device.apns_token.substring(0, 8)}…`,
    );
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
```

- [ ] **Step 2.2: Create `supabase/functions/send-push/README.md`**

```markdown
# send-push

Sends APNs pushes to a user's registered iOS devices.

## Invocation

Internal only — called by Postgres triggers via `pg_net.http_post`. Not user-facing.

Request body:
```json
{
  "recipient_user_id": "<uuid>",
  "type": "message" | "match" | "like",
  "payload": {
    "title": "string",
    "body": "string",
    "deepLink": "chat:<id>" | "match:<id>" | "likes",
    "threadId": "optional collapse identifier",
    "badgeCount": 1
  }
}
```

Response:
```json
{ "sent": 1 }
```

## Required secrets

| Secret             | Source                                            |
|--------------------|---------------------------------------------------|
| `APNS_KEY_ID`      | Apple Developer → Keys → Key ID (10 chars)        |
| `APNS_TEAM_ID`     | Apple Developer → top-right of portal (10 chars)  |
| `APNS_BUNDLE_ID`   | `HarvestGlass.Harvest`                            |
| `APNS_AUTH_KEY`    | Contents of the .p8 file (with BEGIN/END lines)   |
| `APNS_ENVIRONMENT` | `production` (TestFlight + App Store) or `development` (Xcode dev builds) |

Set via `supabase secrets set` or in Dashboard → Project Settings → Edge Functions → Secrets.

## Local testing

```sh
supabase functions serve send-push
curl -X POST http://localhost:54321/functions/v1/send-push \
  -H "content-type: application/json" \
  -d '{
    "recipient_user_id": "<your-uuid>",
    "type": "message",
    "payload": {
      "title": "Test sender",
      "body": "Hi from the Edge Function",
      "deepLink": "chat:abc",
      "threadId": "abc"
    }
  }'
```
```

- [ ] **Step 2.3: Commit**

```
git add supabase/functions/send-push/
git commit -m "feat(edge): send-push function with APNs HTTP/2 + ES256 JWT"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 3: SQL migration — triggers

**Files:**
- Create: `supabase/migrations/20260524130000_push_notification_triggers.sql`

The triggers call the Edge Function via `pg_net.http_post`. They read the Edge Function URL and service-role JWT from Supabase Vault.

- [ ] **Step 3.1: Write the migration**

```sql
-- This migration creates three Postgres triggers that call the send-push
-- Edge Function via pg_net when messages, matches, or likes are inserted.
--
-- BEFORE applying this migration, two secrets must exist in Supabase Vault:
--   - send_push_url            : full URL to the Edge Function, e.g.
--                                https://<project>.supabase.co/functions/v1/send-push
--   - send_push_service_role   : service_role JWT for the project
--
-- Create them via SQL (one-time, in the dashboard SQL editor):
--   select vault.create_secret('https://<project>.supabase.co/functions/v1/send-push', 'send_push_url');
--   select vault.create_secret('<service_role_jwt>', 'send_push_service_role');

create or replace function call_send_push(
  recipient uuid,
  ntype text,
  title text,
  body text,
  deep_link text,
  thread_id text default null,
  badge_count int default null
) returns void
language plpgsql
security definer
as $$
declare
  v_url text;
  v_jwt text;
  v_payload jsonb;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'send_push_url';
  select decrypted_secret into v_jwt
    from vault.decrypted_secrets where name = 'send_push_service_role';

  if v_url is null or v_jwt is null then
    raise warning 'call_send_push: vault secrets missing (send_push_url / send_push_service_role)';
    return;
  end if;

  v_payload := jsonb_build_object(
    'recipient_user_id', recipient,
    'type', ntype,
    'payload', jsonb_build_object(
      'title', title,
      'body', body,
      'deepLink', deep_link,
      'threadId', thread_id,
      'badgeCount', badge_count
    )
  );

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_jwt
    ),
    body := v_payload
  );
end;
$$;

-- 1. messages_after_insert trigger

create or replace function on_messages_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_recipient uuid;
  v_sender_nickname text;
  v_body text;
  v_messages_enabled boolean;
begin
  -- Determine recipient = the conversation participant other than the sender
  select case
           when c.user1_id = NEW.sender_id then c.user2_id
           else c.user1_id
         end
    into v_recipient
    from conversations c
    where c.id = NEW.conversation_id;

  if v_recipient is null or v_recipient = NEW.sender_id then
    return NEW;
  end if;

  -- Honor recipient preference
  select coalesce(notif_messages_enabled, true) into v_messages_enabled
    from users where id = v_recipient;
  if not v_messages_enabled then
    return NEW;
  end if;

  select coalesce(nickname, 'Someone') into v_sender_nickname
    from users where id = NEW.sender_id;

  if NEW.message_type = 'image' or (NEW.content is null or NEW.content = '') then
    v_body := 'Sent you a photo';
  else
    v_body := left(NEW.content, 80);
  end if;

  perform call_send_push(
    recipient   => v_recipient,
    ntype       => 'message',
    title       => v_sender_nickname,
    body        => v_body,
    deep_link   => 'chat:' || NEW.conversation_id,
    thread_id   => NEW.conversation_id::text,
    badge_count => null    -- v1: omit badge; see spec §4.1 fallback
  );

  return NEW;
end;
$$;

drop trigger if exists messages_after_insert on messages;
create trigger messages_after_insert
  after insert on messages
  for each row
  execute function on_messages_after_insert();

-- 2. matches_after_insert trigger

create or replace function on_matches_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_user1_nickname text;
  v_user2_nickname text;
  v_user1_enabled boolean;
  v_user2_enabled boolean;
begin
  select coalesce(nickname, 'Someone') into v_user1_nickname from users where id = NEW.user1_id;
  select coalesce(nickname, 'Someone') into v_user2_nickname from users where id = NEW.user2_id;

  select coalesce(notif_matches_enabled, true) into v_user1_enabled from users where id = NEW.user1_id;
  select coalesce(notif_matches_enabled, true) into v_user2_enabled from users where id = NEW.user2_id;

  if v_user1_enabled then
    perform call_send_push(
      recipient => NEW.user1_id,
      ntype     => 'match',
      title     => 'New match',
      body      => 'You matched with ' || v_user2_nickname || ' 🌱',
      deep_link => 'match:' || NEW.id::text
    );
  end if;

  if v_user2_enabled then
    perform call_send_push(
      recipient => NEW.user2_id,
      ntype     => 'match',
      title     => 'New match',
      body      => 'You matched with ' || v_user1_nickname || ' 🌱',
      deep_link => 'match:' || NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists matches_after_insert on matches;
create trigger matches_after_insert
  after insert on matches
  for each row
  execute function on_matches_after_insert();

-- 3. swipes_after_insert trigger (inbound-like push for Gold tier)

create or replace function on_swipes_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_can_see_likes boolean := false;
  v_likes_enabled boolean;
begin
  if NEW.action not in ('like', 'super_like') then
    return NEW;
  end if;

  select coalesce(notif_likes_enabled, true) into v_likes_enabled
    from users where id = NEW.swiped_id;
  if not v_likes_enabled then
    return NEW;
  end if;

  -- Gate on Gold tier: only users whose active subscription tier sets
  -- can_see_likes = true should receive the inbound-like push.
  select coalesce(t.can_see_likes, false)
    into v_can_see_likes
    from user_subscriptions us
    join subscription_tiers t on t.id = us.tier_id
    where us.user_id = NEW.swiped_id
      and us.status = 'active'
    order by us.started_at desc
    limit 1;

  if not v_can_see_likes then
    return NEW;
  end if;

  perform call_send_push(
    recipient => NEW.swiped_id,
    ntype     => 'like',
    title     => 'Harvest',
    body      => 'Someone likes you',
    deep_link => 'likes',
    thread_id => 'likes:' || NEW.swiped_id::text
  );

  return NEW;
end;
$$;

drop trigger if exists swipes_after_insert on swipes;
create trigger swipes_after_insert
  after insert on swipes
  for each row
  execute function on_swipes_after_insert();
```

- [ ] **Step 3.2: Commit**

```
git add supabase/migrations/20260524130000_push_notification_triggers.sql
git commit -m "db(migration): triggers to send pushes on message/match/like inserts"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

Applied later (Task 16). If the `user_subscriptions.status` enum uses a different active-row identifier in the live schema (e.g. `'current'`), the implementation engineer should fix that string in `on_swipes_after_insert` before applying. The columns referenced (`user_subscriptions.user_id`, `tier_id`, `status`, `started_at`; `subscription_tiers.id`, `can_see_likes`) come from `Harvest/Models/SubscriptionTier.swift` and `Harvest/Services/SubscriptionService.swift`.

---

## Task 4: `UserProfile` — add 5 notification preference fields

**Files:**
- Modify: `Harvest/Models/UserProfile.swift`

- [ ] **Step 4.1: Add the properties**

In `Harvest/Models/UserProfile.swift`, immediately after the existing `var profileGraphSide: String?` line (added in the previous values-questionnaire feature), insert:

```swift
    var notifMessagesEnabled: Bool?
    var notifMatchesEnabled: Bool?
    var notifLikesEnabled: Bool?
    var notifGardenerLocalEnabled: Bool?
    var notifGardenerLocalHour: Int?
```

- [ ] **Step 4.2: Add the coding keys**

In the `CodingKeys` enum, immediately after `case profileGraphSide = "profile_graph_side"`, insert:

```swift
        case notifMessagesEnabled = "notif_messages_enabled"
        case notifMatchesEnabled = "notif_matches_enabled"
        case notifLikesEnabled = "notif_likes_enabled"
        case notifGardenerLocalEnabled = "notif_gardener_local_enabled"
        case notifGardenerLocalHour = "notif_gardener_local_hour"
```

- [ ] **Step 4.3: Commit**

```
git add Harvest/Models/UserProfile.swift
git commit -m "feat(profile): add notif_* preference fields"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 5: `AppDelegate.swift` + `HarvestApp.swift` wiring

**Files:**
- Create: `Harvest/AppDelegate.swift`
- Modify: `Harvest/HarvestApp.swift`

- [ ] **Step 5.1: Create `Harvest/AppDelegate.swift`**

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

- [ ] **Step 5.2: Wire `AppDelegate` into SwiftUI**

In `Harvest/HarvestApp.swift`, add the delegate adaptor and notification-center delegate hookup. Replace the file contents with:

```swift
import SwiftUI

@main
struct HarvestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoading {
                    LaunchScreenView()
                } else if authViewModel.isAuthenticated {
                    if authViewModel.needsOnboarding {
                        OnboardingContainerView(authViewModel: authViewModel)
                    } else {
                        MainTabView(authViewModel: authViewModel)
                    }
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
            .dismissKeyboardOnTap()
            .task {
                UNUserNotificationCenter.current().delegate = NotificationService.shared
                authViewModel.listenToAuthChanges()
                await authViewModel.checkSession()
            }
        }
    }
}

struct LaunchScreenView: View {
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            Image("Splash Page Gradient")
                .resizable()
                .scaledToFill()
                .scaleEffect(animateGlow ? 1.02 : 1.0)
                .ignoresSafeArea()

            Color.black.opacity(0.06)
                .ignoresSafeArea()

            Image("Harvest_Wordmark_Black")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .shadow(color: Color.white.opacity(0.08), radius: 8, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}
```

The two changes from the existing file are: the `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate` line, and the `UNUserNotificationCenter.current().delegate = NotificationService.shared` line at the start of the `.task` closure.

`UserNotifications` is implicitly available via `SwiftUI` import chain on iOS, but if the compiler complains add `import UserNotifications` at the top.

- [ ] **Step 5.3: Don't commit yet — proceed to Task 6**

The compiler will fail until `NotificationService` exists in Task 6. Tasks 5 and 6 ship as one commit.

---

## Task 6: `NotificationService` — token persistence + delegate

**Files:**
- Create: `Harvest/Services/NotificationService.swift`

- [ ] **Step 6.1: Create the file**

```swift
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
```

- [ ] **Step 6.2: Commit Tasks 5 + 6 together**

```
git add Harvest/AppDelegate.swift Harvest/HarvestApp.swift Harvest/Services/NotificationService.swift
git commit -m "feat(notifications): AppDelegate + NotificationService scaffolding"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 7: `CompleteView` — permission prompt card

**Files:**
- Modify: `Harvest/Views/Onboarding/CompleteView.swift`

The user finishes onboarding here. Add a "Stay in the loop" card above the existing "Done"/CTA button. Tapping "Turn on notifications" calls `NotificationService.requestPermissionAndRegister()` and schedules the Gardener local notification at 9am local default.

- [ ] **Step 7.1: Read the file**

First read `Harvest/Views/Onboarding/CompleteView.swift` to confirm the current structure (it should have a single primary CTA at the bottom that calls `viewModel.completeOnboarding`).

- [ ] **Step 7.2: Inject the permission card**

Add a `@State private var notificationsRequested = false` near the top of the struct and `@AppStorage("notifications_prompted_at_onboarding") private var prompted = false` to remember across launches.

In the view body, immediately ABOVE the existing primary "Done"/"Continue" CTA, insert:

```swift
if !prompted {
    GlassCard {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(HarvestTheme.Colors.accent)
                Text("Stay in the loop")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }
            Text("We'll let you know about new matches, messages, and likes — and a gentle daily reflection from your Gardener.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            HStack {
                Button("Maybe later") {
                    prompted = true
                }
                .font(HarvestTheme.Typography.buttonText)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                Spacer()
                Button {
                    Task {
                        await NotificationService.shared.requestPermissionAndRegister()
                        await NotificationService.shared.scheduleGardenerLocalNotification(hour: 9, enabled: true)
                        prompted = true
                    }
                } label: {
                    Text("Turn on")
                        .font(HarvestTheme.Typography.buttonText)
                        .foregroundStyle(HarvestTheme.Colors.textOnCream)
                        .padding(.horizontal, HarvestTheme.Spacing.lg)
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        .background { Capsule().fill(HarvestTheme.Colors.harvestCream) }
                }
            }
        }
    }
    .padding(.horizontal)
}
```

The exact placement depends on `CompleteView`'s current layout; the engineer should insert it within the same `VStack`/`ScrollView` that holds the existing copy, immediately before the primary CTA. The card uses the same `GlassCard` and `HarvestTheme` tokens that the rest of the onboarding flow uses.

- [ ] **Step 7.3: Don't commit yet — proceed to Task 8**

---

## Task 8: `AuthViewModel` — sign-in + sign-out hooks

**Files:**
- Modify: `Harvest/ViewModels/AuthViewModel.swift`

- [ ] **Step 8.1: Read the file**

First read `Harvest/ViewModels/AuthViewModel.swift` to locate the existing `logout()` method and the sign-in / session-check path. The session check is called `checkSession()` and is called on app launch from `HarvestApp.swift`.

- [ ] **Step 8.2: Hook the sign-out path**

Find the existing `logout()` method (likely starts with something like `func logout() async {`). At the VERY TOP of the body — before any Supabase sign-out call — insert:

```swift
        if let userId = currentUserId {
            await NotificationService.shared.unregisterCurrentDevice(userId: userId)
        }
```

This must run BEFORE `supabase.auth.signOut()` because `unregisterCurrentDevice` needs the still-active session to authorize the DELETE on `user_devices`.

- [ ] **Step 8.3: Hook the post-sign-in path**

Find `checkSession()`. At the END of its body — after the session is confirmed and `isAuthenticated` is set to true and `needsOnboarding` is computed — add:

```swift
        if isAuthenticated, !needsOnboarding {
            await NotificationService.shared.requestPermissionAndRegister()
        }
```

If the post-sign-in path goes through a separate function (e.g. `handleSignInSuccess`), put the same call there instead. The condition `!needsOnboarding` exists so we don't prompt before the user has completed onboarding — the `CompleteView` card handles the first prompt.

- [ ] **Step 8.4: Commit Tasks 7 + 8 together**

```
git add Harvest/Views/Onboarding/CompleteView.swift Harvest/ViewModels/AuthViewModel.swift
git commit -m "feat(notifications): onboarding permission prompt + auth hooks"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 9: `SettingsView` — wire toggles to real preferences

**Files:**
- Modify: `Harvest/Views/Settings/SettingsView.swift`

Replace the placeholder `@State private var notificationsEnabled = true` / `matchNotifications = true` / `messageNotifications = true` with bindings into the user's profile.

- [ ] **Step 9.1: Read the file**

First read `Harvest/Views/Settings/SettingsView.swift` to see the current Notifications section structure (located around lines 46–55 with `sectionTitle("Notifications")` and three `toggleRow` calls).

- [ ] **Step 9.2: Add view-model state**

Near the top of the `SettingsView` struct, replace the three placeholder `@State` lines with:

```swift
    @State private var profile: UserProfile?
    @State private var savingError: String?

    private let profileService = ProfileService()
```

- [ ] **Step 9.3: Replace the Notifications section**

Replace the existing `sectionTitle("Notifications") ... { toggleRow ... }` block (around lines 46–55) with:

```swift
                sectionTitle("Notifications")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        toggleRow(
                            "Enable Notifications",
                            isOn: Binding(
                                get: { osNotificationsEnabled },
                                set: { newValue in handleMasterToggle(newValue) }
                            )
                        )
                        if osNotificationsEnabled {
                            dividerRow()
                            toggleRow(
                                "New Matches",
                                isOn: prefBinding(\.notifMatchesEnabled, default: true)
                            )
                            dividerRow()
                            toggleRow(
                                "Messages",
                                isOn: prefBinding(\.notifMessagesEnabled, default: true)
                            )
                            dividerRow()
                            toggleRow(
                                "Inbound Likes (Gold)",
                                isOn: prefBinding(\.notifLikesEnabled, default: true)
                            )
                            dividerRow()
                            toggleRow(
                                "Gardener Daily Reminder",
                                isOn: Binding(
                                    get: { profile?.notifGardenerLocalEnabled ?? true },
                                    set: { newValue in
                                        updatePref(\.notifGardenerLocalEnabled, to: newValue, column: "notif_gardener_local_enabled")
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
                                    Spacer()
                                    Picker("", selection: gardenerHourBinding) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(formatHour(h)).tag(h)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.horizontal, HarvestTheme.Spacing.md)
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
```

- [ ] **Step 9.4: Add helpers**

Add these computed properties / helper methods inside the same `SettingsView` struct, after the `body` definition:

```swift
    @State private var osNotificationsEnabled: Bool = true   // mirrors OS authorization status

    private func loadProfile() async {
        guard let userId = authViewModel.currentUserId else { return }
        profile = try? await profileService.getProfile(userId: userId)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        osNotificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    private func handleMasterToggle(_ newValue: Bool) {
        if newValue {
            // Turning ON — request permission. If previously denied this is a no-op;
            // surface guidance to open iOS Settings.
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
            // Turning OFF — unregister and zero out preferences (defensive: backend
            // already won't send because no device row exists).
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

    private func prefBinding(_ keyPath: WritableKeyPath<UserProfile, Bool?>, default defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in updatePref(keyPath, to: newValue, column: columnName(for: keyPath)) }
        )
    }

    private var gardenerHourBinding: Binding<Int> {
        Binding(
            get: { profile?.notifGardenerLocalHour ?? 9 },
            set: { newValue in
                updateHourPref(to: newValue)
                Task {
                    await NotificationService.shared.scheduleGardenerLocalNotification(
                        hour: newValue,
                        enabled: profile?.notifGardenerLocalEnabled ?? true
                    )
                }
            }
        )
    }

    private func updatePref<T>(_ keyPath: WritableKeyPath<UserProfile, T?>, to newValue: T, column: String) where T: Encodable {
        guard let userId = authViewModel.currentUserId else { return }
        let previous = profile
        profile?[keyPath: keyPath] = newValue
        Task {
            do {
                let json: AnyJSON
                switch newValue {
                case let b as Bool: json = .bool(b)
                case let i as Int:  json = .double(Double(i))
                default: json = .null
                }
                _ = try await profileService.updateProfile(userId: userId, updates: [column: json])
                savingError = nil
            } catch {
                profile = previous
                savingError = error.localizedDescription
            }
        }
    }

    private func updateHourPref(to newValue: Int) {
        updatePref(\.notifGardenerLocalHour, to: newValue, column: "notif_gardener_local_hour")
    }

    private func columnName(for keyPath: WritableKeyPath<UserProfile, Bool?>) -> String {
        switch keyPath {
        case \.notifMatchesEnabled:        return "notif_matches_enabled"
        case \.notifMessagesEnabled:       return "notif_messages_enabled"
        case \.notifLikesEnabled:          return "notif_likes_enabled"
        case \.notifGardenerLocalEnabled:  return "notif_gardener_local_enabled"
        default:                           return ""
        }
    }

    private func formatHour(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h; c.minute = 0
        let cal = Calendar.current
        let date = cal.date(from: c) ?? Date()
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }
```

- [ ] **Step 9.5: Trigger `loadProfile` on appear**

Add a `.task` modifier to the outer `ScrollView`/`VStack` of `SettingsView`'s body:

```swift
        .task { await loadProfile() }
```

- [ ] **Step 9.6: Add missing imports**

At the top of `SettingsView.swift`, ensure these imports exist:

```swift
import SwiftUI
import UserNotifications
import Supabase   // for AnyJSON
```

- [ ] **Step 9.7: Don't commit yet — proceed to Task 10**

---

## Task 10: `MainTabView` — deep-link handling

**Files:**
- Modify: `Harvest/Views/MainTabView.swift`

When the user taps a notification, `NotificationService` posts a `Notification.Name.harvestDeepLink` with a string in `userInfo["deepLink"]`. `MainTabView` listens and switches tab + (for chat) pushes the right detail view onto a `NavigationPath`.

- [ ] **Step 10.1: Read the file**

First read `Harvest/Views/MainTabView.swift` to see the existing structure — it should have a `@State private var selection` for the active tab and a `TabView` with five tabs.

- [ ] **Step 10.2: Add deep-link state**

Inside the `MainTabView` struct, add (next to the existing `selection` state):

```swift
    @State private var messagesPath = NavigationPath()
    @State private var pendingChatDeepLink: String?
```

- [ ] **Step 10.3: Wire the listener**

Add the following `.onReceive` modifier to the `TabView` (or outermost view in `body`):

```swift
        .onReceive(NotificationCenter.default.publisher(for: .harvestDeepLink)) { note in
            guard let link = note.userInfo?["deepLink"] as? String else { return }
            handleDeepLink(link)
        }
```

- [ ] **Step 10.4: Add the handler**

After `body`, add inside the struct:

```swift
    private func handleDeepLink(_ link: String) {
        if link.hasPrefix("chat:") {
            let conversationId = String(link.dropFirst("chat:".count))
            selection = 0   // Mindful Messages tab
            messagesPath = NavigationPath()
            pendingChatDeepLink = conversationId
        } else if link.hasPrefix("match:") {
            selection = 0   // new-matches carousel lives at top of Mindful Messages
            messagesPath = NavigationPath()
        } else if link == "likes" {
            selection = 0   // Likes-You section at top of Mindful Messages
            messagesPath = NavigationPath()
        } else if link == "gardener" {
            selection = 1   // Gardener tab
        }
    }
```

- [ ] **Step 10.5: Propagate the chat deep-link**

The Mindful Messages tab body needs to consume `pendingChatDeepLink` and push the right destination. Replace the existing Mindful Messages tab construction in the `TabView` from:

```swift
                MindfulMessagesView(authViewModel: authViewModel)
```

to:

```swift
                MindfulMessagesView(
                    authViewModel: authViewModel,
                    externalPath: $messagesPath,
                    pendingChatDeepLink: $pendingChatDeepLink
                )
```

This requires updating `MindfulMessagesView` to accept those two parameters (next sub-step).

- [ ] **Step 10.6: Update `MindfulMessagesView` signature**

In `Harvest/Views/Chat/MindfulMessagesView.swift`, add to the struct:

```swift
    @Binding var externalPath: NavigationPath
    @Binding var pendingChatDeepLink: String?
```

(If `externalPath`/`pendingChatDeepLink` are not provided by callers because some call sites don't supply them, add a no-arg initializer that defaults them. Or — simpler — wrap the existing struct in default values via `init`:

```swift
    init(
        authViewModel: AuthViewModel,
        externalPath: Binding<NavigationPath> = .constant(NavigationPath()),
        pendingChatDeepLink: Binding<String?> = .constant(nil)
    ) {
        self.authViewModel = authViewModel
        self._externalPath = externalPath
        self._pendingChatDeepLink = pendingChatDeepLink
    }
```
)

Replace the file's `NavigationStack {` opener with `NavigationStack(path: $externalPath) {`. Inside the navigation stack, attach a `.task(id: pendingChatDeepLink)` that handles the pending deep-link:

```swift
.task(id: pendingChatDeepLink) {
    guard let conversationId = pendingChatDeepLink else { return }
    // Wait briefly so the view's data is loaded (the conversation row needs to
    // exist locally for the ChatDetailView destination to look it up). 100ms
    // is enough for the existing list query to complete in the common case.
    try? await Task.sleep(nanoseconds: 100_000_000)
    externalPath.append("chat:\(conversationId)")
    pendingChatDeepLink = nil
}
```

Add a `.navigationDestination(for: String.self)` that recognizes `"chat:<id>"`:

```swift
.navigationDestination(for: String.self) { value in
    if value.hasPrefix("chat:") {
        let conversationId = String(value.dropFirst("chat:".count))
        ChatDetailView(authViewModel: authViewModel, conversationId: conversationId)
    }
}
```

(If `ChatDetailView`'s actual initializer differs — e.g. takes a `Conversation` rather than an ID — the engineer should match the destination accordingly and may need to look up the conversation by ID from the view model first. Read `ChatDetailView`'s init to confirm.)

- [ ] **Step 10.7: Commit Tasks 9 + 10 together**

```
git add Harvest/Views/Settings/SettingsView.swift Harvest/Views/MainTabView.swift Harvest/Views/Chat/MindfulMessagesView.swift
git commit -m "feat(notifications): settings preferences + deep-link routing"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 11: Xcode capabilities + entitlement file

**Files:**
- Create: `Harvest/Harvest.entitlements`
- Modify: `Harvest.xcodeproj/project.pbxproj` (add capability build settings)

This step is normally done via Xcode's UI on a Mac. Since the project must be edited from Windows here, write the entitlement file by hand and let the user verify in Xcode after pulling.

- [ ] **Step 11.1: Create `Harvest/Harvest.entitlements`**

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

- [ ] **Step 11.2: Update `Harvest.xcodeproj/project.pbxproj`**

In `Harvest.xcodeproj/project.pbxproj`, find each of the four Harvest **target** build configurations (Debug + Release for the main `Harvest` target — search for `PRODUCT_BUNDLE_IDENTIFIER = HarvestGlass.Harvest;` to locate them; each occurrence is in its own `buildSettings = { ... };` block). In each of those two blocks, add the following two settings (alphabetical insertion is conventional):

```
CODE_SIGN_ENTITLEMENTS = Harvest/Harvest.entitlements;
INFOPLIST_KEY_UIBackgroundModes = "remote-notification";
```

Do NOT modify the `HarvestTests` or `HarvestUITests` target build settings — those have different bundle identifiers (`HarvestGlass.HarvestTests`, `HarvestGlass.HarvestUITests`) and don't need push capabilities.

The Xcode-managed `SystemCapabilities` block also needs updating, but Xcode regenerates it on next open of the project — the build settings above are sufficient for the build itself. After the user opens the project in Xcode and confirms the capabilities show up under Signing & Capabilities, they may need to commit Xcode's automatic `project.pbxproj` cleanup.

- [ ] **Step 11.3: Commit**

```
git add Harvest/Harvest.entitlements Harvest.xcodeproj/project.pbxproj
git commit -m "build(ios): enable Push Notifications + Background Modes capabilities"
```

Co-Authored-By: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## Task 12: Apple Developer setup (manual; user must do this)

**No git changes. Manual external work that must happen before Task 16.**

- [ ] **Step 12.1: Enable Push Notifications on the App ID**

Sign in to [developer.apple.com](https://developer.apple.com). Certificates, Identifiers & Profiles → **Identifiers** → select the Harvest App ID (`HarvestGlass.Harvest`) → **Capabilities** → tick **Push Notifications** → Save.

- [ ] **Step 12.2: Create an APNs Auth Key**

Same portal → **Keys** → click **+** → name it `Harvest APNs` → tick **Apple Push Notifications service (APNs)** → Continue → Register → **Download the `.p8` file** (Apple only lets you download it once; store it somewhere safe like a password manager). Note the **Key ID** (10 chars, shown on the page).

- [ ] **Step 12.3: Note your Team ID**

Top-right of any developer.apple.com page → Team ID is the 10-char code under your team name.

- [ ] **Step 12.4: Verify in Xcode after pulling**

After running `git pull` on the Mac:
1. Open `Harvest.xcodeproj` in Xcode.
2. Project navigator → Harvest target → **Signing & Capabilities**.
3. Verify **Push Notifications** appears (Xcode may auto-detect it from the entitlements file).
4. If it doesn't appear, click **+ Capability** → add **Push Notifications**.
5. Click **+ Capability** → add **Background Modes** → tick **Remote notifications**.
6. Xcode may regenerate the `project.pbxproj`'s SystemCapabilities block — commit any resulting changes.

---

## Task 13: Supabase secrets + vault setup (manual; user must do this)

**No git changes. Manual external work that must happen before Task 16.**

- [ ] **Step 13.1: Set Edge Function secrets**

Supabase Dashboard → Project Settings → Edge Functions → **Secrets** (or use `supabase secrets set <KEY>=<VAL>` via CLI). Set:

| Key                  | Value                                                             |
|----------------------|-------------------------------------------------------------------|
| `APNS_KEY_ID`        | 10-char Key ID from Task 12.2                                     |
| `APNS_TEAM_ID`       | 10-char Team ID from Task 12.3                                    |
| `APNS_BUNDLE_ID`     | `HarvestGlass.Harvest`                                            |
| `APNS_AUTH_KEY`      | Paste the entire contents of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. The dashboard preserves newlines automatically. |
| `APNS_ENVIRONMENT`   | `production`                                                      |

- [ ] **Step 13.2: Store vault secrets for the DB triggers**

Supabase Dashboard → SQL Editor → run once:

```sql
select vault.create_secret('https://<your-project-ref>.supabase.co/functions/v1/send-push', 'send_push_url');
select vault.create_secret('<your-service-role-jwt>', 'send_push_service_role');
```

Replace `<your-project-ref>` with the project ref from your Supabase URL (the part before `.supabase.co`), and `<your-service-role-jwt>` with the Service Role JWT from Project Settings → API.

To verify:
```sql
select name, decrypted_secret is not null as set from vault.decrypted_secrets where name in ('send_push_url', 'send_push_service_role');
```

Should return two rows with `set = true`.

---

## Task 14: Deploy the Edge Function (manual; user does on Mac)

**No git changes. Manual external work.**

- [ ] **Step 14.1: Authenticate the Supabase CLI**

If not already logged in: `supabase login` (opens browser).

- [ ] **Step 14.2: Link to the project**

In the project root:

```sh
supabase link --project-ref <your-project-ref>
```

- [ ] **Step 14.3: Deploy `send-push`**

```sh
supabase functions deploy send-push
```

Verify in Dashboard → Edge Functions that `send-push` appears with status "Deployed".

- [ ] **Step 14.4: Smoke-test from CLI**

Before running the migrations, send a test payload to a known device row (you can insert one manually):

```sql
-- Replace <user-uuid> with your own user_id and use a test token (any string).
insert into user_devices (user_id, apns_token) values ('<user-uuid>', 'test-token-will-410');
```

```sh
curl -X POST "https://<your-project-ref>.supabase.co/functions/v1/send-push" \
  -H "content-type: application/json" \
  -H "Authorization: Bearer <service-role-jwt>" \
  -d '{
    "recipient_user_id": "<user-uuid>",
    "type": "message",
    "payload": {
      "title": "Test sender",
      "body": "Hi from the Edge Function",
      "deepLink": "chat:test-conv",
      "threadId": "test-conv"
    }
  }'
```

Expected output: `{"sent":0}` and the bad token is removed from `user_devices` (APNs returns 400 BadDeviceToken). The 0 confirms the function reached APNs.

Edge Function logs (Dashboard → Edge Functions → send-push → Logs) should show "Removed stale token: test-tok…".

---

## Task 15: Apply the SQL migrations (manual; user does)

**No git changes. Manual external work.**

- [ ] **Step 15.1: Apply migrations via CLI**

```sh
supabase db push
```

This applies both `20260524120000_push_notifications.sql` and `20260524130000_push_notification_triggers.sql`.

Alternatively, paste them into Dashboard → SQL Editor in timestamp order.

- [ ] **Step 15.2: Verify schema**

```sql
-- New table exists with RLS
select tablename, rowsecurity from pg_tables where tablename = 'user_devices';

-- New columns exist
select column_name from information_schema.columns
 where table_name = 'users' and column_name like 'notif_%';

-- Triggers exist
select tgname from pg_trigger
 where tgname in ('messages_after_insert', 'matches_after_insert', 'swipes_after_insert');
```

All four queries should return rows.

- [ ] **Step 15.3: Smoke-test the message trigger**

With your own user signed in via the iOS dev build (so a real device token is in `user_devices`), insert a message from a different user pointing at one of your conversations:

```sql
insert into messages (conversation_id, sender_id, content, message_type, created_at)
values ('<existing-conversation-id>', '<other-user-id>', 'Trigger test', 'text', now());
```

You should receive a push notification within a few seconds. Edge Function logs show the `sent: 1` response.

---

## Task 16: TestFlight build + on-device verification (manual; user does)

**No git changes. The end-to-end test.**

- [ ] **Step 16.1: Bump build number if needed**

If you've already uploaded a `1.0 (1)` build, increment `CURRENT_PROJECT_VERSION` in Xcode (target → General → Build) before archiving. Otherwise leave it.

- [ ] **Step 16.2: Archive**

Xcode → select "Any iOS Device (arm64)" → Product → Archive.

- [ ] **Step 16.3: Distribute**

Organizer → select archive → Distribute App → App Store Connect → Upload. Use automatic signing.

- [ ] **Step 16.4: Wait for processing**

5–30 minutes. App Store Connect → My App → TestFlight tab → build appears with status "Ready to Test" when processing completes.

- [ ] **Step 16.5: Install on a real device**

Add yourself to an Internal Testing group, install TestFlight on the device, accept the build.

- [ ] **Step 16.6: End-to-end smoke test**

1. Launch the TestFlight build, sign in, complete onboarding.
2. On the "Stay in the loop" card, tap **Turn on**. iOS shows the permission dialog. Tap Allow.
3. Open Settings → check that "Enable Notifications" is on and the four sub-toggles are visible.
4. Sign in as a different user on a second device (or use a friend's account).
5. From the second device, send you a message. The first device should receive a banner within a few seconds.
6. Background the first device's app and send another message — banner still arrives.
7. Tap a message notification — the app should open to that conversation.
8. Like a profile on the second device that you've already liked from the first device → match created → both devices get the "You matched with…" push.
9. Settings → toggle "Messages" off → ask the friend to send another message → no notification (Edge Function logs show the trigger short-circuited on the recipient's `notif_messages_enabled = false`).
10. Wait until the Gardener hour (default 9:00 am local) → local notification fires.
11. Sign out on the first device → friend sends a message → first device receives nothing (token row deleted).

---

## Task 17: Cleanup + final commit

**Files:** none (status check + final push)

- [ ] **Step 17.1: Verify clean working tree**

```sh
git status
```

Should be `nothing to commit, working tree clean`.

- [ ] **Step 17.2: Push to origin**

```sh
git push origin main
```

- [ ] **Step 17.3: Update PROJECT_STATUS.md**

Open `Harvest/Documentation/PROJECT_STATUS.md`, find the line `[ ] Push notifications: Match alerts, new messages, Gardener reminders` and change `[ ]` to `[x]`.

```sh
git add Harvest/Documentation/PROJECT_STATUS.md
git commit -m "docs(status): push notifications shipped"
git push
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Each spec section is implemented:
  - §1 Scope → Tasks 1–17
  - §2.1 user_devices → Task 1
  - §2.2 users.notif_* → Task 1
  - §2.3 UserProfile → Task 4
  - §3 Edge Function → Task 2
  - §4 Triggers → Task 3
  - §5.1 AppDelegate → Task 5
  - §5.2 HarvestApp wiring → Task 5
  - §5.3 NotificationService → Task 6
  - §5.4 CompleteView prompt → Task 7
  - §5.5 SettingsView rewire → Task 9
  - §5.6 AuthViewModel hooks → Task 8
  - §5.7 Deep-link handling → Task 10
  - §5.8 Entitlement file → Task 11
  - §6 Apple Developer setup → Task 12
  - §7 SQL migration → Tasks 1 + 3, applied in Task 15
- [x] **No placeholders:** No "TBD" / "TODO" / "fill in" remain. The one place the spec deferred ("badge count query depends on read-state schema") is mirrored in the trigger code as `badge_count => null` with an inline comment.
- [x] **Type consistency:** `NotificationService.shared`, `Notification.Name.harvestDeepLink`, `notif_*_enabled` columns, `user_devices.apns_token` are spelled identically everywhere. `requestPermissionAndRegister()` takes no arguments (no `userId:` parameter) since it reads the user ID from the current session; both call sites (CompleteView Step 7.2 and AuthViewModel Step 8.3) match this.
- [x] **Manual-step dependencies:** Tasks 12, 13, 14, 15 are blockers for Task 16's smoke test. The user has to do them in order on a Mac. The plan calls this out explicitly.
