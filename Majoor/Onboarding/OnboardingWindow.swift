import AppKit
import SwiftUI

/// Titled NSWindow that hosts the SwiftUI OnboardingView.
/// AppDelegate switches activation policy to .regular while this window is up,
/// then back to .accessory when it closes.
final class OnboardingWindow: NSWindow, NSWindowDelegate {
    private var onClose: (() -> Void)?

    init(onFinish: @escaping () -> Void, onAPIKeySaved: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        let contentSize = NSSize(width: 520, height: 480)
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.title = "Majoor"
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.center()
        self.onClose = onClose
        self.delegate = self

        let root = OnboardingView(onFinish: onFinish, onAPIKeySaved: onAPIKeySaved)
            .environmentObject(OnboardingState.shared)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: contentSize)
        self.contentView = host
    }

    func present() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
