import Cocoa

/// A placeholder shaped like the content that is on its way. Soft bars stand where the lines will be
/// and a highlight passes over them slowly; with Reduce Motion on they sit still. The status text next
/// to it says what is happening, so the placeholder itself stays out of accessibility.
final class SkeletonView: NSView {
    /// A bar or a dot, placed from the top leading corner of the view.
    struct Piece: Equatable {
        enum Width: Equatable {
            case points(CGFloat)
            /// A share of the room to the right of `x`.
            case share(CGFloat)
        }
        var x: CGFloat
        var top: CGFloat
        var width: Width
        var height: CGFloat
    }

    var pieces: [Piece] = [] {
        didSet { if pieces != oldValue { rebuildLayers() } }
    }

    /// True while the highlight is passing over the bars.
    var isAnimating: Bool { sweep.animation(forKey: "sweep") != nil }

    private let barsLayer = CALayer()
    private let sweepHost = CALayer()
    private let sweepMask = CALayer()
    private let sweep = CAGradientLayer()
    private var barLayers: [CALayer] = []
    private var maskLayers: [CALayer] = []
    private var animatedWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(barsLayer)
        layer?.addSublayer(sweepHost)
        // The highlight is clipped to the shapes of the bars, so it never lights the card between them.
        sweepHost.mask = sweepMask
        sweepHost.addSublayer(sweep)
        sweep.startPoint = CGPoint(x: 0, y: 0.5)
        sweep.endPoint = CGPoint(x: 1, y: 0.5)
        sweep.colors = [
            Token.Color.bgSkeletonSweepClear.cgColor,
            Token.Color.bgSkeletonSweep.cgColor,
            Token.Color.bgSkeletonSweepClear.cgColor
        ]
        sweep.locations = [0, 0.5, 1]
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func rebuildLayers() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        maskLayers.forEach { $0.removeFromSuperlayer() }
        barLayers = pieces.map { _ in
            let bar = CALayer()
            bar.backgroundColor = Token.Color.bgSkeleton.cgColor
            barsLayer.addSublayer(bar)
            return bar
        }
        maskLayers = pieces.map { _ in
            let shape = CALayer()
            shape.backgroundColor = Token.Color.maskOpaque.cgColor
            sweepMask.addSublayer(shape)
            return shape
        }
        needsLayout = true
    }

    /// The highlight is half as wide as the placeholder, and never narrower than a short word.
    private var bandWidth: CGFloat { max(80, bounds.width * 0.5) }

    private func frame(of piece: Piece) -> CGRect {
        let width: CGFloat
        switch piece.width {
        case .points(let points): width = points
        case .share(let share): width = max(0, bounds.width - piece.x) * share
        }
        return CGRect(x: piece.x, y: bounds.height - piece.top - piece.height, width: width, height: piece.height)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barsLayer.frame = bounds
        sweepHost.frame = bounds
        sweepMask.frame = bounds
        for (index, piece) in pieces.enumerated() where index < barLayers.count {
            let rect = frame(of: piece)
            for layer in [barLayers[index], maskLayers[index]] {
                layer.frame = rect
                layer.cornerRadius = Token.Radius.full(min(rect.width, rect.height))
            }
        }
        sweep.frame = CGRect(x: -bandWidth, y: 0, width: bandWidth, height: bounds.height)
        CATransaction.commit()
        if abs(bounds.width - animatedWidth) > 0.5 { restartAnimation() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restartAnimation()
    }

    override func viewDidHide() {
        super.viewDidHide()
        restartAnimation()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        restartAnimation()
    }

    private func restartAnimation() {
        sweep.removeAnimation(forKey: "sweep")
        animatedWidth = bounds.width
        let running = window != nil && !isHiddenOrHasHiddenAncestor && bounds.width > 0 && !Token.Motion.reducesMotion()
        sweepHost.isHidden = !running
        guard running else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = bounds.width + bandWidth
        animation.duration = Token.Motion.shimmer
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        // Every placeholder on screen keeps one beat, so two of them read as a single wait.
        let now = CACurrentMediaTime()
        animation.beginTime = now - now.truncatingRemainder(dividingBy: Token.Motion.shimmer)
        sweep.add(animation, forKey: "sweep")
    }

    // MARK: - Shapes

    /// Bullet lines as an answer sets them: a dot where the bullet is, then a bar as long as a line.
    /// `pitch` is the distance from one line to the next and `lineHeight` the height of a line box.
    static func answerLines(count: Int, indent: CGFloat, pitch: CGFloat, lineHeight: CGFloat) -> [Piece] {
        let shares: [CGFloat] = [0.94, 0.8, 0.58, 0.72, 0.5]
        let bar = Token.Skeleton.lineHeight
        let dot = Token.Skeleton.dot
        var pieces: [Piece] = []
        for row in 0..<max(0, count) {
            let center = lineHeight / 2 + CGFloat(row) * pitch
            pieces.append(Piece(x: 1, top: center - dot / 2, width: .points(dot), height: dot))
            pieces.append(Piece(x: indent, top: center - bar / 2, width: .share(shares[row % shares.count]), height: bar))
        }
        return pieces
    }
}

/// The card the first step of code will fill, in the same place and at the same width: a badge and a
/// file name, a line of why, and a code well with three lines. When the step arrives the card grows
/// or shrinks to fit its code; it does not move.
final class CodeStepSkeletonView: NSView {
    /// Header 30, the line of why 22, a gap, a well of three code lines, the card's padding.
    static let height: CGFloat = 152

    private let well = NSView()
    private let outline = SkeletonView()
    private let codeLines = SkeletonView()

    private let sidePadding = Token.Space.inset
    private let headerHeight: CGFloat = 30
    private let codePadding: CGFloat = 10

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applySurface(.stepCard)
        well.applySurface(.codeWell)
        addSubview(well)
        addSubview(outline)
        well.addSubview(codeLines)
        let badge = Token.Sizing.badgeSmall
        outline.pieces = [
            SkeletonView.Piece(x: sidePadding, top: 5, width: .points(badge), height: badge),
            SkeletonView.Piece(x: sidePadding + badge + Token.Space.sm, top: 10, width: .points(120), height: Token.Skeleton.smallLineHeight),
            SkeletonView.Piece(x: sidePadding, top: headerHeight + 6, width: .share(0.62), height: Token.Skeleton.smallLineHeight)
        ]
        // Code is indented, so the second and third bars start further in.
        codeLines.pieces = (0..<3).map { row in
            SkeletonView.Piece(
                x: row == 0 ? 0 : 16, top: 3 + CGFloat(row) * 17.5,
                width: .share([0.55, 0.7, 0.4][row]), height: Token.Skeleton.smallLineHeight
            )
        }
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let innerWidth = bounds.width - sidePadding * 2
        let wellHeight = 3 * 17.5 + 2 + codePadding * 2
        well.frame = NSRect(x: sidePadding, y: sidePadding, width: innerWidth, height: wellHeight)
        codeLines.frame = NSRect(x: codePadding, y: codePadding, width: innerWidth - codePadding * 2, height: wellHeight - codePadding * 2)
        outline.frame = bounds
    }
}
