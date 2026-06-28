# Posture Corrector

A tiny native macOS menu-bar app that watches your sitting posture through the
front camera and nudges you with a gentle **"Look up a bit! 👀"** when you slouch —
a personal-use clone of [SuperShrimp](https://www.supershrimp.io/).

Everything runs **100% on-device** using Apple's Vision framework. No video ever
leaves your Mac, there's no cloud, no account, and no model downloads.

![concept](todo.md)

## How it works

- **AVFoundation** grabs frames from the front camera (~15 fps, 640×480 — light on battery).
- **Apple Vision** (`VNDetectFaceLandmarksRequest`) finds your eyes and nose on each frame.
- A **calibration** step records your "good posture" eye level + face size as a baseline.
- The **analyzer** smooths the live measurements and flags a slouch when your eyes drop
  below the baseline or your face grows (you've leaned in), with a sensitivity you control.
- A floating **picture-in-picture** panel shows a mirror of you with the landmarks drawn
  and a green target line at your calibrated eye level; the caption appears when you slouch
  and disappears once you straighten up.

## Tech stack

| Concern | Choice |
|---|---|
| Language / UI | Swift + SwiftUI (`MenuBarExtra`, `NSPanel`) |
| Camera | AVFoundation (`AVCaptureSession`) |
| Face detection | Apple **Vision** (on-device, no model files) |
| Packaging | SwiftPM executable → assembled `.app` bundle, ad-hoc signed |
| Launch at login | `SMAppService` |

Chosen over Electron/Tauri because this is a Mac-only, always-running camera utility:
native gives the smallest footprint, best battery, cleanest camera permissions, and a
true menu-bar + floating-panel feel.

## Build & run

Requires the Xcode command-line tools (Swift 6 toolchain).

```bash
# Build, bundle into a .app, ad-hoc sign, and launch:
./scripts/build_app.sh debug run

# Or just build the bundle without launching:
./scripts/build_app.sh debug
open build/PostureCorrector.app
```

> Run it via the `.app` bundle (not the raw binary) — the bundle's `Info.plist`
> carries the camera-usage description macOS needs to grant permission.

For a smaller, optimized binary use `release` instead of `debug`.

## Using it

1. Launch the app — a 🪑 icon appears in the menu bar and the preview panel shows in the
   bottom-right corner. Approve the camera prompt the first time.
2. Sit the way you *want* to sit, then click the menu-bar icon → **Calibrate**.
3. That's it. Slouch and the caption nudges you; straighten up and it goes away.
4. Tune **Sensitivity** (Relaxed → Strict), toggle **Monitoring**, hide the preview with
   its hover **✕** (or the **Show preview window** toggle), and optionally enable
   **Launch at login**.

## Project layout

```
Package.swift                     SwiftPM manifest (macOS 13+, Swift 5 language mode)
Info.plist                        Bundle metadata + NSCameraUsageDescription + LSUIElement
scripts/build_app.sh              build → bundle → codesign → (optional) launch
Sources/PostureCorrector/
  App.swift                       @main; MenuBarExtra with a status-reflecting glyph
  AppDelegate.swift               app lifecycle; creates the floating panel
  AppState.swift                  pipeline wiring + published UI state + settings persistence
  CameraManager.swift             AVCaptureSession, permission, frame delivery
  FaceDetector.swift              Vision face-landmark detection → FaceMetrics
  PostureAnalyzer.swift           smoothing + calibration baseline + slouch decision
  PanelController.swift           borderless, always-on-top, transparent NSPanel
  PiPView.swift                   mirrored video + landmark overlay + caption + close button
  MenuContent.swift               the menu-bar dropdown (calibrate/sensitivity/etc.)
  LoginItem.swift                 SMAppService launch-at-login wrapper
```

## Notes & limitations

- **Ad-hoc signing re-prompts the camera permission on each rebuild** (the code hash
  changes). Fine for a finished build you stop rebuilding; a stable self-signed identity
  removes the nag during development.
- Posture is judged relative to your **calibration** — re-calibrate if you move the laptop
  or change seats.
- Detection needs your face roughly in frame and reasonable lighting.
