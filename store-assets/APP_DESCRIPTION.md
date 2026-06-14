# App Store Connect — Majoor

---

## App Name

Majoor

---

## Subtitle

_(30 characters max — current: 26)_

Voice commands, hands-free

---

## Promotional Text

_(170 characters max — current: 155. Updated any time without a new build review.)_

Majoor puts a Dynamic Island-style pill in your menu bar. Hold Ctrl+Option, speak naturally, and let OpenAI handle the rest — all without touching your keyboard.

---

## Description

_(4000 characters max, plain text only — no HTML.)_

Majoor gives your Mac a voice. Hold Ctrl+Option, say what you need, and let go. That's it.

Whether you want to open an app, look something up, control system settings, or just ask a question, Majoor hears you, thinks, and acts — without you ever leaving whatever you were doing.

**What Majoor does**

A compact pill lives flush with your menu bar, echoing the look of the Dynamic Island. When you hold the hotkey it lights up in listening state, pulsing as it captures your voice. Release the key and the orb shifts to its thinking state while Majoor processes your request. Seconds later you hear the answer spoken aloud and, if an action was triggered, the result appears on screen.

**Key features**

Push-to-talk hotkey (Ctrl+Option) — works globally, no matter which app is in front. The moment you release the keys, recording stops and processing begins.

Voice recognition powered by OpenAI Whisper — accurate, fast transcription that handles natural speech, accents, and technical terms.

Smart intent routing — Majoor understands what you want and routes it to the right handler: launch apps, open URLs, speak answers, or save things to memory.

Spoken responses via macOS text-to-speech — answers come back as natural voice using the system TTS engine, so you never have to look at a screen.

Persistent memory — tell Majoor something once and it remembers it for future sessions.

**What you can say**

Open apps: "Open Gmail", "Launch Spotify", "Switch to Finder"
Ask questions: "What is an API?", "How many feet in a mile?", "What's the capital of Japan?"
Save memory: "Remember my name is Vivek", "Remember my meeting is at 3 pm"
Control your Mac: "Mute the volume", "Turn up brightness", "Lock the screen"
Open websites: "Open YouTube", "Go to my GitHub"

**How it works**

1. You hold Ctrl+Option — Majoor starts recording through your microphone.
2. You release — the audio is sent to OpenAI Whisper for transcription.
3. The transcript is passed to GPT-4o-mini, which classifies your intent and composes a response or action.
4. If an app or URL needs to open, Majoor does it. If an answer needs to be spoken, macOS say delivers it.

The entire round trip typically completes in two to three seconds on a standard broadband connection.

**Privacy**

Majoor never records passively. Audio is captured only while you hold the hotkey and is discarded immediately after transcription. Nothing is stored on any server. Your OpenAI API key lives on your device in the macOS Keychain and is never transmitted anywhere except directly to OpenAI's API. No analytics, no telemetry, no third-party SDKs.

**System requirements**

- macOS 14.0 Sonoma or later
- An OpenAI API key (platform.openai.com — pay-as-you-go, typical usage costs pennies per day)

**Getting started**

1. Launch Majoor. On first run, a setup sheet asks for your OpenAI API key — paste it in and click Save.
2. Grant Microphone access when macOS prompts you (required for voice capture).
3. Grant Accessibility access in System Settings › Privacy & Security › Accessibility (required for the global hotkey).
4. Hold Ctrl+Option and start talking. Release to send.

The pill in your menu bar confirms the current state: idle, listening, or thinking. You can quit Majoor at any time from the menu-bar icon; it uses no resources when idle.

---

## Keywords

_(100 characters max, comma-separated — current: 99)_

voice assistant,productivity,AI,menu bar,push to talk,hands free,OpenAI,GPT,automation,Siri alternative

---

## Support URL

https://github.com/Vivek-Chaudhari30/my_majoor

---

## Marketing URL

https://majoor.vercel.app
