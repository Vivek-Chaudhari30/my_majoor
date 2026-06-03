# Majoor — Context for Claude

Voice-first macOS menu-bar assistant. Loop:

    Hold Ctrl+Option → record audio → Whisper (STT) → gpt-4o-mini tool call → execute (open app / URL) → say reply → idle

## Stack

- Swift + SwiftUI + AppKit, macOS 14+
- Menu-bar app via `NSStatusItem`. `LSUIElement = YES`, no dock icon.
- xcodegen-managed Xcode project. `project.yml` is the source of truth — never hand-edit `Majoor.xcodeproj`. Re-run `xcodegen` after structural changes.
- OpenAI: Whisper (`/v1/audio/transcriptions`) + `gpt-4o-mini` (`/v1/chat/completions`). NO other paid services.
- TTS: `/usr/bin/say` via `Process` for v1. Single swappable function in `Speech/Speaker.swift`.

## Architecture

```
HotkeyMonitor (CGEventTap, Ctrl+Option)
  → AudioRecorder (AVAudioEngine → temp .wav)
  → OpenAIClient.transcribe
  → Brain.process (chat + tools)
  → ToolExecutor (Process: /usr/bin/open ...)
  → Speaker.speak
  → AppState.idle
```

`AppState` is an `ObservableObject` enum: `idle / listening / transcribing / thinking / executing / speaking`. The orb UI binds to it.

## Tools (v1 only)

- `open_app(app_name: String)`
- `open_url(url: String)`
- `search_web(query: String)` → `https://www.google.com/search?q=...`

Common spoken-name aliases (gmail, vs code, linkedin, …) live in `Tools/AppCatalog.swift`.

## API key

Read at launch by `Core/Config.swift`:

1. `~/.majoor/config.json` → `{ "openai_api_key": "sk-..." }`
2. fallback: `OPENAI_API_KEY` env var

Never hardcode. The config file and `.env*` are gitignored.

## Permissions (must be granted before things work)

- Microphone — `NSMicrophoneUsageDescription` in `Info.plist`.
- Accessibility — required for `CGEventTap`. **Until granted, the hotkey silently fails.** Re-grant after every clean build because the codesigned identity changes.

App is **not** sandboxed in v1 so `Process` can run `/usr/bin/open` and `/usr/bin/say`. Entitlements: `com.apple.security.app-sandbox = false`.

## CGEvent tap, not AppKit global monitor

Modifier-only shortcuts (Ctrl+Option alone with no letter key) are detected reliably with `CGEvent.tapCreate` listening for `flagsChanged`. AppKit's `NSEvent.addGlobalMonitorForEvents(.flagsChanged)` works but is flakier and requires the same Accessibility permission.

## Floating orb

`UI/OrbPanel.swift` is a borderless, non-activating `NSPanel` (`.nonactivatingPanel` style mask, `level = .floating`, `hidesOnDeactivate = false`, `canHide = false`). Hosts `OrbView` (SwiftUI). Show on listening, hide on idle.

## Failure modes — always return to idle

- No speech → say "I didn't catch that"
- Whisper empty/error → say "Couldn't hear you"
- OpenAI error/timeout → say "Something went wrong"
- Unknown app → say "I don't know that app"

Never crash on the unhappy path. Log via `Core/Logger.swift`.

## Build flow

```
brew install xcodegen
xcodegen
open Majoor.xcodeproj
# ⌘R
```

## Future (NOT v1)

Screenshots, screen reading, mouse control, calendar, email, Slack, GitHub, terminal exec, file ops, workflows, local SQLite memory, OpenAI TTS, Cloudflare Worker proxy.
