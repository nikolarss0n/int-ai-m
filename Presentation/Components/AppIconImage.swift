import Cocoa

/// The app's icon for use inside a window. A macOS icon keeps a margin and a shadow around its tile
/// (`Scripts/make-app-icon.swift` draws it on that grid); a small frame wants the tile alone, edge to
/// edge, or the mark ends up a fifth smaller than the frame it was given.
enum AppIconImage {
    /// The margin on each edge as a share of the icon's side: 100 of 1024.
    private static let margin: CGFloat = 100.0 / 1024.0

    private static let tile: CGImage? = {
        let developmentPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("icon_1024.png").path
        guard let icon = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: developmentPath),
              let largest = icon.representations.max(by: { $0.pixelsWide < $1.pixelsWide }),
              let full = largest.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = CGFloat(full.width)
        let inset = (side * margin).rounded()
        return full.cropping(to: CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset))
    }()

    /// The tile at `side` points, drawn at the screen's own scale so it stays sharp when small.
    static func tile(side: CGFloat) -> NSImage? {
        guard let tile else { return NSApp.applicationIconImage }
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current else { return false }
            context.imageInterpolation = .high
            context.cgContext.draw(tile, in: rect)
            return true
        }
    }
}
