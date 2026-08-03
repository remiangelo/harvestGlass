# Gardener screenshot review — design (2026-08-04)

Let people send the Gardener a screenshot of a conversation and get coaching on
it. Anything that is not a chat screenshot is politely refused.

## Why

The Gardener is a dating coach (`GardenerService.systemPrompt`). "Here's what
they said, what do I reply?" is the single most natural coaching request, and
today it can only be answered by retyping the conversation.

## Scope decisions already made

- **The image is never stored.** Not in a bucket, not in the database.
- **Available to every tier**, charged against the existing daily Gardener
  budget at a heavier rate than text.
- Refusal wording is **fixed by the app**, not written by the model.

---

## 1. Vision plumbing

`OpenAIService.ChatMessage.content` is a `String` (`OpenAIService.swift:8`) and
is used by `GardenerService`, `MindfulMessagingService`, `BlurbService`,
`CompatibilityService`, and `SafetyAnalysisService`. All of those keep working.

Add a content-parts representation alongside the string one:

```swift
struct ChatMessage: Codable, Sendable {
    let role: String
    let parts: [ContentPart]

    enum ContentPart: Sendable {
        case text(String)
        case imageURL(String)   // data: URL or https:
    }

    /// Existing call sites keep this initializer.
    init(role: String, content: String) {
        self.role = role
        self.parts = [.text(content)]
    }

    init(role: String, parts: [ContentPart]) {
        self.role = role
        self.parts = parts
    }
}
```

`Encodable` emits a bare string when `parts` is exactly one `.text` — matching
what OpenAI receives today, so no existing behaviour changes — and the
content-parts array otherwise:

```json
{"role":"user","content":[
  {"type":"text","text":"..."},
  {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,..."}}
]}
```

`Decodable` is required by the `Codable` conformance but never used for
requests; it accepts either shape.

**No Edge Function deploy.** `supabase/functions/openai-chat/index.ts` parses
the body and forwards it to OpenAI unchanged, so the new shape passes straight
through.

## 2. Image pipeline

In the app, before the request:

1. `PhotosPicker` yields the image.
2. Downscale so the longest side is at most **1024px**. Vision cost scales with
   resolution and phone screenshots are far larger than the model needs.
3. JPEG at quality **0.7**.
4. Base64 into a `data:image/jpeg;base64,...` URL.
5. Send, then drop. Nothing is written to disk or to Supabase.

A screenshot that still exceeds **4 MB** after this is rejected client-side with
a "that image is too large" message rather than being sent.

## 3. Detection and reply — one call

Use the existing `sendChatJSON` with a system prompt that forces:

```json
{ "is_chat_screenshot": true, "reply": "..." }
```

- `is_chat_screenshot` is true only for an image showing a **text/chat
  conversation** — messages in bubbles or lines, from any app, or an SMS thread.
  A selfie, a dating profile, a meme, a landscape, or a document is false.
- When true, `reply` is the coaching response and the app shows it.
- When false, **the app discards `reply`** and shows its own fixed text. Letting
  the model improvise the refusal produced inconsistent wording; pinning it in
  the app also guarantees the promise ("we only review screenshots") is stated
  the same way every time.

The refusal, verbatim:

> I can only read screenshots of a conversation — a chat thread, texts, or DMs.
> This one doesn't look like that, so I'd rather not guess at it. If it *is* a
> conversation, try a fuller screenshot showing the messages and I'll take
> another look.

Wording invites a retry on purpose: detection is a model judgment, and a
cropped or unusual screenshot will occasionally be misread. A final-sounding
refusal would make that failure worse than it is.

Failures of the JSON call itself (network, malformed JSON, missing key) surface
as the Gardener's existing error path, not as a refusal — a user must never be
told their screenshot was invalid because the network dropped.

## 4. Persistence and history

`gardener_messages` rows are unchanged in shape:

- The user turn is stored with the literal content `📷 Screenshot` (plus their
  caption, if they typed one).
- The Gardener's reply is stored as normal text.

History therefore reads back coherently without the image, and no third party's
private messages are retained.

## 5. Cost accounting

A vision call costs far more than a text turn, and the daily budget is measured
in characters (`GardenerService.getTodayCharacterUsage`). A screenshot is
charged a **flat 1,000 characters**, regardless of any caption. When the budget
is already exhausted, the upload is refused by the existing limit path before
any image is encoded or uploaded.

## 6. UI

In `GardenerChatView`'s composer, a photo button beside the text field:

- Opens `PhotosPicker`.
- Selected image shows as a small removable thumbnail above the input, so
  someone can add a caption before sending or back out.
- While the vision call is in flight, the existing typing/loading state is used.
- The composer is disabled during send, matching the re-entry guard already
  applied to the two human chats.

## 7. Testing

Unit-testable without a network:

- `ChatMessage` encodes a single `.text` part as a bare string (proves existing
  callers are unaffected).
- `ChatMessage` encodes text + image as a content-parts array with the right
  `type` keys.
- Image downscaling caps the longest side at 1024 and preserves aspect ratio.
- The classifier response decoder handles `is_chat_screenshot` true and false,
  and throws on a missing key.

Everything else is manual and goes on a Mac checklist: a real chat screenshot
gets coaching; a selfie gets the exact refusal text; a photo of a printed
conversation is an accepted known-ambiguous case.

## 8. Out of scope

- Storing or displaying the image anywhere.
- Reading Harvest's own conversations directly (a "review this Seed chat"
  button) — different feature, no upload involved.
- OCR or any non-model text extraction.
