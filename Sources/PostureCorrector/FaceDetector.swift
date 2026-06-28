import Foundation
import Vision
import CoreVideo
import CoreGraphics

struct FaceMetrics: Sendable {
    /// Average y of the two eyes (higher = head held higher).
    var eyeLevelY: CGFloat
    /// Height of the face bounding box (proxy for distance — bigger = leaning in / closer).
    var faceHeight: CGFloat
    var leftEye: CGPoint
    var rightEye: CGPoint
    var nose: CGPoint
    var boundingBox: CGRect
}

/// Runs Apple's Vision face-landmark detection on camera frames.
/// Called only from the camera's serial processing queue.
final class FaceDetector: @unchecked Sendable {
    private let request: VNDetectFaceLandmarksRequest = {
        let r = VNDetectFaceLandmarksRequest()
        r.constellation = .constellation65Points
        return r
    }()

    func detect(in pixelBuffer: CVPixelBuffer) -> FaceMetrics? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first as? VNFaceObservation else { return nil }
        let bb = face.boundingBox

        // Converts a landmark region (coords normalized to the bounding box) to image-normalized coords.
        func imagePoint(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region, region.pointCount > 0 else { return nil }
            var sx: CGFloat = 0, sy: CGFloat = 0
            for p in region.normalizedPoints {
                sx += CGFloat(p.x)
                sy += CGFloat(p.y)
            }
            let n = CGFloat(region.pointCount)
            return CGPoint(x: bb.origin.x + (sx / n) * bb.size.width,
                           y: bb.origin.y + (sy / n) * bb.size.height)
        }

        let landmarks = face.landmarks

        // Eye landmarks are required — a face without localizable eyes produces garbage
        // eyeLevelY and would corrupt calibration. Treat it as no detection.
        guard let leftEye  = imagePoint(landmarks?.leftEye)  ?? imagePoint(landmarks?.leftPupil),
              let rightEye = imagePoint(landmarks?.rightEye) ?? imagePoint(landmarks?.rightPupil)
        else { return nil }

        let center = CGPoint(x: bb.midX, y: bb.midY)
        let nose   = imagePoint(landmarks?.nose) ?? imagePoint(landmarks?.noseCrest) ?? center
        let eyeLevelY = (leftEye.y + rightEye.y) / 2.0

        return FaceMetrics(
            eyeLevelY: eyeLevelY,
            faceHeight: bb.height,
            leftEye: leftEye,
            rightEye: rightEye,
            nose: nose,
            boundingBox: bb
        )
    }
}
