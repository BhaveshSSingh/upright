import SwiftUI

/// The floating picture-in-picture preview: mirrored live video, landmark dots,
/// a green "target" line at your calibrated eye level, and an auto-showing
/// "Look up a bit!" caption when you slouch.
struct PiPView: View {
    @ObservedObject var state: AppState
    @State private var hovering = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    if let img = state.latestImage {
                        Image(decorative: img, scale: 1.0, orientation: .up)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(x: -1, y: 1) // mirror — feels like a mirror
                            .clipped()
                    } else {
                        ZStack {
                            Color.black
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                Text("Starting camera…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    OverlayCanvas(state: state, size: geo.size)
                }
            }

            // Captions
            VStack {
                if state.monitoring && state.status == .slouching {
                    caption("Look up a bit! 👀")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
                Spacer()
                if state.baseline == nil && state.status != .noFace {
                    caption("Sit up straight, then Calibrate")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.bottom, 8)
                }
                if !state.monitoring {
                    caption("Paused")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.bottom, 8)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.status)
            .animation(.easeInOut(duration: 0.2), value: state.monitoring)
        }
        .frame(width: 260, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { closeButton }
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        .onHover { hovering = $0 }
    }

    /// Hover-revealed dismiss button. Hides the preview (re-show it from the menu bar).
    private var closeButton: some View {
        Button {
            state.setShowPreview(false)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.black.opacity(0.5), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Hide preview (re-enable from the menu bar)")
        .padding(8)
        .opacity(hovering ? 1 : 0)
        .scaleEffect(hovering ? 1 : 0.8, anchor: .topTrailing)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
    }

    @ViewBuilder
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
    }
}

/// Draws the landmark dots, eye line, and calibrated target line over the video.
struct OverlayCanvas: View {
    @ObservedObject var state: AppState
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            // Map Vision image coords (bottom-left origin) to view coords (top-left),
            // mirrored horizontally to match the flipped video.
            func pt(_ p: CGPoint) -> CGPoint {
                CGPoint(x: (1 - p.x) * sz.width, y: (1 - p.y) * sz.height)
            }

            // Calibrated target line (where your eyes should be).
            if let base = state.baseline {
                let y = (1 - base.eyeLevelY) * sz.height
                var line = Path()
                line.move(to: CGPoint(x: 10, y: y))
                line.addLine(to: CGPoint(x: sz.width - 10, y: y))
                ctx.stroke(line,
                           with: .color(.green.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }

            guard let m = state.landmarks else { return }

            // Eye line.
            var eyeLine = Path()
            eyeLine.move(to: pt(m.leftEye))
            eyeLine.addLine(to: pt(m.rightEye))
            ctx.stroke(eyeLine, with: .color(.red.opacity(0.7)), lineWidth: 1.5)

            // Landmark dots.
            for p in [m.leftEye, m.rightEye, m.nose] {
                let c = pt(p)
                let r: CGFloat = 4
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.red))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
