# Harvest Android — Seeds & 1:1 Chat (P2c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Seeds placeholder with the real connection loop — incoming/outgoing Seed requests, accept/decline, the conversation list, and 1:1 chat with Realtime.

**Architecture:** Mirrors what P1 did for The Field. The chat components built there (`ChatBubble`, `ChatComposer`, `DateSeparator`, `MessageGrouping`, `ChatAccent`) are reused wholesale — `ChatAccent.Rose` was defined for exactly this screen and has been unused until now. Seeds is a two-segment list; chat is the same transcript shape as a community room with a different accent and a different message table.

**Tech Stack:** As established. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Scope Decision

`ChatViewModel.swift` (459 lines) reaches into two services that are their own subsystems:

- **`SafetyAnalysisService`** (596 lines) — the AI-backed "ready to move" conversation
  analysis. That is Gardener/OpenAI infrastructure.
- **`MindfulMessagingService`** — the pre-send warning, same OpenAI surface, already
  deferred once in P1's community chat for the same reason.

Both are **deferred to the Gardener/AI subsystem**. The local keyword half of mindful
messaging is already ported as `ObjectionableContent` (P2a) and can be reused when that
subsystem lands.

**`MatchService` is ported in part**: only `reportUser`, `blockUser` and `unmatchUser`.
Those are safety-critical and user-facing, and three methods do not justify deferring the
whole chat. The rest of `MatchService` (the matching queue) ports with Discover.

`MindfulMessagesView` (445 lines — the mindful inbox) is **not** in this plan; it is a
separate screen belonging to the same AI subsystem.

## Global Constraints

Everything from prior phases still applies. Additionally:

- **Do not modify anything under `Harvest/`.**
- **User ids compare case-insensitively.** `Conversation.otherUserId` and
  `Message.isSentBy` both lowercase before comparing. Reproduce that or a conversation
  will show the wrong participant.
- **`accept_seed` is an RPC returning a scalar uuid**, and the Swift decodes it
  defensively (scalar string, then single-element array, then raw-trimmed body) because
  the transport shape varies. Keep all three fallbacks.
- **`SEED_LIMIT_REACHED` from Postgres becomes a typed error** with the copy
  "You've reached today's Seed limit. Upgrade or try again tomorrow."
- **Reuse the P1 chat components.** Do not write a second bubble or composer.
- **All user-visible copy is verbatim.**

---

### Task 1: Seed, Conversation and Message models

**Files:**
- Create: `data/model/Seed.kt`, `data/model/Conversation.kt`, `data/model/Message.kt`
- Test: `src/test/java/com/harvestglass/harvest/data/model/ConversationTest.kt`

**Interfaces:**
- Produces: `enum class SeedStatus { PENDING, ACCEPTED, DECLINED }` (serial names lowercase);
  `Seed(id, senderId, recipientId, openingMessage, status, conversationId, createdAt, respondedAt)`;
  `Conversation(id, matchId, lastMessageAt, lastMessagePreview, user1Id, user2Id, createdAt)`
  with `fun otherUserId(currentUserId: String): String?`;
  `data class ConversationWithProfile(conversation, profile, hasReplyHighlight)`;
  `Message(id, conversationId, senderId, content, messageType, mediaUrl, isRead, readAt, createdAt)`
  with `fun isSentBy(userId: String): Boolean`.

- [ ] **Step 1: Write the failing test**

The case-insensitive id comparison is the subtle part — a mismatch silently shows the
wrong participant in a conversation.

