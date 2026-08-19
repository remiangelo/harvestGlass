# Android Soil Tab (P2b) — Verification Checklist

**Plan:** `docs/superpowers/plans/2026-08-20-android-soil-tab.md`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Automated — verified

```bash
cd android && ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

- [x] **141 unit tests, 0 failures** (up from 115 at the end of P2a)
  - `RadarGeometryTest` (10) — vertex angles, clamping, tier-not-raw-score plotting
  - `ValuesViewModelTest` (15) — both sides of the need/sought inversion, optimistic
    revert on save failure, the 3-value cap, retake banner threshold
  - `ValuesServiceTest` (+1) — the bank is 35 questions, split 12/12/1 on the deep dive
- [x] **44 instrumented tests, 0 failures** (up from 32)
  - `ValuesRadarCardTest` (7) — empty state, legend, zero-secondary handling
  - `QuestionSheetTest` (5) — emits question/option ids, one-at-a-time queue
- [x] Builds, installs, launches with no crash
- [x] The tab renders at parity: "Your relational soil" with the accent heart, Main/Tips
      segments, What I Need / What I Bring segments, the radar, the more-questions button,
      the values picker with its `n / 3` counter, and the Show-on-Profile toggles
- [x] The radar draws correctly with real data: five labelled axes (Emotional Intelligence
      at top), four grid rings, tier numbers 1–4 up the centre line, and a rose polygon at
      30% fill / 1.5 stroke
- [x] The remaining-questions count is right (35 total − 14 answered = "21 left")

## Manual — needs your account

### Radar and scores

- [ ] For the same account, the polygon's shape matches the iOS app axis for axis
- [ ] Switching What I Need / What I Bring swaps both the polygon **and** the chip selection
- [ ] Answering a question in the sheet changes the radar immediately
- [ ] Two raw scores in the same tier plot at the same ring (the chart shows shape, not points)
- [ ] With no answers, the empty state appears and "Start" opens the question sheet

### Values chips

- [ ] The chips reflect the correct list per side — **NEED shows what you seek**,
      **BRING shows what you bring**. Cross-check against iOS; this is the easiest thing
      in the subsystem to have backwards.
- [ ] Selecting a 4th value shakes the chip instead of selecting it
- [ ] Selections persist across app restart and are visible on iOS
- [ ] A save failure (airplane mode) reverts the chip and shows the warning text

### Questions

- [ ] "More questions (N left)" shows the right N and is disabled at 0 ("All caught up")
- [ ] The sheet presents one unanswered question at a time, in display order
- [ ] Answering all of them lands on "You've answered everything for now."
- [ ] Answers persist to `user_question_answers` and appear on iOS

### Display toggles

- [ ] All three toggles default to ON when the columns are null
- [ ] Each toggle persists and is reflected in the iOS profile
- [ ] The graph-side picker only appears when Values Graph is on
- [ ] The graph side persists to `profile_graph_side`

## Known gaps

- **The generated-blurb section is absent — and that is parity.** `ValuesView.swift:92`
  has it commented out (`// blurbSection — temporarily disabled (Generate Blurb caused
  issues)`), so iOS does not show it either. The `Generated Blurb` display toggle is
  still present, exactly as on iOS.
- **The Tips library renders locked.** `hasGrowthFeatures` is fail-closed pending the
  subscription tier lookup, so every user currently sees the gate a free user sees. The
  library content and the tier lookup port with the Subscription subsystem.
- **The upgrade button inside the gate is not wired** — it navigates to the subscription
  screen on iOS, which does not exist here yet.
- **`ValuesPresenceGuide`** (the four-tier explainer) is not ported; it is reached from a
  part of the tab not yet built.
