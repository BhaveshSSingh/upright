import Foundation
import AVFoundation
import CoreImage
import CoreVideo
import CoreGraphics

/// Owns the AVCaptureSession for the front camera and delivers frames
/// (throttled to ~15 fps) to `onFrame` on a private serial queue.
///
/// Thread contract: `configured` and `shouldBeRunning` are only ever read/written
/// inside closures dispatched on `queue`, so they need no additional locking.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let output  = AVCaptureVideoDataOutput()
    private let queue   = DispatchQueue(label: "com.bhavesh.posture.camera")
    private let ciContext = CIContext()

    // Queue-confined state.
    private var configured = false
    private var shouldBeRunning = false
    private var frameIndex = 0

    var onFrame: ((CVPixelBuffer) -> Void)?

    override init() {
        super.init()
        // Resume the session automatically after system interruptions (sleep/wake, FaceTime
        // stealing the camera, etc.).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(interruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
    }

    @objc private func interruptionEnded(_ note: Notification) {
        queue.async { [weak self] in
            guard let self, self.shouldBeRunning, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    /// Requests camera access if needed, configures and starts the session.
    /// `completion(granted)` is always called on the main thread.
    func requestAccessAndStart(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            queue.async { [weak self] in
                self?.configureAndStart()
                DispatchQueue.main.async { completion(true) }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.queue.async { self?.configureAndStart() }
                }
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    /// Must be called on `queue`. Idempotent — configures the session at most once.
    private func configureAndStart() {
        if !configured {
            configured = true
            session.beginConfiguration()
            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            }
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
            if let device,
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
        }
        shouldBeRunning = true
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldBeRunning = false
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameIndex &+= 1
        if frameIndex % 2 != 0 { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }

    func makeCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ci, from: ci.extent)
    }
}
