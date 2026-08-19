# Android Onboarding (P2a) — Verification Checklist

**Plan:** `docs/superpowers/plans/2026-08-19-android-onboarding.md`
**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Automated — verified

```bash
cd android && ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

Last run on the `Medium_Phone_API_36.0` emulator (API 36):

- [x] **115 unit tests, 0 failures** (up from 60 at the end of P1)
  - `QuestionTest` (12) — axis weights, raw/normalized vectors, cosine, tier boundaries
  - `ObjectionableContentTest` (9) — boundary-aware matching, inflections, normalization
  - `ProfileServiceTest` (8) — storage URL round trip, default nickname
  - `ValuesServiceTest` (7) — fallback catalogue shape, Q1–Q10 bank integrity
  - `OnboardingViewModelTest` (19) — every `canProceed` branch, step order, progress
  - plus the 60 from P0/P1
- [x] **32 instrumented tests, 0 failures** (up from 20)
  - `OnboardingStepsTest` (8) — each choice step emits the **stored value**, not the label
  - plus the 24 from P0/P1
- [x] Builds, installs, and launches with no crash
- [x] The wizard renders at parity: "Set Up Profile" bar with Sign Out, progress bar,
      rose glyph, serif "How old are you?", the 18+ subtitle, a date picker defaulting to
      25 years ago, live "Age: N", and the rose Continue button
- [x] The date picker is themed to the Harvest palette (it defaulted to Material3's
      lavender `surfaceVariant`, which clashed with the cream page)

## Manual — needs your account

I have no credentials, so nothing below is verified. Register a **new** account on the
emulator and walk the whole wizard.

### Gating

- [ ] A birth date under 18 keeps Continue disabled and shows "You must be 18 or older to use Harvest"
- [ ] A blank nickname keeps Continue disabled
- [ ] An objectionable nickname keeps Continue disabled
- [ ] Continue stays disabled on Photos until a photo has finished **uploading** (not merely picked)
- [ ] Goals, gender, interested-in and relationship status each require a selection
- [ ] Values requires at least one on **both** "I bring" and "I seek", and caps each at 3
- [ ] Reflections requires all 10 answered
- [ ] Location keeps Continue disabled until a suggestion is chosen
- [ ] Terms must be ticked
- [ ] The system back button goes to the previous step, and does nothing on the first step

### Data

- [ ] A picked photo uploads and appears in the `profile-photos` bucket under `<userId>/`
- [ ] Removing a photo removes it from the grid and from storage
- [ ] Exactly **10** reflection questions appear, not 35
- [ ] The progress bar advances **within** reflections, not only between steps
- [ ] "Everyone" selects all interested-in options; deselecting one clears "everyone"
- [ ] Completion writes `onboarding_completed = true` and lands on The Field
- [ ] The resulting profile is correct in the iOS app: nickname, age, gender, photos,
      location, goals (comma-joined), `relationship_status` stored as
      `single|dating|in_relationship|engaged|married`
- [ ] Selected values persist to `user_values_brought` / `user_values_sought` with 1-based ranking
- [ ] Reflection answers persist to `user_question_answers`
- [ ] Completion still succeeds if the values save fails (best-effort, must not trap the user)

### Geocoding

- [ ] Typing a city produces suggestions after roughly 800ms
- [ ] Editing the text after resolving clears the resolution and re-disables Continue
- [ ] A nonsense query yields no suggestions and no crash

## Known gaps

- **The Soil tab (P2b)** is still a placeholder; `ValuesView`, the radar, and the deep-dive
  question sheet are the next plan.
- **The fallback question bank covers Q1–Q10 only.** That is everything onboarding presents;
  Q11–Q35 land with the Values tab. The DB path is unaffected.
- **`DifferentiationView`** (the one-time intro after onboarding) is not ported.
- **Notification opt-in** on the completion screen is not ported — it belongs with the
  Notifications subsystem.
- The **Terms of Service / Community Guidelines** links are wired to no-op callbacks; the
  Legal screens port with the Profile/Settings subsystem.
