# Majoor — Improvement Roadmap

> Living doc. Captures (1) why the current behavior feels dumb sometimes, (2) the tool/model changes that fix it, and (3) the UI/UX direction toward a **notch-anchored popup** instead of the plain menu-bar icon.

---

## 1. What's currently wrong — observed in actual session logs

### 1.1 Over-eager fallback to `search_web`

**Evidence** — from today's log:

```
Transcript: Is this recording or not? Let's just, you know, check it once.
Tool: search_web  args: { query: "how to check if a recording is happening" }
```

That's a conversational/exploratory utterance. The user wasn't asking to Google anything. The model picked `search_web` because we **force it to pick a tool every time** (`tool_choice: "required"` in `OpenAIClient.chat`) and the only three action tools we expose are `open_app`, `open_url`, and `search_web`. There's no escape valve for "just talk back to me."

Same root cause produced this earlier:

```
Transcript: Hi, this is Vivek here. I don't want you to do anything. I just want you to say hi back to me.
Tool: search_web  args: { query: "Hi Vivek!" }
```

### 1.2 Compound / scoped commands lose half the intent

**Evidence:**

```
Transcript: open gmail.com in safari
Tool: open_app  args: { app_name: "Safari" }   ← lost "gmail.com"
```

The model can only pick *one* tool with *one* set of args. "Open X in Y" is two pieces (URL + target app) but `open_app` and `open_url` are siblings, not composable.

### 1.3 No direct-knowledge answers — everything routes through Google

If the user asks **"what's the weather in Ahmedabad"**, currently the best the model can do is `search_web("weather in Ahmedabad")` — open a browser tab. But `gpt-4o-mini` could just *answer*, spoken: "It's about 38°C and sunny." For factual questions where the model already knows the answer (geography, definitions, conversions, capitals), opening a tab is a worse UX than a one-sentence spoken reply.

### 1.4 Transcription occasionally mis-hears

Examples seen today:
- "Open Notes" → "Open Nodes" (model recovered, but unstable)
- "Open Safari" → "अपने साफारी अपने साफारी" (Whisper auto-detected wrong language — fixed by pinning `language=en`)

### 1.5 Permissions flake on every clean rebuild

Solved (mostly) once we switched to personal-team signing. But TCC still occasionally drops permission if the codesign cert serial changes between builds. Manual re-grant required ~once per major build session.

### 1.6 UI is invisible until you talk

The waveform icon in the menu bar is fine, but it's **not glanceable** — you can't tell at a glance whether the app is running, idle, listening, or thinking. The orb appears only mid-loop. There's no resting state, no history, no affordance.

---

## 2. Tool design — current vs proposed

### 2.1 Tools we have

| Tool | Side effect | Example trigger |
|---|---|---|
| `open_app(app_name)` | `/usr/bin/open -a <App>` | "open Notes" |
| `open_url(url)` | `/usr/bin/open <https://…>` | "open gmail" |
| `search_web(query)` | google.com/search?q= | "look up X" |
| `system_command(action)` *(Copilot branch)* | osascript for dark mode / mute / trash / sleep | "mute volume" |

### 2.2 Tools we need

| Tool | What it does | Why it fixes things |
|---|---|---|
| **`say(text)`** | Speaks `text` via TTS and nothing else | Greeting, thanks, "I'm not sure" — kills the `search_web` fallback for chitchat |
| **`answer(question)`** | Asks gpt-4o-mini to answer from model knowledge, then `say`s the result | "what's the weather in Ahmedabad", "what does API stand for" — direct factual replies, no browser tab |
| **`open_url_in_app(url, app)`** | Opens a URL inside a specific browser app | "open gmail.com in Safari" — composable scoping |
| **`media_control(action)`** | play/pause/next/prev via osascript | "pause Spotify", "next song" |
| **`type_text(text)`** | Pastes text into the focused app | "type 'hello world' into Notes" |
| **`screenshot()`** | Capture & save (future: OCR + describe) | "screenshot this", "what does the screen say" |
| **`set_volume(level)`** | Volume up/down/specific | "set volume to 50" |
| **`clipboard_read()` / `clipboard_write(text)`** | OS clipboard ops | "remember this", "what did I copy" |

