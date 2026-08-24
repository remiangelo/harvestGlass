# Android launch setup

Everything the Android app needs from outside the codebase. Five tasks, roughly
an hour, and nothing here blocks the app from running — it builds and works
today, these just switch on push and purchasing.

Package name, needed throughout: **`com.harvestglass.harvest`**

---

## 1. Firebase — what it is and why

Apple delivers push through APNs. Google delivers it through **FCM** (Firebase
Cloud Messaging). They're the same idea — a service that holds an open
connection to every phone so your server can wake an app that isn't running —
but they're separate systems with separate credentials.

Your `send-push` Edge Function already speaks both. It reads each device's
`platform` column and routes to APNs or FCM. What's missing is the FCM half's
credentials, and the file that lets the Android app register for a token at all.

### Create the project

1. Go to <https://console.firebase.google.com> and click **Add project**.
2. Name it `Harvest` (or anything — the name is internal).
3. Google Analytics is optional. Off is fine.

### Register the Android app

1. In the project, click the **Android** icon.
2. **Android package name:** `com.harvestglass.harvest` — this must match exactly.
3. Nickname and the debug signing certificate are both optional. Skip them.
4. Download **`google-services.json`**.
5. Put it at `android/app/google-services.json`.

That's the client half done. The build picks the file up automatically — the
Gradle plugin is applied only when the file exists, which is why the app
compiles fine without it today.

### Get the server credentials

1. Firebase Console → the gear icon → **Project settings** → **Service accounts**.
2. Click **Generate new private key**. A JSON file downloads.
3. Open it. You need three values:
   - `project_id` → `FCM_PROJECT_ID`
   - `client_email` → `FCM_CLIENT_EMAIL`
   - `private_key` → `FCM_PRIVATE_KEY`

Keep this file out of the repo. It is a credential — anyone holding it can send
push to your users.

### Set the secrets

Supabase Dashboard → **Edge Functions** → **Secrets** → add all three.

`FCM_PRIVATE_KEY` is a long multi-line value beginning
`-----BEGIN PRIVATE KEY-----`. Paste it whole, newlines and all. The function
handles either real newlines or the `\n` escapes the JSON file uses.

---

## 2. Apply the push migrations — all three

**This is bigger than it looked.** Probing the live project on 2026-08-25 found
`user_devices` does not exist (`42P01`). None of the push migrations were ever
applied, and `send-push` had never been deployed either — so the triggers in
`20260524130000` have been calling a 404, and **push has never worked on iOS
either.** That is pre-existing, not something the Android work introduced.

Every other table the app needs is present and healthy: `safety_analyses`,
`red_flag_reports`, `ready_to_move_checks`, all four gardener tables,
`user_usage`, `user_subscriptions`, `swipes`, `user_reports`, `user_blocks`.
The three tier rows are configured, and the quiz bank has 6 questions.

Apply these three **in order** — each depends on the one before:

1. `20260524120000_push_notifications.sql` — creates `user_devices`
2. `20260524130000_push_notification_triggers.sql` — the pg_net triggers
3. `20260825120000_android_push_support.sql` — widens `platform` to accept
   `'android'`

```bash
supabase db push
```

Or paste each into the SQL editor, oldest first.

**Migration 2 has a prerequisite of its own.** Its header comment requires two
Vault secrets to exist *before* it runs, or the triggers will have nothing to
call:

```sql
select vault.create_secret(
  'https://jutzlxdboayvmcuqwodn.supabase.co/functions/v1/send-push',
  'send_push_url'
);
select vault.create_secret('<your service_role JWT>', 'send_push_service_role');
```

**One thing that looks like a bug and isn't:** Android tokens are stored in a
column called `apns_token`. Renaming it would have meant touching the iOS app,
the existing rows, and every query that reads it, to gain nothing. The column
holds "the push token for this device", whatever service issues it.

---

## 3. Deploy the two Edge Functions — done

Both are deployed and live as of 2026-08-25:

