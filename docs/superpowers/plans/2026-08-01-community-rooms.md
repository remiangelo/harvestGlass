# Community Rooms Redesign + Admin Rooms Section — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give The Field's community rooms a green garden identity with room images, quote-replies, @mentions, curated reactions, and message pagination — and add a Rooms tab to the admin panel for room CRUD, member management, and chat moderation.

**Architecture:** Extend the existing `communities` / `community_members` / `community_messages` stack (one SQL migration adds columns, a reactions table, and a storage bucket). iOS work layers onto the existing `CommunityService` → `@Observable` view-model → SwiftUI view pattern. Admin work extends the existing single-page static panel with tab navigation and direct PostgREST calls via the service-role key.

**Tech Stack:** Supabase (Postgres, RLS, Realtime, Storage), SwiftUI + supabase-swift (`@Observable` view models, RealtimeV2), static HTML/JS admin with supabase-js from esm.sh.

**Spec:** `docs/superpowers/specs/2026-08-01-community-rooms-design.md`

## Global Constraints

- **No Mac available.** Swift cannot be compiled or run here. Swift tasks end with careful self-review + commit, NOT a build. The final task produces an Xcode verification checklist. Do not claim Swift code "passes" anything.
- **SQL goes to production via `execute_sql`** (Supabase MCP, project ref `jutzlxdboayvmcuqwodn`), NOT `apply_migration` — the remote migration history is out of sync with the repo. Always ALSO save the migration file in `supabase/migrations/`.
- **Curated reaction emoji, exact set:** 🌱 💚 🌻 😂 👏 🤔 — enforced by a DB check constraint.
- **Green accent hexes:** `fieldGreen #4DB380`, `fieldGreenLight #7ACCA3`. Green is used ONLY in Field views and the admin `--green` variable. Do not touch the rose tokens.
- **Out of scope** (do not build): push notifications, edit/delete-own messages, unread counts, typing indicators in rooms, in-app moderator powers, prompt management in admin, admin auth.
- Admin panel stays a static page: no framework, no build step, no npm. Reuse `escape()` / `fmtDate()` helpers.
- Commit after every task with the message given in the task.

---

### Task 1: Database migration + storage bucket

**Files:**
- Create: `supabase/migrations/20260801090000_community_rooms.sql`

**Interfaces:**
- Produces (later tasks rely on): `communities.image_url text`; `community_messages.reply_to_id uuid`, `community_messages.mentions uuid[]`; table `community_message_reactions(message_id, user_id, emoji, community_id, created_at)` with `community_id` auto-filled by trigger; storage bucket `community-images` (public read).

Note: the spec's reactions table gains one extra column vs the spec text — `community_id`, auto-filled by a BEFORE INSERT trigger from the parent message. It exists so iOS realtime can server-side filter reaction events per room (`filter: community_id=eq.<room>`); without it the client would have to subscribe to the whole table.

- [ ] **Step 1: Write the migration file**

```sql
-- Community rooms v2: room images, quote-replies, mentions, reactions.
-- Applied to production via dashboard/execute_sql (remote history not in sync).

-- 1. Room banner images
alter table communities add column if not exists image_url text;

-- 2. Quote-replies + mentions on messages
alter table community_messages
  add column if not exists reply_to_id uuid references community_messages(id),
  add column if not exists mentions uuid[] not null default '{}';

-- 3. Reactions (curated set enforced at the DB)
create table if not exists community_message_reactions (
  message_id   uuid not null references community_messages(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  emoji        text not null check (emoji in ('🌱','💚','🌻','😂','👏','🤔')),
  community_id uuid not null references communities(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create index if not exists idx_reactions_community
  on community_message_reactions (community_id);

-- community_id is denormalized from the parent message so realtime can
-- filter per-room. A trigger fills it; clients never send it.
create or replace function set_reaction_community()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select community_id into new.community_id
  from community_messages where id = new.message_id;
  if new.community_id is null then
    raise exception 'unknown message %', new.message_id;
  end if;
  return new;
end;
$$;

drop trigger if exists reactions_set_community on community_message_reactions;
create trigger reactions_set_community
  before insert on community_message_reactions
  for each row execute function set_reaction_community();

-- 4. RLS
alter table community_message_reactions enable row level security;

drop policy if exists "reactions_select" on community_message_reactions;
create policy "reactions_select" on community_message_reactions
  for select to authenticated
  using (is_active_member(community_id, auth.uid()));

drop policy if exists "reactions_insert" on community_message_reactions;
create policy "reactions_insert" on community_message_reactions
  for insert to authenticated
  with check (user_id = auth.uid() and is_active_member(community_id, auth.uid()));

drop policy if exists "reactions_delete" on community_message_reactions;
create policy "reactions_delete" on community_message_reactions
  for delete to authenticated
  using (user_id = auth.uid());

-- 5. Realtime: INSERT and DELETE events must reach clients (toggling off
-- a reaction has to sync), so replica identity full is required.
alter table community_message_reactions replica identity full;
alter publication supabase_realtime add table community_message_reactions;

-- 6. Storage bucket for room banners (public read; writes only via admin
-- service key, so no authenticated storage policies are needed).
insert into storage.buckets (id, name, public)
values ('community-images', 'community-images', true)
on conflict (id) do nothing;
```

- [ ] **Step 2: Apply to production**

Use the Supabase MCP `execute_sql` on project `jutzlxdboayvmcuqwodn` with the file's contents. If `alter publication` fails with "already member of publication", that line alone may be skipped — everything else must succeed.

- [ ] **Step 3: Probe — schema exists**

Run via `execute_sql`:

```sql
select column_name from information_schema.columns
where table_name = 'community_messages'
  and column_name in ('reply_to_id', 'mentions');
```

Expected: 2 rows.

```sql
select column_name from information_schema.columns
where table_name = 'communities' and column_name = 'image_url';
```

Expected: 1 row.

- [ ] **Step 4: Probe — emoji constraint rejects junk**

```sql
do $$
begin
  insert into community_message_reactions (message_id, user_id, emoji)
  values (gen_random_uuid(), gen_random_uuid(), '🔥');
  raise exception 'constraint did not fire';
exception when check_violation then
  raise notice 'OK: curated set enforced';
end $$;
```

Expected: notice `OK: curated set enforced` (the check constraint fires before the FK lookup would).

- [ ] **Step 5: Probe — RLS + realtime wiring**

```sql
select policyname from pg_policies where tablename = 'community_message_reactions';
```

Expected: `reactions_select`, `reactions_insert`, `reactions_delete`.

```sql
select relreplident from pg_class where relname = 'community_message_reactions';
```

Expected: `f` (full).

```sql
select id, public from storage.buckets where id = 'community-images';
```

Expected: 1 row, `public = true`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260801090000_community_rooms.sql
git commit -m "feat(db): room images, replies, mentions, reactions + community-images bucket"
```

---

### Task 2: iOS theme tokens + model extensions

**Files:**
- Modify: `Harvest/Theme/HarvestTheme.swift` (Colors enum, after the `amber` token ~line 20)
- Modify: `Harvest/Models/Community.swift` (whole file)

**Interfaces:**
- Produces: `HarvestTheme.Colors.fieldGreen` / `.fieldGreenLight` / `.fieldGreenBorder` / `.fieldGreenSoft` (Color); `Community.imageUrl: String?`; `CommunityMessage.replyToId: String?` and `.mentions: [String]?`; `CommunityReaction` struct with `messageId/userId/emoji/communityId`; `CommunityReaction.curatedEmoji: [String]`.

- [ ] **Step 1: Add Field green tokens to `HarvestTheme.Colors`**

Insert directly below the `amber` declaration (`static let amber = Color(hex: "F5872E")`):

```swift
        // Field greens — The Field / community rooms accent.
        // Used ONLY inside Field views; the rest of the app stays rose.
        static let fieldGreen = Color(hex: "4DB380")
        static let fieldGreenLight = Color(hex: "7ACCA3")
        static let fieldGreenBorder = fieldGreen.opacity(0.18)
        static let fieldGreenSoft = fieldGreen.opacity(0.15)
