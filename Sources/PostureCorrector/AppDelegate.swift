import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState.shared
    let panel = PanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state.onShowPreviewChange = { [weak self] show in
            guard let self else { return }
            if show { self.panel.show(state: self.state) }
            else    { self.panel.hide() }
        }

        // start() drives the initial panel visibility through onShowPreviewChange,
        // accounting for periodic mode (the panel stays hidden until a check runs).
        state.start()

        // When the user switches to this app after granting camera permission in
        // System Settings, retry starting the session so they don't need to relaunch.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        if state.cameraDenied {
            // Re-check; if the user granted access in Settings, cameraDenied will
            // be updated and the session will start.
            state.retryCamera()
        }
    }
}
