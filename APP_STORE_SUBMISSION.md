# Majoor — Mac App Store Submission Guide

This is the complete end-to-end workflow for publishing Majoor to the Mac App Store.
Read every section before starting — the sandbox rework in Step 2 is the hardest part
and must be done before anything else.

---

## Prerequisites

- Apple Developer Program membership ($99/yr): https://developer.apple.com/programs/
- Xcode 15+ installed (free from the Mac App Store)
- The `make` targets in this repo (`make build-appstore`, `make upload`) require
  Xcode command-line tools: `xcode-select --install`
- OpenAI API key in `~/.majoor/config.json` (already your setup; no change needed for testing)

---

## Step 1 — App Store Connect Setup

### 1.1 Create the App Record

1. Go to https://appstoreconnect.apple.com → My Apps → **+** → New Mac App.
2. Set:
   - **Bundle ID**: `com.majoor.app` (must match `project.yml`)
   - **SKU**: `majoor-mac-001` (internal tracking string, any unique value)
   - **App Name**: `Majoor`
3. Select **macOS** platform. Click Create.

### 1.2 App Information tab

Fill these fields before submitting for review:

| Field | Value |
|---|---|
| Category | **Productivity** (primary), **Utilities** (secondary) |
| Content Rights | Check "This app does not contain, show, or access third-party content" |
| Age Rating | Complete the questionnaire (no violence/adult content → 4+) |
| Privacy Policy URL | `https://majoor.vercel.app/privacy` |

### 1.3 Pricing & Availability

- Set **Free** (or your chosen price tier)
- Territories: All territories, or restrict to start

---

## Step 2 — Sandbox Rework (Critical — Must Do First)

The Mac App Store **requires** `com.apple.security.app-sandbox = true`. Majoor currently
runs with sandbox disabled because it calls `/usr/bin/open`, `/usr/bin/say`, and uses
`CGEventTap` (which requires the Accessibility entitlement).

This is the largest engineering task. Budget 1–2 days.

### 2.1 What breaks without sandbox rework

| Feature | Why it breaks in sandbox |
|---|---|
| `CGEventTap` for hotkey | Requires Accessibility entitlement (`com.apple.security.temporary-exception.accessibility`) — Apple rarely grants this for MAS apps. See §2.4 for alternatives. |
| `Process("/usr/bin/open")` | Allowed in sandbox via `com.apple.security.files.user-selected.read-only` but `open` itself is fine; `osascript` is NOT allowed. |
| `/usr/bin/say` via `Process` | Allowed — `/usr/bin/say` is a system binary, `Process` can call it from sandbox. |
| `~/.majoor/config.json` reading | Requires `com.apple.security.files.bookmarks.app-scope` or migrate to `NSUserDefaults`/Keychain. |
| `~/.majoor/memory.json` writing | Same — must migrate to App Group container or `NSApplicationSupportDirectory`. |

### 2.2 Migration plan for each blocker

**Config & memory files**

Replace `~/.majoor/` path construction in `Core/Config.swift` and `Core/MemoryStore.swift`
with `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`.
The data moves to `~/Library/Application Support/Majoor/`. Existing users lose saved
memory on upgrade — add a one-time migration that copies the old path if it exists.

```swift
// Before (in Config.swift)
let configURL = URL(fileURLWithPath: "\(NSHomeDirectory())/.majoor/config.json")

// After
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
let majoorDir  = appSupport.appendingPathComponent("Majoor", isDirectory: true)
let configURL  = majoorDir.appendingPathComponent("config.json")
```

**OpenAI API key in Keychain (recommended over config file for MAS)**

Store the API key in `SecItemAdd` / `SecItemCopyMatching` (Keychain). The first time the
app launches without a key, show a settings window prompting the user to paste it. This
is more MAS-idiomatic than a config file.

**CGEventTap → Accessibility entitlement or alternative**

Option A (preferred for MAS): Replace `CGEventTap` with `NSEvent.addGlobalMonitorForEvents`
plus the Accessibility entitlement `com.apple.security.temporary-exception.accessibility`.
Apple allows this entitlement for assistive tools but reviews it closely — include a clear
justification in your App Review notes.

Option B: Use a registered `NSMenuItem` keyboard shortcut via `NSApplication.keyEquivalent`
— no Accessibility permission needed, but loses the "hold modifier key" feel. Majoor
becomes "press hotkey" rather than "hold to talk".

Option C (push-to-talk preserved without CGEventTap): Use `Carbon`'s `RegisterEventHotKey`
API — sandboxed apps can use it without Accessibility permission for registered hotkeys.
The trade-off is it intercepts at the Carbon layer, not as low as CGEventTap.

**Recommended approach**: Go with Option A + Accessibility entitlement and document clearly
in the App Review notes why the app needs it (voice assistant that works from any app).

### 2.3 Updated entitlements for App Store (see `Majoor/Majoor-AppStore.entitlements`)

The file `Majoor/Majoor-AppStore.entitlements` (already created in this PR) contains
the sandbox-enabled entitlements needed for MAS submission. See Step 3 for details.

### 2.4 Code changes checklist before MAS submission