```

- [ ] **Step 2: Extend the models**

Replace the full contents of `Harvest/Models/Community.swift` with:

```swift
import Foundation

struct Community: Identifiable, Codable, Equatable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let kind: String
    let memberCount: Int?
    let displayOrder: Int?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, kind
        case memberCount = "member_count"
        case displayOrder = "display_order"
        case imageUrl = "image_url"
    }
}

struct CommunityMessage: Identifiable, Codable, Equatable {
    let id: String
    let communityId: String
    let senderId: String
    let content: String
    let isRemoved: Bool
    let createdAt: String?
    let replyToId: String?
    let mentions: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case senderId = "sender_id"
        case content
        case isRemoved = "is_removed"
        case createdAt = "created_at"
        case replyToId = "reply_to_id"
        case mentions
    }
}

/// One emoji reaction by one user on one message.
/// community_id is filled server-side by a trigger; it exists so realtime
/// can filter reaction events per room.
struct CommunityReaction: Codable, Equatable, Hashable {
    let messageId: String
    let userId: String
    let emoji: String
    let communityId: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
        case communityId = "community_id"
    }

    /// The curated set — must match the DB check constraint exactly.
    static let curatedEmoji = ["🌱", "💚", "🌻", "😂", "👏", "🤔"]
}

struct CommunityPrompt: Identifiable, Codable, Equatable {
    let id: String
    let text: String
}

/// Lightweight sender info for community chat (name + avatar).
struct CommunitySender: Identifiable, Codable, Equatable {
    let id: String
    let nickname: String?
    let photos: [String]?

    var photoUrl: String? { photos?.first }
}
```

Caution: `Community` and `CommunityMessage` are decoded from both the `available_communities` RPC and raw table selects — the new fields are optional, so old rows decode fine. The RPC `available_communities()` returns `communities.*`? **No — check it.** The migration at `supabase/migrations/20260609130000_the_field.sql:54-82` selects explicit columns. If it does not include `image_url`, run this via `execute_sql` (and append it to the Task 1 migration file):

```sql
-- Only needed if available_communities() selects explicit columns
-- rather than c.* — read the current definition first:
select pg_get_functiondef('available_communities(uuid)'::regprocedure);
```

If `image_url` is missing from its select list, recreate the function identically but with `image_url` added to the returned columns (keep `security definer` and the existing access logic verbatim).

- [ ] **Step 3: Self-review**

Re-read both diffs. Check: CodingKeys cover every property; no non-optional new fields; curated emoji list matches the DB constraint character-for-character.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Theme/HarvestTheme.swift Harvest/Models/Community.swift
git commit -m "feat(field): green accent tokens + room image/reply/mention/reaction models"
```

---

### Task 3: iOS CommunityService — pagination, rich posts, reactions, members

**Files:**
- Modify: `Harvest/Services/CommunityService.swift`

**Interfaces:**
- Consumes: `CommunityReaction`, extended `CommunityMessage` (Task 2).
- Produces (view-model tasks rely on these exact signatures):
  - `messagesPage(communityId: String, before: String?, limit: Int) async throws -> [CommunityMessage]` (returns newest-first)
  - `messagesByIds(_ ids: [String]) async throws -> [CommunityMessage]` (includes removed rows)
  - `post(communityId:senderId:content:replyToId:mentions:) async throws -> CommunityMessage?`
  - `reactions(messageIds: [String]) async throws -> [CommunityReaction]`
  - `addReaction(messageId:userId:emoji:) async throws`
  - `removeReaction(messageId:userId:emoji:) async throws`
  - `members(communityId: String) async throws -> [CommunitySender]`
  - `subscribeReactions(communityId:onInsert:onDelete:) -> RealtimeChannelV2`

- [ ] **Step 1: Replace `messages(communityId:)` with a paginated version**

Delete the existing `messages(communityId:)` function (lines 49-58) and add:

```swift
    /// Latest page of messages, newest-first. Pass the oldest loaded
    /// created_at as `before` to fetch the next older page.
    func messagesPage(communityId: String, before: String? = nil, limit: Int = 50) async throws -> [CommunityMessage] {
        var query = client
            .from("community_messages")
            .select()
            .eq("community_id", value: communityId)
            .eq("is_removed", value: false)
        if let before {
            query = query.lt("created_at", value: before)
        }
        return try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Fetch specific messages by id — used for quoted-reply previews whose
    /// originals fell outside the loaded pages. Includes removed rows so the
    /// UI can render "Message removed".
    func messagesByIds(_ ids: [String]) async throws -> [CommunityMessage] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("community_messages")
            .select()
            .in("id", values: ids)
            .execute()
            .value
    }
```

- [ ] **Step 2: Replace `post` with the reply/mention-aware version**

Delete the existing `post` (lines 60-76) and add:

```swift
    private struct NewCommunityMessage: Encodable {
        let community_id: String
        let sender_id: String
        let content: String
        let reply_to_id: String?
        let mentions: [String]
    }

    /// Throws ContactInfoBlocked when server-side detection rejects the message.
    /// Returns the inserted row so the sender sees the message immediately,
    /// without waiting for the realtime echo.
    @discardableResult
    func post(
        communityId: String,
        senderId: String,
        content: String,
        replyToId: String? = nil,
        mentions: [String] = []
    ) async throws -> CommunityMessage? {
        let inserted: [CommunityMessage] = try await client
            .from("community_messages")
            .insert(NewCommunityMessage(
                community_id: communityId,
                sender_id: senderId,
                content: content,
                reply_to_id: replyToId,
                mentions: mentions
            ))
            .select()
            .execute()
            .value
        return inserted.first
    }
```

- [ ] **Step 3: Add reactions CRUD + members**

Add after `senderProfiles(ids:)`:

```swift
    /// All reactions for the given messages (bulk, one query per page load).
    func reactions(messageIds: [String]) async throws -> [CommunityReaction] {
        guard !messageIds.isEmpty else { return [] }
        return try await client
            .from("community_message_reactions")
            .select()
            .in("message_id", values: messageIds)
            .execute()
            .value
    }

    func addReaction(messageId: String, userId: String, emoji: String) async throws {
        // community_id is filled by a DB trigger — never send it.
        try await client
            .from("community_message_reactions")
            .upsert([
                "message_id": messageId,
                "user_id": userId,
                "emoji": emoji
            ])
            .execute()
    }

    func removeReaction(messageId: String, userId: String, emoji: String) async throws {
        try await client
            .from("community_message_reactions")
            .delete()
            .eq("message_id", value: messageId)
            .eq("user_id", value: userId)
            .eq("emoji", value: emoji)
            .execute()
    }

    /// Active members of a room (for @mention autocomplete).
    func members(communityId: String) async throws -> [CommunitySender] {
        struct Row: Decodable { let users: CommunitySender }
        let rows: [Row] = try await client
            .from("community_members")
            .select("users(id, nickname, photos)")
            .eq("community_id", value: communityId)
            .eq("status", value: "active")
            .execute()
            .value
        return rows.map(\.users)
    }
```

- [ ] **Step 4: Add the reactions realtime channel**

Add after the existing `subscribe(communityId:onMessage:)`:

```swift
    /// Live reaction add/remove events for one room. DELETE events carry the
    /// full old row because the table has replica identity full.
    func subscribeReactions(
        communityId: String,
        onInsert: @escaping @Sendable (CommunityReaction) -> Void,
        onDelete: @escaping @Sendable (CommunityReaction) -> Void
    ) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("community-reactions:\(communityId)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            table: "community_message_reactions",
            filter: .eq("community_id", value: communityId)
        )
        let deletes = channel.postgresChange(
            DeleteAction.self,
            table: "community_message_reactions",
            filter: .eq("community_id", value: communityId)
        )
        Task {
            for await change in inserts {
                if let r = try? change.decodeRecord(as: CommunityReaction.self, decoder: JSONDecoder()) {
                    onInsert(r)
                }
            }
        }
        Task {
            for await change in deletes {
                if let r = try? change.decodeOldRecord(as: CommunityReaction.self, decoder: JSONDecoder()) {
                    onDelete(r)
                }
            }
        }
        Task { try? await channel.subscribeWithError() }
        return channel
    }
```

