# Harvest Pivot — Soil · The Field · Seeds · The Gardener

**Date:** 2026-06-08
**Status:** Approved for planning
**Author:** Andre + Claude

---

## 1. Summary

Harvest is pivoting from a swipe/match dating app into a **relationship-growth platform** built around values, community, and intentional connection. We are **removing matching and swiping entirely** — no swipe deck, no likes, no mutual matches.

New core flow:

> **Understand your Soil → enter The Field → send Seeds → grow conversations**

This is delivered as a single comprehensive spec, organized into sequenced phases so it can be built and reviewed in order. **Phases 1–6 are MVP.** Phase 7 collects explicitly deferred work.

### Decisions locked during brainstorming

| Decision | Resolution |
|---|---|
| Seeking Connection room basis | **Gender + interested-in** (NOT strongest value — resolves the contradiction in the source doc). Values influence Soil, Gardener, and search only; they do not divide The Field. |
| MVP community set | **Everyone's Field** + **Seeking Connection set** (Women+Men, Women+Women, Men+Men, Open Connections). Growing Together and Just the Girls/Guys deferred to Phase 7. |
| Non-binary access to Seeking Connection rooms | **Can pick any room** — all four Seeking Connection rooms are shown to non-binary users to join freely. |
| Contact-info in community chat | **Block + warn** — message rejected before posting with a gentle nudge to keep contact-sharing to private Seeds. Private accepted Seed chats are unrestricted. |
| Seeds daily send limits | **Tiered: 3 / 5 / 25** (Seed/Green/Gold). Reconciles the doc's flat "25/day" — the tier table wins. Receiving is always unlimited. |
| Gardener match suggestions | **Deferred to Phase 7** (per "fastest MVP = no gardener recommendations for matching"). |

---

## 2. Current State (what exists today)

SwiftUI iOS app + Supabase backend + a web admin panel.

**Tabs today** (`Harvest/Views/MainTabView.swift`): Chat · Gardener · Values · Profile · Swipe.

Reusable / already-built foundations:

- **Values system** (→ Soil): "I Bring / I Need" chips, radar graph, 35-question assessment, 4-axis scoring, compatibility. `ValuesView`, `ValuesViewModel`, `ValuesService`, `CompatibilityService`, `Value`/`Question` models, `values`/`user_values_*`/`questions`/`question_options`/`user_question_answers` tables.
- **Messaging** (→ reused by Seeds): `conversations` + `messages` tables, realtime (postgres_changes), `ChatService`, `ChatViewModel`, `ChatDetailView`, `MessageBubbleView`, push notifications, mindful-messaging filter.
- **Gardener:** complete AI coach. `GardenerChatView`, `GardenerViewModel`, `GardenerService`, `gardener_chat_history` (24h TTL).
- **Onboarding:** `OnboardingContainerView` + `OnboardingViewModel`, steps enum already collects age, nickname, photos, goals, values, reflections, **gender**, **interested-in**, location, terms.
- **Moderation foundation:** `user_reports` table, `moderation_queue` view, admin panel (`admin/app.js`) with dismiss / remove-content / ban-and-eject. `ReportUserView` exists. `is_banned` on users.
- **Subscriptions:** `subscription_tiers` + `user_subscriptions` (currently only gate `can_see_likes`). `SubscriptionService`, `RateLimitService`.
- **Push:** APNs Edge Function `send-push` (types: message/match/like), trigger-driven.
- **Account deletion:** `delete-account` Edge Function (cascading).

Being retired from the app flow (tables retained for data): `swipes`, `matches`, `SwipeService`, `DiscoverViewModel`, `Discover/` views, `MatchModalView`.

---

## 3. Data Model Changes

### 3.1 New tables

