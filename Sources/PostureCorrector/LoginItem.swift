import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService for the "Launch at login" toggle.
enum LoginItem {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func set(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Posture Corrector — login item error: \(error.localizedDescription)")
        }
    }
}
