import SwiftUI
import CoreVideo
import CoreGraphics

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var latestImage: CGImage?
    @Published var landmarks: FaceMetrics?
    @Published var status: PostureStatus = .uncalibrated
    @Published var monitoring: Bool = true
    @Published var showPreview: Bool = true
    @Published var sensitivity: Double = 0.5
    @Published var baseline: Baseline?
    @Published var cameraDenied: Bool = false

    @Published var periodicMode: Bool = false
    @Published var checkIntervalMinutes: Double = 5.0
    @Published var inCheck: Bool = false
    @Published var nextCheckCountdown: String = ""

    nonisolated let camera   = CameraManager()
    nonisolated let detector = FaceDetector()
    nonisolated let analyzer = PostureAnalyzer()

    var onShowPreviewChange: ((Bool) -> Void)?

    private let defaults = UserDefaults.standard

    // Lock-guarded flag read from the camera queue to skip CGImage creation
    // when the preview panel is hidden.
    private let previewLock = NSLock()
    // nonisolated(unsafe): protected by previewLock, read from the camera queue.
    nonisolated(unsafe) private var _previewVisible: Bool = true
    nonisolated private var previewVisible: Bool {
        get { previewLock.lock(); defer { previewLock.unlock() }; return _previewVisible }
        set { previewLock.lock(); _previewVisible = newValue; previewLock.unlock() }
    }

    private var checkTask: Task<Void, Never>?
    private var countdownTimer: Timer?

    // Tracks the visibility we last applied to the floating panel so updates are idempotent.
    private var panelCurrentlyVisible = false

    /// Whether the floating preview panel should be on screen right now.
    ///
    /// Always-on mode simply respects the "Show preview window" toggle.
    ///
    /// Periodic mode is different: the camera is off between checks, so the panel
    /// stays hidden while waiting. During a check the panel surfaces only when it
    /// matters — when a slouch is detected (the nudge is the whole point), or when
    /// there is no calibration baseline yet so the user can calibrate. This makes
    /// "in N minutes, if my posture is bad, open the preview" literally true and
    /// avoids a preview popping up on every check when posture is fine.
    private var panelShouldBeVisible: Bool {
        if periodicMode {
            guard inCheck else { return false }   // waiting between checks → hidden
            if baseline == nil { return true }    // not calibrated → surface so the user can calibrate
            return status == .slouching           // calibrated → open only when posture is bad
        }
        return showPreview                        // always-on mode → respect the toggle
    }

    /// Applies `panelShouldBeVisible` to the panel and the camera-queue CGImage gate.
    /// Idempotent — safe to call from any state transition or per-frame.
    private func updatePanelVisibility() {
        let visible = panelShouldBeVisible
        previewVisible = visible
        guard visible != panelCurrentlyVisible else { return }
        panelCurrentlyVisible = visible
        if !visible { latestImage = nil }
        onShowPreviewChange?(visible)
    }

    private init() {
        if defaults.object(forKey: Keys.sensitivity) != nil {
            sensitivity = defaults.double(forKey: Keys.sensitivity)
        }
        if defaults.object(forKey: Keys.showPreview) != nil {
            showPreview = defaults.bool(forKey: Keys.showPreview)
            _previewVisible = showPreview
        }
        if defaults.object(forKey: Keys.monitoring) != nil {
            monitoring = defaults.bool(forKey: Keys.monitoring)
        }
        if let data = defaults.data(forKey: Keys.baseline),
           let b = try? JSONDecoder().decode(Baseline.self, from: data) {
            baseline = b
        }
        if defaults.object(forKey: Keys.periodicMode) != nil {
            periodicMode = defaults.bool(forKey: Keys.periodicMode)
        }
        if defaults.object(forKey: Keys.checkInterval) != nil {
            checkIntervalMinutes = defaults.double(forKey: Keys.checkInterval)
        }
        analyzer.setSensitivity(sensitivity)
        analyzer.setBaseline(baseline)
    }

    func start() {
        camera.onFrame = { [weak self] pixelBuffer in
            self?.process(pixelBuffer)
        }
        if monitoring {
            if periodicMode {
                scheduleNextCheck()
            } else {
                startCamera()
            }
        }
        updatePanelVisibility()
    }

    func retryCamera() {
        guard monitoring, !cameraDenied else { return }
        guard !periodicMode else { return }
        startCamera()
    }

    private func startCamera() {
        camera.requestAccessAndStart { [weak self] granted in
            self?.cameraDenied = !granted
        }
    }

    /// Runs on the camera queue. Skips CGImage conversion when the preview is hidden
    /// to avoid unnecessary GPU work.
    nonisolated private func process(_ pixelBuffer: CVPixelBuffer) {
        let image = previewVisible ? camera.makeCGImage(from: pixelBuffer) : nil
        let metrics = detector.detect(in: pixelBuffer)
        let newStatus = analyzer.update(metrics: metrics)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let image { self.latestImage = image }
            self.landmarks = metrics
            let statusChanged = self.status != newStatus
            self.status = newStatus
            // A status change can flip panel visibility (e.g. a slouch alert during
            // a periodic check needs to surface the panel).
            if statusChanged { self.updatePanelVisibility() }
        }
    }

    // MARK: - Actions

    func calibrate() {
        guard let m = landmarks else { return }
        let b = Baseline(eyeLevelY: m.eyeLevelY, faceHeight: m.faceHeight)
        baseline = b
        analyzer.setBaseline(b)
        analyzer.reset()
        if let data = try? JSONEncoder().encode(b) {
            defaults.set(data, forKey: Keys.baseline)
        }
    }

    func setSensitivity(_ value: Double) {
        sensitivity = value
        defaults.set(value, forKey: Keys.sensitivity)
        analyzer.setSensitivity(value)
    }

    func setShowPreview(_ value: Bool) {
        showPreview = value
        defaults.set(value, forKey: Keys.showPreview)
        updatePanelVisibility()
    }

    func setMonitoring(_ value: Bool) {
        monitoring = value
        defaults.set(value, forKey: Keys.monitoring)
        if value {
            if periodicMode {
                scheduleNextCheck()
            } else {
                startCamera()
            }
        } else {
            cancelCheck()
            camera.stop()
            // Clear stale visual state so the PiP shows "paused" cleanly.
            latestImage = nil
            landmarks = nil
            status = .uncalibrated
            inCheck = false
            nextCheckCountdown = ""
            analyzer.reset()
        }
        updatePanelVisibility()
    }

    func setPeriodicMode(_ on: Bool) {
        periodicMode = on
        defaults.set(on, forKey: Keys.periodicMode)
        guard monitoring else { updatePanelVisibility(); return }
        if on {
            // Switching from continuous to periodic: stop camera, start countdown.
            // inCheck is false here, so the panel hides until the next check runs.
            camera.stop()
            latestImage = nil
            landmarks = nil
            status = .uncalibrated
            inCheck = false
            analyzer.reset()
            scheduleNextCheck()
        } else {
            // Switching from periodic to continuous: cancel any check, start camera.
            cancelCheck()
            inCheck = false
            nextCheckCountdown = ""
            startCamera()
        }
        updatePanelVisibility()
    }

    func setCheckIntervalMinutes(_ minutes: Double) {
        checkIntervalMinutes = minutes
        defaults.set(minutes, forKey: Keys.checkInterval)
        guard monitoring, periodicMode, !inCheck else { return }
        // Reschedule with the new interval.
        scheduleNextCheck()
    }

    // MARK: - Periodic Check Helpers

    private func scheduleNextCheck() {
        cancelCheck()

        let intervalSeconds = checkIntervalMinutes * 60
        let fireAt = Date().addingTimeInterval(intervalSeconds)

        nextCheckCountdown = formatCountdown(intervalSeconds)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let r = fireAt.timeIntervalSinceNow
            let text = r > 0 ? self.formatCountdown(r) : ""
            Task { @MainActor [weak self] in self?.nextCheckCountdown = text }
        }

        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(intervalSeconds))
            guard !Task.isCancelled, let self else { return }
            await self.runPeriodicCheck()
        }
    }

    private func runPeriodicCheck() async {
        inCheck = true
        nextCheckCountdown = ""

        startCamera()
        updatePanelVisibility()  // stays hidden until a slouch (or missing calibration) surfaces it

        // Warmup: let EMA stabilize.
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }

        // Evaluation loop: up to 8 seconds, sampling every 400ms.
        let evalIterations = Int((8.0 / 0.4).rounded())
        var detectedSlouching = false

        for _ in 0..<evalIterations {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }

            let currentStatus = status

            if currentStatus == .slouching {
                detectedSlouching = true
                break
            } else if currentStatus == .good && landmarks != nil {
                // Good posture detected — end silently.
                break
            }
        }

        guard !Task.isCancelled else { return }

        if detectedSlouching {
            // updatePanelVisibility (driven by the status change) already surfaced the
            // alert panel. Hold the check open until posture returns to good.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                if status == .good, landmarks != nil { break }
            }
        }

        guard !Task.isCancelled else { return }
        endPeriodicCheck()
    }

    private func endPeriodicCheck() {
        inCheck = false
        camera.stop()
        latestImage = nil
        landmarks = nil
        status = .uncalibrated
        analyzer.reset()
        updatePanelVisibility()  // periodic + !inCheck → hides the panel

        guard monitoring, periodicMode else { return }
        scheduleNextCheck()
    }

    private func cancelCheck() {
        checkTask?.cancel()
        checkTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    nonisolated private func formatCountdown(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private enum Keys {
        static let sensitivity  = "sensitivity"
        static let showPreview  = "showPreview"
        static let monitoring   = "monitoring"
        static let baseline     = "baseline"
        static let periodicMode = "periodicMode"
        static let checkInterval = "checkInterval"
    }
}
