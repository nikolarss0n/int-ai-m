// Draws the app icon and writes icon_1024.png, icon.iconset and AppIcon.icns into the repository root.
// Run it from the root, or pass the root's path:
//
//   swiftc -O -o build/make-app-icon Scripts/make-app-icon.swift && build/make-app-icon
//
// The icon is a pair of quotation marks on a dark tile: what was asked in white, what to say in the
// accent. Its colours are the window's (`Token.Global.Palette` in DesignTokens.swift), so a change of
// accent there is a change here.

import AppKit
import SwiftUI

/// The macOS icon grid: a 1024 canvas whose tile is 824 wide, so the shadow has room around it.
/// `AppIconImage` crops to this tile; keep the two in step.
let canvasSide: CGFloat = 1024
let tileMargin: CGFloat = 100
let tileCorner: CGFloat = 0.225

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red, green, blue, alpha])!
}

func vertical(_ ctx: CGContext, from top: CGColor, to bottom: CGColor, in box: CGRect) {
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
}

func squircle(_ rect: CGRect) -> CGPath {
    RoundedRectangle(cornerRadius: rect.width * tileCorner, style: .continuous).path(in: rect).cgPath
}

/// A closing quotation mark: a ball of radius `r` with a tail that leaves its right side and sweeps
/// down to a point on the left. The numbers are in ball radii from the ball's centre.
func quotationMark(center: CGPoint, r: CGFloat) -> CGPath {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: center.x + x * r, y: center.y + y * r) }
    let path = CGMutablePath()
    path.move(to: point(1, 0))
    path.addCurve(to: point(-0.62, -1.72), control1: point(1, -0.95), control2: point(0.35, -1.55))
    path.addCurve(to: point(-0.31, -0.951), control1: point(-0.47, -1.61), control2: point(-0.34, -1.36))
    path.addArc(center: center, radius: r, startAngle: -108 * .pi / 180, endAngle: -360 * .pi / 180, clockwise: true)
    path.closeSubpath()
    return path
}

func drawMark(_ ctx: CGContext, _ path: CGPath, top: CGColor, bottom: CGColor, tile: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -0.012 * tile), blur: 0.03 * tile, color: color(0, 0, 0, 0.4))
    ctx.addPath(path)
    ctx.setFillColor(bottom)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    vertical(ctx, from: top, to: bottom, in: path.boundingBoxOfPath)
    ctx.restoreGState()
}

func drawTile(_ ctx: CGContext, in rect: CGRect) {
    let side = rect.width
    let shape = squircle(rect)

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    vertical(ctx, from: color(0.20, 0.205, 0.24), to: color(0.075, 0.075, 0.09), in: rect)

    // The marks sit a little above the middle of their own box, where their weight is.
    let r = 0.155 * side
    let gap = 0.46 * r
    let middle = CGPoint(x: rect.midX, y: rect.midY + 0.27 * r)
    drawMark(ctx, quotationMark(center: CGPoint(x: middle.x - gap / 2 - r, y: middle.y), r: r),
             top: color(1, 1, 1), bottom: color(0.89, 0.89, 0.93), tile: side)
    drawMark(ctx, quotationMark(center: CGPoint(x: middle.x + gap / 2 + r, y: middle.y), r: r),
             top: color(0.90, 0.50, 0.99), bottom: color(0.74, 0.20, 0.90), tile: side)

    // Light from above, and a hairline so the tile keeps its edge on a dark desktop.
    vertical(ctx, from: color(1, 1, 1, 0.07), to: color(1, 1, 1, 0),
             in: CGRect(x: rect.minX, y: rect.midY, width: side, height: side / 2))
    let line = max(1, side * 0.012)
    ctx.addPath(squircle(rect.insetBy(dx: line / 2, dy: line / 2)))
    ctx.setLineWidth(line)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    vertical(ctx, from: color(1, 1, 1, 0.26), to: color(1, 1, 1, 0.05), in: rect)
    ctx.restoreGState()
}

func icon(pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let unit = CGFloat(pixels) / canvasSide
    let tile = CGRect(x: tileMargin * unit, y: tileMargin * unit,
                      width: (canvasSide - 2 * tileMargin) * unit, height: (canvasSide - 2 * tileMargin) * unit)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 22 * unit, color: color(0, 0, 0, 0.36))
    ctx.addPath(squircle(tile))
    ctx.setFillColor(color(0.1, 0.1, 0.11))
    ctx.fillPath()
    ctx.restoreGState()

    drawTile(ctx, in: tile)
    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
    .standardizedFileURL
guard FileManager.default.fileExists(atPath: root.appendingPathComponent("build.sh").path) else {
    print("\(root.path) is not the repository root: run this from there, or pass its path")
    exit(1)
}
let iconset = root.appendingPathComponent("icon.iconset")
print("writing the icon into \(root.path)")

do {
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
        try write(icon(pixels: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
        try write(icon(pixels: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
    }
    try write(icon(pixels: Int(canvasSide)), to: root.appendingPathComponent("icon_1024.png"))

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("AppIcon.icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else {
        print("iconutil failed with status \(iconutil.terminationStatus)")
        exit(1)
    }
    print("wrote icon_1024.png, icon.iconset and AppIcon.icns")
} catch {
    print("could not write the icon: \(error)")
    exit(1)
}
