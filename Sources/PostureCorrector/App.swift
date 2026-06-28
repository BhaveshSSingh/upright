import SwiftUI

@main
struct PostureCorrectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: AppState.shared)
        } label: {
            // MenuBarLabel is a proper View with @ObservedObject so SwiftUI
            // reliably re-evaluates the label whenever status/monitoring change.
            MenuBarLabel(state: AppState.shared)
        }
        .menuBarExtraStyle(.window)
    }
}

/// A dedicated View for the menu-bar icon so @ObservedObject updates reliably propagate
/// to the label — a computed property in App.body does not reliably trigger MenuBarExtra
/// label re-renders in all macOS versions.
struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    var body: some View {
        Image(systemName: symbolName)
    }

    private var symbolName: String {
        if !state.monitoring { return "pause.circle" }
        switch state.status {
        case .slouching: return "exclamationmark.triangle.fill"
        case .noFace:    return "questionmark.circle"
        default:         return "figure.seated.side"
        }
    }
}
