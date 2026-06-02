# Harvest Moderation Panel

A small **local-only** web panel for reviewing user reports and acting on them
within 24 hours, as required by App Store Guideline 1.2 (user-generated content).

It lists every report — both manual reports and the auto-filed report that each
**block** creates — alongside the reported user's current profile content, and lets
you **dismiss**, **remove content** (clear bio + photos), or **ban & eject** the user.

## ⚠️ Security

The panel uses the Supabase **service_role** key, which has full database access and
bypasses Row Level Security. Treat it like a password:

- Run this panel **only on your own machine**. Do **not** host it anywhere public.
- `config.js` is gitignored. Never commit it.

## One-time setup

1. **Run the migration.** In the Supabase Dashboard → SQL Editor, paste and run
   [`schema.sql`](./schema.sql). This adds `users.is_banned`, the review columns on
   `user_reports`, and the `moderation_queue` view.

2. **Add your credentials.** Copy the config template and fill it in:
   ```sh
   cp config.example.js config.js
   ```
   Set `SUPABASE_URL` (Project Settings → API → Project URL) and `SERVICE_ROLE_KEY`
   (Project Settings → API → `service_role` secret).

## Running it

From this `admin/` folder, serve the files locally and open the page:

```sh
python3 -m http.server 8787
# then open http://localhost:8787
```

(Opening `index.html` directly via `file://` also works, but a local server is tidier.)

## What each action does

| Action | Effect |
|---|---|
| **Dismiss** | Marks the report reviewed (`action_taken = 'dismissed'`). No change to the user. |
| **Remove content** | Clears the reported user's `bio` and `photos`, then marks the report reviewed (`content_removed`). |
| **Ban & eject user** | Sets `users.is_banned = true` and deactivates all their matches. The app signs them out on next launch and hides them from every feed. Marks the report reviewed (`banned`). |

## How the app enforces a ban

- `AuthViewModel.loadProfile` signs out any user whose `is_banned` is true and shows a suspension message.
- `SwipeService.getDiscoverProfiles` filters banned users out of the discover feed.
- Existing matches/conversations with the banned user are deactivated by the ban action above.

## Toggle

- **Show all / Show pending** switches between the open queue and the full history (including already-actioned reports).
