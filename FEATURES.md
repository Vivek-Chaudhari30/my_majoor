# Majoor — Feature Roadmap

> Companion to `MASTER_PLAN.md`. The master plan covers **architecture** decisions. This doc covers **what exists now, what's coming next**, and what's planned further out. Tiered, opinionated, decisive.

---

## What Majoor does today — v1 (current, released)

Majoor is a push-to-talk voice assistant that lives in your macOS menu bar. Hold **Ctrl+Option**, speak, release.

**Core pipeline:** `Ctrl+Option` hotkey → `gpt-4o-mini-transcribe` STT → `gpt-4o-mini` agent loop → tool execution → `/usr/bin/say` TTS → idle.

**Tools available in v1:**

- `open_app(name)` — "Open Spotify", "Open VS Code", "Open Terminal"
- `open_url(url)` — "Go to github.com", "Open Hacker News"
- `open_url_in_app(url, app)` — "Open gmail.com in Safari"
- `search_web(query)` — "Search for Swift async await tutorial"
- `system_command(command)` — sleep, lock, mute, unmute, volume up/down
- `remember(fact)` — "My name is Vivek" → persists across reboots

**Memory:** 6-turn in-session buffer + `~/.majoor/memory.json` (persistent user facts).

**UI:** Dynamic-Island-style pill anchored to the notch. Menu-bar status icon for settings and state. No dock icon.

**Released:** v1.0 (initial), v1.1 (onboarding), v1.2 (eval improvements — 24/25, 96%).

---

## What's coming next — v1.3 (planned, ~1–2 weeks)

High-value, low-complexity additions. These are tool additions wired into `Tools.json` + `ToolExecutor.swift` + few-shot examples in `SystemPrompt.txt`. Predicted total work: ~1 weekend.

### 1.1 `media_control(action)` · Complexity: **XS** · Value: ⭐⭐⭐⭐

Play / pause / next / previous on whatever is currently making sound (Spotify, Music, Safari, Chrome tabs, etc.). One osascript wrapper using universal media keys (F7/F8/F9) — works across all audio apps without knowing which one is playing.

**Tool shape:** `{ "action": { "enum": ["play_pause", "next", "previous"] } }`

**Why ship first:** people say "Majoor, pause my music" within hours of installing. Closest thing to a daily-driver hit.

---

### 1.2 `set_volume(level)` and `change_volume(direction)` · Complexity: **XS** · Value: ⭐⭐⭐

Already have `mute` / `unmute` in `system_command`. This adds:

- `set_volume(level: 0–100)` — exact value via `set volume output volume <n>`
- `change_volume(direction: "up" | "down", amount: 0–50)` — relative

Handles "Majoor, set volume to 30" and "turn it down."

---

### 1.3 `set_brightness(level)` and `change_brightness(direction)` · Complexity: **S** · Value: ⭐⭐⭐

Via IOKit / CoreDisplay — no Homebrew dependency. ~30 lines of Swift in `ToolExecutor`.

---

### 1.4 `clipboard_read()` and `clipboard_write(text)` · Complexity: **XS** · Value: ⭐⭐⭐

NSPasteboard wrappers, ~10 lines each:

- "Majoor, what's on my clipboard?" → reads → speaks aloud
- "Majoor, copy hello world to the clipboard" → writes

Combined with `remember`: "Majoor, save what I just copied to memory."

---

### 1.5 `forget(fact_substring)` · Complexity: **XS** · Value: ⭐⭐⭐⭐

Mirrors the existing `remember` tool. Removes any fact matching the substring (case-insensitive). Without this, the only way to remove a fact is to delete `~/.majoor/memory.json` by hand — a non-starter for real users.

---

### 1.6 `list_memory()` · Complexity: **XS** · Value: ⭐⭐⭐

Reads `MemoryStore.shared.facts` and returns them summarised:

> "I know your name is Vivek, your preferred browser is Safari, and that you live in Ahmedabad."

Trigger phrases: "what do you know about me", "what have I told you".

---

### 1.7 Custom hotkey · Complexity: **S** · Value: ⭐⭐⭐⭐

