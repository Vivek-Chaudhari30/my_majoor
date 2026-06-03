import AppKit
import CoreGraphics

final class HotkeyMonitor {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false

    func start() {
        guard ensureAccessibilityPermission() else {
            Log.warn("Accessibility not granted. Hotkey will not fire. Enable Majoor in System Settings → Privacy & Security → Accessibility, then quit and relaunch.")
            return
        }

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: opaqueSelf
        ) else {
            Log.error("Failed to create CGEvent tap. Accessibility permission likely missing.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        Log.info("HotkeyMonitor started. Hold Ctrl+Option to trigger.")
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS may disable a tap that takes too long; just re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard type == .flagsChanged else { return }

        let flags = event.flags
        let hasBoth = flags.contains(.maskControl) && flags.contains(.maskAlternate)

        if hasBoth && !isHeld {
            isHeld = true
            DispatchQueue.main.async { [weak self] in self?.onPressed?() }
        } else if !hasBoth && isHeld {
            isHeld = false
            DispatchQueue.main.async { [weak self] in self?.onReleased?() }
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
}