```bash
supabase functions deploy send-push --use-api
supabase functions deploy verify-play-purchase --use-api
```

`--use-api` bundles through the Management API instead of Docker, which this
machine doesn't have running.

Both were smoke-tested after deploying and boot correctly.
`verify-play-purchase` was exercised through its real paths: missing fields →
400, unknown product → 400 (so the StoreKit product ids loaded), and a caller
claiming to be a different user → **403**, which is the check that stops one
account upgrading another.

`send-push` boots but returns 500 on a real call, because it queries
`user_devices` — see task 2. It will work once the migrations are applied.

---

## 4. Play Console — subscription products

You already have the account. In **Play Console** → your app → **Monetize** →
**Products** → **Subscriptions**, create four subscriptions. The ids must be
exactly these, because they're the same ids StoreKit uses and both stores write
the same tier rows:

| Product ID | Tier | Period |
| --- | --- | --- |
| `com.harvestglass.harvest.grow.weekly` | Grow | Weekly |
| `com.harvestglass.harvest.grow.monthly` | Grow | Monthly |
| `com.harvestglass.harvest.gold.weekly` | Gold | Weekly |
| `com.harvestglass.harvest.gold.monthly` | Gold | Monthly |

For each one:

1. **Create subscription**, enter the product ID and a name.
2. Add **one base plan**. Set its billing period to match (weekly or monthly),
   auto-renewing, and set the price.
3. **Activate** both the base plan and the subscription. An inactive product
   returns nothing to the app, and the purchase sheet shows "not available".

The app takes the first offer on each product, which is why each needs exactly
one base plan.

### The service account for verification

`verify-play-purchase` asks Google whether a purchase token is real. That needs
a service account with access to the Play Developer API.

1. **Google Cloud Console** → the project linked to your Play account →
   **IAM & Admin** → **Service Accounts** → **Create service account**.
2. Name it something like `play-verification`. No roles needed at this step.
3. On the new account: **Keys** → **Add key** → **Create new key** → **JSON**.
   A file downloads.
4. **Play Console** → **Users and permissions** → **Invite new users** → paste
   the service account's email → grant **View financial data, orders, and
   cancellation survey responses** on your app → **Invite**.
5. **Play Console** → **Setup** → **API access** — confirm the Cloud project is
   linked and the account appears.

Then set three more secrets on Supabase Edge Functions:

- `PLAY_PACKAGE_NAME` → `com.harvestglass.harvest`
- `PLAY_CLIENT_EMAIL` → the service account's `client_email`
- `PLAY_PRIVATE_KEY` → its `private_key`

Permission changes can take up to 24 hours to take effect on Google's side. If
verification returns 502 right after setup, that's usually why.

---

## 5. Testing purchases without spending money

**Play Console** → **Setup** → **License testing** → add your own Google account
under **License testers**. Testers see real purchase flows but are never
charged, and subscriptions renew in minutes rather than weeks.

Two things that will otherwise waste an afternoon:

- **Billing only works from a Play-installed build.** A sideloaded debug APK
  gets no products back. Upload to **internal testing** and install from the
  Play link.
- **The emulator needs a Play Store image.** An AOSP or Google-APIs-only image
  has no Play services to talk to, so `products()` returns empty and the sheet
  says "not available".

---

## What happens if you skip a step

Nothing breaks — each piece fails closed on its own:

| Skipped | Effect |
| --- | --- |
| `google-services.json` | App runs, push registration inert |
| The migration | Android token writes fail; iOS push unaffected |
| FCM secrets | `send-push` reports `FCM_NOT_CONFIGURED` per Android device, still delivers to iOS |
| Play products | Subscription screen loads, purchase sheet says unavailable |
| Play secrets | Purchases complete on Google's side but aren't granted — and are left unacknowledged, so Google refunds them rather than stranding the user |

A subscriber from iOS already reads correctly on Android with none of this done:
tier is server-authoritative, so only *purchasing* is per-store.