Ctrl+Option works for most people, but a non-trivial fraction already uses it for something else (window managers, IDE shortcuts). Let users pick their own combo, stored in `~/.majoor/config.json`. `HotkeyMonitor` re-creates the `CGEventTap` if it changes.

---

### 1.8 Settings window · Complexity: **S** · Value: ⭐⭐⭐⭐

A proper preferences pane accessible from the menu bar:

- Hotkey picker
- Voice picker (drop-down of `say -v "?"` voices — all free)
- Memory view — see facts, click ✗ to forget individually
- Conversation buffer size slider (0–12, default 6)
- STT/chat model selector (gpt-4o-mini default / gpt-4o pricier)
- Reset onboarding button

**Why it matters:** right now, changing any of this requires editing JSON files. That's a non-starter for most users. This single change graduates Majoor from developer tool to polished product.

---

### v1.3 predicted changelog

> 🆕 Media controls (play/pause/next/previous)
> 🆕 Volume and brightness as voice commands
> 🆕 Read & write the clipboard
> 🆕 "Forget" command to remove stored facts
> 🆕 "What do you know about me?" lists everything
> 🆕 Custom hotkey — pick your own
> 🆕 Settings window — hotkey, voice, memory management, model choice

Total: ~80–120 new lines of Swift, 7 new tools in `Tools.json`, 4–5 new few-shots in `SystemPrompt.txt`. Eval target: 30/31 (≥96%).

---

## Solid expansions — v1.4–v1.6 (planned, ~1–3 months)

Build after v1.3 is shipped and stable. These take more than an evening but are obviously valuable.

### 2.1 `screenshot()` and `screen_ocr()` · Complexity: **M** · Value: ⭐⭐⭐⭐

- `screenshot(target: "screen" | "window" | "selection")` — wraps `screencapture`, saves to `~/Pictures/Majoor/`
- `screen_ocr()` — captures current screen, runs Apple Vision framework's `VNRecognizeTextRequest`, returns text the model can answer questions about

**Permission required:** Screen Recording (add to onboarding step 3).

**What it unlocks:** "Majoor, summarise this article" → screenshot + OCR + answer. Without leaving the browser. Huge.

---

### 2.2 `type_text(text)` · Complexity: **S** · Value: ⭐⭐⭐⭐

Synthesises a keystroke sequence into whatever app is currently focused, using `CGEvent.keyboardSetUnicodeString` (already available with Accessibility permission).

- "Majoor, type: hello world" → focused field gets `hello world`
- "Majoor, dictate this email: Hi John, …" → drafts directly into Mail

---

### 2.3 Window management · Complexity: **M** · Value: ⭐⭐⭐

`window_action(action)` with enum: `close_window`, `minimize_window`, `fullscreen_window`, `move_to_left_half`, `move_to_right_half`, `center_window`, `maximize`. Native implementation via the Accessibility API — no Rectangle dependency.

---

### 2.4 File system primitives · Complexity: **S each** · Value: ⭐⭐⭐

- `search_files(query)` — wraps `mdfind` (Spotlight CLI). "Majoor, find my resume."
- `open_file(path)` — Finder-reveal or open with default app
- `open_folder(path)` — common paths: Downloads, Documents, Desktop

Combined: "Majoor, find my last invoice and open it" → search → open first result.

---

### 2.5 Calendar / Reminders · Complexity: **M each** · Value: ⭐⭐⭐⭐

- `create_calendar_event(title, start_time, duration_minutes)` — via EventKit framework
- `create_reminder(title, due_date)` — same

"Majoor, remind me to email Sarah at 3pm" is the canonical voice-assistant command and we don't have it yet. Requires EventKit permission (add to onboarding).

---

### 2.6 `compose_email` and `compose_message` · Complexity: **S** · Value: ⭐⭐⭐

- `compose_email(to, subject, body)` — opens Mail.app with a pre-filled draft via `mailto:` URL scheme
- `compose_message(recipient, body)` — opens Messages.app via `sms:` URL scheme

Both go through the existing `/usr/bin/open` so no extra permission.

---

