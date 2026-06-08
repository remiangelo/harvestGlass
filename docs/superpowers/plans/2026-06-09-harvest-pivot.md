# Harvest Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Harvest from a swipe/match dating app into a relationship-growth platform: Soil (values) · The Field (communities) · Gardener · Seeds (intentional connection requests) — removing swiping/matching entirely.

**Architecture:** SwiftUI iOS client + Supabase (Postgres + RLS + triggers + Edge Functions) + a static web admin panel. Seeds reuse the existing `matches`/`conversations`/`messages` machinery (a Seed accept creates a `matches` row, then `ChatService.ensureConversation` builds the chat). The Field is new tables (`communities`, `community_members`, `community_messages`) with a Postgres access-rules function gating which rooms a user may join, mirrored by a Swift helper for display. Moderation extends the existing `user_reports` + `moderation_queue` + admin panel.

**Tech Stack:** Swift 5.9 / SwiftUI (`@Observable` view models), Supabase Swift SDK, Postgres (plpgsql `security definer` functions, `pg_net` + Vault for push), Deno/TypeScript Edge Functions, vanilla JS admin panel.

---

## Environment Constraints (read first)

- **No macOS available.** Swift code cannot be compiled or run during implementation. Swift tasks therefore ship as complete, reviewed code with a per-task **Xcode verification checklist** to run later; they do NOT use a red/green test loop.
- **Runnable now:** SQL migrations, Edge Functions, and admin-panel JS. Apply SQL via `supabase db push` *or* by pasting into the Supabase Dashboard → SQL Editor (every migration is written idempotently so either path is safe). Verify with the SQL `Verify` query shown in each task.
- **Commit after every task.** Use the commit message shown.
- **Branch:** all work lands on `harvest-pivot` (already created).

## Phase / Dependency Order

1. **Phase 1 — Tab restructure & swipe teardown** (no deps)
2. **Phase 2 — Seeds** (depends on P1; adds `subscription_tiers.daily_seed_limit` used again in P5)
3. **Phase 3 — The Field** (depends on P1; independent of P2)
4. **Phase 4 — Relationship status** (depends on P3 for access recompute to matter)
5. **Phase 5 — Subscription tiers** (depends on P2 for the limit column)
6. **Phase 6 — Moderation & safety** (depends on P2 + P3 for message targets)

Each phase ends in working, shippable software.

---

## File Structure

**New Swift files**
- `Harvest/Models/Seed.swift` — Seed request model + status enum
- `Harvest/Services/SeedService.swift` — send/accept/decline/list Seeds
- `Harvest/ViewModels/SeedsViewModel.swift` — drives the Seeds tab
- `Harvest/Views/Seeds/SeedsView.swift` — Seeds tab (Requests / Conversations segments)
- `Harvest/Views/Seeds/SendSeedSheet.swift` — compose-and-send sheet on a profile
- `Harvest/Models/Community.swift` — Community + membership + message models
- `Harvest/Services/CommunityService.swift` — list/join/leave/post/subscribe
- `Harvest/Services/FieldAccess.swift` — Swift mirror of the access-rules function
- `Harvest/ViewModels/FieldViewModel.swift` — drives The Field tab
- `Harvest/ViewModels/CommunityChatViewModel.swift` — drives a single room
- `Harvest/Views/Field/FieldView.swift` — room directory (available/joined)
- `Harvest/Views/Field/CommunityChatView.swift` — room chat + icebreakers
- `Harvest/Views/Onboarding/RelationshipStatusStepView.swift` — onboarding step

**Modified Swift files**
- `Harvest/Views/MainTabView.swift` — new tab set + deep links
- `Harvest/ViewModels/OnboardingViewModel.swift` — relationship-status step/state
- `Harvest/Views/Profile/ProfileEditView.swift` — edit relationship status
- `Harvest/Models/UserProfile.swift` — `relationshipStatus` field
- `Harvest/Views/Values/ValuesView.swift` — Soil copy
- `Harvest/Views/Chat/ReportUserView.swift` — target-type aware reporting
- `Harvest/Services/SubscriptionService.swift` — expose `dailySeedLimit`

**New / modified backend**
- `supabase/migrations/20260609120000_seeds.sql` — seeds table, RLS, limit + push triggers, accept RPC, `subscription_tiers.daily_seed_limit`
- `supabase/migrations/20260609130000_the_field.sql` — communities tables, RLS, realtime, access function, room seed, prompts
- `supabase/migrations/20260609140000_relationship_status.sql` — `users.relationship_status`
- `supabase/migrations/20260609150000_subscription_tiers_pivot.sql` — tier rows + feature flags
- `supabase/migrations/20260609160000_moderation_pivot.sql` — report targets, community-message detection trigger, moderation_queue update
- `supabase/functions/send-push/index.ts` — add `seed` + `community` notification types
- `admin/app.js`, `admin/index.html`, `admin/schema.sql` — message removal, per-room ban, target grouping

---

# PHASE 1 — Tab Restructure & Swipe Teardown

**Outcome:** App shows **Soil · The Field · Gardener · Seeds · Profile**; no swipe deck is reachable; chat still works under the Seeds tab. Pure client work.

### Task 1.1: Add placeholder Field & Seeds shells so the tab bar compiles

**Files:**
- Create: `Harvest/Views/Field/FieldView.swift`
- Create: `Harvest/Views/Seeds/SeedsView.swift`

These are minimal shells; Phases 2 and 3 replace their bodies. Building the tab bar first (with shells) keeps Phase 1 self-contained and compilable.

- [ ] **Step 1: Create the Field shell**

```swift
// Harvest/Views/Field/FieldView.swift
import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(HarvestTheme.Colors.primary)
                Text("The Field")
                    .font(.title2.bold())
                Text("Community spaces are coming here.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("The Field")
        }
    }
}
```

- [ ] **Step 2: Create the Seeds shell that reuses the existing inbox for now**

The existing `MindfulMessagesView` is the conversation inbox. Phase 1 only renames the tab; we keep showing `MindfulMessagesView` inside a `SeedsView` wrapper so the rename is isolated and Phase 2 has one file to evolve.

```swift
// Harvest/Views/Seeds/SeedsView.swift
import SwiftUI

struct SeedsView: View {
    let authViewModel: AuthViewModel
    @Binding var pendingChatDeepLink: String?

    var body: some View {
        // Phase 2 replaces this body with the Requests / Conversations segments.
        MindfulMessagesView(
            authViewModel: authViewModel,
            pendingChatDeepLink: $pendingChatDeepLink
        )
    }
}
```

- [ ] **Step 3: Xcode verification checklist** (run later on Mac)
  - Both files compile.
  - `FieldView` renders the placeholder; `SeedsView` shows the existing inbox.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Field/FieldView.swift Harvest/Views/Seeds/SeedsView.swift
git commit -m "feat(field,seeds): add tab shells for pivot"
```

### Task 1.2: Rewire MainTabView to the new five tabs

**Files:**
- Modify: `Harvest/Views/MainTabView.swift:32-82`

- [ ] **Step 1: Replace the `TabView` body and deep-link handler**

Replace the `body`'s `TabView { … }` block (lines 33-56) and `handleDeepLink` (lines 70-82) with:

```swift
        TabView(selection: $selection) {
            Tab("Soil", systemImage: "heart.text.square.fill", value: 0) {
                ValuesView(authViewModel: authViewModel)
            }

            Tab("The Field", systemImage: "leaf.circle.fill", value: 1) {
                FieldView(authViewModel: authViewModel)
            }

            Tab("Gardener", systemImage: "leaf.fill", value: 2) {
                GardenerChatView(authViewModel: authViewModel)
            }

            Tab("Seeds", systemImage: "bubble.left.fill", value: 3) {
                SeedsView(
                    authViewModel: authViewModel,
                    pendingChatDeepLink: $pendingChatDeepLink
                )
            }

            Tab("Profile", systemImage: "person.fill", value: 4) {
                ProfileView(authViewModel: authViewModel)
            }
        }
        .tint(HarvestTheme.Colors.primary)
        .onReceive(NotificationCenter.default.publisher(for: .harvestDeepLink)) { note in
            guard let link = note.userInfo?["deepLink"] as? String else { return }
            handleDeepLink(link)
        }
        .fullScreenCover(isPresented: $showDifferentiation) {
            DifferentiationView {
                UserDefaults.standard.set(true, forKey: "hasSeenDifferentiation")
                showDifferentiation = false
                selection = 1   // land on The Field after the intro
            }
        }
    }

    private func handleDeepLink(_ link: String) {
        if link.hasPrefix("chat:") {
            let conversationId = String(link.dropFirst("chat:".count))
            selection = 3
            pendingChatDeepLink = conversationId
        } else if link.hasPrefix("seed:") || link == "seeds" || link.hasPrefix("match:") {
            selection = 3            // all connection events open the Seeds tab
        } else if link == "gardener" {
            selection = 2
        } else if link.hasPrefix("community:") {
            selection = 1            // Phase 3 deep-links into the room
        }
    }
