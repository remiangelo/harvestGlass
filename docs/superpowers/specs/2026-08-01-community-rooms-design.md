# Community Rooms Redesign + Admin Rooms Section — Design

**Date:** 2026-08-01
**Status:** Approved
**Approach:** Extend the existing communities stack (no schema rework)

## Summary

The Field's community rooms get a distinct garden identity (green accent + room imagery) and richer conversation features — inline quote-replies, @mentions, and curated emoji reactions — while staying flat, room-based chats (no threads). The admin panel gains a Rooms tab for creating, editing, imaging, deactivating, and deleting rooms, viewing members, and proactively moderating room chat.

Context: the current implementation is already a flat chronological chat per room. Replies, mentions, and reactions have no existing schema or UI support — all three are greenfield additions.

## Decisions made

| Decision | Choice |
|---|---|
| "Greenery" aesthetic | Green accent used only in The Field; rest of app stays rose/wine |
| Reply model | Inline quote-reply (Telegram-style), one flat stream, no nesting |
| Reactions | Curated set of 6, DB-enforced: 🌱 💚 🌻 😂 👏 🤔 |
| Admin architecture | Keep local-only static panel (service-role key), add tab navigation |
| Build approach | Extend existing tables; no v2 rework, no data migration |

## Out of scope (explicit)

- Push notifications for mentions or room activity — push infra is entirely unconfigured on this project. The `mentions` array is stored so a notification trigger can be added later without schema change.
- Edit/delete-own messages, unread counts/badges, typing indicators in rooms, pinned messages, per-room notification prefs.
- In-app moderator powers. Admin can assign the existing `community_members.role = 'moderator'`, but the iOS app grants no powers to that role yet — bookkeeping for later.
- Community prompts (icebreakers) management in admin — existing seed/SQL workflow stays.
- Hosted admin panel with login — stays local-only.

## Section 1 — iOS: The Field & room experience

### Garden accent tokens

Add to `Harvest/Theme/HarvestTheme.swift` `Colors`:

- `fieldGreen` `#4DB380` — primary Field accent
- `fieldGreenLight` `#7ACCA3` — highlights, mention text
- `fieldGreenBorder` — `fieldGreen.opacity(0.18)` (mirrors existing `border` pattern)

Used **only** inside Field views: join buttons, reaction chips, quote bars, mention rendering, member-count leaf. Surfaces, typography, spacing unchanged (wine/plum system).

### Room directory (`FieldView`)

- Room cards render a banner image from the new `communities.image_url` (AsyncImage, dark gradient overlay, `wineCard` fallback when null) with name + description overlaid.
- Render `member_count` (already fetched, currently unused) as "🌱 N gardeners".
- Join button uses green accent. Joined rooms navigate into chat as today; leave stays in the context menu.
- Empty state keeps the existing leaf motif.

### Room chat (`CommunityChatView` / `CommunityChatViewModel` / `CommunityService`)

**Pagination (required fix).** Replace fetch-all with: latest 50 messages (`created_at desc`, reversed for display); scrolling to top fetches the next older page keyed by `created_at < oldest_loaded`. Realtime INSERT append unchanged.

**Quote-replies.**
- Trigger: swipe right on a bubble, or context menu → Reply. Sets a reply target shown as a dismissible quoted snippet above the composer.
- Sent message stores `reply_to_id`. Bubble renders the quoted original (sender nickname + snippet) above the message text with a `fieldGreen` left bar.
- Tapping a quote scrolls to the original message if loaded; if it's outside the loaded page, fetch it by id for the preview only (no jump).
- One level only; replying to a reply quotes that reply.

**Mentions.**
- Typing `@` in the composer opens an autocomplete list of the room's active members' nicknames above the composer.
- On send, the client resolves selected mentions to user ids and stores them in `mentions uuid[]`. Rendering derives highlights from the array (match nickname spans in content; fall back to plain text if a nickname changed), so old messages don't break on nickname changes.
- Mentions render in `fieldGreenLight`, semibold. Messages mentioning the current user get a subtle `fieldGreenBorder` edge on the bubble.
- Visual-only for now (no push).