### 2.7 Multi-turn follow-ups · Complexity: **M** · Value: ⭐⭐⭐⭐

Today the conversation buffer carries 6 turns but the model can only respond once per turn. True follow-ups need:

1. A way for the model to ask the user a question and wait for the next push-to-talk turn while binding context
2. A `pending_question` state in `AppState` so the orb shows "Awaiting your answer…"

Once shipped, Majoor jumps from "voice-activated launcher" to "assistant that feels like a conversation."

---

## Future / community / experiments — v2.x (no timeline committed)

Build only when the above is stable AND there is clear user demand.

### 3.1 Plugin / extension system

Define a JSON tool-schema + a script (TypeScript via Bun, or Swift) that users drop into `~/.majoor/plugins/`. On startup Majoor scans and registers them as additional tools. Community can then build:

- Notion integration (search + create pages)
- Linear (create issues)
- GitHub (open issues, search code)
- Slack DM / Discord message
- Things 3 / Todoist / Bear / Apple Notes
- Cal.com, Tailscale device control

We don't build any of these. We give the scaffolding and let the community ship.

### 3.2 Conversation history viewer

A small window with the last 100 turns, searchable. Backed by `~/.majoor/history.json` (append-only). UI = SwiftUI `List` + `TextField` for search.

### 3.3 Voice waveform in the pill during recording

Today's pill shows a pulsing dot during listening. A live waveform driven by `AVAudioRecorder.updateMeters()` (the same data the VAD already uses) would be more satisfying. Pure visual polish — no logic change.

### 3.4 Multi-language support

Whisper handles 99 languages. Set `language` via onboarding/settings dropdown. Auto-detect is riskier (short clips mis-detect); manual preference is safer and ships first.

### 3.5 Workflow chains

"Majoor, my morning routine" → opens Slack, Gmail, Calendar; reads top 3 unread emails; gives me the day's first meeting. User-defined chains stored in `~/.majoor/workflows/`. Architecturally just a `run_workflow(name)` tool that fans out into the existing tool layer (~80 lines).

### 3.6 Apple Foundation Models integration

When Apple's on-device models are stable on macOS 15+, route small routing decisions locally and escalate to OpenAI only for tools/reasoning. Cuts latency and cost.

### 3.7 Action confirmation for destructive operations

Today "Majoor, empty the trash" just does it. Confirmation flow: "Empty the trash? Say 'yes' to confirm." Either synchronous or a timed pill in the notch. Light effort, high safety upside.

---

## Distribution & operations — parallel track

Not user-facing, but the difference between "open source side project" and "a thing people install without thinking."

### 4.1 Auto-update via Sparkle · Complexity: **M** · Value: ⭐⭐⭐⭐ · **Target: v1.4**