```

- [ ] **Step 2: Update the default selection**

Change line 6 `@State private var selection: Int = 1` — value `1` is now The Field, which is a good default landing tab. Leave as-is (intentional).

- [ ] **Step 3: Xcode verification checklist**
  - Tab bar shows Soil · The Field · Gardener · Seeds · Profile in that order.
  - Soil opens the existing values screen; Seeds opens the existing inbox.
  - A `chat:` push deep-links to the Seeds tab and opens the conversation.
  - No reference to `DiscoverView` remains in this file.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/MainTabView.swift
git commit -m "feat(tabs): replace swipe tab with Soil/Field/Seeds layout"
```

### Task 1.3: Retire the swipe deck from the app flow

**Files:**
- Modify: `Harvest/Views/Discover/DiscoverView.swift`, `SwipeCardView.swift`, `MatchModalView.swift` (remove from build)
- Search-verify: no remaining references

The `swipes`/`matches` DB tables stay (Seeds reuses `matches`). We only remove the swipe UI from the app.

- [ ] **Step 1: Find every reference to the swipe deck**

Run (ripgrep): search the `Harvest/` tree for `DiscoverView`, `SwipeCardView`, `MatchModalView`, `DiscoverViewModel`, `SwipeService`.
Expected after Task 1.2: the only references are within the `Discover/` folder itself and `DiscoverViewModel`/`SwipeService`.

- [ ] **Step 2: Delete the swipe-only views**

```bash
git rm Harvest/Views/Discover/DiscoverView.swift \
       Harvest/Views/Discover/SwipeCardView.swift \
       Harvest/Views/Discover/MatchModalView.swift
```

Keep `Harvest/Views/Discover/ProfileDetailView.swift` — Phase 2 reuses it for "Send a Seed".

- [ ] **Step 3: Delete the swipe view model (no longer referenced)**

```bash
git rm Harvest/ViewModels/DiscoverViewModel.swift
```

Leave `Harvest/Services/SwipeService.swift` in place for now ONLY if other files reference it; if Step 1 showed no references outside the deleted files, also `git rm Harvest/Services/SwipeService.swift`.

- [ ] **Step 4: Xcode verification checklist**
  - Project builds with the three deck files removed.
  - `ProfileDetailView` still compiles (used by Seeds in Phase 2).
  - No dead references (Xcode shows zero "cannot find … in scope").
  - Remove the deleted files from the Xcode project file membership if not using folder-references (note for the Mac step).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove swipe deck UI from app flow"
```

### Task 1.4: Apply Soil copy to the Values screen

**Files:**
- Modify: `Harvest/Views/Values/ValuesView.swift`

Renaming the tab (Task 1.2) is done; this updates the on-screen language to the Soil framing. No logic changes. Do NOT call it "Growth" — the journey modules aren't built.

- [ ] **Step 1: Update headers / intro copy**

In `ValuesView`, update the screen's title/intro text to the Soil language. Keep the existing "I Bring" / "I Need" section structure; relabel the screen header and any subtitle:
  - Screen title / header: **"Your relational soil"**
  - Subtitle (if a subtitle/intro line exists): **"Discover the conditions where love grows. Understand what you bring and what helps you thrive."**
  - Section headers: **"What I Bring"** and **"What I Need"** (if not already worded this way).

Leave the radar graph, compatibility, and questions untouched.

- [ ] **Step 2: Xcode verification checklist**
  - The Soil tab shows the "Your relational soil" header and the new subtitle.
  - No occurrence of the word "Growth" was introduced.
  - Radar/compatibility/questions still function.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Views/Values/ValuesView.swift
git commit -m "feat(soil): apply Soil copy to the values screen"
```

---

# PHASE 2 — Seeds (replaces matching)

**Outcome:** Users send a Seed (an opening message) from a profile; recipients accept (chat opens) or decline; daily send limit enforced per subscription tier; receiving is unlimited.

### Task 2.1: Create the seeds migration (table, RLS, limit, push, accept RPC)

**Files:**
- Create: `supabase/migrations/20260609120000_seeds.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Seeds: intentional connection requests that replace swipe→match.
-- A Seed is a one-way request carrying an opening message. On accept it
-- creates a matches row + conversation, reusing all existing chat machinery.

-- Per-tier daily send limit (Phase 5 sets the real numbers; default here so
-- the limit trigger works immediately on existing tiers).
alter table public.subscription_tiers
  add column if not exists daily_seed_limit int not null default 3;

create table if not exists public.seeds (
  id              uuid primary key default gen_random_uuid(),
  sender_id       uuid not null references public.users(id) on delete cascade,
  recipient_id    uuid not null references public.users(id) on delete cascade,
  opening_message text not null,
  status          text not null default 'pending'
                    check (status in ('pending','accepted','declined')),
  conversation_id uuid references public.conversations(id) on delete set null,
  created_at      timestamptz not null default now(),
  responded_at    timestamptz,
  check (sender_id <> recipient_id)
);

-- At most one OPEN (pending) seed per directed pair.
create unique index if not exists seeds_one_pending_per_pair
  on public.seeds (sender_id, recipient_id)
  where status = 'pending';

create index if not exists seeds_recipient_idx on public.seeds (recipient_id, status);
create index if not exists seeds_sender_idx    on public.seeds (sender_id, status);

alter table public.seeds enable row level security;

drop policy if exists seeds_select_own on public.seeds;
create policy seeds_select_own on public.seeds
  for select using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists seeds_insert_as_sender on public.seeds;
create policy seeds_insert_as_sender on public.seeds
  for insert with check (auth.uid() = sender_id);

-- Recipient may decline directly; accept goes through accept_seed() RPC.
drop policy if exists seeds_recipient_decline on public.seeds;
create policy seeds_recipient_decline on public.seeds
  for update using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

-- Enforce the sender's daily limit at insert time.
create or replace function enforce_seed_daily_limit() returns trigger
language plpgsql
security definer
as $$
declare
  v_limit int;
  v_sent_today int;
begin
  select coalesce(t.daily_seed_limit, 3)
    into v_limit
    from public.user_subscriptions us
    join public.subscription_tiers t on t.id = us.tier_id
    where us.user_id = NEW.sender_id and us.status = 'active'
    order by us.started_at desc
    limit 1;

  v_limit := coalesce(v_limit, 3);   -- no active subscription => free tier

  select count(*) into v_sent_today
    from public.seeds
    where sender_id = NEW.sender_id
      and created_at >= date_trunc('day', now());

  if v_sent_today >= v_limit then
    raise exception 'SEED_LIMIT_REACHED: daily limit of % seeds reached', v_limit
      using errcode = 'P0001';
  end if;

  return NEW;
end;
$$;

drop trigger if exists seeds_enforce_limit on public.seeds;
create trigger seeds_enforce_limit
  before insert on public.seeds
  for each row execute function enforce_seed_daily_limit();

-- Push the recipient when a Seed arrives (reuses call_send_push from the
-- push-notification-triggers migration).
create or replace function on_seed_after_insert() returns trigger
language plpgsql
security definer
as $$
declare
  v_sender_nickname text;
  v_enabled boolean;
begin
  select coalesce(notif_matches_enabled, true) into v_enabled
    from public.users where id = NEW.recipient_id;
  if not coalesce(v_enabled, true) then
    return NEW;
  end if;

  select coalesce(nickname, 'Someone') into v_sender_nickname
    from public.users where id = NEW.sender_id;

  perform call_send_push(
    recipient => NEW.recipient_id,
    ntype     => 'seed',
    title     => v_sender_nickname || ' sent you a Seed 🌱',
    body      => left(NEW.opening_message, 80),
    deep_link => 'seeds'
  );
  return NEW;
end;
$$;

drop trigger if exists seeds_after_insert on public.seeds;
create trigger seeds_after_insert
  after insert on public.seeds
  for each row execute function on_seed_after_insert();

-- Accept a Seed: create the match + conversation, plant the opening message,
-- and mark the seed accepted — all atomically. Caller must be the recipient.
create or replace function accept_seed(p_seed_id uuid)
returns uuid           -- conversation id
language plpgsql
security definer
as $$
declare
  v_seed public.seeds%rowtype;
  v_match_id uuid;
  v_convo_id uuid;
begin
  select * into v_seed from public.seeds where id = p_seed_id for update;
  if not found then
    raise exception 'SEED_NOT_FOUND';
  end if;
  if v_seed.recipient_id <> auth.uid() then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if v_seed.status <> 'pending' then
    raise exception 'SEED_NOT_PENDING';
  end if;

  insert into public.matches (user1_id, user2_id, is_active, matched_at)
    values (v_seed.sender_id, v_seed.recipient_id, true, now())
    returning id into v_match_id;

  insert into public.conversations (match_id, user1_id, user2_id, created_at, last_message_at, last_message_preview)
    values (v_match_id, v_seed.sender_id, v_seed.recipient_id, now(), now(), left(v_seed.opening_message, 100))
    returning id into v_convo_id;

  insert into public.messages (conversation_id, sender_id, content, message_type, created_at)
    values (v_convo_id, v_seed.sender_id, v_seed.opening_message, 'text', now());

  update public.seeds
    set status = 'accepted', conversation_id = v_convo_id, responded_at = now()
    where id = p_seed_id;

  return v_convo_id;
end;
$$;

grant execute on function accept_seed(uuid) to authenticated;

-- Make sure account deletion also clears seeds (defensive; FK cascade covers it).
-- Handled by on delete cascade above.
```

