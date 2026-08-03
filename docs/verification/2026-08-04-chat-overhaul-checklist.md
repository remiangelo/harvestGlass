# Xcode verification — light repalette + chat overhaul (2026-08-04)

None of this was compiled before it shipped (no Mac in the authoring loop), so
**the build is the first gate** — expect to fix compile errors before any of
the visual items below can be checked.

Needs two test accounts that share at least one room, and a Supabase SQL editor
tab for the double-send check.

## Build
- [ ] `xcodebuild -project Harvest.xcodeproj -scheme Harvest -destination 'generic/platform=iOS Simulator' build` succeeds.
- [ ] Zero new warnings.
- [ ] `xcodebuild test ...` passes, including `MessageGroupingTests` (17 cases)
      and `DateSeparatorTests` (7 cases), plus the five pre-existing suites.

## Light repalette — the highest-risk change
The app inverted from a near-black plum to a cream page. Walk **every** tab.
- [ ] No white-on-cream or cream-on-white text anywhere. Look hardest at:
      onboarding, profile edit, filters, settings, subscription, safety
      dashboard, help centre, values, compatibility.
- [ ] Nav bar titles are dark and legible on every screen (21 toolbars flipped).
- [ ] Tab bar: labels legible, selected state visible.
- [ ] Room banner photos still have their dark scrim and the room name on top
      is white, not dark.
- [ ] Form screens (`formBackground`/`formSurface`) read as light cards, not
      dark panels.
- [ ] Buttons using `.harvestGlass` styles have legible labels.
- [ ] Any remaining dark surface is intentional — the only sanctioned one is
      `photoScrim` over user photography.
- [ ] Sheets and alerts inherit light chrome (`preferredColorScheme(.light)`).

## Double-send — the actual bug
- [ ] Settings → mindful messaging ON. Type a message, tap send twice fast.
      `select count(*) from community_messages where content = '<text>'`
      returns exactly 1.
- [ ] Same in a Seed chat against `messages`. Returns exactly 1.
- [ ] Send button shows a spinner while in flight, then returns to the arrow.
- [ ] Airplane mode: send fails, the text comes back in the field, error shows.
- [ ] Mindful warning → "Edit": the text is back in the composer, not lost.
      (This is new behaviour — the draft is now cleared when the send starts,
      so dismissal has to restore it.)
- [ ] Mindful warning → "Send anyway": exactly one message posts.
- [ ] Reply target survives a failed send and clears on a successful one.

## Grouping
- [ ] Three quick messages from one sender: one avatar, one name, one timestamp.
- [ ] Same sender after a 10-minute gap: new group, avatar and name return.
- [ ] Alternating senders: every message keeps its own avatar and name.
- [ ] Own messages show no avatar and no "You" label.
- [ ] Bubble corners tighten within a run and round off at the ends.
- [ ] Timestamps actually appear. If every message shows none, timestamp
      parsing is failing — check `MessageGrouping.date(from:)` against a real
      `created_at` value from the database.

## Date separators
- [ ] "Today" above the first message of the day.
- [ ] Older conversation shows "Yesterday" / a weekday / a date.
- [ ] Separator appears once at the top of the transcript.

## Regressions — room chat
- [ ] Pagination: >50 messages, "Load earlier" prepends without scroll jump.
- [ ] New incoming message still autoscrolls to the bottom.
- [ ] Swipe right to reply; X clears the reply bar.
- [ ] Reply renders the quoted sender and snippet; tapping scrolls to the original.
- [ ] Admin-remove the original → the quote reads "Message removed".
- [ ] "@" autocomplete lists members; the mention renders green and bold.
- [ ] Mentioned account sees the green bubble edge.
- [ ] Long-press → 🌱 💚 🌻 😂 👏 🤔; toggling syncs live to the second account.
- [ ] Reaction chips line up under the bubble, clear of the avatar gutter, and
      sit on the correct side for your own messages.
- [ ] Icebreakers sheet still opens from the composer's lightbulb.
- [ ] Contact-info block still shows the friendly nudge.
- [ ] Blurred message: tap to reveal works, hint text correct, and the blur
      overlay text is legible against the new near-white bubble.
- [ ] Report message, and tap-avatar → profile with "Send a Seed".
- [ ] Tapping the transcript dismisses the keyboard (new in this screen).

## Regressions — Seed chat
- [ ] Timestamps and read receipts show once per run, on the last message.
- [ ] Typing indicator matches the incoming bubble surface.
- [ ] Safety warning banner and status badge still legible.
- [ ] Blur/reveal, report, block, unmatch, Ready to Move all still work.
- [ ] Tapping the transcript still dismisses the keyboard.

## Field
- [ ] Banner renders above the room list; leaf watermark clipped to the card.
- [ ] Both mode pills visible; nothing overflows at the largest Dynamic Type size.
- [ ] Room cards, join, and leave unchanged.
- [ ] Joined cards keep their green border; the Join button is still green.

## Accessibility
- [ ] Largest Dynamic Type: composer, banner, and bubbles all still usable.
- [ ] Field green and red accents hold contrast against cream for body text.
      `textTertiary` on cream is the weakest pairing — check it is only used
      for decorative or secondary metadata, never for anything load-bearing.