[Sparkle](https://sparkle-project.org/) is the de facto Mac auto-update framework. Without it, every release requires every user to manually re-download. Adoption curve flattens after the initial wave. Wire it up with an `appcast.xml` on GitHub Pages and a GitHub Action that updates the cast on each release.

### 4.2 Notarization · Complexity: **S** (mostly $99 + waiting) · Value: ⭐⭐⭐⭐ · **Target: v1.4**

$99/yr Apple Developer Program → notarize → no more Gatekeeper "are you sure?" dance on first launch. Single biggest friction-killer for new downloaders.

Steps: enroll → `xcodebuild archive` → `xcrun notarytool submit` → `xcrun stapler staple` → distribute. Automatable in GitHub Actions.

### 4.3 Cloudflare Worker proxy for API key · Complexity: **M** · Value: ⭐⭐⭐

A Worker proxy with a usage quota would allow distributing Majoor with a built-in trial key (rate-limited) plus a BYOK upgrade path, or a $5/mo hosted experience. Real product step — don't build unless you're going to actually run it.

### 4.4 Telemetry (opt-in) · Complexity: **S** · Value: ⭐⭐ (you), ⭐⭐⭐⭐ (product decisions)

Anonymous, opt-in event stream: which tools are called most, failure rates per tool, onboarding drop-off. Use [PostHog](https://posthog.com) (generous free tier). Opt-in checkbox in onboarding step 1.

### 4.5 Crash reporting · Complexity: **S** · Value: ⭐⭐⭐

[Sentry](https://sentry.io) for the Swift app + Next.js site. Free tier is generous. First crash → instant stack trace.

### 4.6 Mac App Store distribution

Eventually. Requires notarization + App Sandbox (currently disabled for `Process`/`osascript` — needs entitlements rework) + Apple review (strict on voice assistants). Don't do this unless committing to a serious paid product. Direct distribution via GitHub Releases is fine for the foreseeable future.

---

## Deliberately NOT building

Re-affirming the `MASTER_PLAN.md §11` no-list:

| Rejected | Why |
|---|---|
| **Wake-word always-listening** | Battery drain, privacy theater, false positives. Push-to-talk is a *feature*. Re-evaluate only if Apple ships a sublayer apps can hook into. |
| **On-device Whisper (whisper.cpp)** | 200–500 MB bundle, multi-second cold start, accuracy regression vs `gpt-4o-mini-transcribe`. Not worth it until offline mode is a top user request. |
| **OpenAI Realtime API** | Completely different product shape (full-duplex). Rewrites the whole loop. Revisit only if Majoor becomes always-conversational. |
| **Multi-agent orchestration** | One user → one flow. The current agent loop is the right shape for a long time. |
| **Paid TTS providers (ElevenLabs, Play.ht)** | Hard constraint. `say` works. Users who want better voices can download premium macOS voices free from System Settings → Spoken Content. |
| **`say(text)` as a tool** | Re-introduces the chitchat-misroute bug we already fixed structurally. Speaking is default behavior under `tool_choice="auto"`. |
| **Vector embeddings for memory** | Flat JSON + 6-turn buffer covers 95% of real multi-turn needs. Premature until memory grows to 1000+ facts AND retrieval issues are observed. |
| **Removing the menu bar status icon** | Invisible on no-notch Macs; loses settings and permission-state surface. Always keep it. |
| **Router-then-handler architecture** | Doubles latency to save nothing on gpt-4o-mini. The router IS the handler. |
| **Browser extension companion** | Out of scope for v1.x. Re-evaluate if screen-OCR ships and we want richer per-page context. |

---

## Recommended next session

Ship **Tier 1.1 + 1.2 + 1.4 + 1.5 + 1.6 + 1.7 + 1.8** in one v1.3 weekend. That's:

- media_control, set_volume, change_volume
- clipboard_read, clipboard_write
- forget, list_memory
- custom hotkey + full Settings window

User-visible shift: from "voice command launcher" to "fully customisable voice assistant with media + clipboard + memory management." The Settings window alone graduates Majoor from developer toy to polished tool for most people.

Predicted complexity: ~150 lines of new Swift, mostly in `ToolExecutor.swift`, `Tools.json`, a new `SettingsWindow.swift`, and `SystemPrompt.txt` few-shots.

Tier 4.1 (Sparkle auto-update) is the highest-leverage non-feature work and should land in v1.4 at the latest.

---

## Release timeline summary

| Version | Status | Target | Highlights |
|---|---|---|---|
| v1.0 | ✅ Released | — | Core pipeline: STT + agent loop + open_app/open_url/search_web |
| v1.1 | ✅ Released | — | Onboarding flow |
| v1.2 | ✅ Released | — | Eval improvements (24/25, 96%) |
| v1.3 | 🔜 Planned | ~2 weeks | Media controls, volume/brightness, clipboard, forget/list memory, custom hotkey, Settings window |
| v1.4 | 🔜 Planned | ~4–6 weeks | Screenshot + OCR, type_text, Sparkle auto-update, notarization |
| v1.5 | 🔜 Planned | ~2–3 months | Window management, file search, calendar/reminders, compose email/message |
| v1.6 | 🔜 Planned | ~3–4 months | Multi-turn follow-ups, conversation history viewer |
| v2.x | 💡 Future | TBD | Plugin system, workflow chains, Apple Foundation Models, community integrations |

---

*Last updated: 2026-06-14. Tracks v1.2.0 as the released baseline.*
