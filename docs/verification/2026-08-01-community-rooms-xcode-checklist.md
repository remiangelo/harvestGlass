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
