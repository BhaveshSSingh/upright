import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "figure.seated.side")
                    .foregroundStyle(.teal)
                Text("Upright")
                    .font(.headline)
                Spacer()
            }

            if state.cameraDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Camera access is off", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text("Enable the camera for Posture Corrector to detect your posture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 9, height: 9)
                    Text(statusText).font(.subheadline)
                    Spacer()
                }

                Button(action: { state.calibrate() }) {
                    Label(state.baseline == nil ? "Calibrate (sit up straight!)" : "Re-calibrate posture",
                          systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.landmarks == nil || !state.monitoring)

                Toggle("Monitoring", isOn: Binding(
                    get: { state.monitoring },
                    set: { state.setMonitoring($0) }
                ))

                if state.monitoring {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Camera mode")
                            .font(.subheadline)

                        Picker("", selection: Binding(
                            get: { state.periodicMode },
                            set: { state.setPeriodicMode($0) }
                        )) {
                            Text("Always on").tag(false)
                            Text("Periodic").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if state.periodicMode {
                            HStack {
                                Text("Check every")
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { state.checkIntervalMinutes },
                                    set: { state.setCheckIntervalMinutes($0) }
                                )) {
                                    Text("1 min").tag(1.0)
                                    Text("5 min").tag(5.0)
                                    Text("10 min").tag(10.0)
                                    Text("15 min").tag(15.0)
                                    Text("30 min").tag(30.0)
                                }
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                        }
                    }
                }

                if state.periodicMode {
                    Text("The preview opens automatically when a check finds you slouching.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Toggle("Show preview window", isOn: Binding(
                        get: { state.showPreview },
                        set: { state.setShowPreview($0) }
                    ))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sensitivity").font(.subheadline)
                        Spacer()
                        Text(sensitivityLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { state.sensitivity },
                        set: { state.setSensitivity($0) }
                    ), in: 0...1)
                }

                Toggle("Launch at login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { LoginItem.set($0) }
                ))
            }

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power").frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(width: 270)
    }

    private var statusColor: Color {
        if !state.monitoring { return .gray }
        if state.periodicMode {
            if !state.inCheck {
                return .gray
            }
            switch state.status {
            case .good: return .green
            case .slouching: return .orange
            case .noFace, .uncalibrated: return .teal
            }
        }
        switch state.status {
        case .good: return .green
        case .slouching: return .orange
        case .noFace: return .gray
        case .uncalibrated: return .yellow
        }
    }

    private var statusText: String {
        if !state.monitoring { return "Paused" }
        if state.periodicMode {
            if !state.inCheck {
                return state.nextCheckCountdown.isEmpty ? "Periodic mode" : "Next check in \(state.nextCheckCountdown)"
            }
            switch state.status {
            case .good: return "Looking good ✓"
            case .slouching: return "Sit up straight!"
            case .noFace, .uncalibrated: return "Warming up…"
            }
        }
        switch state.status {
        case .good: return "Looking good ✓"
        case .slouching: return "Slouching — look up a bit"
        case .noFace: return "No face detected"
        case .uncalibrated: return "Not calibrated yet"
        }
    }

    private var sensitivityLabel: String {
        switch state.sensitivity {
        case ..<0.34: return "Relaxed"
        case ..<0.67: return "Medium"
        default: return "Strict"
        }
    }
}