```kotlin
package com.harvestglass.harvest.data.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationTest {
    private val json = Json { ignoreUnknownKeys = true }

    private fun conversation(u1: String?, u2: String?) = Conversation(
        id = "c1", matchId = null, lastMessageAt = null, lastMessagePreview = null,
        user1Id = u1, user2Id = u2, createdAt = null
    )

    @Test
    fun `the other user is whichever slot is not me`() {
        assertEquals("u2", conversation("u1", "u2").otherUserId("u1"))
        assertEquals("u1", conversation("u1", "u2").otherUserId("u2"))
    }

    @Test
    fun `id comparison ignores case`() {
        // Supabase hands back lowercased uuids; a caller may not.
        assertEquals("u2", conversation("U1", "u2").otherUserId("u1"))
        assertEquals("u2", conversation("u1", "u2").otherUserId("U1"))
    }

    @Test
    fun `a conversation I am not part of has no other user`() {
        assertNull(conversation("u1", "u2").otherUserId("u9"))
    }

    @Test
    fun `a half-populated conversation degrades rather than throwing`() {
        assertNull(conversation(null, null).otherUserId("u1"))
    }

    @Test
    fun `message authorship ignores case`() {
        val m = Message(
            id = "m1", conversationId = "c1", senderId = "U1",
            content = "hi", isRead = false, createdAt = null
        )
        assertTrue(m.isSentBy("u1"))
        assertFalse(m.isSentBy("u2"))
    }

    @Test
    fun `seed decodes snake_case columns and its status`() {
        val row = """
            {"id":"s1","sender_id":"u1","recipient_id":"u2","opening_message":"hello",
             "status":"pending","conversation_id":null,"created_at":"2026-08-20T10:00:00Z"}
        """.trimIndent()
        val s = json.decodeFromString<Seed>(row)
        assertEquals("u1", s.senderId)
        assertEquals("hello", s.openingMessage)
        assertEquals(SeedStatus.PENDING, s.status)
        assertNull(s.conversationId)
    }

    @Test
    fun `conversation decodes its preview columns`() {
        val row = """
            {"id":"c1","match_id":"m1","last_message_at":"2026-08-20T10:00:00Z",
             "last_message_preview":"see you then","user1_id":"u1","user2_id":"u2"}
        """.trimIndent()
        val c = json.decodeFromString<Conversation>(row)
        assertEquals("see you then", c.lastMessagePreview)
        assertEquals("m1", c.matchId)
    }
}
```

- [ ] **Step 2: Run to verify failure. Step 3: Implement. Step 4: Run, expect PASS.**

`SeedStatus` needs `@SerialName("pending")` etc. so the lowercase column values decode.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(android): port Seed, Conversation and Message models"
```

---

### Task 2: SeedService and ChatService

**Files:**
- Create: `data/service/SeedService.kt`, `data/service/ChatService.kt`
- Modify: `di/AppModule.kt`
- Test: `src/test/java/com/harvestglass/harvest/data/service/SeedServiceTest.kt`

**Interfaces:**
- Produces:
  - `class SeedError` as a sealed hierarchy: `SeedError.DailyLimitReached`,
    `SeedError.Underlying(message)`, both `Exception` subclasses with the Swift's copy.
  - `class SeedService(client)` with `sendSeed(senderId, recipientId, openingMessage)`,
    `acceptSeed(seedId): String`, `declineSeed(seedId)`, `receivedPending(userId): List<Seed>`,
    `sentPending(userId): List<Seed>`, `sentTodayCount(userId): Int`,
    and `internal fun parseConversationId(raw: String): String?`.
  - `class ChatService(client)` with `getMessages(conversationId): List<Message>`,
    `sendMessage(conversationId, senderId, content): Message?`,
    `conversations(userId): List<Conversation>`, `markAsRead(messageId)`,
    `subscribeToMessages(conversationId): Flow<Message>`,
    `sendTypingIndicator(conversationId, userId)`,
    `subscribeToTyping(conversationId): Flow<String>`.

- [ ] **Step 1: Write the failing test**

The `accept_seed` RPC's response shape varies by transport, and the Swift carries three
fallbacks for it. That parsing is pure and worth pinning down.

```kotlin
class SeedServiceTest {
    private val service = SeedService(mockk(relaxed = true))

    @Test fun `a bare scalar uuid parses`() {
        assertEquals("abc-123", service.parseConversationId("\"abc-123\""))
    }

    @Test fun `a single-element array parses`() {
        assertEquals("abc-123", service.parseConversationId("[\"abc-123\"]"))
    }