- [ ] `Core/Config.swift` — migrate file path to `applicationSupportDirectory`
- [ ] `Core/MemoryStore.swift` — migrate file path to `applicationSupportDirectory`
- [ ] `HotkeyMonitor.swift` — switch from `CGEventTap` to `RegisterEventHotKey` or
      `NSEvent.addGlobalMonitorForEvents` with Accessibility entitlement
- [ ] `ToolExecutor.swift` — audit all `Process` calls; remove any `osascript` usage
      or replace with direct AppleEvent / ScriptingBridge calls (allowed in sandbox
      with `com.apple.security.scripting-targets` entitlement per-app)
- [ ] Add one-time migration: if `~/.majoor/config.json` exists, copy to new location
- [ ] Add Keychain wrapper for API key storage (optional but strongly recommended)

---

## Step 3 — Provisioning Profiles for App Store

### 3.1 In Xcode (Automatic Signing)

Xcode's automatic signing handles this for most cases:

1. Open Majoor.xcodeproj → Target: Majoor → Signing & Capabilities
2. Set **Team** to your paid Developer Program team (27WFRH77ZP or your paid team)
3. Set **Signing**: Automatic
4. For the App Store build: set **Provisioning Profile** to "Mac App Store" (Xcode creates it automatically when you archive for distribution)

### 3.2 Manual provisioning (if needed)

1. Go to https://developer.apple.com/account/resources/profiles/list
2. Create a new **Mac App Store** distribution profile for bundle ID `com.majoor.app`
3. Download and double-click to install
4. In Xcode: Signing → Manual → select the downloaded profile

### 3.3 Two separate signing identities

| Build type | Code Sign Identity | Entitlements file |
|---|---|---|
| Development / direct | `Apple Development` | `Majoor/Majoor.entitlements` |
| App Store submission | `Apple Distribution` | `Majoor/Majoor-AppStore.entitlements` |

The `project.yml` `appstore` build configuration (added in this PR) sets the correct
identity and entitlements automatically — run `make build-appstore` to use it.

---

## Step 4 — Store Assets

All assets live in `store-assets/`. The specs below match App Store Connect requirements.

### 4.1 App Icon — 1024×1024px

File: `store-assets/icon-1024.png`
- PNG, no alpha (App Store Connect strips alpha; flat background required)
- The existing `AppIcon.appiconset` contains smaller sizes; generate 1024px from the same
  source and place it in `store-assets/icon-1024.png`

To generate from the existing Figma/design assets:
```bash
# If you have a 1024px source SVG or PDF:
sips -s format png source-icon.svg --out store-assets/icon-1024.png
sips -Z 1024 store-assets/icon-1024.png  # resize to exactly 1024
```

### 4.2 Screenshots

App Store Connect requires **at least one screenshot** per Mac size class:

