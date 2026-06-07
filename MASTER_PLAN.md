# Majoor — Engineering & UX Master Plan

> A researched, opinionated plan for turning Majoor from "it sometimes Googles 'Thanks Majoor'" into a polished voice-first macOS assistant. Engineer-to-engineer. No hedging where the answer is clear.

---

## Table of Contents

1. [Architecture: Chat-with-Tools When You Need Both Conversation AND Action](#1-architecture-chat-with-tools-when-you-need-both-conversation-and-action)
2. [Tool Design Principles](#2-tool-design-principles)
3. [Prompt Engineering for Tool Selection](#3-prompt-engineering-for-tool-selection)
4. [Latency Budget](#4-latency-budget)
5. [STT Quality](#5-stt-quality)
6. [Memory and Multi-Turn](#6-memory-and-multi-turn)
7. [Error and Unhappy-Path UX](#7-error-and-unhappy-path-ux)
8. [UX Direction: The macOS Notch Popup](#8-ux-direction-the-macos-notch-popup)
9. [Comparable Products — What to Steal, What to Avoid](#9-comparable-products--what-to-steal-what-to-avoid)
10. [Sequenced Execution Plan](#10-sequenced-execution-plan)
11. [Things I Am NOT Recommending and Why](#11-things-i-am-not-recommending-and-why)
12. [References](#references)

---

## 1. Architecture: Chat-with-Tools When You Need Both Conversation AND Action

### The diagnosis

The reason Majoor Googles "Thanks Majoor" is not a prompt-engineering accident. It is a structural consequence of `tool_choice="required"`. OpenAI's function-calling docs define four operational modes for `tool_choice` [1]:

- `auto` — model may call zero, one, or many tools, or just talk.
- `required` — model **must** call at least one tool.
- A specific function name — model must call exactly that one.
- `none` — tools disabled; model must just talk.

`tool_choice="required"` is a hammer. When the user says "thanks", the model is contractually forbidden from replying with words, so it grabs the closest tool that accepts a string and calls `search_web("Thanks Majoor")`. The bug is in the contract, not the prompt.

### The four candidate patterns

**(a) One-shot function call with `tool_choice="auto"`.** Send the user message with the tools attached. The model decides whether to call a tool or reply with assistant text. If it replies with text, speak it. If it calls a tool, execute it and speak a canned confirmation. This is the smallest possible change from today.

**(b) Agent loop with tool results fed back.** The canonical OpenAI pattern documented as a five-step loop [2]:

> 1. Make a request with available tools
> 2. Receive a tool call from the model
> 3. Execute your code using tool call input
> 4. Send a second request with the tool output
> 5. Receive a final response (or additional tool calls)

The OpenAI Cookbook's "Orchestrating Agents" example codifies the same shape as an explicit `while` loop: call the model, append the response, break if no tool calls, otherwise execute each tool and append its result, then repeat [3]. After a tool runs, the model sees the result and produces a real spoken confirmation ("Opened Gmail in Safari") instead of Majoor speaking a hard-coded string.

**(c) Router-then-handler.** A small model classifies intent (chitchat / web / app / url), then dispatches to a handler. Two API calls per turn. Doubles latency to save nothing — gpt-4o-mini is already cheap and fast enough that the router IS the handler.

**(d) Structured Outputs / JSON mode.** Structured Outputs guarantees JSON-Schema adherence; JSON mode only guarantees valid JSON without schema adherence [4]. For tool-calling applications, OpenAI explicitly states "If you are connecting the model to tools, functions, data, etc. in your system, then you should use function calling" rather than `response_format` [5]. So Structured Outputs is not an alternative to function calling here — it is something you **layer onto** function calling via `strict: true`.

### Recommendation for Majoor: Pattern (b), the agent loop, with `tool_choice="auto"` and `strict: true` on every tool

Justification:

1. **`auto` fixes the chitchat bug structurally.** "Thanks" produces an assistant text message ("You're welcome"), not a tool call. No prompt heroics required.
2. **The loop fixes the "speaks a canned confirmation" problem.** After `open_url_in_app({app:"Safari", url:"gmail.com"})` succeeds, the loop sends the tool result back and the model says "Opened Gmail in Safari" — natural, contextual, in voice. Today Majoor speaks a stringly-templated reply, which is why it sometimes sounds robotic.
3. **`strict: true` should be on every function.** OpenAI's explicit recommendation: "Setting strict to true will ensure function calls reliably adhere to the function schema, instead of being best effort. We recommend always enabling strict mode" [6]. Strict mode is supported on gpt-4o-mini, gpt-4o-mini-2024-07-18, gpt-4o-2024-08-06 and later, so Majoor's current model already qualifies [7]. This won't eliminate every argument-loss bug (the model can still pick the wrong tool, or pass `url:"gmail.com"` without `app:"Safari"`), but it does eliminate the class where the model emits malformed JSON or skips required fields.
4. **Two API calls per turn is acceptable.** On gpt-4o-mini the second call is small (one tool result, ~50 tokens) and fast. Worst-case adds ~300–500ms to a turn that already costs 2–3 seconds. Worth it for natural confirmations.

Bound the loop at **3 iterations**. Voice commands are not deep agent tasks. If the model wants a fourth tool call, something is wrong — break and speak an apology.

---

## 2. Tool Design Principles

### When is something a tool vs. just text the model speaks?

A capability is a tool if and only if executing it has a side effect outside the LLM — opening an app, hitting an API, reading a file, controlling a process. Speaking, answering, thanking, apologizing, asking a clarifying question — these are **not** tools. Under `tool_choice="auto"`, the model emits them as ordinary assistant content and you pipe that into `/usr/bin/say`. This is the entire reason `tool_choice="auto"` is the right choice (see §1): it makes "say a thing" a default behavior, not a special case.

A common anti-pattern is `say(text: String)` as a tool. Don't do this. It forces the model to emit a tool call for every reply, doubles your API round-trips for chitchat, and re-introduces the problem you just solved.

### Compound tools without exploding surface area

The current eval failures on `open_url_in_app` ("open gmail.com in Safari" losing the URL half) are caused by tool decomposition. With separate `open_app` and `open_url` tools, the model has to choose one and discard half the user's intent. The fix is a compound tool:

```json
{
  "name": "open_url_in_app",
  "description": "Open a URL in a specific app (e.g. gmail.com in Safari, github.com in Chrome). Use this whenever the user names BOTH a URL/domain AND an app.",
  "parameters": {
    "type": "object",
    "properties": {
      "url": {"type": "string", "description": "Full URL or bare domain. Prepend https:// if missing."},
      "app": {"type": "string", "description": "App name as the user said it (Safari, Chrome, Arc, Firefox)."}
    },
    "required": ["url", "app"],
    "additionalProperties": false
  },
  "strict": true
}
```

The general principle: **collapse n-ary intents into single tools rather than expecting the model to compose them.** A model picking between `open_app` and `open_url` will discard information; a model picking `open_url_in_app` is given a slot for every piece of the user's request.

### How many tools?

OpenAI's guidance: "Aim for fewer than 20 functions available at the start of a turn at any one time, though this is just a soft suggestion" [8]. Majoor will live forever well under 20. The current target set is six:

1. `open_app(name)` — "open Gmail", "open VS Code"
2. `open_url(url)` — "go to github.com", "open hacker news"
3. `open_url_in_app(url, app)` — "open gmail.com in Safari"
4. `search_web(query)` — "search for swift menu bar tutorial"
5. `system_command(command: enum)` — sleep, lock, mute, brightness, volume
6. `recall_memory(key)` — Phase C; see §6

Everything else is a candidate for "the model just says it" — answers, jokes, acknowledgements, clarifying questions.

### Strict-mode caveats

`strict: true` has documented schema restrictions: no `minimum` on integers, no `oneOf`/`allOf`, 100-parameter limit, first-request latency overhead from schema compilation [6]. None of these matter for Majoor's flat string/enum schemas, but they're worth knowing if a future tool gets complicated.

---

## 3. Prompt Engineering for Tool Selection

### Few-shot vs. rules-only in 2025-era models

Rules-only system prompts ("If user names an app, call `open_app`. If user names a URL, call `open_url`.") underperform on natural speech. Real voice input is messy: "uh open gmail real quick", "throw on some lo-fi on youtube", "what's the weather". The rules don't enumerate cleanly, and the model resolves ambiguity by guessing.

Few-shot examples teach the model the **shape** of correct routing using actual transcripts. Eight to twelve examples covering the long tail (chitchat, factual question, app, URL, app+URL, system command) is the sweet spot — enough variety for generalization, few enough to keep token cost manageable.

### Recommended system prompt structure

```
[ROLE]
You are Majoor, a voice-first macOS assistant. You hear the user via Whisper transcription, then either reply briefly in spoken English OR call exactly one tool to take action on their Mac.

[BEHAVIOR RULES]
1. If the user is making smalltalk, thanking you, or asking a factual question you can answer in one sentence, REPLY WITH TEXT. Do NOT call search_web.
2. If the user wants to open an app, call open_app.
3. If the user wants to visit a URL or domain, call open_url.
4. If the user names BOTH a URL/domain AND an app, call open_url_in_app.
5. If the user wants a system action (sleep, lock, mute, brightness), call system_command.
6. If the user is asking you to search the web for current information, call search_web.
7. Spoken replies must be under 12 words. No markdown, no lists.

[FEW-SHOT EXAMPLES]
User: "thanks majoor"
Assistant: "Anytime."

User: "what's the capital of france"
Assistant: "Paris."

User: "open gmail"
Assistant: open_app(name="Gmail")

User: "throw on youtube"
Assistant: open_app(name="YouTube")  // catalog alias

User: "go to hacker news"
Assistant: open_url(url="https://news.ycombinator.com")

User: "open gmail.com in safari"
Assistant: open_url_in_app(url="https://gmail.com", app="Safari")

User: "open this in chrome github.com slash anthropic"
Assistant: open_url_in_app(url="https://github.com/anthropic", app="Chrome")

User: "lock my mac"
Assistant: system_command(command="lock")

User: "search for swift package manager tutorial"
Assistant: search_web(query="swift package manager tutorial")

User: "who won the world series last night"
Assistant: search_web(query="world series winner last night")

User: "is this recording"
Assistant: "Yes, I'm listening."

User: "never mind"
Assistant: "Okay."
```

### Model choice

Stick with **gpt-4o-mini** for v1. It supports strict-mode Structured Outputs [7], is fast, cheap, and well-calibrated on tool selection given good few-shots. Upgrade to gpt-4o or gpt-4.1-mini only if Phase A evals plateau below ~88%. Don't change two variables at once — a model upgrade should be its own eval delta.

### Temperature

Set `temperature: 0` for the tool-routing call. There is exactly one correct tool for each utterance; sampling diversity buys nothing and costs determinism in your eval harness. Spoken replies at temperature 0 are slightly flatter but voice users will not notice.

### Structured Outputs / strict mode

Already covered in §2. Set `strict: true` on every tool. This is OpenAI's official guidance [6] and has no downside for Majoor's schema shapes.

---

## 4. Latency Budget

### The perceptual threshold

Human-to-human conversation lands turn gaps around 200ms with most under 300ms [9]. For voice AI, sub-300ms is perceived as instantaneous, ~500ms is consciously noticed ("did it hear me?"), and over ~1000ms users start to assume failure [10]. The Stivers et al. PNAS cross-linguistic study is the primary anchor here — natural conversational gaps cluster around 200ms across 10 languages [9].

Majoor will not hit 300ms end-to-end without on-device models or streaming, and that's fine for a push-to-talk assistant. The bar Majoor must clear is: **when the user releases the hotkey, something visible happens within 300ms, and the spoken reply starts under 2 seconds.**

### Current Majoor breakdown (estimated, hold-to-release to first spoken word)

| Stage | Estimate | Notes |
|---|---|---|
| Hotkey release detected | ~10ms | CGEventTap latency |
| Audio file flush + upload | 150–400ms | depends on clip length, network |
| Whisper-1 transcription | 600–1500ms | dominant cost, no streaming |
| Chat completion (gpt-4o-mini) | 400–900ms | one round trip |
| Tool execution (`open`) | 30–100ms | local process |
| `say` startup + first phoneme | 200–500ms | system TTS |
| **Total to first audible word** | **~1.4–3.4s** | |

With the agent loop (§1), add a second chat call (~300–500ms) before the spoken confirmation. So worst case ~3.9s. Above the comfort zone, but acceptable for push-to-talk.

### Concrete optimizations, ordered by ROI

1. **Visible state change within 50ms of hotkey release.** The notch UI (§8) flips to "thinking" before the network has done anything. This is the single biggest perceived-latency win — it reframes the wait from "broken" to "working".
2. **Stream chat completion.** OpenAI's chat endpoint supports SSE streaming. As soon as the first tokens arrive, you know whether it's a tool call or text; for text, start `say` on the first sentence. Cuts perceived chat latency by ~50%.
3. **Switch Whisper to `gpt-4o-mini-transcribe`** (see §5). Faster and cheaper than whisper-1; comparable accuracy.
4. **Pre-warm `say`.** Spawn `/usr/bin/say` as a long-lived process and pipe text to it, instead of `Process.launch` per utterance. Saves ~150–300ms of process startup per turn.
5. **Parallel TTS for tool path.** Once the tool call arrives and starts executing, you can start speaking a generic confirmation ("Opening Gmail...") in parallel with the second agent-loop call. If the second call disagrees, you've still said the right thing 95% of the time.
6. **Audio compression.** Upload Whisper audio as 16kHz mono Opus/WebM instead of WAV. Whisper accepts compressed formats; WAV is 10–20x larger. Saves 100–300ms on upload over typical home Wi-Fi.
7. **Connection reuse.** Keep a single `URLSession` with HTTP/2 / connection pooling enabled; don't tear down the TLS handshake per request.

What NOT to optimize: don't chase sub-1s end-to-end. You'll burn weeks on the OpenAI Realtime API or on-device Whisper and ship nothing. Push-to-talk users tolerate 2s; conversational voice (always-on) users don't, and Majoor is not conversational voice.

---

## 5. STT Quality

### Comparing the OpenAI STT options

| Model | Accuracy (accented English) | Latency | Cost | Streaming |
|---|---|---|---|---|
| `whisper-1` | Strong baseline; some hallucination on short clips | 600–1500ms typical | $0.006/min | No |
| `gpt-4o-mini-transcribe` | Comparable to Whisper on common accents, better on noisy audio | ~30–40% faster than whisper-1 in OpenAI's reports | Cheaper per minute | Yes (chunked) |
| `gpt-4o-transcribe` | Best accuracy on hard accents and overlapping speech | Similar to mini-transcribe | More expensive | Yes |

### Recommendation: `gpt-4o-mini-transcribe`

Reasons:

1. Latency win is real and felt — the STT stage is currently the longest single step in Majoor's loop.
2. Cost decrease is meaningful at hobby scale; you can run more eval iterations.
3. Streaming unlocks the future option of speculative tool dispatch while the user is still speaking.
4. Accuracy is competitive with whisper-1 for the user's accent (USC, presumably standard-to-mild-Indian-English; mini-transcribe handles this well).

Move to `gpt-4o-transcribe` only if eval cases reveal accent-driven STT errors are a top failure mode. For Majoor's command-shaped utterances ("open gmail", "search for X"), the mini model is sufficient.

### Practical Whisper/transcribe tuning

- **Language pinning.** Pass `language: "en"` explicitly. Whisper auto-detect occasionally mis-fires on short clips and decodes English as a different language phonetically.
- **Prompt biasing.** Pass `prompt: "Majoor, Gmail, GitHub, VS Code, Safari, Chrome, Cmd, Ctrl, Opt"` and your common spoken aliases. Whisper uses this as decoding context and gets dramatically better on rare brand names. Tune the prompt list against your evals.
- **Sample rate.** 16kHz mono is the Whisper sweet spot; recording at 48kHz wastes bandwidth and gives no accuracy boost. AVAudioEngine should be configured for `AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1)`.
- **Endpointing/VAD.** Don't transcribe silence. Drop clips under 300ms and clips that the audio engine reports as below an RMS threshold. Saves a round trip and prevents the "I didn't catch that" loop on accidental hotkey taps.
- **Trim leading silence.** Whisper occasionally hallucinates on leading silence (the "is this recording" failure mode). Trim 100ms from the start of the buffer once recording ends.

---

## 6. Memory and Multi-Turn

### What production voice assistants actually do

Three layers, in increasing scope:

1. **Conversation buffer** (in-process, ephemeral). The last 4–8 turns of `(user, assistant, tool_calls)` kept in memory. Lets the user say "open it again" referring to the previous app, or "the other one" when disambiguating. This is just `messages: [...]` reused across turns.
2. **Session memory** (in-process, decays). Things mentioned this session — "my browser is Arc", "use Spotify not Apple Music". Lives in a struct, dies when Majoor quits.
3. **Persistent preferences** (`~/.majoor/memory.json`). Stable user facts — default browser, name, timezone, common aliases. Injected into the system prompt at launch.

Siri and Alexa do all three; ChatGPT voice does (1) and (3); Raycast AI does (1) and pieces of (3).

### Recommendation: smallest version that unlocks value

For Phase C, build only:

- **Conversation buffer**: keep the last 6 turns in `AppState.history`. Send them with every chat request. Cost is ~300–800 tokens — trivial on gpt-4o-mini.
- **`~/.majoor/memory.json`** with a fixed schema:

  ```json
  {
    "default_browser": "Safari",
    "name": "Nishtha",
    "aliases": { "gmail": "https://mail.google.com", "calendar": "https://calendar.google.com" },
    "recent_apps": ["Gmail", "VS Code", "Safari"]
  }
  ```

  Load at launch, splice into system prompt as a `[USER FACTS]` block. Update `recent_apps` after each `open_app` call. No model writes to disk.

What to skip in v1: vector embeddings of conversation history (premature), a `remember(fact)` tool (cute but invites prompt injection), and per-app context (overengineered).

Do **not** add a separate Memory API call. Inject memory inline into the system prompt. One round trip is faster than two.

---

## 7. Error and Unhappy-Path UX

The rule: **never crash, never go silent, always return to idle.** What you say in failure mode is product UX, not error handling.

| Failure | What to say | What to show |
|---|---|---|
| Empty/short transcript | "I didn't catch that." | Brief shake animation, return to idle |
| Whisper times out (>8s) | "Connection's slow — try again." | Red dot in notch for 2s |
| OpenAI 5xx / chat fails | "Something went wrong. Try again in a sec." | Red dot, log to file |
| Network down | "I'm offline right now." | Offline icon in notch |
| Unknown app | "I don't have an app called {name}." | Brief shake |
| Permission missing (Accessibility/Mic) | (Spoken) "Need permission first — check the menu bar." + open System Settings | Persistent banner in notch |
| Hotkey tap with no speech | (silent) | Brief idle pulse, no spoken reply |

### What leading assistants do

- **Siri** says short, branded apologies ("I'm having trouble connecting") and degrades to a typed-input fallback. Failure language is consistent across error types — users can't distinguish offline from API failure, which is intentional.
- **Alexa** uses progressive disclosure — "Sorry, I'm having trouble" first; only on retry does it say what's actually wrong.
- **Raycast AI** is engineer-honest: shows error codes, lets you retry inline. Works for Raycast's power-user audience; would feel hostile in a voice context.
- **ChatGPT voice** speaks short apologies and stays in the conversation, never breaking flow to show a modal.

Majoor's voice should sit between Siri and ChatGPT: short, human, never blame the user, never expose stack traces. Log everything to `Core/Logger.swift`; never speak the log.

### One non-obvious detail

When the user has clearly given a multi-part command and you can only fulfill part of it ("open gmail in safari and start a new email" — you can do the first half), do the part you can and say "Opened Gmail. Can't start the email yet." Honesty beats silence.

---

## 8. UX Direction: The macOS Notch Popup

### What's actually possible

You cannot render inside the physical notch cutout. macOS does not expose any public or private API to put pixels behind the notch glass; the cutout is a hardware mask. What you can do is render an `NSPanel` (`.nonactivatingPanel`, `level = .mainMenu + n`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`) positioned at and around the notch area, so the panel's visual mass appears to merge with the cutout. This is exactly the pattern BoringNotch uses — its `BoringNotchWindow` is an `NSPanel` with `isFloatingPanel = true`, `isOpaque = false`, `backgroundColor = .clear`, `level = .mainMenu + 3`, and `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]` [11]. The notch-shaped visual is drawn by SwiftUI shapes extending downward from the cutout, giving the illusion of "the notch grew".

Apple's public APIs for working with notched displays are `NSScreen.auxiliaryTopLeftArea` and `NSScreen.auxiliaryTopRightArea` [12], which report the unobscured menu bar regions adjacent to the cutout. Atoll, a notch-anchored production app, uses exactly these APIs to size and position its overlay window [13]. This is the documented, App-Store-safe path.

### Three libraries that solve most of this for you

- **DynamicNotchKit (MrKai77)** — Swift Package, SwiftUI-based, handles window drawing, content insets, safe areas. Exposes a generic `DynamicNotch { ContentView() }` container plus a specialized `DynamicNotchInfo` for icon/title/description [14][15]. macOS 13+. MIT licensed. Strongest fit.
- **DynamicNotch (jackson-storm)** — Different package with the same name. Auto-degrades to a floating capsule shape (`DynamicIslandShape`) on non-notched Macs and external displays [16]. Useful if Majoor will ever run on an M1/M2 Air without a notch (your case — MacBook Air M2). Architecturally describes itself as "AppDelegate manages app lifecycle, floating overlay window setup, workspace observers, and lock-screen handoff" [17].
- **BoringNotch (TheBoredTeam)** — Not a library, a full reference app. 9.5k stars, actively maintained, macOS 14+, Swift 98.2%, SwiftUI [18]. Read its source for window class patterns. Don't depend on it.

### Recommendation: adopt `DynamicNotchKit` for Phase B

Reasons:

1. SwiftUI-first, matches Majoor's stack.
2. macOS 13+ baseline, well below Majoor's 14+ floor.
3. The `DynamicNotch { AnyView }` container directly supports Majoor's state-driven UI — pass different SwiftUI views for idle/listening/thinking/speaking [15].
4. MIT-licensed, no commercial-use friction.
5. Maintained, ~418 stars; not abandoned.

If `DynamicNotchKit` (MrKai77) ships with edge cases that break on the M2 Air (no notch), fall back to jackson-storm's `DynamicNotch`, which explicitly handles the no-notch case by transitioning to a capsule shape [16].

### Visual states

| State | Visual | Width | Duration | Sound |
|---|---|---|---|---|
| Idle | Hidden, or 4px idle pill next to notch | 0–60px | persistent | none |
| Listening | Notch expands downward; pulsing waveform | 280px × 50px | held while recording | optional soft chirp on start |
| Thinking | Notch compact; spinning dot | 80px × 32px | until first tool call or token | none |
| Executing | Notch compact; checkmark fill animation | 80px × 32px | ~300ms | none |
| Speaking | Notch expanded; mouth/wave animation matching `say` output | 280px × 50px | while TTS plays | none |
| Error | Notch flashes red, brief shake | 200px × 40px | ~1.5s | none |

Transitions: ~250ms spring animations. Match the rhythm of Apple's own Dynamic Island on iPhone.

### Retire or keep the menu bar status icon?

**Keep it, demote it.** Use it for:
- Showing permission state (red dot if Accessibility/Mic missing)
- Settings, quit, "launch at login"
- A discoverable surface so users know Majoor is running

The notch panel becomes the **interaction** surface; the menu bar icon stays as the **state and config** surface. Removing the menu bar icon entirely would leave Majoor invisible when idle on the M2 Air (no notch to anchor an idle pill to).

---

## 9. Comparable Products — What to Steal, What to Avoid

| Product | What they do well | What to steal | What NOT to copy |
|---|---|---|---|
| **Raycast AI Commands** | Discoverable command library, fast keyboard-first | Catalog of named commands the user can map to triggers | Their kitchen-sink AI tab — feature creep |
| **ChatGPT macOS app** | "Ask anything" with Cmd+Space-like trigger, beautiful streaming | Streaming text as soon as it arrives; conversation continuity | Their full-screen overlay; over-engineered for voice |
| **Wispr Flow** | Dictation that "knows" what app you're in, low-friction | Per-app context awareness (Phase D, not now) | Their always-listening model — privacy and battery cost |
| **Superwhisper** | High-quality on-device Whisper for dictation | Reliability of push-to-talk dictation flow | On-device Whisper itself for v2 (see §11) |
| **Voiceflow** | Designer-friendly voice flow tooling | Nothing directly — different product category | Treating voice as a graph of intents and slots; Majoor is LLM-routed |
| **BoringNotch / Atoll** | Notch-anchored UI that feels native | Window patterns, hover-to-expand interaction model [11][13][18] | Their "swiss army knife" feature scope (media, calendar, battery, weather) |

### Three design moves Majoor should steal

1. **Streaming feedback during thought.** From ChatGPT and Raycast — show *something* the instant the user finishes speaking. The notch flipping to "thinking" within 50ms is the single biggest perceived-latency win.
2. **Notch-as-state-display.** From BoringNotch/Atoll — your idle, listening, thinking, speaking states should each have a distinctive notch shape. Users learn the vocabulary in one session.
3. **Push-to-talk, not wake-word.** From Superwhisper and Wispr Flow — explicit user action is a feature, not a limitation. It eliminates the "is it listening?" anxiety and the battery drain of always-on audio.

### One or two things to explicitly NOT copy

1. **Don't copy Raycast's "AI as a feature tab" model.** Majoor IS the AI; don't bury it.
2. **Don't copy iOS Dynamic Island's information density.** That UI is glanceable from across the room; Majoor's user is two feet from the screen. Less density, more clarity.

---

## 10. Sequenced Execution Plan

Each phase has a predicted eval delta. Baseline is **13/25 (52%)** — chitchat (5) and factual (4) misroute to `search_web`; `open_url_in_app` (3) cases mispick because the tool doesn't exist.

### Phase A — Loop refactor + few-shots + `open_url_in_app` (THIS WEEK)

Goal: get the eval over 85%. Architecture and prompt fixes only.

1. Add `open_url_in_app(url, app)` tool to `Tools.json` and Swift executor.
2. Switch `tool_choice` from `"required"` to `"auto"`.
3. Implement the agent loop in `Brain.process` per §1, bounded at 3 iterations.
4. Set `strict: true` on every tool.
5. Set `temperature: 0` on the tool-routing call.
6. Replace the current system prompt with the structure in §3, including all 12 worked examples.
7. Add `language: "en"` and Whisper `prompt` biasing per §5.
8. Update `evals/run_eval.py` to assert assistant-text replies for chitchat/factual cases (not just tool calls).

**Predicted eval:** 22–24/25 (88–96%). The 9 chitchat+factual cases now pass (text replies), the 3 `open_url_in_app` cases pass, baseline 13 hold.

**Visible improvement:** Majoor stops Googling thank-yous. Tool-call confirmations are now natural sentences ("Opened Gmail in Safari") because the agent loop feeds the result back.

**Time estimate:** 1–2 evenings.

### Phase B — Notch UI (NEXT WEEK)

Goal: make Majoor feel like a real product. No model changes.

1. Add `DynamicNotchKit` via SPM.
2. Build five SwiftUI views for idle / listening / thinking / speaking / error states (§8).
3. Drive notch state from `AppState` enum — already wired.
4. Add 50ms-after-hotkey-release visible state change (key perceptual-latency win, §4).
5. Pre-warm `/usr/bin/say` as a long-lived `Process` with stdin piping.
6. Stream chat completion; speak text as it arrives (§4).
7. Keep menu bar icon for state + settings; demote its role.
8. Test on M2 Air (no notch) — fallback to floating capsule per §8.

**Predicted eval:** no change (UI work, not routing).

**Visible improvement:** dramatic. Majoor goes from "menu-bar curiosity" to "thing that lives near my notch and responds instantly". This is the phase that makes it feel finished.

**Time estimate:** 1 weekend + 2 evenings of polish.

### Phase C — Memory + STT upgrade (WEEK 3)

Goal: multi-turn understanding, faster STT, persistent preferences.

1. Switch STT to `gpt-4o-mini-transcribe` (§5). Re-run evals to confirm no regression.
2. Add conversation buffer in `AppState` — last 6 turns, sent with every request (§6).
3. Add `~/.majoor/memory.json` schema and loader. Splice into system prompt as `[USER FACTS]`.
4. Update `recent_apps` after each `open_app` call.
5. Add 3–5 new eval cases for multi-turn ("open it again", "use the other browser") to catch regressions.

**Predicted eval:** 23–25/25 with new multi-turn cases included.

**Visible improvement:** "open it again" works. Majoor remembers your default browser. STT is faster.

**Time estimate:** 1 weekend.

### Phase D and beyond — DO NOT SCOPE YET

Wispr-style per-app context, terminal exec, calendar/email, on-device models, wake words. All real, all worth doing eventually. None of them ship until Phases A–C are landed and stable. Resist.

---

## 11. Things I Am NOT Recommending and Why

| Rejected | Why |
|---|---|
| **Wake-word always-listening** | Battery drain, privacy cost, false-positive nightmare. Push-to-talk is a feature. |
| **On-device Whisper (whisper.cpp) for v2** | 200–500MB model in the bundle, multi-second cold start, accuracy regression vs. `gpt-4o-mini-transcribe`. Not worth it until offline mode is a top user request. |
| **OpenAI Realtime API** | Different product shape (full-duplex conversation); rewrites the whole loop; expensive; latency wins don't help push-to-talk. Revisit when Majoor becomes conversational, not before. |
| **Multi-agent orchestration** | OpenAI's own guidance: use multiple agents only when "dealing with many unique flows" [19]. Majoor is one flow. One agent, one loop. |
| **Paid TTS providers (ElevenLabs, Play.ht)** | Hard constraint from the user; also adds latency, monthly cost, and a second vendor lock-in. `/usr/bin/say` works. |
| **A separate router model before the main model** | Doubles latency to save nothing on gpt-4o-mini. The router IS the handler. |
| **`say(text)` as a tool** | Re-introduces the chitchat-misroute bug you just fixed. Speaking is default behavior, not a tool. |
| **Vector embeddings for memory in v1** | Premature. A flat JSON file and a 6-turn buffer cover 95% of real multi-turn needs. |
| **Removing the menu bar icon entirely** | Invisible on no-notch Macs; loses settings surface and permission-state indicator. |

---

## References

[1] OpenAI. *Function calling — tool_choice modes.* https://platform.openai.com/docs/guides/function-calling — "Call zero, one, or multiple functions. tool_choice: 'auto'... Call one or more functions. tool_choice: 'required'... Call exactly one specific function."

[2] OpenAI. *Function calling — five-step loop.* https://platform.openai.com/docs/guides/function-calling — "1. Make a request with available tools 2. Receive a tool call from the model 3. Execute your code using tool call input 4. Send a second request with the tool output 5. Receive a final response (or additional tool calls)."

[3] OpenAI Cookbook. *Orchestrating Agents — explicit tool loop.* https://cookbook.openai.com/examples/orchestrating_agents — call the model → check for tool calls → execute tools → append results → repeat until no tool calls remain.

[4] OpenAI. *Structured Outputs vs JSON mode.* https://platform.openai.com/docs/guides/structured-outputs — "Structured Outputs is the evolution of JSON mode. While both ensure valid JSON is produced, only Structured Outputs ensure schema adherence."

[5] OpenAI. *Structured Outputs — when to use function calling.* https://platform.openai.com/docs/guides/structured-outputs — "If you are connecting the model to tools, functions, data, etc. in your system, then you should use function calling."

[6] OpenAI. *Function calling — strict mode recommendation.* https://platform.openai.com/docs/guides/function-calling — "Setting strict to true will ensure function calls reliably adhere to the function schema, instead of being best effort. We recommend always enabling strict mode."

[7] OpenAI. *Structured Outputs — model support.* https://platform.openai.com/docs/guides/structured-outputs — "Structured Outputs with strict schema validation requires `gpt-4o-mini`, `gpt-4o-mini-2024-07-18`, `gpt-4o-2024-08-06`, and later models."

[8] OpenAI. *Function calling — function count guidance.* https://platform.openai.com/docs/guides/function-calling — "Aim for fewer than 20 functions available at the start of a turn at any one time, though this is just a soft suggestion."

[9] Stivers, T. et al. (2009). *Universals and cultural variation in turn-taking in conversation.* PNAS. doi:10.1073/pnas.0903616106 — Cross-linguistic median inter-turn gaps of 0–300ms, mode ~200ms.

[10] Hamming AI. *Voice AI latency thresholds.* https://hamming.ai/resources/voice-ai-latency-whats-fast-whats-slow-how-to-fix-it — "Under 300ms: Perceived as instantaneous... Over 500ms: Users wonder if they were heard... Over 1000ms: Assumption of connection failure or system breakdown."

[11] TheBoredTeam. *BoringNotchWindow.swift.* https://github.com/TheBoredTeam/boring.notch — `class BoringNotchWindow: NSPanel` with `isFloatingPanel = true`, `level = .mainMenu + 3`, `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]`.

[12] Apple. *NSScreen.auxiliaryTopLeftArea / auxiliaryTopRightArea.* https://developer.apple.com/documentation/AppKit/NSScreen/auxiliaryTopLeftArea-uglc — public APIs for unobscured menu bar regions adjacent to the notch.

[13] Ebullioscopic. *Atoll — Dynamic Island for macOS.* https://github.com/Ebullioscopic/Atoll — uses `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` and `NSPanel` with `.fullScreenAuxiliary` collection behavior. macOS 14.0+, MacBook with notch.

[14] MrKai77. *DynamicNotchKit README.* https://github.com/MrKai77/DynamicNotchKit — "provides a set of tools to help you integrate your macOS app with the new notch on modern MacBooks... handles the complexities of managing the notch area, such as drawing a custom window, ensuring proper content insets and safe areas."

[15] MrKai77. *DynamicNotchKit components.* https://github.com/MrKai77/DynamicNotchKit — "DynamicNotch — a customizable container that accepts any SwiftUI View... DynamicNotchInfo — a specialized component for displaying icon, title, and description information."

[16] jackson-storm. *DynamicNotch — capsule fallback.* https://github.com/jackson-storm/DynamicNotch — "Automatic support for devices without a physical hardware notch... transitions to a floating capsule shape (`DynamicIslandShape`) when `topInset == 0`."

[17] jackson-storm. *DynamicNotch — architecture.* https://github.com/jackson-storm/DynamicNotch — "AppDelegate manages app lifecycle, floating overlay window setup, workspace observers, and lock-screen handoff... built with SwiftUI for notch content and settings UI; AppKit for windows, input handling, and macOS integration."

[18] TheBoredTeam. *BoringNotch project stats.* https://github.com/TheBoredTeam/boring.notch — 9.5k stars, macOS 14+ (Sonoma) minimum, Swift 98.2%, SwiftUI UI framework. Actively maintained.

[19] OpenAI Cookbook. *Orchestrating Agents — when to go multi-agent.* https://cookbook.openai.com/examples/orchestrating_agents — Single agent for focused tasks; multi-agent only "when dealing with many unique flows" where the routine grows too complex.
