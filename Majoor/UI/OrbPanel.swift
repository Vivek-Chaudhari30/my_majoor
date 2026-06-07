import AppKit
import SwiftUI

/// Borderless, non-activating panel that hosts the SwiftUI notch pill.
/// Positioned flush with the menu bar bottom at top-center, so on a notched
/// MacBook the pill visually extends from the notch (Dynamic-Island style).
final class OrbPanel: NSPanel {
    /// The panel itself is the LARGEST possible bounding box; the SwiftUI
    /// content draws a smaller pill inside it and animates its own size.
    /// Panel size doesn't change — content size does. Simpler & avoids
    /// the NSWindow-resize jank.
    private static let panelSize = NSSize(width: 360, height: 60)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false

        // Transparent so the SwiftUI rounded pill is the only visible shape.
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        // Pass-through clicks — the pill never blocks the app below.
        self.ignoresMouseEvents = true

        let host = NSHostingView(rootView: OrbView().environmentObject(AppState.shared))
        host.frame = NSRect(origin: .zero, size: Self.panelSize)
        self.contentView = host

        positionFlushWithMenuBar()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show() {
        positionFlushWithMenuBar()
        self.orderFrontRegardless()
    }

    func hide() {
        self.orderOut(nil)
    }

    /// Anchor to the top-center of the screen, immediately below the menu bar.
    /// On notched Macs the pill extends visually from the notch.
    private func positionFlushWithMenuBar() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = self.frame.size
        let x = visible.midX - size.width / 2
        // Bottom edge sits `size.height` below the menu bar's bottom — i.e.
        // the panel hangs DOWN from the menu bar with its top flush against it.
        let y = visible.maxY - size.height
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
