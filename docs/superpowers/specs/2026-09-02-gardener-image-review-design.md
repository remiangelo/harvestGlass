# Gardener image review — design (2026-09-02)

Let someone attach several screenshots to the Gardener, ask a question about
them, and get an answer to *that question* — with follow-ups that still know
what was in the pictures.

## Why

Three launch reports share one cause, and it is not plumbing. The caption is
already sent to the model correctly, as a text part beside the image
(`GardenerService.kt:145-153`). What is wrong is what the model is asked to do.

`SCREENSHOT_SYSTEM_PROMPT` asks exactly one question — *is this a screenshot of
a TEXT CONVERSATION?* — and names "a dating profile" as a thing that is not.
So:

- **The user's question has no role.** Nothing in the prompt tells the model to
  answer it. It is in the payload and ignored, and the model returns generic
  coaching about the exchange instead.
- **A dating profile is refused outright.** When the verdict is false the
  model's reply is discarded and replaced with `NOT_A_SCREENSHOT_REPLY` — for
  one of the use cases the feature exists to serve.
- **Follow-ups have nothing to work from.** Only `📷 Screenshot — <caption>` is
  persisted as the user turn. When the assistant turn is the canned refusal,
  the next message sees a user asking about a picture and an assistant saying
  it cannot read pictures, so it improvises. That is the "totally unrelated
  response".

And one image at a time cannot carry a conversation that spans several
screenshots, which is the natural way people would use this.

## Scope decisions already made

- **A message is one review**, however many images it carries. Images per
  message ladder by tier: seed 3, green 6, gold 10. Daily review counts are
  untouched.
- **Only sexually explicit content is refused.** Conversations, dating
  profiles, bios, photos of people are all in scope.
- **Images are never stored server-side.** They stay in the ViewModel for the
  session so follow-ups can re-send them, and are gone when the app closes.
- **One call, plain text, sentinel refusal** — approach C below.

---

## 1. Why not JSON any more

Today the model is asked for `{"is_chat_screenshot": …, "reply": "…"}` and
`parseVerdict` digs it back out, throwing *"The Gardener returned no verdict"*
when it cannot. With `maxTokens = 400` a long reply is truncated mid-object and
that throw is what the user gets. Multi-image answers are longer, so this
would get worse, not better.

The new call returns **prose**. The only structure is a refusal sentinel:

> If any image is sexually explicit or graphic, reply with exactly
> `REFUSE_EXPLICIT` and nothing else.

The client compares the trimmed reply against the sentinel and substitutes its
own copy. Refusal wording stays in the app — which is what the existing comment
on `NOT_A_SCREENSHOT_REPLY` asks for, and the reason it is not left to the
model — while everything else is plain text that cannot be broken by
truncation.

Rejected alternatives: keeping JSON with a changed schema (keeps the
fragility), and a separate moderation call before the answer (more reliable
refusal, but a second round trip on a multi-megabyte payload for a case that is
rare).

## 2. The prompt

Replaces `SCREENSHOT_SYSTEM_PROMPT` on both platforms. Shape, not final
wording:

- You are The Gardener. The user has attached one or more images and may have
  asked a question.
- **If they asked a question, answer that question**, grounded only in what is
  visible. Do not substitute generic advice for the thing they asked.
- Treat multiple images as one continuous piece of context — most often
  consecutive screenshots of the same conversation, in order.
- With no question, fall back to coaching: what you notice, then what to do
  about it.
- Never invent content that is not visible.
- If any image is sexually explicit or graphic, reply with exactly
  `REFUSE_EXPLICIT`.
- Existing constraints carry over: concise, short paragraphs, no medical or
  legal advice, name distress or abuse clearly and point at human support.

`maxTokens` rises 400 → 700; several images and a specific question need more
room than a single-screenshot verdict did.

## 3. Encoding budget

`ScreenshotEncoder` currently downscales each image to 1400px on the longest
side at fixed JPEG quality. Ten of those in one JSON body is several megabytes,
and each is sent base64, inflating by a third.

The target dimension becomes a function of how many images are attached, so
total payload stays bounded rather than growing linearly:

| Images | Longest side |
|-------:|-------------:|
| 1–2    | 1400 |
| 3–5    | 1100 |
| 6–10   |  900 |

Text in a phone screenshot stays legible at 900px. **The actual Supabase Edge
Function request ceiling must be measured before these numbers are settled** —
they are chosen to be conservative, not because the limit is known. If a
selection still exceeds the budget after scaling, the send fails with a clear
message naming the count, rather than a transport error.

## 4. Tier cap

One new column, following the pattern of `gardener_screenshots_per_day`:

```sql
alter table public.subscription_tiers
  add column if not exists gardener_images_per_review int not null default 1;
```

