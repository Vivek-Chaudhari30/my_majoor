# Majoor Pro — Revenue & Feature Plan

*Status: planning only — no code. Revisit once v1.0 is stable in the wild.*

---

## Why a Pro tier?

Majoor's free tier covers the core loop: push-to-talk, transcribe, answer, open things.
Pro captures power users who live in the assistant all day and want deeper integrations,
better voice, and near-instant responses. Target price: **$9/mo** (annual: $79/yr).
A lighter "Starter Pro" at **$5/mo** is possible if the full bundle feels too expensive.

---

## Proposed Pro Features

### 1. Custom Voices  ($5–9/mo tier anchor)
Replace `/usr/bin/say` with OpenAI TTS (`tts-1` or `tts-1-hd`) or ElevenLabs.
Users pick a voice from a curated set (e.g., Alloy, Echo, Nova, Shimmer from OpenAI).
Free tier keeps the system `say` voice. This alone is a strong upgrade reason.
*Implementation note: swap `Speaker.swift` to call the TTS API; stream audio via AVAudioPlayer.*

### 2. Calendar Integration  ($9/mo tier)
Read-only Google Calendar + Apple Calendar access.
- "What do I have tomorrow afternoon?" → Majoor reads out upcoming events.
- "When is my next meeting with Sarah?" → searches by attendee name.
- Create events: "Add a dentist appointment Friday at 2pm."
Uses EventKit (Apple Calendar, no extra auth) and Google Calendar API (OAuth2 flow).
*Privacy note: events never leave the device except for the LLM call; anonymise if possible.*

### 3. Email Replies  ($9/mo tier)
Draft and send short replies from the latest unread emails.
- "Reply to the last email from Jake: sounds good, I'll be there."
- Reads subject/sender only to confirm before sending — no full inbox access.
Scope: Gmail via OAuth + Apple Mail via AppleScript fallback.
*Risk: high permission footprint. Ship read-only draft mode first.*

### 4. Slack Message Sending  ($9/mo tier)
Post to a Slack workspace via a Majoor-installed Slack app (OAuth bot token).
- "Tell #general the standup is cancelled today."
- "Send Alex on Slack: can we push the meeting by 30 min?"
One workspace per account in v1 Pro. Multi-workspace in v2.
*Implementation: Slack Web API `chat.postMessage`. Store bot token in Keychain.*

### 5. Smarter Web Search  ($9–15/mo tier)
Upgrade `search_web` from Google link-open to actual answer synthesis:
- Perplexity API or Tavily API for real-time grounded answers.
- "What's the weather in Mumbai right now?" → spoken answer, not a browser tab.
- "Summarise the top HN stories today." → reads + summarises top 5.
Free tier keeps the current open-in-browser behaviour.
*Rough cost: Perplexity API ~$5/1000 queries; margin positive at $9/mo for typical usage.*

### 6. Faster Response Times / Priority API Queue  ($15/mo tier or add-on)
Two levers:
a) Route to `gpt-4o` (full model) instead of `gpt-4o-mini` for complex queries.
b) Pre-warm a persistent HTTP connection; skip cold-start transcription latency.
Marketing framing: "sub-2-second responses" for power users on fast internet.
*Note: gpt-4o is ~15× more expensive per token than mini — gate behind explicit user opt-in
or a higher tier. Default Pro still uses mini.*

### 7. Majoor Sync (stretch goal, $9/mo bundled)
Sync `~/.majoor/memory.json` across Macs via iCloud Drive or a lightweight Cloudflare
Workers + R2 backend. Single account, multiple machines.
*This is the feature that turns Majoor from a per-Mac tool into a personal AI layer.*

---

## Pricing Summary

| Tier      | Price        | Key additions over Free                              |
|-----------|-------------|------------------------------------------------------|
| Free      | $0           | Core push-to-talk, open_app/url/search, system say   |
| Starter   | $5/mo        | Custom voices (OpenAI TTS), Majoor Sync              |
| Pro       | $9/mo        | Starter + Calendar, Email drafts, Slack, smart search|
| Pro+      | $15/mo       | Pro + gpt-4o routing, priority queue                 |

Annual billing discounts: ~20% off (e.g., Pro annual = $86/yr ≈ $7.17/mo).

---

## Monetisation Stack (recommended)

- **Payments**: Stripe (subscription billing, customer portal for upgrades/cancels).
- **Licensing**: Paddle as an alternative if Mac App Store distribution is added later
  (App Store requires IAP; direct distribution can use Stripe freely).
- **Licence key delivery**: Cloudflare Workers endpoint validates a JWT; Majoor checks
  on launch and caches result for 7 days offline grace.
- **Backend**: Keep it minimal — one Cloudflare Worker + one D1 (SQLite) table for
  `user_id, stripe_customer_id, tier, valid_until`. No app server to maintain.

---

## Sequencing (post-v1 stable)

1. Custom voices — lowest risk, purely local change, strong marketing hook.
2. Majoor Sync — enables annual billing conversation, cross-device value prop.
3. Smart web search — replaces the weakest current tool, high user-visible impact.
4. Calendar — high value, relatively safe (read-only first).
5. Slack — moderate risk (token scope), but high daily-driver stickiness.
6. Email — highest risk/complexity, ship last.
7. Priority queue / gpt-4o routing — wire in once usage data shows who wants it.

---

## Open Questions

- App Store vs. direct-only distribution? (App Store = 30% cut + IAP requirement)
- Should calendar/email/Slack integrations require separate OAuth per account, or
  go through a Majoor cloud relay? (Cloud relay is simpler UX but increases trust burden.)
- Free-to-paid conversion target: 3–5% of MAU is typical for B2C utilities.
- Name: "Majoor Pro" vs "Majoor+" vs just removing the free tier at some user count?

---

*Last updated: 2025-06 (pre-monetisation planning pass). No code exists yet for any of these.*
