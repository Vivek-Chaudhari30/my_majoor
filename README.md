# Majoor

> A voice-first macOS menu-bar assistant. Hold **Ctrl + Option**, speak, get things done.

Majoor lives in your menu bar as a small Dynamic-Island-style pill under the notch. Push-to-talk, then it transcribes what you said, picks the right action (or just talks back), and either opens what you asked for, answers your question, or remembers what you told it.

```
"Open gmail.com in Safari."     → Safari opens Gmail
"What does API stand for?"      → "Application Programming Interface."
"Mute the volume."              → Volume muted
"My name is Vivek."             → Remembered. Survives reboots.
"What's my name?"               → "Vivek."
"Thanks Majoor."                → "Anytime."
```

---

## What's inside

| Layer | Tech | Notes |
|---|---|---|
| **Hotkey** | `CGEventTap` on Ctrl+Option | Modifier-only push-to-talk — reliable, no global shortcut conflicts |
| **STT** | OpenAI `gpt-4o-mini-transcribe` | Whisper prompt biasing for app/brand names, language pinned to `en` |
| **Brain** | OpenAI `gpt-4o-mini`, agent loop | `tool_choice: "auto"`, `strict: true`, `temperature: 0`, bounded at 3 iterations |
| **Tools** | `open_app` · `open_url` · `open_url_in_app` · `search_web` · `system_command` · `remember` | Compound `open_url_in_app` preserves "X in Y" intent. `remember` writes to persistent memory. |
| **TTS** | macOS `/usr/bin/say` | Free, instant, no paid TTS vendor |
| **Memory** | 6-turn in-memory buffer + `~/.majoor/memory.json` | Same-session multi-turn AND across-session user facts |
| **UI** | Native SwiftUI + AppKit, `NSPanel` | Dynamic-Island-style pill flush with menu bar, plus menu-bar status icon |

Everything is grounded in a researched plan: see **[`MASTER_PLAN.md`](MASTER_PLAN.md)** for architecture decisions, latency budget, and what's deliberately NOT built. Quick architecture context in **[`CLAUDE.md`](CLAUDE.md)**.

---

## Install (downloaded release)

