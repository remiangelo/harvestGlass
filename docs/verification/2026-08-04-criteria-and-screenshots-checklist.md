# Verification — room criteria + Gardener screenshots (2026-08-04)

Two features. The SQL half is verifiable now; the Swift half needs the Mac.

**The migration has NOT been applied.** `supabase/migrations/20260804120000_room_access_criteria.sql`
must be run in the Supabase SQL editor before any of §1 can be checked. Nothing
in the app breaks until it is — the column simply doesn't exist yet, and
`available_communities()` keeps its current behaviour.

## 1. Migration (run in the SQL editor, then verify)

- [ ] Migration applies cleanly; `cube` and `earthdistance` extensions install.
- [ ] Every existing room now has `criteria = '{}'`.
- [ ] Every user still sees exactly the rooms they saw before —
      `select count(*) from available_communities('<user>')` is unchanged for
      a few sample users.

### Criteria logic
- [ ] Age-restricted room: user inside the band sees it, user outside doesn't.
- [ ] Faith-restricted room: user with matching `spiritual_orientation` sees it.
- [ ] **User with NULL `spiritual_orientation` does NOT see it.** This is the
      deliberate strict rule — if this passes for them, the feature is broken.
- [ ] Multi-value array (`"drinking": ["Never","Socially"]`) matches either.
- [ ] Matching is case-insensitive.
- [ ] Empty array (`"gender": []`) behaves as no constraint.

### Location
- [ ] Room centred on Washington DC with `radius_miles: 100`: a user with
      coordinates ~50 mi away sees it.
- [ ] A user ~500 mi away does not.
- [ ] A user with NULL latitude/longitude does not.

### Grandfathering — the one most likely to regress
- [ ] Join a room, then edit your profile so you no longer qualify.
- [ ] The room **still appears** in your Field and still opens.
- [ ] It does **not** appear for a non-member who fails the same criteria.

## 2. Admin panel (runnable now, no Mac)

- [ ] Restrictions section is collapsed for unrestricted rooms, open for
      restricted ones.
- [ ] Setting age + faith + a location and saving round-trips: reopen the form
      and every value is still there.
- [ ] Room list shows a `restricted` pill with a readable summary.
- [ ] "Look up place" resolves and displays the matched address; lat/lng fields
      populate and are read-only.
- [ ] Saving a place with no coordinates is **rejected** with the explanatory
      alert, not silently saved.
- [ ] Clearing all restrictions saves `{}` and the pill disappears.

## 3. Gardener screenshots (Mac)

- [ ] Build succeeds; `ChatMessageEncodingTests`, `ScreenshotVerdictParsingTests`,
      and `ScreenshotEncoderTests` pass.
- [ ] **Regression:** ordinary Gardener text chat still works. If it broke, the
      `ChatMessage` encoding change is the cause — a lone text part must encode
      as a bare string.
- [ ] Mindful warnings, blurbs, and compatibility summaries still work (same
      `ChatMessage` type).
- [ ] Photo button opens the picker; chosen image appears as a thumbnail with
      the "not saved" note.
- [ ] X removes the staged image and re-enables normal text sending.
- [ ] Send with no caption works — a screenshot alone is sendable.
- [ ] **A real chat screenshot gets coaching about the conversation.**
- [ ] **A selfie/landscape/meme gets the exact refusal text**, which mentions
      only reviewing chat screenshots and invites a retry.
- [ ] History shows `📷 Screenshot` for the user turn, and the reply below it.
- [ ] Reopening the Gardener shows that history correctly.
- [ ] Character counter drops by 1,000 per screenshot.
- [ ] At the daily limit, uploading is refused before any encoding happens.
- [ ] Airplane mode: sending a screenshot shows "I couldn't read that
      screenshot just now" — **not** the not-a-screenshot refusal. Blaming the
      user for a network failure is the bug to watch for here.

## 4. Known-ambiguous, not bugs

- A photo *of* a printed or on-screen conversation may be refused. Detection is
  a model judgement; the refusal wording invites a retry for this reason.
- Restricted rooms look sparse. Blank profile fields exclude, by design.
- A user who hasn't opened the updated app has no coordinates and sees no
  location-restricted rooms until they do.