### 2.3 Tool selection precedence (proposed)

Apply in order; pick the first that matches:

1. **Greeting / chitchat / "say…" / "tell me…"** → `say`
2. **Factual question answerable without fresh web data** → `answer`
3. **Explicit `X in Y` scoped command** ("open gmail.com in Safari") → `open_url_in_app`
4. **Domain or known service** ("gmail.com", "linkedin") → `open_url`
5. **System action** ("mute", "dark mode") → `system_command`
6. **Mac app name explicitly stated** → `open_app`
7. **"play/pause/skip"** → `media_control`
8. **Genuinely needs fresh web** ("latest news", "stock price now") → `search_web`
9. **Total ambiguity** → `say` with "I'm not sure what you meant — could you rephrase?"

Every tool returns a `reply` field that gets spoken — keep behavior consistent.

---

## 3. Model + prompt improvements

### 3.1 Few-shot examples (highest ROI, ~50 lines, ~$0.00004/call)

Replace abstract rules with ~10 worked input → tool examples covering the edge cases above. gpt-4o-mini follows patterns more reliably than rules.

### 3.2 Upgrade `gpt-4o-mini` → `gpt-4o`

5× more expensive (still ~$0.10–$0.50/day at heavy use). Materially better at:
- Detecting conversational vs action intent
- Honoring compound commands
- Resolving filler words ("uhhh open uhhh Notes")

### 3.3 Conversation history (multi-turn)

Pass last 3–5 transcript/tool pairs in `messages`. Enables:
- "open my email" → "which one?" → "Gmail" 
- "close it" → understands what "it" is
- "again" / "continue"

### 3.4 Memory file (`~/.majoor/memory.json`)

User-specific facts prepended to every system prompt:
```json
{
  "preferred_browser": "Safari",
  "preferred_email": "Gmail",
  "name": "Vivek",
  "city": "Ahmedabad",
  "facts": ["I'm a developer", "I use VS Code"]
}
```
Updates on demand: "remember I prefer Brave" → memory append.

### 3.5 Better STT

- **Already on Copilot branch:** Whisper prompt biasing, 44.1 kHz audio, VAD threshold.
- **Next:** switch model from `whisper-1` → `gpt-4o-mini-transcribe` (newer, +5–10% accuracy on accented English).

---

## 4. UI / UX — the notch-anchored popup direction

### 4.1 What's possible

