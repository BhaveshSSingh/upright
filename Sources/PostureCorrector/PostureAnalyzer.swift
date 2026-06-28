import Foundation
import CoreGraphics

enum PostureStatus: Sendable {
    case uncalibrated
    case noFace
    case good
    case slouching
}

struct Baseline: Codable, Sendable {
    var eyeLevelY: CGFloat
    var faceHeight: CGFloat
}

/// Decides whether the user is slouching by comparing smoothed live measurements
/// to a calibrated baseline.
///
/// Thread contract:
///   - `_baseline`, `_sensitivity`, `_pendingReset` are written from any thread, guarded by `lock`.
///   - `emaEyeY`, `emaFaceH`, `slouchSince`, `goodSince`, `status` are ONLY ever read/written
///     inside `update()` which always runs on the camera serial queue.
final class PostureAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private var _baseline: Baseline?
    private var _sensitivity: Double = 0.5
    private var _pendingReset = false

    // Camera-queue-only state — never touched off the camera queue.
    private var emaEyeY: CGFloat?
    private var emaFaceH: CGFloat?
    private let alpha: CGFloat = 0.3
    private var slouchSince: Date?
    private var goodSince: Date?
    private var status: PostureStatus = .uncalibrated

    func setBaseline(_ b: Baseline?) {
        lock.lock(); _baseline = b; lock.unlock()
    }

    func setSensitivity(_ s: Double) {
        lock.lock(); _sensitivity = s; lock.unlock()
    }

    /// Schedules an EMA/debounce reset; the reset is applied at the top of the next
    /// `update()` call, which runs on the camera queue — so all EMA state is
    /// touched only on that queue. Safe to call from any thread.
    func reset() {
        lock.lock(); _pendingReset = true; lock.unlock()
    }

    func update(metrics: FaceMetrics?) -> PostureStatus {
        let now = Date()

        // Consume all cross-thread state in one lock region.
        lock.lock()
        let base = _baseline
        let sensitivity = _sensitivity
        let doReset = _pendingReset
        _pendingReset = false
        lock.unlock()

        // Apply deferred reset here, safely on the camera queue.
        if doReset {
            emaEyeY = nil; emaFaceH = nil; slouchSince = nil; goodSince = nil
        }

        guard let m = metrics else {
            slouchSince = nil
            goodSince = nil
            status = .noFace
            return status
        }

        emaEyeY = emaEyeY.map { $0 + alpha * (m.eyeLevelY - $0) } ?? m.eyeLevelY
        emaFaceH = emaFaceH.map { $0 + alpha * (m.faceHeight - $0) } ?? m.faceHeight

        guard let base, let eyeY = emaEyeY, let faceH = emaFaceH else {
            status = .uncalibrated
            return status
        }

        let drop = base.eyeLevelY - eyeY
        let lean = base.faceHeight > 0 ? (faceH / base.faceHeight - 1.0) : 0

        let s = CGFloat(sensitivity)
        let eyeThreshold  = 0.06 - 0.04 * s  // 0.06 (relaxed) … 0.02 (strict)
        let leanThreshold = 0.18 - 0.12 * s  // 0.18 (relaxed) … 0.06 (strict)

        let bad = (drop > eyeThreshold) || (lean > leanThreshold)

        if bad {
            goodSince = nil
            if slouchSince == nil { slouchSince = now }
            if now.timeIntervalSince(slouchSince!) > 0.6 { status = .slouching }
        } else {
            slouchSince = nil
            if goodSince == nil { goodSince = now }
            if now.timeIntervalSince(goodSince!) > 0.8 { status = .good }
        }

        return status
    }
}
