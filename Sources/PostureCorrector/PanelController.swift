import AppKit
import SwiftUI

/// Manages the borderless, always-on-top, transparent floating panel that hosts
/// the PiP preview. Lives in the bottom-right corner and can be dragged anywhere.
@MainActor
final class PanelController {
    private var panel: NSPanel?

    func show(state: AppState) {
        if panel == nil {
            let hosting = NSHostingView(rootView: PiPView(state: state))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 200),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true // let the close button take clicks without stealing focus
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.contentView = hosting

            if let screen = NSScreen.main {
                let vf = screen.visibleFrame
                let margin: CGFloat = 20
                panel.setFrameOrigin(NSPoint(
                    x: vf.maxX - panel.frame.width - margin,
                    y: vf.minY + margin
                ))
            }
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
