# Majoor — Feature Roadmap

> Companion to `MASTER_PLAN.md`. The master plan covers **architecture** (why
> the agent loop, why the notch UI, why the memory model). This doc covers
> **what to build next** — tools, integrations, polish, and ops. Tiered,
> opinionated, decisive. Engineer-to-engineer.

Each item carries three labels:

| Label | Meaning |
|---|---|
| **Tier 1 / 2 / 3 / 4** | Roughly when to build it. Tier 1 = next release. Tier 4 = eventually. |
| **Complexity** | XS (1 hour) · S (1 evening) · M (2–3 evenings) · L (1+ week) |
| **Value** | how much it changes the user's daily life. ⭐ → ⭐⭐⭐⭐⭐ |

If something doesn't have all three, it's not a real proposal yet.

---

## Table of contents

1. [Tier 1 — Next release (v1.3)](#tier-1--next-release-v13)
2. [Tier 2 — Solid expansions (v1.4–v1.6)](#tier-2--solid-expansions-v14v16)
3. [Tier 3 — Future / community / experiments](#tier-3--future--community--experiments)
4. [Tier 4 — Distribution & operations](#tier-4--distribution--operations)
5. [Deliberately NOT building](#deliberately-not-building-confirms-master_plan-11)

---

## Tier 1 — Next release (v1.3)

These are high-value, low-complexity additions that should land in the next 1–2 weeks. All are tool additions you wire into `Tools.json` + `ToolExecutor.swift` + a few-shot example in `SystemPrompt.txt`. Total predicted work: ~1 weekend.

### 1.1 `media_control(action)` · Complexity: **XS** · Value: ⭐⭐⭐⭐

Play / pause / next / previous on whatever's currently making sound (Spotify, Music, Safari/Chrome tabs, etc.). One osascript wrapper:

```applescript
tell application "System Events" to key code 100  -- F8 = play/pause
```

The media keys (F7/F8/F9) work universally across audio apps. No need to know which app is playing.

**Tool shape:**
```json
{ "action": { "enum": ["play_pause", "next", "previous"] } }
```

**Why ship first:** people say "Majoor, pause my music" within hours of installing. Closest thing to a daily-driver hit.

---

### 1.2 `set_volume(level)` and `change_volume(direction)` · Complexity: **XS** · Value: ⭐⭐⭐

Already have `mute` / `unmute` in `system_command`. This adds:

- `set_volume(level: 0–100)` — exact value via `set volume output volume <n>`
- `change_volume(direction: "up" | "down", amount: 0–50)` — relative

Replaces "mute the volume" + handles "Majoor, set volume to 30" and "turn it down."

**Open question:** add as new tools, or extend `system_command` enum? I'd say new tools — `system_command` enum is overflowing if we keep stuffing things in.

---

### 1.3 `set_brightness(level)` and `change_brightness(direction)` · Complexity: **S** · Value: ⭐⭐⭐

Brightness is trickier than volume on macOS. Two options:

- **`brightness` CLI** (`brew install brightness`) — clean, but requires Homebrew dependency.
- **Native** via `IOKit / CoreDisplay` — no dependency, but lower-level API.

I'd go IOKit. ~30 lines of Objective-C-style Swift in `ToolExecutor`. No external runtime needed.

---

### 1.4 `clipboard_read()` and `clipboard_write(text)` · Complexity: **XS** · Value: ⭐⭐⭐

NSPasteboard wrappers, ~10 lines each:

- "Majoor, what's on my clipboard?" → reads → speaks aloud
- "Majoor, copy hello world to the clipboard" → writes

Combined with `remember`, this unlocks "Majoor, save what I just copied to memory."

---

### 1.5 `forget(fact_substring)` · Complexity: **XS** · Value: ⭐⭐⭐⭐

Mirrors the existing `remember` tool. Removes any fact matching the substring (case-insensitive). Already-clean addition to `MemoryStore`.

**Tool shape:**
```json
{ "fact_substring": { "type": "string" } }
```

**Why it matters:** today, the only way to remove a fact is to delete `~/.majoor/memory.json` by hand. That's a "developer fix" — real users won't do it. Without `forget`, memory accumulates forever and gradually drifts.

---

### 1.6 `list_memory()` · Complexity: **XS** · Value: ⭐⭐⭐

Reads `MemoryStore.shared.facts` and returns them. The model summarises:

> "I know your name is Vivek, your preferred browser is Safari, and that you live in Ahmedabad."

Trigger phrases: "what do you know about me", "what have I told you".

---

### 1.7 Custom hotkey · Complexity: **S** · Value: ⭐⭐⭐⭐

Ctrl+Option works for most people, but a non-trivial fraction already uses it for something else (window managers, IDE shortcuts). Let users pick their own.

**Implementation:**
- Settings window with a "Record hotkey" button (uses `KeyboardShortcuts` open-source Swift package, or roll-your-own with `NSEvent.addLocalMonitorForEvents`).
- Store the chosen combo in `~/.majoor/config.json`.
- `HotkeyMonitor` reads it on init, re-creates the `CGEventTap` if it changes.

**Why now:** the bug report rate on this will only go up.

---

### 1.8 Settings window · Complexity: **S** · Value: ⭐⭐⭐⭐

Bundling 1.7 with a proper preferences pane:

- **Hotkey** picker
- **Voice** picker (drop-down of all `say -v "?"` voices — already free)
- **Memory** — view facts, click ✗ to forget individually
- **Conversation buffer size** — slider 0–12, default 6
- **STT/chat model** — radio: gpt-4o-mini (default) / gpt-4o (pricier, smarter)
- **Reset onboarding** button

Surfaces via menu bar → "Settings…" — same pattern as `Show Onboarding…`.

**Why it matters:** this is the single biggest unlock for non-technical users. Right now to change any of this they edit JSON files. That's a non-starter for most.

---

### Tier 1 summary — predicted v1.3 changelog

> 🆕 Media controls (play/pause/next/previous)
> 🆕 Volume and brightness as voice commands
> 🆕 Read & write the clipboard
> 🆕 "Forget" command to remove stored facts
> 🆕 "What do you know about me?" lists everything you've told Majoor
> 🆕 Custom hotkey — pick your own
> 🆕 Settings window — hotkey, voice, memory management, model choice

Total: ~80–120 lines of new Swift, 7 new tools in `Tools.json`, 4–5 new few-shots in `SystemPrompt.txt`. **Eval impact:** add ~6 new test cases (media/clipboard/memory mgmt). Predicted score 30/31 (≥96%).

---

## Tier 2 — Solid expansions (v1.4–v1.6)

Things that take more than an evening but are obviously valuable. Build only after Tier 1 is shipped and stable.

### 2.1 `screenshot()` and `screen_ocr()` · Complexity: **M** · Value: ⭐⭐⭐⭐

- `screenshot(target: "screen" | "window" | "selection")` — wraps `screencapture` CLI, saves to `~/Pictures/Majoor/`.
- `screen_ocr()` — captures current screen, runs Apple's Vision framework's `VNRecognizeTextRequest`, returns the text the model can answer questions about ("what does my screen say", "what's the error message").

**Permission:** Screen Recording permission. Add to onboarding step 3 alongside Accessibility.

**Why it unlocks:** "Majoor, summarise this article" → screenshot + OCR + answer. Without leaving the browser. Huge.

---

### 2.2 `type_text(text)` · Complexity: **S** · Value: ⭐⭐⭐⭐

Synthesises a keystroke sequence into whatever app is currently focused. Uses `CGEvent.keyboardSetUnicodeString` — already available since we have Accessibility permission.

- "Majoor, type: hello world" → focused field gets `hello world`
- "Majoor, dictate this email: Hi John, …" → drafts directly into Mail

Pairs well with clipboard tools — sometimes you want to paste, sometimes type character-by-character (passwords, forms that block paste).

---

### 2.3 Window management · Complexity: **M** · Value: ⭐⭐⭐

`window_action(action)` with enum:
- `close_window`, `minimize_window`, `fullscreen_window`
- `move_to_left_half`, `move_to_right_half`, `center_window`, `maximize`

Implementation: keystrokes for the standard shortcuts. For halves/quarters, integrate with [Rectangle](https://github.com/rxhanson/Rectangle)'s URL scheme OR roll our own via the Accessibility API.

**Caveat:** Rectangle integration requires Rectangle to be installed. Native is bigger code but no dependency. Suggest native.

---

### 2.4 File system primitives · Complexity: **S each** · Value: ⭐⭐⭐

- `search_files(query)` — wraps `mdfind` (Spotlight CLI). "Majoor, find my resume."
- `open_file(path)` — Finder-reveal or open with default app.
- `open_folder(path)` — common paths: Downloads, Documents, Desktop.

Combined: "Majoor, find my last invoice and open it" → search → open first result.

---

### 2.5 Calendar / Reminders · Complexity: **M each** · Value: ⭐⭐⭐⭐

- `create_calendar_event(title, start_time, duration_minutes)` — via EventKit framework.
- `create_reminder(title, due_date)` — same.

Both require EventKit permission. Add to onboarding.

**Why it's valuable:** "Majoor, remind me to email Sarah at 3pm" is the canonical voice-assistant command and we don't have it yet.

---

### 2.6 `compose_email(to, subject, body)` and `compose_message(recipient, body)` · Complexity: **S** · Value: ⭐⭐⭐

- `compose_email` — opens Mail.app with a pre-filled draft. URL scheme: `mailto:?to=X&subject=Y&body=Z`.
- `compose_message` — opens Messages.app to a recipient. URL scheme: `sms:&body=…` (works for both SMS and iMessage on a logged-in Mac).

Both go through the existing `/usr/bin/open` so no extra permission.

---

### 2.7 Multi-turn follow-ups · Complexity: **M** · Value: ⭐⭐⭐⭐

Today the conversation buffer carries 6 turns but the model can only *respond once per turn*. We don't yet support:

- "Majoor, find my emails from John" → list 3 → "open the second"
- "Majoor, what's the weather in Boston?" → "do you want a search?" → "yes"

This needs:

1. A way for the model to *ask* the user a question and *wait* for the next press-to-talk turn while binding context.
2. Possibly a `pending_question` field in `AppState` so the orb shows "Awaiting your answer…"

Real work. M-level. Once shipped, Majoor jumps to "feels like an assistant" rather than "voice-activated tool launcher."

---

## Tier 3 — Future / community / experiments

Build only when the above is stable AND there's clear user demand.

### 3.1 Plugin / extension system

Define a JSON tool-schema + a script (TypeScript via Bun, or Swift) that the user drops into `~/.majoor/plugins/`. On startup Majoor scans, registers them as additional tools. Lets the community build:

- Notion integration (search + create pages)
- Linear (create issues)
- GitHub (open issues, repos, search code)
- Slack DM
- Discord message
- Cal.com booking
- Things 3 / Todoist
- Bear / Apple Notes
- Tailscale device control

We don't build any of these. We give the scaffolding and let the community ship.

### 3.2 Conversation history viewer

A small window with the last 100 turns, searchable. "What did I ask Majoor last Tuesday about the project?" UI = a SwiftUI `List` + `TextField` for search. Backed by `~/.majoor/history.json` (append-only).

### 3.3 Voice waveform in the pill during recording

Today's pill shows a pulsing dot during listening. A live waveform (driven by the same `AVAudioRecorder.updateMeters()` data the VAD already uses) would be more satisfying. Pure visual polish — no logic change.

### 3.4 Multi-language support

Whisper handles 99 languages. Set `language` based on user preference. Two ways:

- **Manual** — onboarding/settings dropdown.
- **Auto-detect** — drop the `language=en` pin, let Whisper guess each call.

Auto-detect adds risk (your "open Safari" gets mis-detected as Hindi like in our v0.x days). Manual is safer.

### 3.5 Workflow chains

"Majoor, my morning routine" → opens Slack, Gmail, Calendar; reads top 3 unread emails; gives me the day's first meeting. User-defined chains stored in `~/.majoor/workflows/`. Triggers an internal sequence of tool calls.

Architecturally just a new tool `run_workflow(name)` that fan-outs into the existing tool layer. ~80 lines.

### 3.6 Apple Intelligence integration

When Apple Foundation Models are stable on macOS 15+, route SMALL routing decisions to the on-device model and only escalate to OpenAI for tools/reasoning. Cuts latency + cost. Apple announced public API; status of public availability depends on date.

### 3.7 Action confirmation for destructive operations

Today "Majoor, empty the trash" just does it. Should probably confirm:

> "Empty the trash? Say 'yes' to confirm."

Either with a synchronous confirm-then-act, or a confirmation pill in the notch with a 3-second timer to say yes/cancel.

Light effort, high safety upside.

---

## Tier 4 — Distribution & operations

Not user-facing, but the difference between "open source side project" and "a thing people install without thinking."

### 4.1 Auto-update via Sparkle · Complexity: **M** · Value: ⭐⭐⭐⭐

[Sparkle](https://sparkle-project.org/) is the de facto Mac auto-update framework. Wire it up:

- Add Sparkle SPM dep.
- Publish an `appcast.xml` to the website (or GitHub Pages).
- On every new release, GitHub Action updates the appcast.
- Users on v1.2.0 get notified when v1.3.0 ships, one-click update.

**Without this:** every release requires every user to manually re-download. Adoption curve flattens after the initial wave.

### 4.2 Notarization · Complexity: **S** (mostly money + waiting) · Value: ⭐⭐⭐⭐

$99/yr Apple Developer Program → notarize → no more Gatekeeper "are you sure?" dance on first launch. The single biggest friction-killer for new downloaders.

Steps:
1. Enroll in the Developer Program.
2. `xcodebuild archive` → `xcrun notarytool submit`.
3. Wait ~10 minutes for Apple to scan.
4. `xcrun stapler staple` to embed the notarization ticket.
5. Distribute.

Can be automated in GitHub Actions.

### 4.3 Cloudflare Worker proxy for API key · Complexity: **M** · Value: ⭐⭐⭐

Right now every user needs their own OpenAI key. A Worker proxy with a usage quota would let you:

- Distribute Majoor with a built-in trial key (Worker rate-limited).
- Let users upgrade to BYOK for unlimited.
- Or charge $5/mo for a hosted experience.

Real product step. Don't build unless you're going to actually run it.

### 4.4 Telemetry (opt-in) · Complexity: **S** · Value: ⭐⭐ (for you), ⭐⭐⭐⭐ (for product decisions)

Anonymous, opt-in event stream so you can see what people actually use:

- Which tools are called most (informs what to build next)
- Failure rates per tool
- Onboarding step drop-off

Use [PostHog](https://posthog.com) (generous free tier) or roll your own. Opt-in checkbox in onboarding step 1.

### 4.5 Crash reporting · Complexity: **S** · Value: ⭐⭐⭐

Wire up [Sentry](https://sentry.io) for the Swift app + Next.js site. Free tier is generous. The moment someone hits a crash, you see the stack trace.

### 4.6 Mac App Store distribution

Eventually. Requires:
- Notarization (Tier 4.2)
- App Sandbox enabled (currently disabled — we need it off for `/usr/bin/open` and `osascript`. Would require entitlements rework.)
- Review process (Apple gates voice assistants strictly)

**Verdict:** Don't do this unless you're committing to building a serious paid product. Direct distribution via GitHub Releases is fine for the foreseeable future.

---

## Deliberately NOT building (confirms MASTER_PLAN §11)

Re-affirming the master plan's "no" list with one update each based on what we now know:

| Rejected | Why (status today) |
|---|---|
| **Wake-word always-listening** | Battery drain, privacy theater, false positives. Push-to-talk is a *feature*, not a limitation. Re-evaluate only if Apple ships their own "Hey Siri" sublayer apps can hook into. |
| **On-device Whisper (whisper.cpp)** | 200–500 MB bundle, multi-second cold start, accuracy regression vs `gpt-4o-mini-transcribe`. Not worth it until offline mode is a top user request. Maybe relevant if Apple Foundation Models work well (3.6). |
| **OpenAI Realtime API** | Completely different product shape (full-duplex). Rewrites the whole loop. Tied to the wake-word problem above. Revisit only if Majoor becomes a continuously-conversational thing. |
| **Multi-agent orchestration** | One user → one flow. Use multiple agents only when you have many unique flows. We don't, and Phase A's agent loop is the right shape for a long time. |
| **Paid TTS providers (ElevenLabs, Play.ht)** | Hard constraint. macOS `say` works. The day a user complains the voice sounds robotic, point them at System Settings → Spoken Content → premium voices (free, downloadable). |
| **`say(text)` as a tool** | Re-introduces the bug we already structurally fixed. Speaking is default behavior under `tool_choice="auto"`. |
| **Vector embeddings for memory** | A flat JSON file + 6-turn buffer covers 95% of real multi-turn needs. Premature. Revisit when memory grows to 1000+ facts AND we observe retrieval issues. |
| **Removing the menu bar status icon** | Invisible on no-notch Macs, loses settings/permission surface. Always keep it. |
| **Router-then-handler architecture** | Doubles latency to save nothing on gpt-4o-mini. The router IS the handler. |
| **Browser extension companion** | Out of scope for v1.x. Voice is the input modality. Re-evaluate if we ship a screen-OCR tool and want richer per-page context. |

---

## Recommended next session

I'd ship **Tier 1.1 + 1.2 + 1.4 + 1.5 + 1.6 + 1.7 + 1.8** in one v1.3 weekend. That's:

- media_control, set_volume, change_volume
- clipboard_read, clipboard_write
- forget, list_memory
- custom hotkey + the full Settings window

User-visible value: from "voice command launcher" to "fully customisable voice assistant with media + clipboard + memory mgmt." Settings window alone graduates Majoor from "developer toy" to "polished tool" for most people.

Predicted complexity: ~150 lines of new Swift, mostly in `ToolExecutor.swift`, `Tools.json`, a new `SettingsWindow.swift`, and `SystemPrompt.txt` few-shots.

Tier 4.1 (Sparkle auto-update) is the highest-leverage non-feature work and should land in v1.4 at the latest.

---

*Last updated: 2026-06-08. Tracks v1.2.0 as the released baseline.*