- [ ] **Step 5: Self-review**

`messages(communityId:)` must be fully gone (its only caller, `CommunityChatViewModel.start`, is rewritten in Task 5 — grep for `service.messages(` to confirm nothing else calls it; the compile break until Task 5 lands is expected and noted in the commit). Check every new query's column names against Task 1's SQL.

- [ ] **Step 6: Commit**

```bash
git add Harvest/Services/CommunityService.swift
git commit -m "feat(field): paginated messages, reply/mention posts, reactions API (VM update follows)"
```

---

### Task 4: iOS FieldView — banner cards, member count, green identity

**Files:**
- Modify: `Harvest/Views/Field/FieldView.swift`

**Interfaces:**
- Consumes: `Community.imageUrl`, `Community.memberCount` (Task 2), `HarvestTheme.Colors.fieldGreen*` (Task 2).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Rewrite `CommunityCard`**

Replace the whole `private struct CommunityCard` (lines 67-129) with:

```swift
private struct CommunityCard: View {
    let community: Community
    let isJoined: Bool
    let authViewModel: AuthViewModel
    let onToggle: () -> Void

    var body: some View {
        if isJoined {
            NavigationLink {
                CommunityChatView(authViewModel: authViewModel, community: community)
            } label: {
                cardBody(joined: true)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: onToggle) {
                    Label("Leave room", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } else {
            cardBody(joined: false)
        }
    }

    private func cardBody(joined: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            details(joined: joined)
        }
        .background(HarvestTheme.Colors.wineCard)
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .stroke(joined ? HarvestTheme.Colors.fieldGreenBorder : HarvestTheme.Colors.border, lineWidth: 1)
        )
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlString = community.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        bannerPlaceholder
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, HarvestTheme.Colors.wineBlack.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)

            Text(community.name)
                .font(HarvestTheme.Typography.h4)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .padding(HarvestTheme.Spacing.md)
        }
        .frame(height: 110)
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(HarvestTheme.Colors.wineRaised)
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(HarvestTheme.Colors.fieldGreen.opacity(0.4))
            }
    }

    private func details(joined: Bool) -> some View {
        HStack(alignment: .top, spacing: HarvestTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
                if let description = community.description {
                    Text(description)
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let count = community.memberCount, count > 0 {
                    Label("\(count) gardener\(count == 1 ? "" : "s")", systemImage: "leaf.fill")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                }

                if joined {
                    Label("Tap to open room", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(HarvestTheme.Typography.caption)
                        .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                        .padding(.top, HarvestTheme.Spacing.xxs)
                }
            }

            Spacer(minLength: HarvestTheme.Spacing.sm)

            if joined {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    .padding(.top, HarvestTheme.Spacing.xxs)
            } else {
                Button("Join", action: onToggle)
                    .font(HarvestTheme.Typography.bodySmall.weight(.semibold))
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.xs)
                    .background(Capsule().fill(HarvestTheme.Colors.fieldGreen))
            }
        }
        .padding(HarvestTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: Green the empty state leaf**

In `FieldView.emptyState` (line 53), change the `Image(systemName: "leaf.circle")` foreground from `HarvestTheme.Colors.primary` to `HarvestTheme.Colors.fieldGreen`.

- [ ] **Step 3: Self-review**

Verify: `GlassCard` import no longer needed in `CommunityCard` (FieldView's `emptyState` still uses it — keep it compiling); `HarvestTheme.Radius.xl` exists (it does — used by `GlassCard`); no rose token replaced outside this file.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Field/FieldView.swift
git commit -m "feat(field): banner-image room cards with member counts and green identity"
```

---

### Task 5: iOS chat pagination — view model + view

**Files:**
- Modify: `Harvest/ViewModels/CommunityChatViewModel.swift`
- Modify: `Harvest/Views/Field/CommunityChatView.swift`

**Interfaces:**
- Consumes: `messagesPage` / `messagesByIds` / `members` (Task 3).
- Produces (Tasks 6-8 build on this exact view-model shape):
  - `messages: [CommunityMessage]` (ascending, oldest first)
  - `hasMore: Bool`, `isLoadingOlder: Bool`
  - `members: [CommunitySender]`
  - `referenced: [String: CommunityMessage]` (reply-preview cache, keyed by message id)
  - `loadOlder(communityId: String) async`
  - `pageSize: Int` constant = 50

- [ ] **Step 1: Rewrite `start` + add pagination state in the view model**

In `CommunityChatViewModel`, replace the property block (lines 7-11) and `start` (lines 22-41) with:

```swift
    var messages: [CommunityMessage] = []
    var prompts: [CommunityPrompt] = []
    var senders: [String: CommunitySender] = [:]
    var members: [CommunitySender] = []
    var referenced: [String: CommunityMessage] = [:]
    var draft: String = ""
    var error: String?
    var hasMore = false
    var isLoadingOlder = false

    let pageSize = 50
```

```swift
    func start(communityId: String) async {
        do {
            async let page = service.messagesPage(communityId: communityId, before: nil, limit: pageSize)
            async let pr = service.prompts(communityId: communityId)
            async let mem = service.members(communityId: communityId)
            let newest = try await page
            self.messages = newest.reversed()
            self.hasMore = newest.count == pageSize
            self.prompts = try await pr
            self.members = try await mem
        } catch {
            self.error = error.localizedDescription
        }
        await loadSenders(for: Set(messages.map(\.senderId)))
        await loadReferenced()
        channel = service.subscribe(communityId: communityId) { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == msg.id }) && !msg.isRemoved {
                    self.messages.append(msg)
                    await self.loadSenders(for: [msg.senderId])
                    await self.loadReferenced()
                }
            }
        }
    }

    func loadOlder(communityId: String) async {
        guard hasMore, !isLoadingOlder, let oldest = messages.first?.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older = try await service.messagesPage(communityId: communityId, before: oldest, limit: pageSize)
            hasMore = older.count == pageSize
            let existing = Set(messages.map(\.id))
            messages.insert(contentsOf: older.reversed().filter { !existing.contains($0.id) }, at: 0)
            await loadSenders(for: Set(older.map(\.senderId)))
            await loadReferenced()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Fetch originals for any quoted replies whose parent isn't loaded.
    private func loadReferenced() async {
        let loaded = Set(messages.map(\.id))
        let missing = Set(messages.compactMap(\.replyToId))
            .subtracting(loaded)
            .subtracting(referenced.keys)
        guard !missing.isEmpty else { return }
        if let rows = try? await service.messagesByIds(Array(missing)) {
            for row in rows { referenced[row.id] = row }
            await loadSenders(for: Set(rows.map(\.senderId)))
        }
    }
```