The MacBook Air M2 **does** have a notch (it's not just a Pro thing). macOS does NOT let any app render *inside* the notch cutout itself — that's hardware. But you can render *anchored to it* and that's where products like **Boring Notch**, **NotchNook**, and **DynamicNotchKit** live.

The OS exposes the notch geometry via:
- `NSScreen.main.safeAreaInsets.top` → height of menu bar including notch
- `NSScreen.main.auxiliaryTopLeftArea` → CGRect to the LEFT of the notch
- `NSScreen.main.auxiliaryTopRightArea` → CGRect to the RIGHT of the notch

Notch width on M2 Air ≈ 200 pt. Height ≈ menu-bar height (~24 pt).

### 4.2 Proposed: Dynamic-Island-style Majoor

**Resting state:** a small rounded pill *under* the notch, ~200 pt wide × 26 pt tall. Same width as the notch, so visually they look like a single black shape. Contains just the tiny waveform glyph.

**On hover (cursor enters top center of screen):** pill smoothly expands downward to a panel ~360 pt × 140 pt that shows:
- Current state (Idle / Listening / Thinking / Speaking)
- Last transcript
- Last reply
- Last 3 commands as quick-replay chips
- A mic button (alternative to Ctrl+Option)

**On Ctrl+Option (talking):** pill expands and morphs into the orb we already have, with the live state.

**On click elsewhere:** collapses back to the pill.

### 4.3 Implementation sketch (NEW file: `Majoor/UI/NotchPanel.swift`)

- Subclass `NSPanel` similarly to current `OrbPanel`.
- Position: `x = screen.midX - panelWidth/2`, `y = screen.frame.maxY - panelHeight` (no inset → flush with top).
- `borderless`, `nonactivating`, `level = .statusBar`, `collectionBehavior = .canJoinAllSpaces`.
- A SwiftUI `NotchView` with a `@State expanded: Bool`; spring animation on geometry change.
- A `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` watcher that flips `expanded` when cursor enters the trigger zone (`y >= screen.maxY - 6` and `|x - screen.midX| <= 120`).
- Remove the menu-bar `NSStatusItem` once this lands, OR keep both for a fallback.

Effort estimate: ~200 lines for a first cut. Use `Boring Notch` or `DynamicNotchKit` (Swift package, MIT) to skip the geometry math.

### 4.4 Visual references

- Apple's iPhone Dynamic Island — the design target
- [boring-notch on GitHub](https://github.com/TheBoredTeam/boring.notch) — open-source macOS implementation
- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) — Swift Package; could be a dependency

---

## 5. Action plan — what to do, in order

### Phase A — Fix the dumb-sounding behavior (1 session, ~1 hr)
1. Add `say` tool + executor branch.
2. Add `answer` tool (internally calls gpt-4o-mini once more to answer, then speaks).
3. Tune system prompt with 8–10 few-shot examples.
4. Swap STT to `gpt-4o-mini-transcribe`.
5. Bump chat model to `gpt-4o` (consider — depends on cost tolerance).
6. **Test** that "Is this recording?" doesn't trigger a Google search.

### Phase B — Notch UI (1–2 sessions, ~3 hrs)
7. Add `DynamicNotchKit` SPM dependency (or roll our own).
8. Build resting pill that anchors under the notch.
9. Hover-expand into Dynamic-Island-style panel.
10. Wire existing AppState → NotchView. Keep or retire the menu-bar icon.

### Phase C — Conversational depth (1 session)
11. Multi-turn conversation history (in-memory ring buffer, last 5 turns).
12. `~/.majoor/memory.json` for persistent personal context.
13. Spoken error on app-not-found (validate `open` exit code).

### Phase D — More tools (incremental)
14. `media_control` (play/pause/next).
15. `set_volume`.
16. `screenshot`.
17. `open_url_in_app` for compound commands.

---

## 6. Cost & privacy notes (for the user)

- **Whisper STT:** ~$0.006 / min of audio.
- **gpt-4o-mini chat:** ~$0.00005 per command.
- **OpenAI TTS (alloy):** ~$0.015 / 1k characters; typical reply = ~$0.0003.
- Total per interaction: ~$0.005–$0.01 ish. At ~50 interactions/day = ~$0.30/day.
- **Audio is sent to OpenAI.** That's their privacy policy, not ours. If we ever want local-only STT, look at `whisper.cpp` (free, runs on-device, ~250 MB model). Slower (~2× realtime on M2) but private.

---

## 7. Open questions to discuss before coding

1. Should `answer` use the **same chat call** as tool selection (one round-trip with a `say` tool whose argument *is* the answer), or a **separate second call** (cleaner but doubles latency)?
2. Should we keep the menu-bar icon when we ship the notch UI, or replace entirely?
3. Are you OK with the OpenAI TTS cost trade-off vs free `say`? The Copilot branch has OpenAI TTS as default with `say` fallback.
4. Wake word ("Hey Majoor") — interested? Cool but adds always-listening, battery drain, false triggers.
5. Local memory — store in plain JSON or encrypt at rest?

---

*Last updated: 2026-06-07*