1. Grab the latest `Majoor.app.zip` from the **[Releases page](https://github.com/Vivek-Chaudhari30/my_majoor/releases)**.
2. Unzip → drag `Majoor.app` into `/Applications`.
3. **First launch:** Right-click `Majoor.app` → **Open** → confirm in the Gatekeeper dialog. (The app is code-signed under a free Apple Developer ID but not notarized — Gatekeeper warns on first launch but trusts it after one confirmation.)
4. macOS will prompt for **Microphone** and **Accessibility**. Grant both. Quit and relaunch once.
5. Configure your OpenAI key:
   ```bash
   mkdir -p ~/.majoor
   cat > ~/.majoor/config.json <<'EOF'
   { "openai_api_key": "sk-..." }
   EOF
   chmod 600 ~/.majoor/config.json
   ```
6. Hold **Ctrl + Option**, speak, release.

The menu-bar icon also offers **Launch at Login**, so Majoor starts with your Mac.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/Vivek-Chaudhari30/my_majoor.git
cd my_majoor
xcodegen                                  # generates Majoor.xcodeproj
open Majoor.xcodeproj                     # ⌘R in Xcode (sets up signing the first time)
```

After signing with your own personal Apple ID (Xcode → Settings → Accounts → +), set the team in **Signing & Capabilities** for the Majoor target. The first build pops the Mic + Accessibility permission prompts.

---

## Capabilities (v1.0)

- **Chitchat** that doesn't open a Google tab.
  ("Thanks Majoor" → spoken reply, no tab.)
- **Factual answers** from model knowledge, no browser detour.
  ("What does API stand for" → answered aloud.)
- **Compound app+URL commands** with both halves preserved.
  ("Open gmail.com in Safari" → Safari, specifically.)
- **Persistent memory** in `~/.majoor/memory.json`.
  ("Remember I prefer Safari" → recalled forever.)
- **Same-session multi-turn**: a 6-turn ring buffer rides along.
- **System commands**: dark mode toggle, mute/unmute, empty trash, sleep, lock.
- **Dynamic-Island-style pill** anchored flush under the notch.
- **Launch at Login** via `SMAppService.mainApp`.

## Tested limits

- Eval harness (`evals/run_eval.py`, 25 labelled cases): **24/25 (96%)** on `gpt-4o-mini` with `tool_choice="auto"`, `strict: true`. Baseline before refactor was 13/25 (52%). The single residual failure is a tool-choice boundary on "open Gmail" (model picks `open_app`, `AppCatalog` redirects to URL — end behavior is correct).
- Tested on MacBook Air M2 (notched), macOS 14+ (Sonoma+).

## Permissions

- **Microphone** — to record audio while the hotkey is held.
- **Accessibility** — for the `CGEventTap` global hotkey. Without this, Ctrl+Option silently does nothing.

Both are TCC-tracked by code signing identity. Stable personal team → permissions persist across rebuilds.

## Privacy

- Audio is uploaded once to OpenAI's transcription endpoint and not retained on disk after the request.
- Transcripts + chat history are sent to OpenAI for routing. OpenAI's API policy is "do not train on your data by default."
- The persistent memory file `~/.majoor/memory.json` is **owner-only** (`chmod 600`) and never leaves your machine.
- API key lives in `~/.majoor/config.json` (also `0600`), never in source, gitignored.

## Cost

At light personal use (~30 utterances/day): **roughly $0.05–$0.15 per day**. STT is the largest line item. TTS is free (`/usr/bin/say`).

---

## Project structure

```
Majoor/
├── AppDelegate.swift          ← menu bar, hotkey wiring, pipeline orchestration, memory buffer
├── MajoorApp.swift            ← @main entrypoint
├── AI/
│   ├── OpenAIClient.swift     ← transcribe() + agent-loop chat()
│   └── Tools.swift            ← bundle-loaded tool schemas + SystemPrompt loader
├── Audio/
│   └── AudioRecorder.swift    ← AVAudioRecorder with VAD threshold
├── Core/
│   ├── AppState.swift         ← @MainActor observable phase enum
│   ├── Config.swift           ← API key resolution (file → env)
│   ├── Log.swift              ← os.Logger wrapper
│   └── MemoryStore.swift      ← persistent facts (~/.majoor/memory.json)
├── Hotkey/
│   └── HotkeyMonitor.swift    ← CGEventTap (flagsChanged) on Ctrl+Option
├── Resources/
│   ├── SystemPrompt.txt       ← single source of truth: shared with Python eval harness
│   └── Tools.json             ← single source of truth: same
├── Speech/
│   └── Speaker.swift          ← Process wrapper around /usr/bin/say
├── Tools/
│   ├── AppCatalog.swift       ← spoken-name → canonical-app / canonical-URL aliases
│   └── ToolExecutor.swift     ← dispatches each tool to /usr/bin/open or osascript
└── UI/
    ├── OrbPanel.swift         ← borderless non-activating NSPanel, flush with menu bar
    └── OrbView.swift          ← SwiftUI Dynamic-Island pill with state-driven animations

evals/                         ← Python harness (reads SystemPrompt.txt + Tools.json directly)
MASTER_PLAN.md                 ← researched architecture + UX direction
ROADMAP.md                     ← earlier planning doc (superseded by MASTER_PLAN)
CLAUDE.md                      ← quick context for future Claude sessions
project.yml                    ← xcodegen source-of-truth for the .xcodeproj
```

## Future ideas (not in v1)

These are deliberately deferred — see [`MASTER_PLAN.md` §11](MASTER_PLAN.md) for why:

- Wake-word always-listening
- On-device Whisper (`whisper.cpp`)
- OpenAI Realtime API for full-duplex voice
- Multi-agent orchestration
- Paid TTS providers (ElevenLabs etc.)

What might get built later: media controls (play/pause/skip), screenshot + OCR, browser bookmark recall via memory, calendar / email / GitHub integrations.

---

## License

MIT.