(`loadReferenced` is inert until Task 6 sends the first reply — safe to land now so pagination and replies don't collide in this file.)

- [ ] **Step 2: Add the "Load earlier" control + fix the autoscroll trigger in the view**

In `CommunityChatView`, inside the `LazyVStack` before the `if vm.messages.isEmpty` block, add:

```swift
                        if vm.hasMore {
                            Button {
                                Task { await vm.loadOlder(communityId: community.id) }
                            } label: {
                                if vm.isLoadingOlder {
                                    ProgressView().tint(HarvestTheme.Colors.fieldGreen)
                                } else {
                                    Label("Load earlier messages", systemImage: "arrow.up.circle")
                                        .font(HarvestTheme.Typography.caption)
                                        .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HarvestTheme.Spacing.xs)
                        }
```

Then change the autoscroll (lines 50-54) so prepending older messages does NOT yank the user to the bottom — scroll only when the *newest* message changes:

```swift
                .onChange(of: vm.messages.last?.id) { _, lastId in
                    if let lastId {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
```

- [ ] **Step 3: Self-review**

Check: `messages` stays ascending everywhere; dedup on prepend; `hasMore` false when a short page returns; no remaining call to the deleted `service.messages(`.

- [ ] **Step 4: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(field): paginate room chat (latest 50 + load earlier)"
```

---

### Task 6: iOS quote-replies

**Files:**
- Modify: `Harvest/ViewModels/CommunityChatViewModel.swift`
- Modify: `Harvest/Views/Field/CommunityChatView.swift`

**Interfaces:**
- Consumes: `post(...replyToId:mentions:)` (Task 3), `referenced` cache (Task 5).
- Produces: `replyTarget: CommunityMessage?` on the view model; `quotedMessage(for:) -> CommunityMessage?`.

- [ ] **Step 1: View model — reply target + send-through**

Add to `CommunityChatViewModel` properties:

```swift
    var replyTarget: CommunityMessage?
```

Add helper:

```swift
    /// The original message a reply points at, from loaded pages or the
    /// referenced cache. nil while it loads (bubble hides the quote briefly).
    func quotedMessage(for message: CommunityMessage) -> CommunityMessage? {
        guard let id = message.replyToId else { return nil }
        return messages.first(where: { $0.id == id }) ?? referenced[id]
    }
```

In `performSend`, change the `service.post` call and success path to:

```swift
            let sent = try await service.post(
                communityId: communityId,
                senderId: senderId,
                content: text,
                replyToId: replyTarget?.id,
                mentions: []
            )
            draft = ""
            pendingDraft = ""
            replyTarget = nil
```

(`mentions: []` becomes real in Task 7.)

- [ ] **Step 2: Composer reply bar**

In `CommunityChatView`, insert directly above `composer` in the `VStack` (after the error text block):

```swift
            if let target = vm.replyTarget {
                HStack(spacing: HarvestTheme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HarvestTheme.Colors.fieldGreen)
                        .frame(width: 3, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replying to \(vm.senders[target.senderId]?.nickname ?? "Member")")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                        Text(target.content)
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        vm.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.top, HarvestTheme.Spacing.xs)
            }
```

- [ ] **Step 3: Context-menu Reply + swipe-to-reply on bubbles**

In the `ForEach`'s `.contextMenu`, add as the FIRST item (before the report button):

```swift
                                    Button {
                                        vm.replyTarget = msg
                                    } label: {
                                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                                    }
```

Then wrap the `CommunityBubble` call with a swipe gesture. Replace the bubble instantiation in the `ForEach` so the row becomes:

```swift
                            SwipeToReply(onReply: { vm.replyTarget = msg }) {
                                CommunityBubble(
                                    message: msg,
                                    quoted: vm.quotedMessage(for: msg),
                                    quotedSenderName: vm.quotedMessage(for: msg).map {
                                        vm.senders[$0.senderId]?.nickname ?? "Member"
                                    },
                                    sender: vm.senders[msg.senderId],
                                    isMine: msg.senderId == userId,
                                    onTapSender: msg.senderId == userId
                                        ? nil
                                        : { Task { await openProfile(senderId: msg.senderId) } },
                                    onTapQuote: { originalId in
                                        if vm.messages.contains(where: { $0.id == originalId }) {
                                            withAnimation { proxy.scrollTo(originalId, anchor: .center) }
                                        }
                                    }
                                )
                            }
```

Add this helper view at file scope (below `ReportSheetItem`):

```swift
/// Drag-right-to-reply. Threshold 40pt; the row springs back either way.
private struct SwipeToReply<Content: View>: View {
    let onReply: () -> Void
    @ViewBuilder let content: Content

    @State private var offsetX: CGFloat = 0

    var body: some View {
        content
            .offset(x: offsetX)
            .gesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        guard value.translation.width > 0,
                              abs(value.translation.width) > abs(value.translation.height) else { return }
                        offsetX = min(value.translation.width * 0.5, 60)
                    }
                    .onEnded { value in
                        if offsetX > 40 { onReply() }
                        withAnimation(.spring(duration: 0.25)) { offsetX = 0 }
                    }
            )
    }
}
```

- [ ] **Step 4: Render the quote inside `CommunityBubble`**

Change `CommunityBubble`'s stored properties to:

```swift
    let message: CommunityMessage
    var quoted: CommunityMessage? = nil
    var quotedSenderName: String? = nil
    let sender: CommunitySender?
    let isMine: Bool
    var onTapSender: (() -> Void)? = nil
    var onTapQuote: ((String) -> Void)? = nil
