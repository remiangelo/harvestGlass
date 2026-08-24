# Android Seeds & 1:1 Chat (P2c) — Verification Checklist

**Plan:** `docs/superpowers/plans/2026-08-20-android-seeds-chat.md`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Automated — verified

```bash
cd android && ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

- [x] **172 unit tests, 0 failures** (up from 141 at the end of P2b)
  - `ConversationTest` (9) — case-insensitive participant and authorship resolution
  - `SeedServiceTest` (7) — all three `accept_seed` response shapes, typed error copy
  - `SeedsViewModelTest` (7) — accept routes to the conversation with the **sender** as
    partner, decline removes, a failed accept leaves the seed in place, a failing
    conversation list doesn't fail the tab
  - `ChatViewModelTest` (8) — double-tap send guard, realtime echo de-duplication,
    failed-send text recovery, blur-hint category mapping
- [x] **44 instrumented tests, 0 failures**
- [x] Builds, installs, launches with no crash
- [x] The Seeds tab renders at parity: "Seeds" title, Requests/Conversations segments,
      Received/Sent sub-segments, and seed cards with verbatim "Let It Grow" / "No Thanks"
- [x] Segment row spacing matches iOS (the two rows were flush; iOS has `Spacing.md`
      between them)

Note on the instrumented run: the first attempt reported "Starting 0 tests … FAILED".
That was a wedged emulator — `boot_completed` was 1 but the package manager was
unresponsive. A cold restart fixed it and all 44 passed. Not a code fault.

## Manual — needs two accounts

This is the first subsystem that genuinely needs **two** users to verify. Use the iOS app
as the second participant.

### Seeds

- [ ] A Seed sent from iOS appears under Received on Android
- [ ] A Seed sent from Android appears on iOS, and shows under Sent as "Pending" here
- [ ] "Let It Grow" opens the conversation immediately and the seed disappears from
      Received — on both clients
- [ ] The conversation opens with the **sender** as the partner, not yourself
- [ ] "No Thanks" removes the seed and creates no conversation
- [ ] Exceeding the daily Seed limit shows "You've reached today's Seed limit. Upgrade or
      try again tomorrow."
- [ ] Empty states read "No new Seeds yet" / "No pending sent Seeds" with the right
      subtitle for each side

### Conversations list

- [ ] Accepted conversations appear under Conversations, newest activity first
- [ ] Each row shows the partner's nickname, photo and last-message preview
- [ ] A conversation whose newest message came from the partner shows the reply dot
- [ ] A blocked user's conversation disappears from the list
- [ ] A preview containing flagged language is masked as "Message hidden — tap to view"

### 1:1 chat

- [ ] History loads oldest-first and lands on the newest message
- [ ] Your messages are rose gradient on the right; theirs are near-white on the left
- [ ] A message sent from iOS appears live without a refresh
- [ ] Double-tapping send inserts exactly one message
- [ ] A failed send (airplane mode) returns the text to the composer
- [ ] Time labels appear once per run, not on every bubble
- [ ] Your sent messages show the read receipt filling in when the partner reads them
- [ ] With the keyboard open, the last message is fully visible above the composer

### Safety

- [ ] An incoming message with hostile language arrives **blurred**, with
      "May contain hostile language" and "Tap to reveal"
- [ ] Tapping reveals it, and it stays revealed
- [ ] Your own outgoing messages are never blurred
- [ ] Report files a row in `user_reports`
- [ ] Block files a `user_blocks` row, auto-files a report alongside, and deactivates the
      match — verify all three

## Known gaps

- **The mindful pre-send warning is not ported.** On iOS, sending a concerning message
  opens a warning sheet first. Here the message sends directly. That needs
  `MindfulMessagingService`'s OpenAI path and lands with the AI subsystem.
  **Blur-on-receive IS present** — it runs on the local keyword path.
- **Blur hints are limited to two categories.** `aggressive` and `sexual_pressure` are
  ported and produce their exact iOS hint. The other five lexicons (manipulative,
  possessive, pressuring, excessive_intensity, personal_info) are not ported, so messages
  that would trip only those do not blur at all yet.
- **The "ready to move" safety gate is not ported** — `SafetyAnalysisService`, AI subsystem.
- **Report has no category picker.** iOS opens `ReportUserView` with a reason list; the
  Android menu files a report with a fixed reason. The picker ports with Safety.
- **Inbound likes / "Likes You"** are not ported — swipe-era, and gated on the
  subscription tier lookup that is still deferred.
- **Typing indicators** are implemented in the service but not surfaced in the chat UI.
