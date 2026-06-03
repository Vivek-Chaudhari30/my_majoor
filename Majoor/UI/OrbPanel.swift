import AppKit
import SwiftUI

final class OrbPanel: NSPanel {
    private static let panelSize = NSSize(width: 220, height: 64)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Floats above normal windows, never steals focus, present on every Space.
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false

        // Transparent so the SwiftUI rounded background shows through.
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        // Pass-through clicks so the orb never blocks the app underneath.
        self.ignoresMouseEvents = true

        let host = NSHostingView(rootView: OrbView().environmentObject(AppState.shared))
        host.frame = NSRect(origin: .zero, size: Self.panelSize)
        self.contentView = host

        positionNearTop()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show() {
        positionNearTop()
        self.orderFrontRegardless()
    }

    func hide() {
        self.orderOut(nil)
    }

    private func positionNearTop() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = self.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 16
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
