#!/usr/bin/env swift
// Generates AppIcon.icns for PostureCorrector.
// Run: swift scripts/make_icon.swift  (from project root)
import AppKit
import Foundation

// Draws a clean fallback seated-figure-in-profile glyph in white into `rect`.
// Used only if the SF Symbol "figure.seated.side" cannot be loaded.
func drawFallbackSeatedFigure(in rect: CGRect, ctx: CGContext) {
    ctx.saveGState()
    let w = rect.width
    let x = rect.minX, y = rect.minY
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))

    // Head
    let headR = w * 0.13
    ctx.fillEllipse(in: CGRect(x: x + w * 0.30 - headR, y: y + w * 0.82 - headR,
                               width: headR * 2, height: headR * 2))

    // Upright back + thigh (seated L-shape), thick rounded strokes
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(w * 0.155)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // straight back
    ctx.move(to:    CGPoint(x: x + w * 0.30, y: y + w * 0.70))
    ctx.addLine(to: CGPoint(x: x + w * 0.30, y: y + w * 0.36))
    // thigh forward
    ctx.addLine(to: CGPoint(x: x + w * 0.66, y: y + w * 0.36))
    ctx.strokePath()
    // shin down
    ctx.setLineWidth(w * 0.13)
    ctx.move(to:    CGPoint(x: x + w * 0.66, y: y + w * 0.38))
    ctx.addLine(to: CGPoint(x: x + w * 0.66, y: y + w * 0.10))
    ctx.strokePath()

    ctx.restoreGState()
}

func makeIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    defer { img.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    let w = size, h = size
    let cs = CGColorSpaceCreateDeviceRGB()

    // ── Squircle background plate ─────────────────────────────────────────────
    let margin = w * 0.08
    let plate  = CGRect(x: margin, y: margin, width: w - margin * 2, height: h - margin * 2)
    let radius = plate.width * 0.2237   // Big Sur corner-radius ratio
    let squircle = NSBezierPath(roundedRect: NSRectFromCGRect(plate),
                                xRadius: radius, yRadius: radius)

    ctx.saveGState()
    squircle.addClip()

    // Brand teal vertical gradient: brighter top → deeper bottom
    let bg = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 0.17, green: 0.75, blue: 0.78, alpha: 1),   // #2BC0C8
                 CGColor(red: 0.05, green: 0.49, blue: 0.54, alpha: 1)] as CFArray, // #0E7C8A
        locations: [0, 1])!
    ctx.drawLinearGradient(bg,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end:   CGPoint(x: plate.midX, y: plate.minY),
        options: [])

    // Subtle top highlight sheen
    let sheen = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
                 CGColor(red: 1, green: 1, blue: 1, alpha: 0.00)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(sheen,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end:   CGPoint(x: plate.midX, y: plate.midY + plate.height * 0.08),
        options: [])

    // Soft bottom inner shadow for depth
    let bottomShadow = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 0, green: 0, blue: 0, alpha: 0.22),
                 CGColor(red: 0, green: 0, blue: 0, alpha: 0.00)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(bottomShadow,
        start: CGPoint(x: plate.midX, y: plate.minY),
        end:   CGPoint(x: plate.midX, y: plate.minY + plate.height * 0.28),
        options: [])

    ctx.restoreGState()

    // ── Foreground: white seated-figure glyph ────────────────────────────────
    // Target draw box ~55% of the icon, optically centered.
    let glyphSize = w * 0.55
    let glyphRect = CGRect(x: (w - glyphSize) / 2,
                           y: (h - glyphSize) / 2,
                           width: glyphSize, height: glyphSize)

    // Soft drop shadow so the glyph lifts off the gradient.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.012),
                  blur: w * 0.03,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))

    var drewSymbol = false
    let config = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .bold)
    if let base = NSImage(systemSymbolName: "figure.seated.side", accessibilityDescription: nil),
       let symbol = base.withSymbolConfiguration(config) {
        // Tint solid white.
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: NSRect(origin: .zero, size: symbol.size),
                    operation: .sourceOver, fraction: 1.0)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        // Aspect-fit + center the tinted symbol inside glyphRect.
        let s = symbol.size
        let scale = min(glyphRect.width / s.width, glyphRect.height / s.height)
        let drawW = s.width * scale
        let drawH = s.height * scale
        let drawRect = CGRect(x: glyphRect.midX - drawW / 2,
                              y: glyphRect.midY - drawH / 2,
                              width: drawW, height: drawH)
        if let cg = tinted.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(cg, in: drawRect)
            drewSymbol = true
        } else {
            tinted.draw(in: NSRectFromCGRect(drawRect),
                        from: NSRect(origin: .zero, size: s),
                        operation: .sourceOver, fraction: 1.0)
            drewSymbol = true
        }
    }

    if !drewSymbol {
        drawFallbackSeatedFigure(in: glyphRect, ctx: ctx)
    }

    ctx.restoreGState()

    return img
}

// ── Export iconset ───────────────────────────────────────────────────────────
let iconsetPath = "build/AppIcon.iconset"
let outputIcns  = "Resources/AppIcon.icns"

let sizes: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = makeIcon(size: CGFloat(size))
    guard let tiff = image.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:]) else {
        print("✗ \(name)  (render failed)")
        continue
    }
    try png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    print("✓ \(name).png  (\(size)×\(size))")
}

print("\nConverting to .icns …")
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments  = ["-c", "icns", iconsetPath, "-o", outputIcns]
task.launch()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✓ \(outputIcns)")
} else {
    print("✗ iconutil failed (exit \(task.terminationStatus))")
}