```
seeds
  id              uuid pk
  sender_id       uuid fk users
  recipient_id    uuid fk users
  opening_message text            -- the first message attached to the Seed
  status          text            -- 'pending' | 'accepted' | 'declined'
  conversation_id uuid null fk conversations  -- set on accept
  created_at      timestamptz
  responded_at    timestamptz null
  unique (sender_id, recipient_id) where status = 'pending'   -- one open Seed per pair

communities
  id              uuid pk
  slug            text unique     -- 'everyones-field', 'women-men', 'women-women', 'men-men', 'open-connections'
  name            text
  description     text
  kind            text            -- 'everyone' | 'seeking_connection'  (extensible: 'relationship_stage','peer')
  is_active        bool
  member_count    int default 0
  display_order   int

community_members
  community_id    uuid fk communities
  user_id         uuid fk users
  role            text            -- 'member' | 'moderator'
  status          text            -- 'active' | 'banned' | 'left'
  joined_at       timestamptz
  primary key (community_id, user_id)

community_messages
  id              uuid pk
  community_id    uuid fk communities
  sender_id       uuid fk users
  content         text
  is_removed      bool default false   -- soft-delete for moderator removal
  removed_by      uuid null
  removed_at      timestamptz null
  created_at      timestamptz

community_prompts            -- optional icebreakers
  id              uuid pk
  community_id    uuid null fk communities   -- null = applies to all rooms
  text            text
  is_active        bool
```

### 3.2 Column additions

```
users.relationship_status   text   -- 'single' | 'dating' | 'in_relationship' | 'engaged' | 'married'
                                    -- nullable until backfilled / re-onboarded

user_reports.target_type    text   -- 'profile' | 'community_message' | 'seed_message'
user_reports.target_id      uuid null   -- message id when applicable (reported_id remains the user)

subscription_tiers          -- add feature columns (see §8): daily_seed_limit int, etc.
```

### 3.3 Access-rules engine

A single source of truth computes which communities a user **may join** from `(gender, interested_in[], relationship_status)`:

- **Everyone's Field** → all users.
- **Seeking Connection set** → users whose `relationship_status ∈ {single, dating}`:
  - **Women + Men** — shown if (gender = woman AND interested-in includes men) OR (gender = man AND interested-in includes women).
  - **Women + Women** — shown if gender = woman AND interested-in includes women.
  - **Men + Men** — shown if gender = man AND interested-in includes men.
  - **Open Connections** — shown to anyone open to multiple genders.
  - **Non-binary users:** all four Seeking Connection rooms shown (free choice).

Implemented as a Postgres function `available_communities(user_id) returns setof communities` (authoritative, RLS-enforced for join), mirrored by a Swift helper for display. "Available" ≠ "joined": the user explicitly taps **Join**.

---

## 4. Phase 1 — Tab Restructure & Swipe Teardown

**Goal:** Stop being a swipe app; rebrand tabs. Low-risk, unblocks everything.

- `MainTabView`: reorder/relabel to **Soil · The Field · Gardener · Seeds · Profile**. Field tab placeholder until Phase 3.
- Remove **Swipe** tab and route into `DiscoverView`; delete deck UI from navigation (`DiscoverView`, `SwipeCardView`, `MatchModalView`). Keep `ProfileDetailView` (reused by Seeds/search).
- **Values → Soil:** rename tab label + icon copy; update `ValuesView` headers to "What I Bring / What I Need / Your relational soil — Discover the conditions where love grows." No logic change. (Do **not** call it "Growth" — modules not built.)
- **Chat → Seeds:** rename tab; `MindfulMessagesView` becomes the Seeds inbox shell (filled in Phase 2).
- Retire `SwipeService` / `DiscoverViewModel` from the app (leave files or delete; remove references). `matches`/`swipes` tables stay in DB.

**Acceptance:** App builds with 5 new tabs, no swipe deck reachable, Soil and Seeds labels live, existing chat still works under the Seeds tab.

---

## 5. Phase 2 — Seeds (replaces matching)

**Goal:** Replace swipe→match→chat with sendSeed→accept→conversation.

