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

## Rooms tab

Create, edit, image, deactivate, and delete community rooms; manage members
(ban/unban, promote/demote moderators) and moderate chat (remove/restore
messages) from a room's "Members & chat" panel.

Room banner images upload to the public `community-images` storage bucket.
Prefer **Deactivate** over Delete — Delete permanently removes the room and
all its messages, reactions, and memberships.

### Restrictions

The room form has a **Restrictions** section that writes `communities.criteria`
(jsonb). Leave it empty and the room is visible to everyone it would have been
visible to before.

- **All set restrictions must be met** (they are ANDed).
- **A blank profile field fails a restriction.** Someone who never set their
  faith does not qualify for a Christianity-only room. Expect restricted rooms
  to look sparse.
- **Existing members keep access** regardless of criteria changes. Restrictions
  gate discovery and joining, never revoke a membership.
- **Location** needs coordinates, not just a place name. Type the place, press
  **Look up place**, confirm the resolved address shown beneath, and set a
  radius. Saving with a place but no coordinates is rejected rather than
  silently ignored.

Lookup uses OpenStreetMap Nominatim — the one external service this panel
talks to besides Supabase. It is free and needs no key.

Enforcement lives entirely in the `available_communities()` Postgres function
(`supabase/migrations/20260804120000_room_access_criteria.sql`). Nothing is
checked in the browser, and **the iOS app needs no update** for a new
restriction to take effect — that is the point of the feature.
