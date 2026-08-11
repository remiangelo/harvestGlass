# Verification — subscription tier restructure (2026-08-11)

Swift in this change was written on Windows and has **not been compiled**. The
SQL has **not been applied**. Work through this in order — the migration first,
because the app reads the new columns.

## 1. Apply the migration

`supabase/migrations/20260811100000_subscription_tiers_restructure.sql`, via the
dashboard SQL editor (`execute_sql`, not `apply_migration` — this project's
history is out of sync with the repo).

- [ ] Runs without error. The `DROP COLUMN` block at the end is the risky part:
      if a view, policy or function still references `can_see_likes` or the
      other swipe-era columns it will fail there. **Do not add CASCADE** — find
      the dependency and decide about it deliberately.
- [ ] Verify query at the bottom of the file returns:

| name | price_monthly | seeds/day | gardener chars | screenshots/day | filters | deep soil | growth |
|------|---------------|-----------|----------------|-----------------|---------|-----------|--------|
| Seed | 0 | 3 | 2,000 | 1 | none | false | false |
| Green | 19.99 | 5 | 10,000 | 5 | advanced | true | false |
| Gold | 24.99 | 25 | 25,000 | 20 | full | true | true |

- [ ] `user_usage.gardener_screenshots_today` exists and defaults to 0.
- [ ] Prices are untouched: `price_monthly` / `price_weekly` / `price_cents`
      are exactly what they were before.

## 2. Build

- [ ] `Harvest` target compiles. New file: `Harvest/Utilities/KeywordMatcher.swift`
      (from the earlier flag-detection change) and no new files in this one —
      everything here edits existing types.
- [ ] `HarvestTests` compiles and passes, in particular
      `SubscriptionTierTests` (new) — it pins the matrix above.

## 3. Gardener — the two budgets are now separate

- [ ] Free (Seed) account: send one screenshot for review. It works, and the
      character counter next to the send button does **not** drop by 1,000.
- [ ] Send a second screenshot the same day → refused with "That's your
      screenshot review for today", and the photo picker icon is greyed out.
- [ ] Burn the 2,000 chat characters. The composer stays usable for a staged
      screenshot if one is left; the input bar only shows the full "You've used
      today's Gardener allowance" lock when **both** budgets are spent.
- [ ] Next day (or reset `gardener_last_reset_date`): both budgets return.

## 4. Field roster filters

- [ ] Seed account: room member roster shows search only; advanced filters show
      the "Grow" gate, full filters show the "Gold" gate.
- [ ] Green: advanced unlocked, full still gated. Gold: everything unlocked.
- [ ] These now read `field_filter_level` off the tier row — flip Green's value
      to `'full'` in the DB and confirm the app follows without a rebuild.

## 5. Newly gated (behaviour change — see note below)

- [ ] Compatibility sheet on a Seed account: radar and value chips still show;
      "Value overlap" and the written read are replaced by an upgrade card.
- [ ] Same sheet on Green/Gold: both sections render as before.
- [ ] Soil → Tips on a Seed/Green account: upgrade card. On Gold: the tips list.

## 6. Paywall copy

- [ ] Subscription screen rows read: Seeds per day · Receive Seeds · Gardener
      chat · Screenshot reviews · Room member filters · Deeper Soil · Advanced
      compatibility · Premium growth features.
- [ ] No row mentions matches per week, distance, or "who likes you".
- [ ] Purchase sheet shows the same numbers as the plan cards.

## 7. Regression watch

- [ ] "Likes You" in the Seeds inbox: still visible on Green and Gold, hidden
      on Seed. It lost its own column (`can_see_likes`) and now keys off
      "any paid plan", which preserves the previous behaviour.
- [ ] StoreKit purchase still resolves to the right tier row (product IDs and
      `tier_id` mapping were not touched).

---

**Note — two features became paid that were free before:** the compatibility
overlap/written read, and the Soil tips library. That was the explicit ask
("actually gate the growth and soil features"), but it *is* a takeaway for
existing free users. If that's not wanted, the gate is one `if` in
`CompatibilityView.body` and one in `ValuesView.body`.