| Size | Required? | Notes |
|---|---|---|
| 1280×800 (13" MacBook) | Yes | Most common; Apple shows this first |
| 1440×900 (MacBook Air M2) | Recommended | |
| 2560×1600 (16" MacBook Pro) | Recommended | Retina; shown on large-screen searches |

Take screenshots while the orb is in its "thinking" or "listening" state — these convey
what the app does at a glance. Show at least one with a spoken command and the orb visible.

Capture with Xcode Simulator or directly on device:
```bash
screencapture -x store-assets/screenshot-1280x800.png   # full screen, no shadow
```

See `store-assets/SCREENSHOT_GUIDE.md` for framing and copy guidelines.

### 4.3 App Description

See `store-assets/APP_DESCRIPTION.md` for the full short + long description and
promotional text to paste into App Store Connect.

### 4.4 Keywords

See `store-assets/APP_DESCRIPTION.md` — keywords are included in that file.
100-character limit, comma-separated.

### 4.5 Privacy Policy

Privacy policy page lives at `https://majoor.vercel.app/privacy` (see `site/app/privacy/page.tsx`).
This URL must be filled in App Store Connect before submitting.

---

## Step 5 — Build for App Store

Once the sandbox rework (Step 2) is done:

```bash
# Install xcodegen if needed
brew install xcodegen

# Regenerate project with App Store configuration
xcodegen

# Archive for App Store (runs clean build automatically)
make build-appstore
```

The `make build-appstore` target (in `Makefile`) runs:
```bash
xcodebuild archive \
  -project Majoor.xcodeproj \
  -scheme Majoor \
  -configuration AppStore \
  -archivePath build/Majoor.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  CODE_SIGN_STYLE=Automatic
```

Verify the archive before uploading:
```bash
# Check the archive was created
ls -la build/Majoor.xcarchive

# Validate entitlements in the built binary
codesign -d --entitlements :- build/Majoor.xcarchive/Products/Applications/Majoor.app
```

Confirm the output shows `com.apple.security.app-sandbox = true`.

---

## Step 6 — Local Test Before Upload

**Important**: The sandboxed App Store build behaves differently from the dev build.
Test these scenarios before uploading:

1. Fresh launch with no config file → should prompt for API key (not crash)
2. Hold hotkey → orb appears and recording starts
3. Speak a command → transcribes, brain responds, TTS plays
4. Speak "remember my name is Vivek" → saves to `~/Library/Application Support/Majoor/memory.json`
5. Quit and relaunch → memory persists
6. `open_app(Safari)` → Safari opens
7. `open_url(https://example.com)` → browser opens URL
8. `search_web(swift tips)` → browser opens Google search
9. `system_command(mute)` → audio muted

Run the eval harness too (it uses a mock, so it works even without sandbox):
```bash
cd evals && python3 run_eval.py
```
Target score: 24/25 or better before submitting.

---

## Step 7 — Upload to App Store Connect

### Option A: Xcode Organizer (Recommended for first submission)

1. In Xcode: **Product → Archive** (ensure Scheme is set to Majoor, destination is "Any Mac")
2. Xcode Organizer opens automatically showing the archive
3. Click **Distribute App**
4. Select **App Store Connect** → **Upload**
5. Follow the wizard — Xcode handles signing, entitlement verification, and upload
6. Wait for the "Upload Successful" confirmation (usually < 2 minutes)

### Option B: Command-line via `make upload`

```bash
make upload
```

This runs `xcrun altool --upload-app` (or `xcrun notarytool` for notarization if you
want to notarize before MAS submission — MAS does its own notarization, so this is
optional for the store flow).

### After upload

App Store Connect takes 10–30 minutes to process the build. You will get an email.
Once processed, the build appears in **TestFlight** or **App Store** depending on
what you chose in the upload wizard.

---

## Step 8 — Fill Out Review Metadata and Submit

### 8.1 Review Information

In App Store Connect → Version → App Review Information:

| Field | What to enter |
|---|---|
| Sign-in required | No |
| Attachment | A 30-second screen recording of the app working (optional but helps reviewers) |
| Notes for Review | "This is a voice-activated macOS assistant that uses Ctrl+Option as a push-to-talk hotkey. It requires Microphone permission (captured by AVAudioEngine) and Accessibility permission (for the global hotkey). The Accessibility permission is used solely to detect modifier key presses (CGEventTap on flagsChanged) — no screen content is read, no input is injected. The app makes outbound API calls to OpenAI only (user supplies their own API key)." |

### 8.2 Version Information

| Field | Value |
|---|---|
| Version number | `1.0.0` |
| What's New (release notes) | See `store-assets/RELEASE_NOTES.md` |

### 8.3 Rating

Complete the content rating questionnaire:
- No objectionable content
- No cartoon/realistic violence
- No profanity
- No gambling/contests
- Result: **4+**

### 8.4 Export Compliance

Majoor uses standard HTTPS (TLS) for OpenAI API calls. Under US export compliance:
- Check "No" for proprietary encryption algorithm
- Check "Yes" for standard encryption (TLS/SSL)
- Exemption: "Encryption is integral to the product and is exempt under EAR §742.15"

### 8.5 Submit for Review

1. All red badges in App Store Connect must be resolved
2. At least one screenshot uploaded per required size
3. Privacy policy URL filled in
4. Click **Submit for Review**

Apple's typical review time for new Mac apps: **1–3 business days**.

---

## Common Rejection Reasons (and How to Avoid Them)

**2.1 — App Completeness**: App crashes or has obvious bugs. Run the full test suite (Step 6) first.

**2.5.1 — Software Requirements**: App requires sandbox. Ensure Step 2 is complete.

**5.1.1 — Privacy**: App accesses microphone without proper disclosure. The `NSMicrophoneUsageDescription` in Info.plist covers this, but also add a clear explanation in the privacy policy.

**5.1.2 — Data Use**: OpenAI processes the audio. Disclose this in the privacy policy and App Store listing.

**4.1 — Design**: App must adhere to macOS HIG. The orb panel approach is non-standard but has precedent (Raycast, Alfred). Include a clear explanation of the interaction model.

**3.1.1 — In-App Purchase**: If you plan a freemium model, all paid features must use StoreKit. If the app is free + BYOK, this doesn't apply.

---

## Timeline Estimate

| Task | Effort |
|---|---|
| App Store Connect setup (Steps 1, 3.1–3.3, 8) | 2–3 hours |
| Sandbox rework + code migration (Step 2) | 1–2 days |
| Store asset creation (Step 4) | 2–4 hours |
| Build + local test (Steps 5–6) | 1–2 hours |
| Upload + metadata fill (Steps 7–8) | 1 hour |
| Apple review | 1–3 business days |

**Total before review: ~2 full days of work** (dominated by the sandbox rework).

---

## Files Created in This PR

- `APP_STORE_SUBMISSION.md` — this guide
- `Majoor/Majoor-AppStore.entitlements` — sandbox-on entitlements for MAS build
- `Makefile` — `build-appstore` and `upload` targets
- `store-assets/APP_DESCRIPTION.md` — app name, subtitle, description, keywords
- `store-assets/SCREENSHOT_GUIDE.md` — screenshot framing instructions
- `store-assets/RELEASE_NOTES.md` — v1.0.0 release notes
- `site/app/privacy/page.tsx` — privacy policy page (deployed to majoor.vercel.app/privacy)