**Reactions.**
- Long-press a bubble → reaction bar with the 6 curated emoji.
- Chips under the bubble show emoji + count; the current user's own reactions tint green. Tap a chip to toggle.
- Loaded in bulk per message page (one `in (...)` query); kept live via realtime INSERT + DELETE on `community_message_reactions`.

**Preserved unchanged:** icebreaker prompts sheet, mindful-messaging warning + incoming blur, `CONTACT_INFO_BLOCKED` friendly error, report via context menu, tap-avatar → `ProfileDetailView` with Send a Seed.

## Section 2 — Backend schema (Supabase)

One migration file in `supabase/migrations/`; applied to production via dashboard `execute_sql` (remote migration history is not in sync with the repo — do not use `apply_migration`).

### Table changes

```sql
alter table communities add column image_url text;

alter table community_messages
  add column reply_to_id uuid references community_messages(id),
  add column mentions uuid[] not null default '{}';
```

### New table

```sql
create table community_message_reactions (
  message_id uuid not null references community_messages(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  emoji      text not null check (emoji in ('🌱','💚','🌻','😂','👏','🤔')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);
```

- RLS: active room members (via existing `is_active_member`) can SELECT all reactions on messages in their rooms; INSERT only `user_id = auth.uid()`; DELETE only own rows.
- Add to `supabase_realtime` publication with `replica identity full` (DELETE events must carry the row so toggles sync).

### Query plan

- Message pages served by the existing `(community_id, created_at)` index.
- Reactions fetched per page with one `message_id in (...)` query.
- Reply previews come from in-memory messages when possible; fallback single-row fetch by id.

### Storage

New bucket `community-images`, public read. Writes only via admin (service-role key) — no authenticated-user storage policies needed.

## Section 3 — Admin panel

Same stack: static `index.html` + `app.js` ES module + supabase-js from esm.sh, service-role key, local-only. Two header tabs: **Moderation** (existing queue, unchanged) and **Rooms** (new). CSS custom properties gain `--green: #4db380`.

### Rooms tab — list

All communities including inactive: image thumbnail, name, slug, kind, member count, display order, active status. Per-card actions:

- **Edit** — opens the form pre-filled.
- **Activate / Deactivate** — toggles `is_active`. UI copy recommends deactivate over delete.
- **Delete** — `confirm()` warning that it permanently removes the room and cascades to messages, memberships, and reactions.

### Create / Edit form

Inline form: name, slug (auto-generated from name on create, editable), description, kind (dropdown: `everyone` / `seeking_connection` / `relationship_stage` / `peer`), display order, image file input. Image uploads to `community-images` and the public URL is saved to `image_url`.

### Room detail (expand a card)

- **Members panel** — nickname, role, status, joined date. Actions: ban / unban (sets `community_members.status`), promote to moderator / demote (sets `role`).
- **Chat moderation panel** — latest 100 messages newest-first, "load older" button. Each row: sender, timestamp, content, removed badge. Actions: remove (`is_removed = true`, `removed_by`, `removed_at` — same fields the queue action sets), restore, ban author from room.

### Implementation shape

`index.html`: tab nav in `.controls`, `#rooms` container alongside `#list`. `app.js`: `loadRooms()`, `roomCard()`, `memberRow()`, `messageRow()` renderers reusing `escape()` / `fmtDate()`; new branches in the existing `onAction` delegation.

## Error handling

- iOS: pagination and reaction failures surface via the existing inline error line pattern in `CommunityChatViewModel`; reaction toggles are optimistic with rollback on error.
- Reply to a deleted/removed message: quote renders "Message removed".
- Admin: image upload failure keeps the form open with the error shown in `#banner`; delete/ban actions keep the existing `confirm()` → action → reload pattern.

## Testing & verification

- **Runnable now (Windows):** migration SQL (execute_sql against production after review), reaction RLS behavior via SQL probes, full admin panel manually in a browser against the live project.
- **Not runnable (no Mac):** SwiftUI changes ship as reviewed code with an Xcode verification checklist (build, join/leave, paginate, reply, mention autocomplete, reaction toggle live-sync between two accounts, image banners).