### Flow
1. User opens a profile (from search or The Field) → taps **Send a Seed** → writes an opening message → submits.
2. Creates a `seeds` row (`status=pending`). Enforces the sender's **daily limit** (§8) server-side; blocks + informs when exhausted.
3. Recipient sees **"<Name> sent you a Seed 🌱"** in Seeds → **Requests**. Push notification type `seed`.
4. **Let It Grow / Accept** → create a `conversation`, set `seeds.status=accepted`, `conversation_id`; opening message becomes the first message. Both land in **Conversations**.
5. **No Thanks / Decline** → `status=declined`; no chat; sender is not notified of decline (request simply doesn't grow).

### Seeds tab UI
- Two segments: **Requests** and **Conversations**.
- **Requests** has a received/sent sub-toggle: *Received* (incoming pending) and *Sent* (your pending outgoing).
- **Conversations** = accepted, active threads (reuses `ChatDetailView`).
- Replaces the current matches+inbound-likes inbox in `MindfulMessagesView`.

### Backend
- `SeedService` (Swift): `sendSeed`, `acceptSeed`, `declineSeed`, `listReceived`, `listSent`, `listConversations`.
- Postgres: insert trigger enforces daily limit + uniqueness; accept is an RPC that atomically flips status and creates the conversation. Push trigger for `seed`.
- `send-push` Edge Function: add `seed` notification type.

**Acceptance:** Can send a Seed (limited by tier), receive it, accept→chat opens with opening message, decline→closes; daily limit enforced; reused messaging works end-to-end.

---

## 6. Phase 3 — The Field (communities)

**Goal:** Community discovery + group chat with access rules.

- **The Field tab** lists **available** communities (from §3.3), showing joined vs joinable; user taps **Join** / **Leave**.
- **MVP rooms** seeded: Everyone's Field + the four Seeking Connection rooms.
- **Community chat** view reuses the realtime message pattern over `community_messages` (`is_removed` filtered out). New `CommunityService`, `CommunityChatViewModel`, `FieldView`, `CommunityChatView`.
- **Icebreaker prompts:** optional, surfaced when entering a room (from `community_prompts`); seed the list from the source doc's examples.
- **Contact-info guard** (see §9) runs on community message send.
- RLS: a user may read/post in a community only if they are an `active` member and not `banned`.

**Acceptance:** User sees only rooms they qualify for, can join/leave, post and see realtime messages, icebreakers appear, contact info is blocked with a nudge.

---

## 7. Phase 4 — Relationship Status (onboarding + profile)

**Goal:** Collect relationship status; drive Field access; allow updates.

- New onboarding step `.relationshipStatus` inserted after `.interestedIn` in `OnboardingStep` + `OnboardingContainerView` switch + `OnboardingViewModel` state. Options: **Single / Dating / In a relationship / Engaged / Married**.
- **Expectation copy** on the step: *"Harvest communities are built around trust and intentional connection. Please select your current relationship status honestly so you enter the spaces designed for your current season."*
- `users.relationship_status` written on completion; existing users prompted once (or default handling — backfill nullable, treat null as not-yet-set and prompt before Field access).
- **Editable** in Profile → Edit Profile → Relationship Status. Changing it **recomputes Field availability** immediately (e.g., single→dating keeps Seeking Connection; moving to in_relationship/engaged/married removes Seeking Connection access and, in Phase 7, would unlock Growing Together).
- **Community Standards** addition (honesty clause) added to terms/standards copy — see source doc §10.

**Acceptance:** New users set status; it gates Seeking Connection (single/dating only); editing it updates available rooms; honesty copy shown.

---

## 8. Phase 5 — Subscription Tiers

**Goal:** Redefine tiers and enforce Seed send limits.

| Tier | Price | Daily Seeds sent | Receive | Gardener | Soil insights | Notes |
|---|---|---|---|---|---|---|
| 🌱 **Seed** (Free) | $0 | **3** | Unlimited | Limited | Basic | Soil assessment, basic profile, Field access, receive unlimited Seeds |
| 🌿 **Green** | $19.99/mo | **5** | Unlimited | More | Deeper + advanced compatibility | More reflection features |
| 🌳 **Gold** | $24.99/mo | **25** | Unlimited | Full | Premium growth features | Future: Growth Path modules + free in-person events (Phase 7) |

- Add `daily_seed_limit` (and feature flags) to `subscription_tiers`; seed the three tiers.
- Enforce send limit server-side in the Seeds insert path (reuse `RateLimitService` pattern); surface remaining/limit in UI.
- `SubscriptionService.getTierForUser` already exists; extend to expose `dailySeedLimit` and feature gates.
- **Dependency:** IAP price-point wiring for $19.99 / $24.99 (StoreKit products). Flagged for planning; limit-enforcement does not block on it.

**Acceptance:** Each tier enforces its daily Seed limit; receiving always unlimited; tier features gated.

---

## 9. Phase 6 — Moderation & Safety

**Goal:** Protect The Field (public) and Seeds (private).

### Reporting (extends existing `user_reports`)
- Add `target_type` (`profile | community_message | seed_message`) + `target_id`.
- Report entry points: a community message, a private Seed message, and a user profile (existing `ReportUserView` extended to carry target type/id).

### Admin abilities (extend `admin/app.js` + `moderation_queue`)
- Review reported content (now grouped by target type).
- **Remove an individual community message for everyone** (set `community_messages.is_removed`).
- **Per-room ban** (`community_members.status = 'banned'`) — removes a user from a specific Field community.
- **Restrict / remove a user from Harvest entirely** (existing `is_banned` + eject) for Community Standards violations.
- Andre is the initial moderator/admin; `community_members.role = 'moderator'` supports adding more later.

### Contact-info flagging (community messages only)
- On community message send, run regex detection for **phone numbers** and **Snap/Instagram handles** ("add me on snap", `@handle`, digit runs).
- **Action: block + warn** before posting: *"Keep contact sharing to private Seed conversations."* Message is not posted.
- Private accepted Seed conversations are **unrestricted** (both parties chose to connect).
- Detection runs client-side for instant feedback **and** server-side (DB trigger / function) as the authority.

**Acceptance:** Users can report messages/profiles; admin can remove a community message and per-room ban; phone/handle attempts in community chat are blocked with a nudge; private chats unaffected.

---

## 10. Phase 7 — Deferred (Post-MVP)

Explicitly out of MVP scope; documented for continuity:

- **Gardener match suggestions** — Gardener suggests people to send Seeds to (intentional intros, not matches; never limits visibility). All discovery still ends in Send Seed → accept → chat.
- **Profile search/discovery filters** — convert existing matching filters (`FilterService`) into search/explore filters (location, age, values, status, I-Bring/I-Need alignment, gender, interested-in). Browse → profile → Send Seed. (MVP relies on community + direct profile access; full search UI is Phase 7.)
- **Growing Together** room (in_relationship/engaged/married) + "Invite your partner."
- **Just the Girls / Just the Guys** peer spaces (gender-based, non-binary opt-in) — needs the safest gender-peer implementation; launch general M+M/F+F/M+F first.
- **Location-based** Seeking Connection spaces.
- **Growth Path** content: Soil → Seed → Sprout → Bloom → Thrive lessons/modules/e-books.
- **In-person community events** (Gold free access).

---

## 11. Open dependencies / assumptions

- IAP/StoreKit products for the new price points must be configured (Phase 5).
- Existing-user backfill for `relationship_status`: treat null as "prompt before granting Field access."
- Realtime publication must include `community_messages` (mirror the `messages` migration `20260604120000_enable_message_realtime.sql`).
- `matches`/`swipes`/`conversations(match_id)` retained read-only; new conversations created by Seeds use a nullable/created path independent of `match_id` (verify `conversations` schema allows conversation without a match during planning).

---

## 12. Positioning

Old: Swipe → Match → Chat. New: **Soil → Field → Seeds → Conversation** — understand what you bring and need, enter the community, send intentional Seeds, grow conversations. Removes App-Store dating-app similarity concerns and aligns with the Harvest 2.0 vision.