- [ ] **Step 2: Apply the migration**

Run: `supabase db push` — or paste the file into Dashboard → SQL Editor → Run.

- [ ] **Step 3: Verify the schema**

Run this query; expected: returns the `seeds` table columns and the `daily_seed_limit` column on tiers.

```sql
select column_name from information_schema.columns where table_name = 'seeds' order by 1;
select column_name from information_schema.columns
  where table_name = 'subscription_tiers' and column_name = 'daily_seed_limit';
-- accept_seed exists:
select proname from pg_proc where proname in ('accept_seed','enforce_seed_daily_limit','on_seed_after_insert');
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260609120000_seeds.sql
git commit -m "feat(seeds): add seeds table, daily-limit + push triggers, accept RPC"
```

### Task 2.2: Add the `seed` notification type to send-push

**Files:**
- Modify: `supabase/functions/send-push/index.ts`

- [ ] **Step 1: Inspect how types map to APNs payloads**

Open `supabase/functions/send-push/index.ts` and find the switch/lookup over notification `type` ('message' | 'match' | 'like'). Each builds an aps payload + deep link.

- [ ] **Step 2: Add a `seed` case**

Add a `seed` branch alongside `match` (same shape — alert title/body passed through, sound default, deep link `seeds`). Mirror the existing `match` case exactly, substituting the type string `seed`. If the function already passes `payload.title`/`payload.body` through generically, add `seed` to any allow-list of accepted types so it isn't rejected.

- [ ] **Step 3: Deploy & verify**

Run: `supabase functions deploy send-push`
Verify (replace placeholders): a test invocation with `"type":"seed"` returns 200, not "unsupported type".

```bash
curl -i -X POST "$SEND_PUSH_URL" \
  -H "Authorization: Bearer $SERVICE_ROLE_JWT" -H "Content-Type: application/json" \
  -d '{"recipient_user_id":"<a-test-user-with-no-device>","type":"seed","payload":{"title":"t","body":"b","deepLink":"seeds"}}'
```
Expected: HTTP 200 with a JSON body indicating no device tokens (not a 4xx "unsupported type").

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/send-push/index.ts
git commit -m "feat(push): support seed notification type"
```

### Task 2.3: Seed model

**Files:**
- Create: `Harvest/Models/Seed.swift`

- [ ] **Step 1: Write the model**

```swift
import Foundation

enum SeedStatus: String, Codable {
    case pending, accepted, declined
}

struct Seed: Identifiable, Codable, Equatable {
    let id: String
    let senderId: String
    let recipientId: String
    let openingMessage: String
    let status: SeedStatus
    let conversationId: String?
    let createdAt: String?
    let respondedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case openingMessage = "opening_message"
        case status
        case conversationId = "conversation_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}
```

- [ ] **Step 2: Xcode verification checklist** — file compiles; `Seed` decodes a row returned by the seeds table (snake_case keys).

- [ ] **Step 3: Commit**

```bash
git add Harvest/Models/Seed.swift
git commit -m "feat(seeds): add Seed model"
```

### Task 2.4: SeedService

**Files:**
- Create: `Harvest/Services/SeedService.swift`

Follows the `ChatService` struct pattern (`SupabaseManager.shared.client`).

- [ ] **Step 1: Write the service**

```swift
import Foundation
import Supabase

enum SeedError: LocalizedError {
    case dailyLimitReached
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "You've reached today's Seed limit. Upgrade or try again tomorrow."
        case .underlying(let m):
            return m
        }
    }
}