    @Test fun `an unquoted body is trimmed`() {
        assertEquals("abc-123", service.parseConversationId("  abc-123\n"))
    }

    @Test fun `an empty body yields nothing`() {
        assertNull(service.parseConversationId("  \n "))
        assertNull(service.parseConversationId("\"\""))
    }
}
```

Also assert the typed error copy:

```kotlin
    @Test fun `the daily limit error carries the user-facing copy`() {
        assertEquals(
            "You've reached today's Seed limit. Upgrade or try again tomorrow.",
            SeedError.DailyLimitReached().message
        )
    }
```

- [ ] **Step 2: Run to verify failure. Step 3: Implement.**

Details that must carry over:
- `sendSeed` catches any error whose string contains `SEED_LIMIT_REACHED` and rethrows
  `SeedError.DailyLimitReached`; everything else becomes `SeedError.Underlying`.
- `acceptSeed` calls the `accept_seed` RPC with param `p_seed_id` and runs the raw body
  through `parseConversationId`, throwing `SeedError.Underlying` when it yields null.
- `declineSeed` sets `status = "declined"` and `responded_at` to an ISO-8601 instant.
- `receivedPending` / `sentPending` filter `status = "pending"` and order
  `created_at` **descending**.
- `sentTodayCount` counts rows with `created_at >= ` start-of-day, matching the server
  trigger's `date_trunc('day', now())`.
- `subscribeToMessages` mirrors the community-room pattern: channel `messages:<id>`,
  `postgresChangeFlow<PostgresAction.Insert>` on `messages` filtered by `conversation_id`.
- Typing indicators use a **broadcast** channel `typing:<id>`, not postgres_changes —
  read lines 146–195 of `ChatService.swift` and match the event name and payload key.

- [ ] **Step 4: Run tests, expect PASS. Add both Hilt providers. Commit**

```bash
git commit -m "feat(android): port SeedService and ChatService"
```

---

### Task 3: MatchService (safety slice)

**Files:**
- Create: `data/service/MatchService.kt`
- Modify: `di/AppModule.kt`

**Interfaces:**
- Produces: `class MatchService(client)` with `reportUser(reporterId, reportedUserId, reason, details)`,
  `blockUser(userId, blockedUserId)`, `unmatchUser(matchId)`.

Only these three. The matching queue ports with Discover.

- [ ] **Step 1: Read `Harvest/Services/MatchService.swift`** and port exactly those three
  methods, including their table names and column shapes.
- [ ] **Step 2: Build, add the provider, commit**

```bash
git commit -m "feat(android): port the MatchService safety actions"
```

---

### Task 4: SeedsViewModel and the Seeds screen

**Files:**
- Create: `ui/seeds/SeedsViewModel.kt`, `ui/seeds/SeedsScreen.kt`, `ui/seeds/SendSeedSheet.kt`
- Modify: `ui/MainTabScreen.kt` — replace the SEEDS placeholder
- Test: `src/test/java/com/harvestglass/harvest/ui/seeds/SeedsViewModelTest.kt`
- Test: `src/androidTest/java/com/harvestglass/harvest/ui/seeds/SeedsScreenTest.kt`

**Interfaces:**
- Produces: `enum class SeedsSegment { REQUESTS, CONVERSATIONS }`;
  `enum class RequestKind { RECEIVED, SENT }`;
  `data class SeedsUiState(segment, requestKind, received, sent, conversations, isLoading, error, openedConversationId, openedPartnerUserId)`;
  `@HiltViewModel class SeedsViewModel` with `load(userId)`, `setSegment`, `setRequestKind`,
  `accept(seed, userId)`, `decline(seed, userId)`, `clearOpenedConversation()`;
  `@Composable fun SeedsScreen(userId: String, onOpenConversation: (String, String) -> Unit)`
  and a stateless `SeedsContent(...)`.

- [ ] **Step 1: Write the failing test**

```kotlin
    @Test
    fun `accepting a seed removes it and routes into the conversation`() = runTest {
        coEvery { service.receivedPending("u1") } returns listOf(seed)
        coEvery { service.sentPending("u1") } returns emptyList()
        coEvery { service.acceptSeed("s1") } returns "c9"
        val vm = vm(); vm.load("u1"); advanceUntilIdle()

        vm.accept(seed, "u1"); advanceUntilIdle()

        assertTrue(vm.state.value.received.isEmpty())
        assertEquals("c9", vm.state.value.openedConversationId)
        // The partner is the SENDER of the accepted seed.
        assertEquals("u2", vm.state.value.openedPartnerUserId)
    }

    @Test
    fun `declining removes the seed without opening anything`() = runTest { … }

    @Test
    fun `a failed accept leaves the seed in place`() = runTest { … }

    @Test
    fun `the daily-limit error surfaces its copy`() = runTest { … }