Set to 3 / 6 / 10 for seed / green / gold. The picker is opened with the
tier's cap as its selection limit, and the count is clamped again before
sending — the client is not the only thing standing between a user and a
20-image request.

`gardener_screenshots_per_day` and the `gardener_character_limit` budget are
unchanged. A review still costs one review.

## 5. Service interface

Both platforms:

```
sendScreenshot(userId, imageDataUrl: String,       caption, history)   // before
sendImages    (userId, imageDataUrls: List<String>, caption, history)  // after
```

The payload builder becomes a pure function — one text part when a caption
exists, then one image part per image, in selection order — so it can be tested
without a network, in the style of the existing `upsertPayload`,
`photoObjectPath` and `storagePathFromUrl` helpers.

`screenshotPlaceholder` learns to count: `📷 Screenshot — <caption>` for one,
`📷 3 screenshots — <caption>` for several. Both stores read it back, so iOS
and Android must compose it identically.

## 6. Session memory for follow-ups

A new ViewModel field holds the encoded data URLs of the last send — distinct
from `pendingScreenshot`, which holds an unencoded `Uri` awaiting send. While
it is populated, a text message in the same sitting is routed to `sendImages`
with those URLs and the new question, so "what did the second message say?" is
answered by looking rather than guessing.

**A re-send is not a new review.** Counting already lives in the ViewModel —
`rateLimitService.trackScreenshotReview` is called there, not in the service —
so the follow-up path simply does not call it, and needs no flag threaded
through `sendImages`.

**But a re-send IS chat, and spends the chat character budget.** Routing to the
retained path happens *after* `checkGardenerLimit`, not before it. The exemption
recorded on `gardener_screenshots_per_day` covers a review, not the conversation
that follows one; putting the branch first would have made "attach one image,
then chat indefinitely" an unmetered route through a budget every other message
obeys. (Revised 2026-09-02 during implementation — the first draft had the
branch before the check.)

The retained URLs are dropped when a new selection replaces them, when the user
dismisses them, and with the process. Nothing reaches storage, and nothing is
written to `gardener_chat_history` beyond the placeholder — the privacy stance
in the current code is deliberate and is preserved.

**Retention must be visible and dismissible.** The ViewModel is Activity-scoped
— `hiltViewModel()` from a `when (selectedTab)` branch, with no NavHost — so
"the session" is really "until the process dies", not the sitting a user would
imagine. Invisible state that silently re-sends ten images on every later
message is the wrong default, so while images are retained and nothing new is
staged the composer shows a dismissible chip naming the count, wired to
`clearRetainedImages()`. (Added 2026-09-02 during implementation — the first
draft described retention as session-scoped without saying how a user ends it.)

This costs input tokens on follow-ups. At `gpt-4.1-mini` vision rates a ten
image re-send is fractions of a cent, so the ceiling here is latency and the
daily review limit, neither of which this changes.

## 7. Composer UI

- Multi-select picker (`PickMultipleVisualMedia` on Android,
  `PhotosPicker(maxSelectionCount:)` on iOS), opened with the tier's cap.
- A horizontal thumbnail strip above the input, each with a remove control.
- A counter reading `3 / 6` against the tier cap.
- Send stays disabled while encoding, and an encode failure leaves the
  selection exactly as the user left it — matching the care the current
  `sendScreenshot` already takes.

## 8. Error handling

| Case | Behaviour |
|---|---|
| Any image explicit | Sentinel matched, canned refusal shown, review still counted |
| Over the tier cap | Blocked in the picker; clamped again before send |
| Over the payload budget after scaling | Clear message naming the count; nothing sent |
| Encode failure | Message shown, selection preserved |
| Transport failure | Existing behaviour — thrown, never reported as "invalid screenshot" |
| Daily limit reached | Existing `checkScreenshotLimit` path, unchanged |
| Follow-up re-sending retained images | Not counted as a review; no limit check |

## 9. Testing

Pure helpers, no network, mirrored on both platforms:

- N images produce N image parts plus one text part, in order; no text part
  when the caption is empty.
- The sentinel — alone, trimmed, and with stray whitespace — maps to the canned
  refusal; ordinary prose never does.
- The tier cap clamps an over-long selection.
- The encoder budget picks the right target dimension per count boundary
  (2/3, 5/6).
- `screenshotPlaceholder` singular vs plural, matching across platforms.
- A follow-up with retained images does not increment the review count, and a
  fresh selection does.

Not covered by unit tests, and needing a real device: that the model actually
answers the question, and that a follow-up re-reads the images. Both are prompt
behaviour, verified by hand against a real conversation screenshot and a real
dating profile.

## 10. Out of scope

- Storing images server-side, and the deletion obligation that would create.
- Changing daily review limits or the chat character budget.
- Reworking the ordinary text chat path. A follow-up carrying retained images
  is routed to `sendImages` by the ViewModel instead; `sendMessage` keeps its
  current signature and prompt.