struct SeedService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Send a Seed (opening message) to another user.
    func sendSeed(senderId: String, recipientId: String, openingMessage: String) async throws {
        do {
            try await client
                .from("seeds")
                .insert([
                    "sender_id": senderId,
                    "recipient_id": recipientId,
                    "opening_message": openingMessage
                ])
                .execute()
        } catch {
            // Surface the daily-limit Postgres exception as a typed error.
            if "\(error)".contains("SEED_LIMIT_REACHED") {
                throw SeedError.dailyLimitReached
            }
            throw SeedError.underlying("\(error)")
        }
    }

    /// Accept a Seed via the RPC; returns the new conversation id.
    func acceptSeed(seedId: String) async throws -> String {
        let conversationId: String = try await client
            .rpc("accept_seed", params: ["p_seed_id": seedId])
            .execute()
            .value
        return conversationId
    }

    func declineSeed(seedId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("seeds")
            .update(["status": AnyJSON.string("declined"),
                     "responded_at": AnyJSON.string(now)])
            .eq("id", value: seedId)
            .execute()
    }

    /// Pending Seeds received by the user (incoming requests).
    func receivedPending(userId: String) async throws -> [Seed] {
        try await client
            .from("seeds")
            .select()
            .eq("recipient_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Pending Seeds the user has sent (outgoing requests).
    func sentPending(userId: String) async throws -> [Seed] {
        try await client
            .from("seeds")
            .select()
            .eq("sender_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
```

- [ ] **Step 2: Xcode verification checklist**
  - Compiles against the installed Supabase SDK (`.rpc(_:params:)`, `.from(_).insert(_)`).
  - `acceptSeed` decodes a bare `uuid` return as `String` (the RPC returns a scalar). If the SDK rejects scalar decoding, wrap the RPC to `returns table(conversation_id uuid)` and decode `[ [String:String] ]` — note for the Mac step.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Services/SeedService.swift
git commit -m "feat(seeds): add SeedService (send/accept/decline/list)"
```

### Task 2.5: SeedsViewModel

**Files:**
- Create: `Harvest/ViewModels/SeedsViewModel.swift`

- [ ] **Step 1: Write the view model**

```swift
import Foundation
import Observation

@Observable
final class SeedsViewModel {
    enum Segment { case requests, conversations }
    enum RequestKind { case received, sent }

    var segment: Segment = .requests
    var requestKind: RequestKind = .received
    var received: [Seed] = []
    var sent: [Seed] = []
    var isLoading = false
    var error: String?
    /// Set when a Seed is accepted so the view can route into the conversation.
    var openedConversationId: String?

    private let service = SeedService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let received = service.receivedPending(userId: userId)
            async let sent = service.sentPending(userId: userId)
            self.received = try await received
            self.sent = try await sent
        } catch {
            self.error = error.localizedDescription
        }
    }

    func accept(_ seed: Seed, userId: String) async {
        do {
            let convoId = try await service.acceptSeed(seedId: seed.id)
            received.removeAll { $0.id == seed.id }
            openedConversationId = convoId
        } catch {
            self.error = error.localizedDescription
        }
    }

    func decline(_ seed: Seed, userId: String) async {
        do {
            try await service.declineSeed(seedId: seed.id)
            received.removeAll { $0.id == seed.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Xcode verification checklist** — compiles; `@Observable` matches the codebase's other view models (e.g. `OnboardingViewModel`).

- [ ] **Step 3: Commit**

```bash
git add Harvest/ViewModels/SeedsViewModel.swift
git commit -m "feat(seeds): add SeedsViewModel"
```

### Task 2.6: SeedsView (Requests / Conversations)

**Files:**
- Modify: `Harvest/Views/Seeds/SeedsView.swift` (replace the Phase 1 shell body)

- [ ] **Step 1: Replace the shell with the segmented Seeds tab**

`Conversations` reuses the existing inbox view (`MindfulMessagesView`) so accepted chats keep working unchanged. `Requests` is new.

```swift
import SwiftUI

struct SeedsView: View {
    let authViewModel: AuthViewModel
    @Binding var pendingChatDeepLink: String?

    @State private var vm = SeedsViewModel()

    private var userId: String { authViewModel.userId ?? "" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $vm.segment) {
                    Text("Requests").tag(SeedsViewModel.Segment.requests)
                    Text("Conversations").tag(SeedsViewModel.Segment.conversations)
                }
                .pickerStyle(.segmented)
                .padding()

                switch vm.segment {
                case .requests:
                    requests
                case .conversations:
                    MindfulMessagesView(
                        authViewModel: authViewModel,
                        pendingChatDeepLink: $pendingChatDeepLink
                    )
                }
            }
            .navigationTitle("Seeds")
            .task { await vm.load(userId: userId) }
            .refreshable { await vm.load(userId: userId) }
            .navigationDestination(item: $vm.openedConversationId) { convoId in
                ChatDetailView(authViewModel: authViewModel, conversationId: convoId)
            }
        }
    }

    @ViewBuilder private var requests: some View {
        VStack(spacing: 0) {
            Picker("", selection: $vm.requestKind) {
                Text("Received").tag(SeedsViewModel.RequestKind.received)
                Text("Sent").tag(SeedsViewModel.RequestKind.sent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                let items = vm.requestKind == .received ? vm.received : vm.sent
                if items.isEmpty {
                    Text(vm.requestKind == .received ? "No new Seeds yet 🌱" : "No pending sent Seeds.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { seed in
                        SeedRow(
                            seed: seed,
                            isReceived: vm.requestKind == .received,
                            onAccept: { Task { await vm.accept(seed, userId: userId) } },
                            onDecline: { Task { await vm.decline(seed, userId: userId) } }
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct SeedRow: View {
    let seed: Seed
    let isReceived: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(seed.openingMessage).font(.body)
            if isReceived {
                HStack {
                    Button("Let It Grow", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .tint(HarvestTheme.Colors.primary)
                    Button("No Thanks", action: onDecline)
                        .buttonStyle(.bordered)
                }
            } else {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Xcode verification checklist**
  - Verify `authViewModel.userId` exists (used elsewhere); if the property differs, use the codebase's accessor for the current user id.
  - Verify `ChatDetailView`'s initializer signature matches `init(authViewModel:conversationId:)`; adjust to the real signature found in `Harvest/Views/Chat/ChatDetailView.swift`.
  - Requests segment lists received/sent; accept routes into the chat; decline removes the row.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Views/Seeds/SeedsView.swift
git commit -m "feat(seeds): Requests/Conversations Seeds tab"
```

### Task 2.7: "Send a Seed" from a profile

**Files:**
- Create: `Harvest/Views/Seeds/SendSeedSheet.swift`
- Modify: `Harvest/Views/Discover/ProfileDetailView.swift` (add the entry button)

- [ ] **Step 1: Write the compose sheet**

```swift
import SwiftUI

struct SendSeedSheet: View {
    let authViewModel: AuthViewModel
    let recipientId: String
    let recipientName: String
    var onSent: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var isSending = false
    @State private var error: String?

    private let service = SeedService()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plant a Seed with \(recipientName) 🌱")
                    .font(.headline)
                Text("Start with something intentional — a question or a shared value.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
                Spacer()
            }
            .padding()
            .navigationTitle("Send a Seed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
        }
    }

    private func send() async {
        guard let senderId = authViewModel.userId else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await service.sendSeed(
                senderId: senderId,
                recipientId: recipientId,
                openingMessage: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSent()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add the entry point to ProfileDetailView**

In `ProfileDetailView`, add `@State private var showSendSeed = false`, a primary button labeled **Send a Seed** that sets `showSendSeed = true`, and:

```swift
.sheet(isPresented: $showSendSeed) {
    SendSeedSheet(
        authViewModel: authViewModel,
        recipientId: profile.id,
        recipientName: profile.nickname ?? "this person"
    )
}
```

Replace any existing like/swipe buttons in this view with the single **Send a Seed** button. Use the property names actually present on the profile model shown in `ProfileDetailView`.

- [ ] **Step 3: Xcode verification checklist**
  - Opening a profile shows **Send a Seed**; tapping presents the sheet.
  - Sending inserts a row; hitting the daily limit shows the friendly limit message.
  - No like/super-like controls remain on the profile.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Seeds/SendSeedSheet.swift Harvest/Views/Discover/ProfileDetailView.swift
git commit -m "feat(seeds): send a Seed from a profile"
```

---

# PHASE 3 — The Field (communities)

**Outcome:** Users see the rooms they qualify for, join/leave them, and chat in realtime; icebreaker prompts surface on entry. MVP rooms: **Everyone's Field** + **Women+Men / Women+Women / Men+Men / Open Connections**.

> **Note:** this phase creates `users.relationship_status` (the access function needs it). Phase 4 adds only the onboarding UI, profile editing, and standards copy — no new column.

### Task 3.1: Create The Field migration (tables, access function, RLS, realtime, seed data)

**Files:**
- Create: `supabase/migrations/20260609130000_the_field.sql`

- [ ] **Step 1: Write the migration**

```sql
-- The Field: community spaces + membership + room chat + access rules.

-- Relationship status lives here because the access function depends on it.
alter table public.users
  add column if not exists relationship_status text;   -- single|dating|in_relationship|engaged|married

create table if not exists public.communities (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  name          text not null,
  description   text,
  kind          text not null default 'everyone'
                  check (kind in ('everyone','seeking_connection','relationship_stage','peer')),
  is_active     boolean not null default true,
  member_count  int not null default 0,
  display_order int not null default 0
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  role         text not null default 'member' check (role in ('member','moderator')),
  status       text not null default 'active' check (status in ('active','banned','left')),
  joined_at    timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.community_messages (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  sender_id    uuid not null references public.users(id) on delete cascade,
  content      text not null,
  is_removed   boolean not null default false,
  removed_by   uuid,
  removed_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists community_messages_room_idx
  on public.community_messages (community_id, created_at);

create table if not exists public.community_prompts (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid references public.communities(id) on delete cascade,  -- null = all rooms
  text         text not null,
  is_active    boolean not null default true
);

-- ── Access rules ──────────────────────────────────────────────────────────
-- Returns the communities a user MAY join, from gender + interested_in + status.
-- NOTE: confirm the exact gender / interested_in tokens stored by
-- GenderStepView / InterestedInStepView; normalization below covers common forms.
create or replace function available_communities(p_user uuid)
returns setof public.communities
language plpgsql
stable
security definer
as $$
declare
  v_gender   text;
  v_int      text[];
  v_status   text;
  is_woman   boolean;
  is_man     boolean;
  is_nb      boolean;
  wants_men   boolean;
  wants_women boolean;
  v_eligible boolean;   -- eligible for Seeking Connection rooms
begin
  select lower(coalesce(gender,'')),
         coalesce(interested_in, array[]::text[]),
         lower(coalesce(relationship_status,''))
    into v_gender, v_int, v_status
    from public.users where id = p_user;

  -- Normalize interested_in tokens to lowercase.
  v_int := array(select lower(x) from unnest(v_int) as x);

  is_woman := v_gender = any (array['woman','women','female','f']);
  is_man   := v_gender = any (array['man','men','male','m']);
  is_nb    := v_gender = any (array['non-binary','nonbinary','nb','enby','non binary']);

  wants_women := v_int && array['woman','women','female','f'];
  wants_men   := v_int && array['man','men','male','m'];

  -- Seeking Connection rooms require an active dating season.
  v_eligible := v_status in ('single','dating');

  return query
  select c.* from public.communities c
  where c.is_active and (
    c.kind = 'everyone'
    or (c.kind = 'seeking_connection' and v_eligible and (
          (c.slug = 'women-men'       and ((is_woman and wants_men) or (is_man and wants_women) or is_nb))
       or (c.slug = 'women-women'      and ((is_woman and wants_women) or is_nb))
       or (c.slug = 'men-men'          and ((is_man and wants_men) or is_nb))
       or (c.slug = 'open-connections')   -- catch-all for all eligible users
    ))
  )
  order by c.display_order;
end;
$$;
grant execute on function available_communities(uuid) to authenticated;

create or replace function can_join_community(p_user uuid, p_community uuid)
returns boolean language sql stable security definer as $$
  select exists (select 1 from available_communities(p_user) c where c.id = p_community);
$$;
grant execute on function can_join_community(uuid, uuid) to authenticated;

create or replace function is_active_member(p_user uuid, p_community uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.community_members
    where community_id = p_community and user_id = p_user and status = 'active'
  );
$$;
grant execute on function is_active_member(uuid, uuid) to authenticated;

-- ── RLS ──────────────────────────────────────────────────────────────────
alter table public.communities       enable row level security;
alter table public.community_members  enable row level security;
alter table public.community_messages enable row level security;
alter table public.community_prompts   enable row level security;

drop policy if exists communities_read on public.communities;
create policy communities_read on public.communities
  for select using (true);   -- directory is readable; app shows joinable vs available

drop policy if exists prompts_read on public.community_prompts;
create policy prompts_read on public.community_prompts
  for select using (true);

drop policy if exists members_read_own on public.community_members;
create policy members_read_own on public.community_members
  for select using (auth.uid() = user_id or is_active_member(auth.uid(), community_id));

drop policy if exists members_join on public.community_members;
create policy members_join on public.community_members
  for insert with check (auth.uid() = user_id and can_join_community(auth.uid(), community_id));

drop policy if exists members_update_own on public.community_members;
create policy members_update_own on public.community_members
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists messages_read on public.community_messages;
create policy messages_read on public.community_messages
  for select using (is_active_member(auth.uid(), community_id));

drop policy if exists messages_post on public.community_messages;
create policy messages_post on public.community_messages
  for insert with check (auth.uid() = sender_id and is_active_member(auth.uid(), community_id));

-- ── member_count maintenance ───────────────────────────────────────────────
create or replace function refresh_community_count() returns trigger
language plpgsql security definer as $$
begin
  update public.communities c
    set member_count = (
      select count(*) from public.community_members m
      where m.community_id = c.id and m.status = 'active'
    )
  where c.id = coalesce(NEW.community_id, OLD.community_id);
  return null;
end;
$$;
drop trigger if exists community_members_count on public.community_members;
create trigger community_members_count
  after insert or update or delete on public.community_members
  for each row execute function refresh_community_count();

-- ── Realtime for room chat ──────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='community_messages'
  ) then
    alter publication supabase_realtime add table public.community_messages;
  end if;
end $$;
alter table public.community_messages replica identity full;

-- ── Seed the MVP rooms ──────────────────────────────────────────────────────
insert into public.communities (slug, name, description, kind, display_order) values
  ('everyones-field','Everyone''s Field','General conversations about relationships, values, and intentional connection.','everyone',0),
  ('women-men','Women + Men Connections','For women interested in meeting men and men interested in meeting women.','seeking_connection',1),
  ('women-women','Women + Women Connections','For women interested in meeting women.','seeking_connection',2),
  ('men-men','Men + Men Connections','For men interested in meeting men.','seeking_connection',3),
  ('open-connections','Open Connections','For anyone open to broader discovery and non-binary connections.','seeking_connection',4)
on conflict (slug) do nothing;

-- ── Seed icebreaker prompts (apply to all rooms) ────────────────────────────
insert into public.community_prompts (community_id, text) values
  (null,'What value are you working on strengthening in yourself right now?'),
  (null,'What value do you most hope a partner brings?'),
  (null,'What does consistency look like to you?'),
  (null,'What is one way you feel most loved?'),
  (null,'What relationship pattern are you trying to grow beyond?'),
  (null,'What does emotional safety mean to you?'),
  (null,'What helps you feel respected in a relationship?'),
  (null,'What does intentional connection look like to you right now?')
on conflict do nothing;
```

- [ ] **Step 2: Apply the migration** — `supabase db push` (or paste into the SQL editor).

- [ ] **Step 3: Verify rooms + access function**

```sql
select slug, kind, display_order from public.communities order by display_order;
-- expect 5 rows.

-- Simulate access for a single straight woman:
update public.users set gender='woman', interested_in=array['man'], relationship_status='single'
  where id = '<test-user-id>';
select slug from available_communities('<test-user-id>') order by display_order;
-- expect: everyones-field, women-men, open-connections
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260609130000_the_field.sql
git commit -m "feat(field): communities schema, access rules, RLS, realtime, seed rooms"
```

### Task 3.2: Community models

**Files:**
- Create: `Harvest/Models/Community.swift`

- [ ] **Step 1: Write the models**

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

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, kind
        case memberCount = "member_count"
        case displayOrder = "display_order"
    }
}

struct CommunityMessage: Identifiable, Codable, Equatable {
    let id: String
    let communityId: String
    let senderId: String
    let content: String
    let isRemoved: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case senderId = "sender_id"
        case content
        case isRemoved = "is_removed"
        case createdAt = "created_at"
    }
}

struct CommunityPrompt: Identifiable, Codable, Equatable {
    let id: String
    let text: String
}
```

- [ ] **Step 2: Xcode verification checklist** — compiles; decodes rows from the three tables.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Models/Community.swift
git commit -m "feat(field): community models"
```

### Task 3.3: CommunityService

**Files:**
- Create: `Harvest/Services/CommunityService.swift`

- [ ] **Step 1: Write the service**

```swift
import Foundation
import Supabase
import Realtime

struct CommunityService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Rooms the user is allowed to join (via the access-rules RPC).
    func availableCommunities(userId: String) async throws -> [Community] {
        try await client
            .rpc("available_communities", params: ["p_user": userId])
            .execute()
            .value
    }

    /// Community ids the user has actively joined.
    func joinedCommunityIds(userId: String) async throws -> Set<String> {
        struct Row: Decodable { let community_id: String }
        let rows: [Row] = try await client
            .from("community_members")
            .select("community_id")
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .execute()
            .value
        return Set(rows.map(\.community_id))
    }

    func join(communityId: String, userId: String) async throws {
        try await client
            .from("community_members")
            .upsert([
                "community_id": communityId,
                "user_id": userId,
                "status": "active"
            ])
            .execute()
    }

    func leave(communityId: String, userId: String) async throws {
        try await client
            .from("community_members")
            .update(["status": "left"])
            .eq("community_id", value: communityId)
            .eq("user_id", value: userId)
            .execute()
    }

    func messages(communityId: String) async throws -> [CommunityMessage] {
        try await client
            .from("community_messages")
            .select()
            .eq("community_id", value: communityId)
            .eq("is_removed", value: false)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Throws ContactInfoBlocked when server-side detection rejects the message (Phase 6).
    func post(communityId: String, senderId: String, content: String) async throws {
        try await client
            .from("community_messages")
            .insert([
                "community_id": communityId,
                "sender_id": senderId,
                "content": content
            ])
            .execute()
    }

    func prompts(communityId: String) async throws -> [CommunityPrompt] {
        // Room-specific OR global (community_id is null).
        try await client
            .from("community_prompts")
            .select("id, text")
            .or("community_id.eq.\(communityId),community_id.is.null")
            .eq("is_active", value: true)
            .execute()
            .value
    }

    func subscribe(communityId: String, onMessage: @escaping @Sendable (CommunityMessage) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("community:\(communityId)")
        let changes = channel.postgresChange(
            InsertAction.self,
            table: "community_messages",
            filter: .eq("community_id", value: communityId)
        )
        Task {
            for await change in changes {
                if let msg = try? change.decodeRecord(as: CommunityMessage.self, decoder: JSONDecoder()) {
                    onMessage(msg)
                }
            }
        }
        Task { try? await channel.subscribeWithError() }
        return channel
    }

    func unsubscribe(_ channel: RealtimeChannelV2) {
        Task { await channel.unsubscribe() }
    }
}
```

- [ ] **Step 2: Xcode verification checklist**
  - Realtime subscribe mirrors `ChatService.subscribeToMessages` exactly (same SDK calls).
  - `availableCommunities` decodes the RPC's setof-row result into `[Community]`.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Services/CommunityService.swift
git commit -m "feat(field): CommunityService (list/join/leave/post/subscribe)"
```

### Task 3.4: FieldViewModel + FieldView (room directory)

**Files:**
- Create: `Harvest/ViewModels/FieldViewModel.swift`
- Modify: `Harvest/Views/Field/FieldView.swift` (replace the Phase 1 shell)

- [ ] **Step 1: Write the view model**

```swift
import Foundation
import Observation

@Observable
final class FieldViewModel {
    var available: [Community] = []
    var joinedIds: Set<String> = []
    var isLoading = false
    var error: String?

    private let service = CommunityService()

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let avail = service.availableCommunities(userId: userId)
            async let joined = service.joinedCommunityIds(userId: userId)
            self.available = try await avail
            self.joinedIds = try await joined
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleJoin(_ community: Community, userId: String) async {
        do {
            if joinedIds.contains(community.id) {
                try await service.leave(communityId: community.id, userId: userId)
                joinedIds.remove(community.id)
            } else {
                try await service.join(communityId: community.id, userId: userId)
                joinedIds.insert(community.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isJoined(_ community: Community) -> Bool { joinedIds.contains(community.id) }
}
```

- [ ] **Step 2: Write the directory view**

```swift
import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel
    @State private var vm = FieldViewModel()
    private var userId: String { authViewModel.userId ?? "" }

    var body: some View {
        NavigationStack {
            List {
                if vm.available.isEmpty && !vm.isLoading {
                    Text("Set your relationship status in Profile to unlock connection spaces.")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.available) { community in
                    CommunityRow(
                        community: community,
                        isJoined: vm.isJoined(community),
                        authViewModel: authViewModel,
                        onToggle: { Task { await vm.toggleJoin(community, userId: userId) } }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("The Field")
            .task { await vm.load(userId: userId) }
            .refreshable { await vm.load(userId: userId) }
        }
    }
}

private struct CommunityRow: View {
    let community: Community
    let isJoined: Bool
    let authViewModel: AuthViewModel
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(community.name).font(.headline)
                    if let d = community.description {
                        Text(d).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(isJoined ? "Leave" : "Join", action: onToggle)
                    .buttonStyle(.bordered)
                    .tint(isJoined ? .secondary : HarvestTheme.Colors.primary)
            }
            if isJoined {
                NavigationLink {
                    CommunityChatView(authViewModel: authViewModel, community: community)
                } label: {
                    Label("Open room", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Xcode verification checklist**
  - Available rooms list; Join/Leave toggles membership; "Open room" appears once joined.
  - Empty state shows when no rooms (e.g., status not set).

- [ ] **Step 4: Commit**

```bash
git add Harvest/ViewModels/FieldViewModel.swift Harvest/Views/Field/FieldView.swift
git commit -m "feat(field): room directory with join/leave"
```

### Task 3.5: CommunityChatViewModel + CommunityChatView (room chat + icebreakers)

**Files:**
- Create: `Harvest/ViewModels/CommunityChatViewModel.swift`
- Create: `Harvest/Views/Field/CommunityChatView.swift`

- [ ] **Step 1: Write the view model**

```swift
import Foundation
import Observation
import Realtime

@Observable
final class CommunityChatViewModel {
    var messages: [CommunityMessage] = []
    var prompts: [CommunityPrompt] = []
    var draft: String = ""
    var error: String?

    private let service = CommunityService()
    private var channel: RealtimeChannelV2?

    func start(communityId: String) async {
        do {
            async let msgs = service.messages(communityId: communityId)
            async let pr = service.prompts(communityId: communityId)
            self.messages = try await msgs
            self.prompts = try await pr
        } catch {
            self.error = error.localizedDescription
        }
        channel = service.subscribe(communityId: communityId) { [weak self] msg in
            Task { @MainActor in
                guard let self else { return }
                if !self.messages.contains(where: { $0.id == msg.id }) && !msg.isRemoved {
                    self.messages.append(msg)
                }
            }
        }
    }

    func send(communityId: String, senderId: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await service.post(communityId: communityId, senderId: senderId, content: text)
            draft = ""
        } catch {
            // Phase 6: contact-info block surfaces here as a friendly nudge.
            if "\(error)".contains("CONTACT_INFO_BLOCKED") {
                self.error = "Keep contact sharing to private Seed conversations 🌱"
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    func stop() {
        if let channel { service.unsubscribe(channel) }
        channel = nil
    }
}
```

- [ ] **Step 2: Write the room chat view**

```swift
import SwiftUI

struct CommunityChatView: View {
    let authViewModel: AuthViewModel
    let community: Community

    @State private var vm = CommunityChatViewModel()
    @State private var showPrompts = false
    private var userId: String { authViewModel.userId ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.messages) { msg in
                            CommunityBubble(message: msg, isMine: msg.senderId == userId)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let error = vm.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal)
            }

            HStack(spacing: 8) {
                Button { showPrompts.toggle() } label: {
                    Image(systemName: "lightbulb")
                }
                TextField("Share something…", text: $vm.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await vm.send(communityId: community.id, senderId: userId) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.start(communityId: community.id) }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showPrompts) {
            PromptPicker(prompts: vm.prompts) { chosen in
                vm.draft = chosen
                showPrompts = false
            }
        }
    }
}

private struct CommunityBubble: View {
    let message: CommunityMessage
    let isMine: Bool
    var body: some View {
        HStack {
            if isMine { Spacer() }
            Text(message.content)
                .padding(10)
                .background(isMine ? HarvestTheme.Colors.primary.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isMine { Spacer() }
        }
    }
}

private struct PromptPicker: View {
    let prompts: [CommunityPrompt]
    let onPick: (String) -> Void
    var body: some View {
        NavigationStack {
            List(prompts) { p in
                Button(p.text) { onPick(p.text) }
            }
            .navigationTitle("Icebreakers")
        }
    }
}
```

- [ ] **Step 3: Xcode verification checklist**
  - Entering a joined room loads history and live-updates on new messages (two simulators/users).
  - The lightbulb shows icebreaker prompts; picking one fills the composer.
  - Posting from a non-member is rejected by RLS (verify by attempting via a non-joined account).

- [ ] **Step 4: Commit**

```bash
git add Harvest/ViewModels/CommunityChatViewModel.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(field): realtime room chat with icebreaker prompts"
```

---

# PHASE 4 — Relationship Status (onboarding + profile)

**Outcome:** New users set a relationship status during onboarding (with an honesty expectation); it gates Seeking Connection rooms (single/dating only); users can change it in Profile and Field access recomputes.

### Task 4.1: Add the relationship-status step to the onboarding flow

**Files:**
- Modify: `Harvest/ViewModels/OnboardingViewModel.swift:7-19` (enum), `:37-44` (state), `:59-76` (canProceed), `:204-214` (save)

- [ ] **Step 1: Add the enum case** — insert `relationshipStatus` after `interestedIn`:

```swift
enum OnboardingStep: Int, CaseIterable {
    case age
    case nickname
    case photos
    case goals
    case values
    case reflections
    case genderIdentity
    case interestedIn
    case relationshipStatus
    case location
    case terms
    case complete
}
```

- [ ] **Step 2: Add state** — after `var interestedIn: Set<String> = []` (line 38) add:

```swift
    var relationshipStatus = ""   // single|dating|in_relationship|engaged|married
```

- [ ] **Step 3: Add the `canProceed` case** — inside the switch, after `.interestedIn`:

```swift
        case .relationshipStatus: return !relationshipStatus.isEmpty
```

- [ ] **Step 4: Persist it in `completeOnboarding`** — add to the `updates` dictionary:

```swift
            "relationship_status": .string(relationshipStatus),
```

- [ ] **Step 5: Xcode verification checklist**
  - `OnboardingStep.allCases.count` increased by 1 (progress math at line 106 still works — it divides by `count - 1`).
  - `canProceed` blocks advancing until a status is chosen.

- [ ] **Step 6: Commit**

```bash
git add Harvest/ViewModels/OnboardingViewModel.swift
git commit -m "feat(onboarding): add relationship-status step to view model"
```

### Task 4.2: Build the RelationshipStatusStepView and wire it into the container

**Files:**
- Create: `Harvest/Views/Onboarding/RelationshipStatusStepView.swift`
- Modify: `Harvest/Views/Onboarding/OnboardingContainerView.swift` (add the `.relationshipStatus` case to the step switch)

- [ ] **Step 1: Write the step view** (mirrors the existing single-select step views like `GoalsStepView`)

```swift
import SwiftUI

struct RelationshipStatusStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let options: [(value: String, label: String)] = [
        ("single", "Single"),
        ("dating", "Dating / exploring connections"),
        ("in_relationship", "In a relationship"),
        ("engaged", "Engaged"),
        ("married", "Married")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What is your current relationship status?")
                .font(.title2.bold())

            Text("Harvest communities are built around trust and intentional connection. Please select your current relationship status honestly so you enter the spaces designed for your current season.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { option in
                    Button {
                        viewModel.relationshipStatus = option.value
                    } label: {
                        HStack {
                            Text(option.label)
                            Spacer()
                            if viewModel.relationshipStatus == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.relationshipStatus == option.value
                                        ? HarvestTheme.Colors.primary : Color.gray.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 2: Wire into the container** — in `OnboardingContainerView`, find the `switch viewModel.currentStep` that renders each step, and add (matching the existing case style, e.g. how `.interestedIn` renders `InterestedInStepView(viewModel: viewModel)`):

```swift
            case .relationshipStatus:
                RelationshipStatusStepView(viewModel: viewModel)
```

- [ ] **Step 3: Xcode verification checklist**
  - After interested-in, the relationship-status step appears with the honesty copy.
  - Cannot advance until a status is picked; selection persists to `relationship_status` on completion.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Onboarding/RelationshipStatusStepView.swift Harvest/Views/Onboarding/OnboardingContainerView.swift
git commit -m "feat(onboarding): relationship-status step view"
```

### Task 4.3: Add relationshipStatus to UserProfile + editable in Profile

**Files:**
- Modify: `Harvest/Models/UserProfile.swift`
- Modify: `Harvest/Views/Profile/ProfileEditView.swift`

- [ ] **Step 1: Add the field to the model** — add a stored property + its `CodingKeys` entry mirroring the existing snake_case mapping (e.g. alongside `gender`):

```swift
    let relationshipStatus: String?
    // in CodingKeys:
    case relationshipStatus = "relationship_status"
```

If `UserProfile` has a memberwise initializer or sample/mocks, add `relationshipStatus` there too (the compiler will flag every site on the Mac build).

- [ ] **Step 2: Add an editor control to ProfileEditView**

Add a `@State private var relationshipStatus: String` seeded from the loaded profile and a `Picker` (same five options as Task 4.2). On save, include `"relationship_status": .string(relationshipStatus)` in the update payload the edit view already sends via `ProfileService.updateProfile`. Use the exact update mechanism already in `ProfileEditView` (match its existing field-save pattern).

```swift
Picker("Relationship status", selection: $relationshipStatus) {
    Text("Single").tag("single")
    Text("Dating / exploring").tag("dating")
    Text("In a relationship").tag("in_relationship")
    Text("Engaged").tag("engaged")
    Text("Married").tag("married")
}
```

- [ ] **Step 3: Xcode verification checklist**
  - Profile → Edit shows the relationship-status picker pre-filled with the current value.
  - Saving updates the row; returning to The Field and pull-to-refresh recomputes available rooms (e.g., switching single→married removes Seeking Connection rooms). No extra code needed — `FieldView.load` already calls `available_communities`.

- [ ] **Step 4: Commit**

```bash
git add Harvest/Models/UserProfile.swift Harvest/Views/Profile/ProfileEditView.swift
git commit -m "feat(profile): edit relationship status; recomputes Field access"
```

### Task 4.4: Add the honesty clause to Community Standards / Terms copy

**Files:**
- Modify: `Harvest/Views/Onboarding/TermsStepView.swift` (or wherever the standards/terms text constant lives)

- [ ] **Step 1: Append the standards language**

Add this paragraph to the existing terms/standards text shown at the `.terms` step:

> "Harvest is built on trust, intentionality, and authentic connection. Users are expected to accurately represent their relationship status. If we determine that someone intentionally misrepresented their relationship status to access communities that do not align with their current relationship season, Harvest reserves the right to restrict, suspend, or remove access to the platform."

- [ ] **Step 2: Xcode verification checklist** — the terms step shows the honesty clause.

- [ ] **Step 3: Commit**

```bash
git add Harvest/Views/Onboarding/TermsStepView.swift
git commit -m "docs(standards): add relationship-status honesty clause"
```

---

# PHASE 5 — Subscription Tiers

**Outcome:** Three tiers — 🌱 Seed (free, 3/day) · 🌿 Green ($19.99, 5/day) · 🌳 Gold ($24.99, 25/day) — with the daily Seed-send limit enforced (already wired in Phase 2's trigger) and surfaced in the UI.

> **Note:** The Phase 2 trigger already reads `subscription_tiers.daily_seed_limit`. This phase only sets the correct per-tier values + feature flags and shows the limit to users. IAP/StoreKit product configuration for the new price points is an external App Store Connect task, tracked here but not codeable.

### Task 5.1: Inspect current tiers, then set pivot values

**Files:**
- Create: `supabase/migrations/20260609150000_subscription_tiers_pivot.sql`

- [ ] **Step 1: Inspect the existing tier rows** (do this before writing UPDATEs — we must not break `user_subscriptions` FKs)

```sql
select * from public.subscription_tiers order by 1;
select column_name from information_schema.columns where table_name='subscription_tiers' order by 1;
```
Record the existing `id`/`name` of each tier. The migration UPDATES these rows in place (never deletes — `user_subscriptions.tier_id` references them).

- [ ] **Step 2: Write the migration** (add feature columns, then set values)

```sql
-- Pivot subscription tiers: daily Seed limits + pricing + gardener access.
alter table public.subscription_tiers
  add column if not exists price_cents      int   not null default 0,
  add column if not exists gardener_access  text  not null default 'limited',  -- limited|more|full
  add column if not exists tier_key         text;                              -- stable key: seed|green|gold

-- daily_seed_limit already added in 20260609120000_seeds.sql.

-- Map existing rows to the three pivot tiers. EDIT the WHERE clauses to match
-- the real id/name values found in Step 1. Example assumes rows are named
-- 'free'/'green'/'gold' (case-insensitive); adjust as needed.
update public.subscription_tiers
  set tier_key='seed',  daily_seed_limit=3,  price_cents=0,    gardener_access='limited', can_see_likes=false
  where lower(name) in ('free','seed','basic') or tier_key='seed';

update public.subscription_tiers
  set tier_key='green', daily_seed_limit=5,  price_cents=1999, gardener_access='more',    can_see_likes=true
  where lower(name) in ('green','plus') or tier_key='green';

update public.subscription_tiers
  set tier_key='gold',  daily_seed_limit=25, price_cents=2499, gardener_access='full',    can_see_likes=true
  where lower(name) in ('gold','premium') or tier_key='gold';

-- If a fresh project has NO tiers, create them (no-op when rows already exist):
insert into public.subscription_tiers (name, tier_key, daily_seed_limit, price_cents, gardener_access, can_see_likes)
select * from (values
  ('Seed',  'seed',  3,  0,    'limited', false),
  ('Green', 'green', 5,  1999, 'more',    true),
  ('Gold',  'gold',  25, 2499, 'full',    true)
) as v(name, tier_key, daily_seed_limit, price_cents, gardener_access, can_see_likes)
where not exists (select 1 from public.subscription_tiers);
```

- [ ] **Step 3: Apply & verify**

```sql
-- expect three tiers with seed limits 3 / 5 / 25
select tier_key, name, daily_seed_limit, price_cents, gardener_access, can_see_likes
  from public.subscription_tiers order by daily_seed_limit;
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260609150000_subscription_tiers_pivot.sql
git commit -m "feat(subscriptions): set Seed/Green/Gold tiers and daily seed limits"
```

### Task 5.2: Expose the daily Seed limit + remaining count to the client

**Files:**
- Modify: `Harvest/Services/SubscriptionService.swift`
- Modify: `Harvest/Services/SeedService.swift` (add today's sent count)
- Modify: `Harvest/Views/Seeds/SendSeedSheet.swift` (show "X of N today")

- [ ] **Step 1: Add a daily-limit accessor to SubscriptionService**

Following the existing `getTierForUser` / `getCharacterLimit` pattern in the file, add:

```swift
    /// Daily Seed-send limit for the user's active tier (defaults to free tier = 3).
    func getDailySeedLimit(userId: String) async -> Int {
        // Reuse however getTierForUser already resolves the active tier row,
        // then read its `daily_seed_limit`. Fallback to 3 on any failure.
        do {
            let tier = try await getTierForUser(userId: userId)   // existing method
            return tier?.dailySeedLimit ?? 3
        } catch {
            return 3
        }
    }
```

Also add `dailySeedLimit` to the `SubscriptionTier` model (`Harvest/Models/SubscriptionTier.swift`) with CodingKey `daily_seed_limit` (Int, default 3 if absent).

- [ ] **Step 2: Add today's sent count to SeedService**

```swift
    /// How many Seeds the user has sent since local midnight UTC (matches the
    /// server trigger's date_trunc('day', now())).
    func sentTodayCount(userId: String) async throws -> Int {
        let startOfDay = ISO8601DateFormatter().string(
            from: Calendar(identifier: .gregorian).startOfDay(for: Date()))
        let rows: [Seed] = try await client
            .from("seeds")
            .select("id, created_at, sender_id, recipient_id, opening_message, status, conversation_id, responded_at")
            .eq("sender_id", value: userId)
            .gte("created_at", value: startOfDay)
            .execute()
            .value
        return rows.count
    }
```

- [ ] **Step 3: Show remaining in SendSeedSheet**

In `SendSeedSheet`, add `@State private var sentToday = 0` and `@State private var limit = 3`, load them in a `.task`, and render a caption: `Text("\(sentToday) of \(limit) Seeds sent today")`. Disable Send when `sentToday >= limit` (the server still enforces; this is just UX).

- [ ] **Step 4: Xcode verification checklist**
  - Free user sees "of 3"; the counter increments after sending; Send disables at the limit with the friendly message.
  - Server enforcement still returns `dailyLimitReached` if the client guard is bypassed.

- [ ] **Step 5: Commit**

```bash
git add Harvest/Services/SubscriptionService.swift Harvest/Services/SeedService.swift Harvest/Views/Seeds/SendSeedSheet.swift Harvest/Models/SubscriptionTier.swift
git commit -m "feat(subscriptions): surface daily Seed limit and remaining count"
```

### Task 5.3: (External) Configure IAP products

**Not codeable here — checklist for App Store Connect / StoreKit:**
- [ ] Create auto-renewable subscription products priced $19.99 (Green) and $24.99 (Gold).
- [ ] Map product identifiers to `tier_key` `green` / `gold` in whatever purchase-completion code writes `user_subscriptions`.
- [ ] Confirm purchase flow sets `user_subscriptions.status='active'` and the correct `tier_id`, so the daily-limit trigger reads the right tier.

---

# PHASE 6 — Moderation & Safety

**Outcome:** Users can report community messages, private Seed messages, and profiles. Admin can remove a community message for everyone and ban a user from a specific room (plus the existing platform ban). Phone numbers / social handles posted in community chat are blocked with a gentle nudge; private accepted chats are unrestricted.

### Task 6.1: Extend reports + add contact-info detection (migration)

**Files:**
- Create: `supabase/migrations/20260609160000_moderation_pivot.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Moderation pivot: report targets, community-message contact-info guard,
-- and an updated moderation_queue view that surfaces message targets.

alter table public.user_reports
  add column if not exists target_type text not null default 'profile'
      check (target_type in ('profile','community_message','seed_message')),
  add column if not exists target_id   uuid;   -- message id when applicable

-- ── Contact-info detection (community chat only) ────────────────────────────
-- Blocks phone numbers and Snap/Instagram handle-drops to keep contact sharing
-- inside private Seed conversations. Conservative patterns; tune as needed.
create or replace function detect_contact_info(p_text text)
returns boolean language plpgsql immutable as $$
declare t text := lower(coalesce(p_text,''));
begin
  -- 7+ digit run (with common separators) => likely a phone number
  if t ~ '(\d[\s().+-]?){7,}' then return true; end if;
  -- social handle solicitation
  if t ~* '(snap(chat)?|insta(gram)?|\+?my\s+(snap|ig|insta)|add\s+me\s+on)' then return true; end if;
  -- @handle of 3+ chars
  if t ~ '@[a-z0-9_.]{3,}' then return true; end if;
  return false;
end;
$$;

create or replace function guard_community_contact_info() returns trigger
language plpgsql as $$
begin
  if detect_contact_info(NEW.content) then
    raise exception 'CONTACT_INFO_BLOCKED' using errcode = 'P0001';
  end if;
  return NEW;
end;
$$;

drop trigger if exists community_messages_contact_guard on public.community_messages;
create trigger community_messages_contact_guard
  before insert on public.community_messages
  for each row execute function guard_community_contact_info();

-- ── moderation_queue view (replaces the one in admin/schema.sql) ────────────
create or replace view public.moderation_queue as
select
  r.id,
  r.reporter_id,
  r.reported_id,
  r.reason,
  r.description,
  r.status,
  r.action_taken,
  r.created_at,
  r.target_type,
  r.target_id,
  reported.nickname  as reported_nickname,
  reported.bio       as reported_bio,
  reported.photos    as reported_photos,
  reported.is_banned as reported_is_banned,
  reporter.nickname  as reporter_nickname,
  cm.content         as target_message_content,
  cm.community_id    as target_community_id,
  comm.name          as target_community_name
from public.user_reports r
left join public.users reported on reported.id = r.reported_id
left join public.users reporter on reporter.id = r.reporter_id
left join public.community_messages cm
       on r.target_type = 'community_message' and cm.id = r.target_id
left join public.communities comm on comm.id = cm.community_id;
```

- [ ] **Step 2: Apply & verify**

```sql
-- contact-info guard works:
select detect_contact_info('hit me up 5551234567');     -- expect true
select detect_contact_info('add me on snap');           -- expect true
select detect_contact_info('I value honesty and time');  -- expect false
-- view has the new columns:
select target_type, target_message_content, target_community_name
  from public.moderation_queue limit 1;
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260609160000_moderation_pivot.sql
git commit -m "feat(moderation): report targets + community contact-info guard + queue view"
```

### Task 6.2: Keep admin/schema.sql in sync

**Files:**
- Modify: `admin/schema.sql`

- [ ] **Step 1: Update the schema file** so a fresh admin setup matches the migration. Add the `target_type`/`target_id` columns to the `alter table public.user_reports` block, and replace the `create or replace view public.moderation_queue` definition with the one from Task 6.1 (the version with `target_type`, `target_id`, `target_message_content`, `target_community_id`, `target_community_name`).

- [ ] **Step 2: Verify** — `admin/schema.sql` is idempotent and, when run on a DB that already has the migration applied, produces no errors and an identical view.

- [ ] **Step 3: Commit**

```bash
git add admin/schema.sql
git commit -m "chore(admin): sync schema.sql with moderation pivot"
```

### Task 6.3: Admin actions — remove community message & per-room ban

**Files:**
- Modify: `admin/app.js`

- [ ] **Step 1: Branch the report card by target type**

In `reportCard(r)`, when `r.target_type === 'community_message'`, render the reported message text and room name instead of (or in addition to) the profile block, and show message-specific actions:

```js
  const isMessage = r.target_type === "community_message";
  const messageBlock = isMessage
    ? `<div class="desc">In <b>${escape(r.target_community_name || "a room")}</b>: “${escape(r.target_message_content || "(removed)")}”</div>`
    : "";

  const actions = reviewed
    ? ""
    : isMessage
    ? `<div class="actions">
         <button class="ghost" data-action="dismiss" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Dismiss</button>
         <button data-action="remove-msg" data-id="${r.id}" data-msg="${escape(r.target_id)}">Remove message</button>
         <button data-action="ban-room" data-id="${r.id}" data-reported="${escape(r.reported_id)}" data-community="${escape(r.target_community_id)}">Ban from room</button>
         <button class="danger" data-action="ban" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Ban &amp; eject user</button>
       </div>`
    : `<div class="actions">
         <button class="ghost" data-action="dismiss" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Dismiss</button>
         <button data-action="remove" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Remove content</button>
         <button class="danger" data-action="ban" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Ban &amp; eject user</button>
       </div>`;
```

Insert `${messageBlock}` into the returned card markup (e.g., right after the existing `${r.description ? … : ""}` line), and update the event-binding loop to also pass the new datasets:

```js
  listEl.querySelectorAll("[data-action]").forEach((btn) => {
    btn.addEventListener("click", () =>
      onAction(btn.dataset.action, btn.dataset.id, btn.dataset.reported, {
        msgId: btn.dataset.msg,
        communityId: btn.dataset.community,
      }));
  });
```

- [ ] **Step 2: Handle the new actions in `onAction`**

Change the signature to `async function onAction(action, reportId, reportedId, extra = {})` and add:

```js
    } else if (action === "remove-msg") {
      if (!confirm("Remove this message for everyone?")) return;
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: true, removed_at: new Date().toISOString(), removed_by: "admin" })
        .eq("id", extra.msgId);
      if (error) throw error;
      await markReviewed(reportId, "content_removed");
    } else if (action === "ban-room") {
      if (!confirm("Ban this user from this room?")) return;
      const { error } = await supabase
        .from("community_members")
        .update({ status: "banned" })
        .eq("community_id", extra.communityId)
        .eq("user_id", reportedId);
      if (error) throw error;
      await markReviewed(reportId, "content_removed");
    }
```

(The existing `dismiss` / `remove` / `ban` branches stay unchanged.)

- [ ] **Step 3: Verify in the browser**
  - Open `admin/index.html` against a DB that has a `community_message` report.
  - The card shows the room + message text; **Remove message** sets `is_removed` (message vanishes from the app); **Ban from room** sets the membership to `banned` (user can no longer post there); **Ban & eject** still bans platform-wide.

- [ ] **Step 4: Commit**

```bash
git add admin/app.js
git commit -m "feat(admin): remove community message + per-room ban actions"
```

### Task 6.4: Report entry points in the app (community + private messages)

**Files:**
- Modify: `Harvest/Views/Chat/ReportUserView.swift`
- Modify: `Harvest/Views/Field/CommunityChatView.swift` (long-press a message → report)

- [ ] **Step 1: Make ReportUserView target-aware**

Extend `ReportUserView` to accept an optional target:

```swift
    enum ReportTarget {
        case profile
        case communityMessage(id: String)
        case seedMessage(id: String)

        var typeString: String {
            switch self {
            case .profile: return "profile"
            case .communityMessage: return "community_message"
            case .seedMessage: return "seed_message"
            }
        }
        var targetId: String? {
            switch self {
            case .profile: return nil
            case .communityMessage(let id), .seedMessage(let id): return id
            }
        }
    }
```

Add a `var target: ReportTarget = .profile` property. Where the view currently inserts into `user_reports` (find the existing insert), add the two fields:

```swift
            "target_type": .string(target.typeString),
            "target_id": target.targetId.map(AnyJSON.string) ?? .null
```

Keep `reported_id` set to the message author's user id (so room/platform bans work).

- [ ] **Step 2: Add a report action to community messages**

In `CommunityChatView`'s `CommunityBubble` (or via `.contextMenu` on the bubble), add a "Report message" action that presents `ReportUserView(reportedUserId: message.senderId, target: .communityMessage(id: message.id))`. Use the existing `ReportUserView` initializer signature (match its real init; pass the reported user's id the same way the chat report flow already does).

```swift
.contextMenu {
    Button(role: .destructive) {
        // present ReportUserView with .communityMessage(id: message.id)
    } label: { Label("Report message", systemImage: "flag") }
}
```

- [ ] **Step 3: Xcode verification checklist**
  - Long-pressing a community message offers **Report message**; submitting inserts a `user_reports` row with `target_type='community_message'`, `target_id=<message id>`, `reported_id=<author>`.
  - The existing profile report path still works (`target_type` defaults to `profile`).
  - Posting a phone number or "add me on snap" in a room shows the nudge: "Keep contact sharing to private Seed conversations 🌱" and does NOT post.
  - Sharing contact info inside an accepted private Seed chat still works (no guard there).

- [ ] **Step 4: Commit**

```bash
git add Harvest/Views/Chat/ReportUserView.swift Harvest/Views/Field/CommunityChatView.swift
git commit -m "feat(moderation): report community/private messages from the app"
```

---

# Done — MVP complete

After Phase 6, Harvest runs the full pivot: **Soil → The Field → Seeds → Conversation**, with no swiping/matching, community spaces gated by gender + interested-in + relationship status, intentional Seed requests with tiered daily limits, and moderation across both public and private spaces.

**Deferred (see spec §10 / Phase 7):** Gardener match suggestions, full profile search filters, Growing Together, Just the Girls/Guys peer spaces, location-based rooms, Growth Path modules, in-person events.

## Post-implementation verification (run on Mac once available)
- [ ] Full Xcode build with zero unresolved references after the swipe-deck removal.
- [ ] End-to-end: onboard a new user (incl. relationship status) → join a room → post → send a Seed → accept on the other account → chat.
- [ ] Confirm `available_communities` tokens match the real `gender` / `interested_in` strings produced by `GenderStepView` / `InterestedInStepView` (adjust the function's normalization arrays if they differ).
- [ ] Confirm `ChatDetailView` and `ReportUserView` initializer signatures match the calls used in the new Seeds/Field views.

