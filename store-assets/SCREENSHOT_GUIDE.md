# App Store Screenshot Guide — Majoor

This document covers the screenshots required for Mac App Store submission, what to show in each one, how to capture them, and suggested caption overlays.

---

## Required Sizes

Apple requires at least one screenshot for each display class you target. For a macOS app the mandatory sizes are:

| Class | Pixel dimensions | Notes |
|---|---|---|
| MacBook (non-Retina) | 1280 × 800 | Required |
| MacBook (Retina 1x) | 1440 × 900 | Required |
| iMac / Pro Display | 2560 × 1600 | Required |

Submit the same three compositions at each size. PNG format, RGB color space, no alpha channel.

---

## What to Show in Each Screenshot

### Screenshot 1 — Listening State

Show Majoor mid-capture: the orb pill is glowing in its listening color (e.g. blue/cyan pulse), and the spoken words "Open Gmail" (or similar) appear as live transcript text beneath or beside the pill. The menu bar should be visible at the top of the screen with the pill sitting flush against the notch area on a MacBook or flush with the right side of the menu bar on non-notch models. The rest of the desktop should be clean — a minimal wallpaper, no distracting windows.

Goal: communicate instantly that Majoor listens to you.

Suggested caption overlay: "Hold Ctrl+Option and speak"

### Screenshot 2 — Thinking State

Show the orb pill in its processing / thinking animation (e.g. amber/white spinner or morphing shape). The transcript of the recognized phrase should still be readable (e.g. "Open Gmail"). Ideally show a subtle waveform or animated ring to convey activity. The rest of the screen remains clean.

Goal: show that the app is doing something smart between voice capture and result.

Suggested caption overlay: "Majoor thinks, so you don't have to"

### Screenshot 3 — Result

Show the outcome of the command. Two good options:
- App launched: Gmail (or another recognizable app) is now in the foreground, and the Majoor pill has returned to its idle/calm state in the menu bar. A small toast or label near the pill reading "Opened Gmail" reinforces what just happened.
- Answer spoken: a macOS speech bubble or subtitle overlay shows the GPT answer text (e.g. "An API is a set of rules that lets software talk to other software.") while the pill glows in its response color.

Goal: close the loop — the user spoke, and something real happened.

Suggested caption overlay: "Results delivered in seconds"

---

## How to Capture Screenshots on macOS

### Full-screen capture at exact resolution

The easiest method is the `screencapture` command-line tool, which captures without the macOS screenshot UI chrome:

```
screencapture -x ~/Desktop/majoor-screenshot-1.png
```

The `-x` flag suppresses the shutter sound.

To capture a specific window by window ID (useful for cropping to just the Majoor overlay):

```
screencapture -l <window_id> ~/Desktop/majoor-window.png
```

Get the window ID with `osascript` or the Accessibility Inspector.

### Matching the required pixel dimensions

On a Retina (HiDPI) display, macOS captures at 2× by default, so a 1440 × 900 logical screen produces a 2880 × 1800 PNG. Downscale with `sips`:

```
sips -z 900 1440 ~/Desktop/raw-screenshot.png --out ~/Desktop/majoor-1440x900.png
```

For the 2560 × 1600 size, set your display to a scaled resolution that yields that logical size, or capture at full Retina and resize:

```
sips -z 1600 2560 ~/Desktop/raw-screenshot.png --out ~/Desktop/majoor-2560x1600.png
```

For the 1280 × 800 size:

```
sips -z 800 1280 ~/Desktop/raw-screenshot.png --out ~/Desktop/majoor-1280x800.png
```

### Notch / pill visibility note

On MacBook Pro models with a notch, stage the orb so that its pill sits in the menu bar to the left of the notch (or centered on a non-notch model). Make sure the menu-bar pill is fully visible and not clipped. Increase the menu-bar height in the screenshot composition if necessary, or add a few pixels of padding above the pill in post so Apple's review grid does not clip it.

---

## Adding Caption Overlays

After capture, add the suggested caption text using any of the following:

- Sketch or Figma: place text in the Majoor brand font over the screenshot artboard at the target size.
- Preview (built-in): Tools › Annotate › Text to add a text annotation, then export flat.
- Command-line with ImageMagick:

```
magick majoor-1440x900.png \
  -gravity South \
  -pointsize 48 \
  -fill white \
  -annotate +0+60 "Hold Ctrl+Option and speak" \
  majoor-1440x900-captioned.png
```

Adjust `-pointsize`, color, and offset to match your brand style.

---

## Submission Checklist

Before uploading to App Store Connect:

- All three sizes present for each of the three screenshots (9 files total minimum).
- No alpha/transparency channel (flatten before export).
- No rounded corners applied by you — App Store Connect adds them.
- Caption text is legible at thumbnail size (App Store browse view shows images small).
- Menu-bar pill is visible and not clipped in any size variant.
- No placeholder text or developer watermarks.
