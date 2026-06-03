# Majoor

Voice-first macOS menu-bar assistant. Hold **Ctrl + Option**, speak, and Majoor opens the app or URL you asked for and speaks a short confirmation.

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode 15+
- [Homebrew](https://brew.sh) + `xcodegen` (`brew install xcodegen`)
- An OpenAI API key with available credit

## Build & run

```bash
# from the repo root
brew install xcodegen      # one time
xcodegen                   # generates Majoor.xcodeproj from project.yml
open Majoor.xcodeproj      # then press ⌘R in Xcode
```

You should see a small waveform icon appear in the macOS menu bar. Click it to see the quick menu (and Quit).

## Configure your API key

Majoor reads `OPENAI_API_KEY` from `~/.majoor/config.json`:

```bash
mkdir -p ~/.majoor
cat > ~/.majoor/config.json <<'EOF'
{ "openai_api_key": "sk-..." }
EOF
chmod 600 ~/.majoor/config.json
```

A `OPENAI_API_KEY` environment variable in the Xcode scheme is honored as a fallback.

## Permissions

On first run, macOS will ask for two permissions. Grant both in **System Settings → Privacy & Security**:

1. **Microphone** — so Majoor can record while you hold the hotkey.
2. **Accessibility** — so Majoor can detect the global Ctrl+Option hotkey via `CGEventTap`. Until this is granted, the hotkey will silently not fire.

After granting Accessibility, you may need to quit and relaunch Majoor.

## Using Majoor

1. Hold **Ctrl + Option**.
2. The orb appears — speak your command.
   - "Open Safari"
   - "Open Gmail"
   - "Search for the weather in Boston"
3. Release the keys. Majoor transcribes → decides → opens → speaks back.

## v1 scope (intentionally tiny)

- Two tool categories: app control (`open_app`) and browser/URL (`open_url`, `search_web`).
- No screen reading, no mouse control, no calendar/email/Slack/GitHub, no terminal execution, no file ops, no local memory.

## Future ideas

- OpenAI TTS instead of `say`
- Cloudflare Worker proxy for the API key
- Screen-aware mode, mouse control, more tools
- App catalog auto-discovery from `/Applications`