```

- [ ] **Step 2: Run to verify failure. Step 3: Implement.**

Read `Harvest/Views/Seeds/SeedsView.swift` (149) and `SendSeedSheet.swift` (100) for copy
and layout. The Seeds tab has a Requests/Conversations segment, and within Requests a
Received/Sent sub-segment.

- [ ] **Step 4: Wire into `MainTabScreen`. Step 5: Run tests, expect PASS. Commit**

```bash
git commit -m "feat(android): port the Seeds tab"
```

---

### Task 5: 1:1 chat

**Files:**
- Create: `ui/chat/ChatViewModel.kt`, `ui/chat/ChatDetailScreen.kt`, `ui/chat/ReportUserSheet.kt`
- Modify: `ui/MainTabScreen.kt` — route from a Seed conversation into chat
- Test: `src/test/java/com/harvestglass/harvest/ui/chat/ChatViewModelTest.kt`

**Interfaces:**
- Produces: `data class ChatUiState(messages, partner, draft, isLoading, isSending, error, isPartnerTyping)`;
  `@HiltViewModel class ChatViewModel` with `start(conversationId, userId, partnerUserId)`,
  `send(content)`, `markRead(messageId)`, `onDraftChange(text)`, `report(...)`, `block(...)`,
  `unmatch(...)`; `@Composable fun ChatDetailScreen(conversationId, userId, partnerUserId, onBack)`.

- [ ] **Step 1: Write the failing test**

Reuse the shape of `CommunityChatViewModelTest` — the same hazards apply:

```kotlin
    @Test fun `start loads history oldest-first`() = …
    @Test fun `send is a no-op while a send is in flight`() = …
    @Test fun `blank content is not sent`() = …
    @Test fun `a realtime echo does not duplicate the sent message`() = …
    @Test fun `a failed send hands the text back`() = …
```

- [ ] **Step 2: Run to verify failure. Step 3: Implement.**

`ChatDetailScreen` reuses `ChatBubble`, `ChatComposer`, `DateSeparator` and
`MessageGrouping` with **`ChatAccent.Rose`**. The mindful pre-send check and the
safety "ready to move" banner are **not** wired — see Scope Decision — and their absence
must be noted in the checklist rather than faked.

- [ ] **Step 4: Run tests, run the app, commit**

```bash
git commit -m "feat(android): port 1:1 Seed chat"
```

---

### Task 6: Verification

- [ ] Run the whole suite; record actual counts.
- [ ] Create `docs/verification/2026-08-20-android-seeds-chat-checklist.md` covering:
      a Seed sent from iOS appears in Received; accepting opens the conversation and the
      seed disappears on both clients; declining removes it; the daily limit surfaces its
      copy; messages send, appear live from iOS, and do not duplicate on echo; typing
      indicators work; report/block/unmatch take effect; and the deferred mindful/safety
      layers are visible-but-expected omissions.
- [ ] Commit.

---

## What this plan deliberately does not cover

- **Mindful messaging** (pre-send warning, `MindfulMessagesView` inbox) — OpenAI surface.
- **Safety "ready to move" analysis** — `SafetyAnalysisService`, same subsystem.
- **Discover / swiping / compatibility / filters** — the rest of `MatchService`.
- **Gardener, Profile/Settings/Help/Safety, Subscription + Notifications.**