```

Then, inside the bubble's `VStack` (line 235), insert ABOVE the `Text(message.content)`:

```swift
                if message.replyToId != nil {
                    HStack(spacing: HarvestTheme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(HarvestTheme.Colors.fieldGreen)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(quotedSenderName ?? "Member")
                                .font(HarvestTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                            Text(quoted.map { $0.isRemoved ? "Message removed" : $0.content } ?? "…")
                                .font(HarvestTheme.Typography.caption)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.sm)
                    .padding(.vertical, HarvestTheme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                            .fill(HarvestTheme.Colors.wineBlack.opacity(0.35))
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let id = message.replyToId { onTapQuote?(id) }
                    }
                }
```

Note: `HarvestTheme.Radius.md` — confirm it exists in `HarvestTheme.swift` (Radius enum ~line 190); if the mid step is named differently (e.g. only `sm`/`lg`), use `lg`.

- [ ] **Step 5: Self-review**

Check: reply target cleared on send AND on mindful-warning cancel path (add `vm.replyTarget` is preserved through the warning — `performSend` clears it only on success; on `CONTACT_INFO_BLOCKED` failure the target stays, which is correct); quote block sits inside the bubble background so mine/theirs colors still read; swipe gesture ignores vertical scrolling (`minimumDistance: 25` + horizontal dominance check).

- [ ] **Step 6: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(field): quote-replies — swipe or long-press to reply, tap quote to jump"
```

---

### Task 7: iOS @mentions

**Files:**
- Modify: `Harvest/ViewModels/CommunityChatViewModel.swift`
- Modify: `Harvest/Views/Field/CommunityChatView.swift`

**Interfaces:**
- Consumes: `members` (Task 5), `post(...mentions:)` (Task 3).
- Produces: `mentionSuggestions: [CommunitySender]`, `pickMention(_:)`, `mentionedNicknames(for:) -> [String]` on the view model; `MentionText` helper in the view file.

- [ ] **Step 1: View model — autocomplete + mention resolution**

Add properties:

```swift
    /// nickname (lowercased) → user id, accumulated as the sender picks
    /// suggestions. Filtered against the final text at send time.
    private var draftMentions: [String: String] = [:]
```

Add members/API:

```swift
    /// Non-empty while the draft ends in an "@query" token that matches members.
    var mentionSuggestions: [CommunitySender] {
        guard let query = currentMentionQuery() else { return [] }
        return members.filter { member in
            guard let nick = member.nickname, !nick.isEmpty else { return false }
            return query.isEmpty || nick.lowercased().hasPrefix(query)
        }
    }

    /// The trailing "@..." token of the draft, lowercased, or nil.
    private func currentMentionQuery() -> String? {
        guard let atIndex = draft.lastIndex(of: "@") else { return nil }
        let after = draft[draft.index(after: atIndex)...]
        // A space before "@" (or "@" at the start) begins a mention; a space
        // after it ends one.
        if atIndex != draft.startIndex {
            let before = draft[draft.index(before: atIndex)]
            guard before == " " || before == "\n" else { return nil }
        }
        guard !after.contains(" "), !after.contains("\n") else { return nil }
        return after.lowercased()
    }

    func pickMention(_ member: CommunitySender) {
        guard let nick = member.nickname, let atIndex = draft.lastIndex(of: "@") else { return }
        draft = String(draft[..<atIndex]) + "@" + nick + " "
        draftMentions[nick.lowercased()] = member.id
    }

    /// User ids whose "@nickname" is still present in the given text.
    private func mentions(in text: String) -> [String] {
        let lower = text.lowercased()
        return draftMentions.compactMap { nick, id in
            lower.contains("@" + nick) ? id : nil
        }
    }

    /// Nicknames to highlight in a message bubble, resolved from the
    /// mentions id array via the sender/member caches.
    func mentionedNicknames(for message: CommunityMessage) -> [String] {
        guard let ids = message.mentions, !ids.isEmpty else { return [] }
        return ids.compactMap { id in
            senders[id]?.nickname ?? members.first(where: { $0.id == id })?.nickname
        }
    }
```

In `performSend`, change `mentions: []` to `mentions: mentions(in: text)`, and clear the accumulator on success (next to `draft = ""`):

```swift
            draftMentions = [:]
```

- [ ] **Step 2: Suggestion strip above the composer**

In `CommunityChatView`, insert between the reply bar (Task 6) and `composer`:

```swift
            if !vm.mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        ForEach(vm.mentionSuggestions) { member in
                            Button {
                                vm.pickMention(member)
                            } label: {
                                Text("@\(member.nickname ?? "")")
                                    .font(HarvestTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(HarvestTheme.Colors.fieldGreenLight)
                                    .padding(.horizontal, HarvestTheme.Spacing.sm)
                                    .padding(.vertical, HarvestTheme.Spacing.xs)
                                    .background(Capsule().fill(HarvestTheme.Colors.fieldGreenSoft))
                            }
                        }
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                }
                .padding(.top, HarvestTheme.Spacing.xs)
            }
```

- [ ] **Step 3: Highlight mentions in bubbles + green edge when you're mentioned**

Add to `CommunityBubble`'s properties:

```swift
    var mentionNicknames: [String] = []
    var mentionsMe: Bool = false
```

Replace `Text(message.content)` with `MentionText(...)` — the text line becomes:

```swift
                MentionText(
                    content: message.content,
                    nicknames: mentionNicknames,
                    baseColor: isMine ? HarvestTheme.Colors.textOnRedPrimary : HarvestTheme.Colors.textPrimary
                )
```

(keep all the existing modifiers — font, padding, blur, background, overlay — attached to it exactly as they were on the `Text`), and extend the background overlay so a mention of the viewer gets a green edge. After the existing `.background(...)` modifier, add:

```swift
                    .overlay {
                        if mentionsMe {
                            bubble.stroke(HarvestTheme.Colors.fieldGreen.opacity(0.5), lineWidth: 1)
                        }
                    }
```

Add the helper at file scope:

```swift
/// Message text with "@nickname" spans tinted green. Falls back to plain
/// text when a mentioned user's nickname changed and no longer matches.
private struct MentionText: View {
    let content: String
    let nicknames: [String]
    let baseColor: Color

    var body: some View {
        Text(attributed)
            .font(HarvestTheme.Typography.bodyRegular)
            .foregroundStyle(baseColor)
    }

    private var attributed: AttributedString {
        var attr = AttributedString(content)
        for nick in nicknames where !nick.isEmpty {
            let needle = "@" + nick
            var searchStart = attr.startIndex
            while searchStart < attr.endIndex,
                  let range = attr[searchStart...].range(of: needle, options: [.caseInsensitive]) {
                attr[range].foregroundColor = HarvestTheme.Colors.fieldGreenLight
                attr[range].inlinePresentationIntent = .stronglyEmphasized
                searchStart = range.upperBound
            }
        }
        return attr
    }
}
```

Then pass the new arguments at the `CommunityBubble` call site (inside `SwipeToReply`):

```swift
                                    mentionNicknames: vm.mentionedNicknames(for: msg),
                                    mentionsMe: (msg.mentions ?? []).contains(userId),
```

(add them after `quotedSenderName:`; order must match the property declaration order used with the memberwise init — declare `mentionNicknames`/`mentionsMe` after `quotedSenderName` in the struct).

- [ ] **Step 4: Self-review**

Check: `MentionText` keeps the base font/color when no mentions; the `foregroundStyle(baseColor)` on the outer Text does not override per-range colors (AttributedString range attributes win — they do); mention accumulator survives the mindful-warning detour (it does — it's only cleared in `performSend` success).

- [ ] **Step 5: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(field): @mentions — autocomplete, stored ids, green highlights"
```

---

### Task 8: iOS reactions UI + realtime

**Files:**
- Modify: `Harvest/ViewModels/CommunityChatViewModel.swift`
- Modify: `Harvest/Views/Field/CommunityChatView.swift`

**Interfaces:**
- Consumes: `reactions(messageIds:)`, `addReaction`, `removeReaction`, `subscribeReactions` (Task 3); `CommunityReaction.curatedEmoji` (Task 2).
- Produces: `reactions: [String: [CommunityReaction]]`, `toggleReaction(emoji:message:userId:) async` on the view model; `ReactionChips` view.

- [ ] **Step 1: View model — reaction state, toggle, realtime**

Add properties:

```swift
    /// message id → reactions on it.
    var reactions: [String: [CommunityReaction]] = [:]
    private var reactionChannel: RealtimeChannelV2?
```

Add loading (call sites next) :

```swift
    private func loadReactions(for messageIds: [String]) async {
        guard !messageIds.isEmpty else { return }
        if let rows = try? await service.reactions(messageIds: messageIds) {
            var grouped = reactions
            for id in messageIds { grouped[id] = [] }
            for row in rows { grouped[row.messageId, default: []].append(row) }
            reactions = grouped
        }
    }

    private func applyReaction(_ r: CommunityReaction) {
        guard messages.contains(where: { $0.id == r.messageId }) else { return }
        var list = reactions[r.messageId] ?? []
        guard !list.contains(where: { $0.userId == r.userId && $0.emoji == r.emoji }) else { return }
        list.append(r)
        reactions[r.messageId] = list
    }

    private func dropReaction(_ r: CommunityReaction) {
        guard var list = reactions[r.messageId] else { return }
        list.removeAll { $0.userId == r.userId && $0.emoji == r.emoji }
        reactions[r.messageId] = list
    }

    func toggleReaction(emoji: String, message: CommunityMessage, userId: String) async {
        let mine = CommunityReaction(messageId: message.id, userId: userId, emoji: emoji, communityId: message.communityId)
        let alreadyMine = (reactions[message.id] ?? [])
            .contains(where: { $0.userId == userId && $0.emoji == emoji })
        // Optimistic; realtime echo is deduped by applyReaction/dropReaction.
        if alreadyMine {
            dropReaction(mine)
        } else {
            applyReaction(mine)
        }
        do {
            if alreadyMine {
                try await service.removeReaction(messageId: message.id, userId: userId, emoji: emoji)
            } else {
                try await service.addReaction(messageId: message.id, userId: userId, emoji: emoji)
            }
        } catch {
            // Roll back
            if alreadyMine { applyReaction(mine) } else { dropReaction(mine) }
            self.error = error.localizedDescription
        }
    }
```

Wire the loads and the channel:
- In `start`, after `await loadReferenced()`, add `await loadReactions(for: messages.map(\.id))`, then after the message `channel = ...` block add:

```swift
        reactionChannel = service.subscribeReactions(
            communityId: communityId,
            onInsert: { [weak self] r in
                Task { @MainActor in self?.applyReaction(r) }
            },
            onDelete: { [weak self] r in
                Task { @MainActor in self?.dropReaction(r) }
            }
        )
```

- In `loadOlder`, after `await loadReferenced()`, add `await loadReactions(for: older.map(\.id))`.
- In `stop()`, add:

```swift
        if let reactionChannel { service.unsubscribe(reactionChannel) }
        reactionChannel = nil
```

- [ ] **Step 2: Reaction palette in the context menu**

In the `ForEach`'s `.contextMenu`, add ABOVE the Reply button:

```swift
                                    ControlGroup {
                                        ForEach(CommunityReaction.curatedEmoji, id: \.self) { emoji in
                                            Button(emoji) {
                                                Task { await vm.toggleReaction(emoji: emoji, message: msg, userId: userId) }
                                            }
                                        }
                                    }
                                    .controlGroupStyle(.palette)
```

- [ ] **Step 3: Chips under bubbles**

Below the `CommunityBubble(...)` call (still inside `SwipeToReply`'s content, so wrap both in a `VStack`), the row becomes:

```swift
                            SwipeToReply(onReply: { vm.replyTarget = msg }) {
                                VStack(alignment: msg.senderId == userId ? .trailing : .leading, spacing: 2) {
                                    CommunityBubble( /* existing arguments unchanged */ )
                                    if let rs = vm.reactions[msg.id], !rs.isEmpty {
                                        ReactionChips(
                                            reactions: rs,
                                            myUserId: userId,
                                            isMine: msg.senderId == userId
                                        ) { emoji in
                                            Task { await vm.toggleReaction(emoji: emoji, message: msg, userId: userId) }
                                        }
                                    }
                                }
                            }
```

Add at file scope:

```swift
/// Grouped emoji counts under a bubble. Your own reactions tint green.
private struct ReactionChips: View {
    let reactions: [CommunityReaction]
    let myUserId: String
    let isMine: Bool
    let onToggle: (String) -> Void

    private var grouped: [(emoji: String, count: Int, mine: Bool)] {
        CommunityReaction.curatedEmoji.compactMap { emoji in
            let matching = reactions.filter { $0.emoji == emoji }
            guard !matching.isEmpty else { return nil }
            return (emoji, matching.count, matching.contains { $0.userId == myUserId })
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(grouped, id: \.emoji) { group in
                Button {
                    onToggle(group.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(group.emoji).font(.system(size: 12))
                        Text("\(group.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(group.mine ? HarvestTheme.Colors.fieldGreenLight : HarvestTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(group.mine ? HarvestTheme.Colors.fieldGreenSoft : HarvestTheme.Colors.wineRaised)
                    )
                    .overlay(
                        Capsule().stroke(group.mine ? HarvestTheme.Colors.fieldGreenBorder : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, isMine ? 0 : 38)   // align under bubble, past avatar
        .padding(.trailing, isMine ? 38 : 0)
    }
}
```

- [ ] **Step 4: Self-review**

Check: optimistic toggle + realtime echo can't double-count (applyReaction dedups); rollback path restores exactly the prior state; `stop()` tears down both channels; chips align under the bubble on both sides.

- [ ] **Step 5: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(field): curated reactions — palette on long-press, live chips"
```

---

### Task 9: Admin — tabs + Rooms list + create/edit/delete + image upload

**Files:**
- Modify: `admin/index.html`
- Modify: `admin/app.js`

**Interfaces:**
- Consumes: `communities` table (+`image_url`), `community-images` bucket (Task 1).
- Produces: tab switching (`switchTab(name)`), `loadRooms()`, `roomsCache` (array of community rows), `#rooms` container — Task 10's detail panels render inside room cards from this task.

- [ ] **Step 1: index.html — tabs, rooms container, styles**

In `<header>`, replace the `<h1>` line with:

```html
    <h1>Harvest <span id="page-title">Moderation</span></h1>
    <nav class="tabs">
      <button id="tab-moderation" class="tab active">Moderation</button>
      <button id="tab-rooms" class="tab">Rooms</button>
    </nav>
```

In `.controls`, add a New-room button (hidden by default) before `#toggle`:

```html
      <button id="new-room" class="primary" style="display:none">＋ New room</button>
```

After `<div id="list"></div>`, add:

```html
  <div id="room-form" style="display:none"></div>
  <div id="rooms" style="display:none"></div>
```

Add to the `:root` block: `--green: #4db380; --green-light: #7acca3;`

Append to the `<style>` block:

```css
    .tabs { display: flex; gap: 6px; }
    .tab { background: transparent; border-color: transparent; color: var(--text-dim); }
    .tab.active { border-color: var(--green); color: var(--text); }
    .room { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 16px; margin-bottom: 14px; }
    .room.inactive { opacity: 0.55; }
    .room-top { display: flex; gap: 16px; align-items: flex-start; }
    .room-thumb { width: 96px; height: 64px; object-fit: cover; border-radius: 10px; background: var(--raised); flex-shrink: 0; }
    .no-thumb { width: 96px; height: 64px; border-radius: 10px; background: var(--raised); display: grid; place-items: center; color: var(--green); font-size: 20px; flex-shrink: 0; }
    .pill.kind { background: rgba(77, 179, 128, 0.18); color: var(--green-light); }
    .pill.off { background: rgba(201, 169, 180, 0.15); color: var(--text-dim); }
    .form-card { background: var(--card); border: 1px solid var(--green); border-radius: 16px; padding: 16px; margin-bottom: 14px; }
    .form-card .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .form-card label { display: block; font-size: 12px; color: var(--text-dim); margin-bottom: 3px; }
    .form-card input, .form-card select, .form-card textarea {
      width: 100%; font: inherit; color: var(--text); background: var(--raised);
      border: 1px solid var(--border); border-radius: 10px; padding: 8px 10px;
    }
    .form-card textarea { grid-column: 1 / -1; resize: vertical; min-height: 60px; }
    button.green { background: var(--green); border-color: var(--green); color: #fff; }
```

- [ ] **Step 2: app.js — tab state and switching**

At the top, after the existing element lookups, add:

```js
const roomsEl = document.getElementById("rooms");
const roomFormEl = document.getElementById("room-form");
const newRoomBtn = document.getElementById("new-room");
const pageTitleEl = document.getElementById("page-title");
const tabModBtn = document.getElementById("tab-moderation");
const tabRoomsBtn = document.getElementById("tab-rooms");

let activeTab = "moderation";
let roomsCache = [];
```

Add near the bottom (before the existing listeners):

```js
function switchTab(name) {
  activeTab = name;
  const rooms = name === "rooms";
  tabModBtn.classList.toggle("active", !rooms);
  tabRoomsBtn.classList.toggle("active", rooms);
  pageTitleEl.textContent = rooms ? "Rooms" : "Moderation";
  listEl.style.display = rooms ? "none" : "";
  roomsEl.style.display = rooms ? "" : "none";
  roomFormEl.style.display = "none";
  toggleBtn.style.display = rooms ? "none" : "";
  newRoomBtn.style.display = rooms ? "" : "none";
  rooms ? loadRooms() : load();
}

tabModBtn.addEventListener("click", () => switchTab("moderation"));
tabRoomsBtn.addEventListener("click", () => switchTab("rooms"));
newRoomBtn.addEventListener("click", () => openRoomForm(null));
```

Change the `refreshBtn` listener to refresh the active tab:

```js
refreshBtn.addEventListener("click", () => (activeTab === "rooms" ? loadRooms() : load()));
```

- [ ] **Step 3: app.js — loadRooms + roomCard**

```js
async function loadRooms() {
  statusEl.textContent = "Loading rooms…";
  const { data, error } = await supabase
    .from("communities")
    .select("*")
    .order("display_order", { ascending: true });
  if (error) {
    fatal("Rooms query failed: " + error.message);
    return;
  }
  roomsCache = data || [];
  roomsEl.innerHTML = roomsCache.map(roomCard).join("") ||
    `<div class="empty">No rooms yet. Create one!</div>`;
  roomsEl.querySelectorAll("[data-raction]").forEach((btn) => {
    btn.addEventListener("click", () => onRoomAction(btn.dataset.raction, btn.dataset.id));
  });
  statusEl.textContent = `${roomsCache.length} rooms`;
}

function roomCard(c) {
  const thumb = c.image_url
    ? `<img class="room-thumb" src="${escape(c.image_url)}" alt="" />`
    : `<div class="no-thumb">🌱</div>`;
  return `
    <div class="room ${c.is_active ? "" : "inactive"}" id="room-${c.id}">
      <div class="room-top">
        ${thumb}
        <div class="meta">
          <div class="name">${escape(c.name)}
            <span class="pill kind">${escape(c.kind)}</span>
            ${c.is_active ? "" : `<span class="pill off">inactive</span>`}
          </div>
          <div class="sub">/${escape(c.slug)} · ${c.member_count ?? 0} members · order ${c.display_order ?? 0}</div>
          ${c.description ? `<div class="desc">${escape(c.description)}</div>` : ""}
          <div class="actions">
            <button class="ghost" data-raction="detail" data-id="${c.id}">Members &amp; chat</button>
            <button data-raction="edit" data-id="${c.id}">Edit</button>
            <button data-raction="toggle-active" data-id="${c.id}">${c.is_active ? "Deactivate" : "Activate"}</button>
            <button class="danger" data-raction="delete" data-id="${c.id}">Delete</button>
          </div>
        </div>
      </div>
      <div class="room-detail" id="detail-${c.id}"></div>
    </div>`;
}
```

(`data-raction` — distinct attribute so moderation's `[data-action]` wiring never double-binds these buttons. The `detail` action and `.room-detail` div are Task 10's mount points; in this task `detail` may show `alert("coming next")` or be left unhandled.)

- [ ] **Step 4: app.js — create/edit form + image upload + save**

```js
function openRoomForm(room) {
  const c = room || {};
  roomFormEl.style.display = "";
  roomFormEl.innerHTML = `
    <div class="form-card">
      <div class="grid">
        <div><label>Name</label><input id="rf-name" value="${escape(c.name || "")}" /></div>
        <div><label>Slug</label><input id="rf-slug" value="${escape(c.slug || "")}" placeholder="auto from name" /></div>
        <div><label>Kind</label>
          <select id="rf-kind">
            ${["everyone", "seeking_connection", "relationship_stage", "peer"]
              .map((k) => `<option value="${k}" ${c.kind === k ? "selected" : ""}>${k}</option>`).join("")}
          </select>
        </div>
        <div><label>Display order</label><input id="rf-order" type="number" value="${c.display_order ?? 0}" /></div>
        <textarea id="rf-desc" placeholder="Description">${escape(c.description || "")}</textarea>
        <div><label>Banner image</label><input id="rf-image" type="file" accept="image/*" /></div>
        <div style="align-self:end; display:flex; gap:8px; justify-content:flex-end;">
          <button class="ghost" id="rf-cancel">Cancel</button>
          <button class="green" id="rf-save">${c.id ? "Save changes" : "Create room"}</button>
        </div>
      </div>
    </div>`;
  document.getElementById("rf-cancel").addEventListener("click", () => {
    roomFormEl.style.display = "none";
  });
  document.getElementById("rf-save").addEventListener("click", () => saveRoom(c.id || null, c.image_url || null));
  roomFormEl.scrollIntoView({ behavior: "smooth" });
}

const slugify = (s) =>
  s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");

async function saveRoom(id, existingImageUrl) {
  const name = document.getElementById("rf-name").value.trim();
  if (!name) return alert("Name is required.");
  const slug = document.getElementById("rf-slug").value.trim() || slugify(name);
  const row = {
    name,
    slug,
    kind: document.getElementById("rf-kind").value,
    display_order: parseInt(document.getElementById("rf-order").value, 10) || 0,
    description: document.getElementById("rf-desc").value.trim() || null,
    image_url: existingImageUrl,
  };

  try {
    const file = document.getElementById("rf-image").files[0];
    if (file) {
      const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
      const path = `${slug}-${Date.now()}.${ext}`;
      const { error: upErr } = await supabase.storage
        .from("community-images")
        .upload(path, file, { upsert: true });
      if (upErr) throw upErr;
      row.image_url = supabase.storage.from("community-images").getPublicUrl(path).data.publicUrl;
    }

    const { error } = id
      ? await supabase.from("communities").update(row).eq("id", id)
      : await supabase.from("communities").insert({ ...row, is_active: true });
    if (error) throw error;

    roomFormEl.style.display = "none";
    await loadRooms();
  } catch (e) {
    fatal("Save failed: " + (e.message || e));
  }
}
```

- [ ] **Step 5: app.js — room actions (edit / toggle / delete)**

```js
async function onRoomAction(action, id) {
  const room = roomsCache.find((c) => c.id === id);
  if (!room) return;
  try {
    if (action === "edit") {
      openRoomForm(room);
    } else if (action === "toggle-active") {
      const { error } = await supabase
        .from("communities")
        .update({ is_active: !room.is_active })
        .eq("id", id);
      if (error) throw error;
      await loadRooms();
    } else if (action === "delete") {
      if (!confirm(
        `PERMANENTLY delete "${room.name}"?\n\nThis removes the room, ALL its messages, reactions, and memberships. ` +
        `Prefer Deactivate to hide it without losing history.`
      )) return;
      // Explicit ordered deletes — don't rely on FK cascade config.
      await supabase.from("community_message_reactions").delete().eq("community_id", id);
      await supabase.from("community_messages").delete().eq("community_id", id);
      await supabase.from("community_members").delete().eq("community_id", id);
      await supabase.from("community_prompts").delete().eq("community_id", id);
      const { error } = await supabase.from("communities").delete().eq("id", id);
      if (error) throw error;
      await loadRooms();
    } else if (action === "detail") {
      await toggleRoomDetail(id); // Task 10; stub as alert("Detail panel lands in the next task") until then
    }
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}
```

- [ ] **Step 6: Verify in the browser**

Run `python -m http.server 8787` in `admin/` (needs `config.js` populated), open `http://localhost:8787`, and confirm:
1. Moderation tab renders exactly as before (regression check).
2. Rooms tab lists the 5 seeded rooms, ordered.
3. Create a room named "Test Garden" with an image → appears with thumbnail; check `communities` row + `community-images` object in the dashboard.
4. Edit it (change description) → persists. Deactivate → grays out, pill shows.
5. Delete "Test Garden" → confirm dialog mentions cascade; row gone.

- [ ] **Step 7: Commit**

```bash
git add admin/index.html admin/app.js
git commit -m "feat(admin): Rooms tab — create/edit/delete rooms with banner upload"
```

---

### Task 10: Admin — room detail: members + chat moderation

**Files:**
- Modify: `admin/index.html` (styles only)
- Modify: `admin/app.js`

**Interfaces:**
- Consumes: `roomsCache`, `.room-detail` mount divs, `onRoomAction` "detail" branch (Task 9).
- Produces: `toggleRoomDetail(id)`, `onDetailAction(...)` — terminal; nothing depends on this task.

- [ ] **Step 1: Styles**

Append to `admin/index.html`'s `<style>`:

```css
    .room-detail { margin-top: 14px; display: none; }
    .room-detail.open { display: block; }
    .panel { background: var(--raised); border-radius: 12px; padding: 12px; margin-top: 10px; }
    .panel h3 { margin: 0 0 8px; font-size: 14px; color: var(--green-light); }
    .mrow { display: flex; align-items: center; gap: 10px; padding: 6px 0; border-top: 1px solid var(--border); font-size: 14px; flex-wrap: wrap; }
    .mrow:first-of-type { border-top: none; }
    .mrow .who { font-weight: 600; min-width: 120px; }
    .mrow .when { color: var(--text-dim); font-size: 12px; }
    .mrow .txt { flex: 1 1 100%; color: var(--text-dim); }
    .mrow .txt.removed { text-decoration: line-through; opacity: 0.6; }
    .mrow button { padding: 3px 10px; font-size: 12px; }
    .pill.mod { background: rgba(122, 204, 163, 0.2); color: var(--green-light); }
    .pill.room-banned { background: rgba(251, 46, 99, 0.2); color: var(--rose-light); }
```

- [ ] **Step 2: app.js — detail state + loader**

Add state near `roomsCache`:

```js
let openDetailId = null;
let detailMsgLimit = 100;
```

Add:

```js
async function toggleRoomDetail(id) {
  const panel = document.getElementById(`detail-${id}`);
  if (openDetailId === id) {
    panel.classList.remove("open");
    openDetailId = null;
    return;
  }
  document.querySelectorAll(".room-detail.open").forEach((p) => p.classList.remove("open"));
  openDetailId = id;
  detailMsgLimit = 100;
  await renderRoomDetail(id);
}

async function renderRoomDetail(id) {
  const panel = document.getElementById(`detail-${id}`);
  panel.classList.add("open");
  panel.innerHTML = `<div class="panel">Loading…</div>`;

  const [membersRes, msgsRes] = await Promise.all([
    supabase
      .from("community_members")
      .select("user_id, role, status, joined_at, users!user_id(nickname)")
      .eq("community_id", id)
      .order("joined_at", { ascending: true }),
    supabase
      .from("community_messages")
      .select("id, sender_id, content, is_removed, created_at, users!sender_id(nickname)")
      .eq("community_id", id)
      .order("created_at", { ascending: false })
      .limit(detailMsgLimit),
  ]);

  if (membersRes.error || msgsRes.error) {
    panel.innerHTML = `<div class="panel">Load failed: ${escape((membersRes.error || msgsRes.error).message)}</div>`;
    return;
  }

  const members = membersRes.data || [];
  const msgs = msgsRes.data || [];

  panel.innerHTML = `
    <div class="panel">
      <h3>Members (${members.length})</h3>
      ${members.map((m) => memberRow(id, m)).join("") || `<div class="sub">Nobody here yet.</div>`}
    </div>
    <div class="panel">
      <h3>Latest messages</h3>
      ${msgs.map((m) => messageRow(id, m)).join("") || `<div class="sub">No messages yet.</div>`}
      ${msgs.length >= detailMsgLimit
        ? `<div class="actions"><button class="ghost" data-daction="older" data-room="${id}">Load older</button></div>`
        : ""}
    </div>`;

  panel.querySelectorAll("[data-daction]").forEach((btn) => {
    btn.addEventListener("click", () =>
      onDetailAction(btn.dataset.daction, btn.dataset.room, btn.dataset.user, btn.dataset.msg));
  });
}

function memberRow(roomId, m) {
  const nick = escape(m.users?.nickname || m.user_id);
  const rolePill = m.role === "moderator" ? `<span class="pill mod">mod</span>` : "";
  const statusPill = m.status === "banned" ? `<span class="pill room-banned">banned</span>`
    : m.status === "left" ? `<span class="pill off">left</span>` : "";
  const actions =
    m.status === "banned"
      ? `<button data-daction="unban" data-room="${roomId}" data-user="${m.user_id}">Unban</button>`
      : `<button data-daction="ban" data-room="${roomId}" data-user="${m.user_id}">Ban</button>` +
        (m.role === "moderator"
          ? `<button class="ghost" data-daction="demote" data-room="${roomId}" data-user="${m.user_id}">Demote</button>`
          : `<button class="ghost" data-daction="promote" data-room="${roomId}" data-user="${m.user_id}">Make mod</button>`);
  return `
    <div class="mrow">
      <span class="who">${nick}${rolePill}${statusPill}</span>
      <span class="when">${fmtDate(m.joined_at)}</span>
      ${actions}
    </div>`;
}

function messageRow(roomId, m) {
  const nick = escape(m.users?.nickname || m.sender_id);
  return `
    <div class="mrow">
      <span class="who">${nick}</span>
      <span class="when">${fmtDate(m.created_at)}</span>
      ${m.is_removed
        ? `<button data-daction="restore" data-room="${roomId}" data-msg="${m.id}">Restore</button>`
        : `<button data-daction="remove" data-room="${roomId}" data-msg="${m.id}">Remove</button>
           <button class="danger" data-daction="ban" data-room="${roomId}" data-user="${m.sender_id}">Ban author</button>`}
      <span class="txt ${m.is_removed ? "removed" : ""}">${escape(m.content)}</span>
    </div>`;
}
```

- [ ] **Step 3: app.js — detail actions**

```js
async function onDetailAction(action, roomId, userId, msgId) {
  try {
    if (action === "older") {
      detailMsgLimit += 100;
    } else if (action === "ban") {
      if (!confirm("Ban this user from this room?")) return;
      const { error } = await supabase
        .from("community_members")
        .update({ status: "banned" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "unban") {
      const { error } = await supabase
        .from("community_members")
        .update({ status: "active" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "promote" || action === "demote") {
      const { error } = await supabase
        .from("community_members")
        .update({ role: action === "promote" ? "moderator" : "member" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "remove") {
      if (!confirm("Remove this message for everyone?")) return;
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: true, removed_at: new Date().toISOString() })
        .eq("id", msgId);
      if (error) throw error;
    } else if (action === "restore") {
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: false, removed_at: null })
        .eq("id", msgId);
      if (error) throw error;
    }
    await renderRoomDetail(roomId);
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}
```

Also remove the Task 9 stub in `onRoomAction`'s `detail` branch if one was left (it must call `toggleRoomDetail(id)`).

- [ ] **Step 4: Verify in the browser**

With the local server running:
1. Expand "Members & chat" on a seeded room → both panels render.
2. Ban then unban a member (use a test account) → pills flip; verify the row in `community_members` from the dashboard.
3. Make mod / demote → `role` flips in the dashboard.
4. Remove a message → strikethrough + Restore appears; the iOS query filters `is_removed`, so it would vanish from the app. Restore it.
5. Only one detail panel open at a time; "Load older" appears only at 100+ messages.
6. If the embedded `users!user_id(...)` join errors with a relationship hint, use the FK-name form from the error message's hint (PostgREST suggests the exact string) — adjust both selects the same way.

- [ ] **Step 5: Commit**

```bash
git add admin/index.html admin/app.js
git commit -m "feat(admin): room detail — member management + proactive chat moderation"
```

---

### Task 11: Docs — admin README + Xcode verification checklist

**Files:**
- Modify: `admin/README.md` (append a Rooms section)
- Create: `docs/verification/2026-08-01-community-rooms-xcode-checklist.md`

**Interfaces:**
- Consumes: everything above. Produces: the checklist the Mac session will execute.

- [ ] **Step 1: Append to `admin/README.md`**

```markdown
## Rooms tab

Create, edit, image, deactivate, and delete community rooms; manage members
(ban/unban, promote/demote moderators) and moderate chat (remove/restore
messages) from a room's "Members & chat" panel.

Room banner images upload to the public `community-images` storage bucket.
Prefer **Deactivate** over Delete — Delete permanently removes the room and
all its messages, reactions, and memberships.
```

- [ ] **Step 2: Write the Xcode checklist**

Create `docs/verification/2026-08-01-community-rooms-xcode-checklist.md`:

```markdown
# Xcode verification — community rooms redesign (2026-08-01)

Swift shipped un-compiled (no Mac in the dev loop). Run on a Mac before merge
to TestFlight. Needs two test accounts that share at least one room.

## Build
- [ ] Project compiles with zero new warnings in Field/Community files.

## Field directory
- [ ] Rooms with an image show the banner; rooms without show the leaf placeholder.
- [ ] Member count renders ("N gardeners"); joining updates it after refresh.
- [ ] Join button is green; joined cards show green border + "Tap to open room".

## Pagination
- [ ] Room with >50 messages: latest 50 load, "Load earlier messages" appears.
- [ ] Loading earlier prepends without scroll jump; button disappears on last page.
- [ ] New incoming message still autoscrolls to bottom.

## Replies
- [ ] Swipe right on a bubble sets the reply bar; X clears it.
- [ ] Context menu → Reply does the same.
- [ ] Sent reply renders quoted sender + snippet with green bar (both mine/theirs bubbles).
- [ ] Tapping the quote scrolls to the original when loaded.
- [ ] Reply to a message, then admin-remove the original → quote shows "Message removed".

## Mentions
- [ ] Typing "@" then letters shows matching member chips; picking inserts "@Nick ".
- [ ] Sent message: mention renders green+bold for everyone.
- [ ] On the mentioned account: bubble has a green edge.
- [ ] Deleting the "@Nick" text before sending drops the id from mentions (check row in DB).

## Reactions
- [ ] Long-press → palette row with exactly 🌱 💚 🌻 😂 👏 🤔.
- [ ] Toggling on/off updates chips instantly (optimistic) and syncs to the
      second account live (insert AND delete).
- [ ] Own reactions tint green; counts aggregate across users.
- [ ] Airplane-mode toggle rolls back and shows the inline error.

## Regressions
- [ ] Icebreakers sheet, mindful warning + blur, contact-info block message,
      report message, tap-avatar profile sheet all still work.
- [ ] 1:1 Seed chat untouched.
```

- [ ] **Step 3: Commit**

```bash
git add admin/README.md docs/verification/2026-08-01-community-rooms-xcode-checklist.md
git commit -m "docs: admin rooms tab README + Xcode verification checklist"
```
