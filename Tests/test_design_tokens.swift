import Cocoa

private var checks = 0
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("DesignTokens: \(message)") }
}

private struct RGB { var r, g, b: Double }

private func components(_ color: NSColor) -> (rgb: RGB, alpha: Double) {
    let c = color.usingColorSpace(.sRGB)!
    return (RGB(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent)), Double(c.alphaComponent))
}

private func alpha(_ color: NSColor) -> Double { components(color).alpha }

/// `top` painted over an opaque `base`.
private func over(_ top: NSColor, _ base: RGB) -> RGB {
    let (c, a) = components(top)
    return RGB(r: c.r * a + base.r * (1 - a), g: c.g * a + base.g * (1 - a), b: c.b * a + base.b * (1 - a))
}

/// APCA-W3 0.0.98G-4g lightness contrast, absolute value. Mirrors Scripts/focus-ui-qa/colors.py.
private func lc(_ fg: RGB, _ bg: RGB) -> Double {
    func y(_ c: RGB) -> Double { 0.2126729 * pow(c.r, 2.4) + 0.7151522 * pow(c.g, 2.4) + 0.0721750 * pow(c.b, 2.4) }
    var text = y(fg), back = y(bg)
    if text < 0.022 { text += pow(0.022 - text, 1.414) }
    if back < 0.022 { back += pow(0.022 - back, 1.414) }
    if abs(back - text) < 0.0005 { return 0 }
    if back > text {
        let s = (pow(back, 0.56) - pow(text, 0.57)) * 1.14
        return s < 0.1 ? 0 : (s - 0.027) * 100
    }
    let s = (pow(back, 0.65) - pow(text, 0.62)) * 1.14
    return s > -0.1 ? 0 : abs((s + 0.027) * 100)
}

private func gray(_ v: Double) -> RGB { RGB(r: v, g: v, b: v) }

private func strictlyIncreasing(_ values: [Double]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
}

// The port has to agree with the reference values before anything is measured with it.
check(abs(lc(gray(1), gray(0)) - 107.88) < 0.05 && abs(lc(gray(0), gray(1)) - 106.04) < 0.05, "APCA matches the reference values")

// MARK: Scales

let ramp = [
    Token.Global.Opacity.o06, Token.Global.Opacity.o10, Token.Global.Opacity.o16, Token.Global.Opacity.o28,
    Token.Global.Opacity.o30, Token.Global.Opacity.o45, Token.Global.Opacity.o55, Token.Global.Opacity.o66,
    Token.Global.Opacity.o72, Token.Global.Opacity.o80, Token.Global.Opacity.o85, Token.Global.Opacity.o94
].map(Double.init)
check(strictlyIncreasing(ramp), "the opacity ramp has no duplicates or out-of-order steps")

check(strictlyIncreasing([Token.Tint.faint, .soft, .medium, .strong].map { Double($0.alpha) }), "tints get stronger")
check(strictlyIncreasing([Token.Edge.faint, .soft, .regular, .strong, .active].map { Double($0.alpha) }), "edges get stronger")

let textLevels = [Token.Color.textMuted, Token.Color.textBody, Token.Color.textStrong, Token.Color.textPrimary].map(alpha)
check(strictlyIncreasing(textLevels), "text steps run muted to primary")
check(alpha(Token.Color.textPrimary) == 1, "primary text is opaque")

check(alpha(NSColor.white.tint(.soft)) == Double(Token.Tint.soft.alpha), "tint sets the wash strength")
check(alpha(NSColor.white.edge(.active)) == Double(Token.Edge.active.alpha), "edge sets the outline strength")
check(Token.Radius.full(32) == 16 && Token.Radius.full(52) == 26, "full rounding is half the side")
check(Token.Radius.lg == LayoutConstants.CornerRadius.large && Token.Sizing.control == LayoutConstants.IconButton.size,
      "scales reuse the layout constants that already fit")

// MARK: Legibility

// The glass behind the window is its `.menu` material at 0.8 alpha over the desktop, about 0.09 gray
// over black, 0.26 over a typical desktop and 0.44 over white. The fills above it are exact.
private let backdrops: [(name: String, rgb: RGB)] = [("dark", gray(0.09)), ("typical", gray(0.26)), ("light", gray(0.44))]
let bodyLc = 75.0, labelLc = 60.0, glyphLc = 30.0

for (name, glass) in backdrops {
    let card = over(Token.Color.bgCard, glass)
    // Text steps, on the cards where all reading text sits.
    check(lc(over(Token.Color.textPrimary, card), card) >= 90, "primary text is Lc 90+ on a card over \(name)")
    check(lc(over(Token.Color.textStrong, card), card) >= 90, "strong text is Lc 90+ on a card over \(name)")
    check(lc(over(Token.Color.textBody, card), card) >= bodyLc, "body text is Lc 75+ on a card over \(name)")
    check(lc(over(Token.Color.textMuted, card), card) >= labelLc, "muted text is Lc 60+ on a card over \(name)")

    // A dimmed control keeps its glyph discernible.
    let dimmed = NSColor.white.withAlphaComponent(CGFloat(alpha(Token.Color.iconDefault)) * Token.State.disabledAlpha)
    check(lc(over(dimmed, card), card) >= glyphLc, "a dimmed glyph is Lc 30+ on a card over \(name)")

    // Each hue's text step, on the washes it is drawn on. Badges and the banner sit on cards.
    for (hueName, hue) in [("accent", Token.Hue.accent), ("code", .code), ("success", .success), ("warning", .warning), ("danger", .danger)] {
        let badge = over(Token.SurfaceStyle.badge(hue).background!, card)
        check(lc(over(hue.text, badge), badge) >= labelLc, "\(hueName) badge text is Lc 60+ on its wash on a card over \(name)")
    }
    let banner = over(Token.SurfaceStyle.banner.background!, card)
    check(lc(over(Token.Hue.warning.text, banner), banner) >= labelLc, "banner text is Lc 60+ on its wash over \(name)")

    // The failed answer's headline is 13 point words on the card: body text, not a label.
    check(lc(over(Token.Hue.danger.text, card), card) >= bodyLc, "the failed answer's headline is Lc 75+ on a card over \(name)")

    // The step numbers and the code badge glyph sit on the code wash inside a step card.
    let stepBadge = over(Token.SurfaceStyle.badgeSmall(.code).background!, over(Token.SurfaceStyle.stepCard.background!, card))
    check(lc(over(Token.Hue.code.text, stepBadge), stepBadge) >= labelLc, "step numbers are Lc 60+ on their badge over \(name)")
}

// Pills and the selection bar sit on the question list, a widget fill over the glass.
// Checked on the dark and typical desktops; a white desktop lightens the glass and is reported by
// colors.py, which treats the HUD materials it cannot compute as transparent.
for (name, glass) in backdrops.prefix(2) {
    let strip = over(Token.SurfaceStyle.strip.background!, glass)
    for (hueName, hue) in [("success", Token.Hue.success), ("warning", .warning), ("danger", .danger)] {
        let pill = over(Token.SurfaceStyle.pill(hue, height: Token.Sizing.pill).background!, strip)
        check(lc(over(hue.text, pill), pill) >= labelLc, "\(hueName) pill text is Lc 60+ on the strip over \(name)")
    }
    let queued = over(Token.SurfaceStyle.pill(.neutral, height: Token.Sizing.pill).background!, strip)
    check(lc(over(Token.Color.textMuted, queued), queued) >= labelLc, "queued pill text is Lc 60+ on the strip over \(name)")
    let selected = over(Token.SurfaceStyle.highlight.background!, strip)
    check(lc(over(Token.SurfaceStyle.highlightBar.background!, selected), selected) >= glyphLc, "the selection bar is Lc 30+ on its wash over \(name)")
    check(lc(over(Token.Color.textStrong, selected), selected) >= bodyLc, "the selected question is Lc 75+ on its wash over \(name)")
    check(lc(over(Token.Color.textBody, strip), strip) >= bodyLc, "a question is Lc 75+ on the list over \(name)")
}

// A notice sits straight on the glass in the header. Its button is a second wash over it, and both take the
// hue's text step (an info notice takes body text).
for (name, glass) in backdrops.prefix(2) {
    for (hueName, hue, words) in [("success", Token.Hue.success, Token.Hue.success.text), ("warning", .warning, Token.Hue.warning.text),
                                  ("danger", .danger, Token.Hue.danger.text), ("info", .neutral, Token.Color.textBody)] {
        let notice = over(Token.SurfaceStyle.notice(hue).background!, glass)
        let button = over(Token.ControlStyle.noticeAction(hue).background, notice)
        check(lc(over(words, notice), notice) >= labelLc, "\(hueName) notice text is Lc 60+ on its wash over \(name)")
        check(lc(over(words, button), button) >= labelLc, "\(hueName) notice button text is Lc 60+ on its chip over \(name)")
    }
}

// MARK: Meaning

check(Token.Hue.warning.text.isEqual(Token.Hue.warning.solid), "gold is light enough to be its own text")
for hue in [Token.Hue.accent, .code, .success, .danger] {
    func luma(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    check(luma(components(hue.text).rgb) > luma(components(hue.solid).rgb), "a hue's text step is lighter than its solid")
}
private let hues = [Token.Hue.accent, .code, .success, .warning, .danger].map { components($0.solid).rgb }
private func hueAngle(_ c: RGB) -> Double {
    let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), d = mx - mn
    guard d > 0 else { return 0 }
    let h: Double
    if mx == c.r { h = (c.g - c.b) / d } else if mx == c.g { h = 2 + (c.b - c.r) / d } else { h = 4 + (c.r - c.g) / d }
    return (h * 60 + 360).truncatingRemainder(dividingBy: 360)
}
for (i, a) in hues.enumerated() {
    for b in hues.dropFirst(i + 1) {
        let gap = abs(hueAngle(a) - hueAngle(b))
        check(min(gap, 360 - gap) > 15, "every hue is more than 15 degrees from the others, so no two read as one color")
    }
}

// MARK: Typography

private struct Wrapped { var lines: Int; var pitch: Double; var fullLineChars: Int; var firstX: Double; var secondX: Double }

/// Lays text out in a private TextKit stack, the way the views do, and reads back what it drew.
private func wrap(_ text: NSAttributedString, width: CGFloat) -> Wrapped {
    let storage = NSTextStorage(attributedString: text)
    let manager = NSLayoutManager()
    let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    manager.addTextContainer(container)
    storage.addLayoutManager(manager)
    manager.ensureLayout(for: container)
    var rects: [NSRect] = [], used: [NSRect] = [], chars: [Int] = []
    manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, usedRect, _, glyphs, _ in
        rects.append(rect)
        used.append(usedRect)
        chars.append(manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil).length)
    }
    let pitch = rects.count > 1 ? Double((rects[rects.count - 1].minY - rects[0].minY) / CGFloat(rects.count - 1)) : Double(rects.first?.height ?? 0)
    return Wrapped(lines: rects.count, pitch: pitch, fullLineChars: chars.dropLast().max() ?? chars.first ?? 0,
                   firstX: Double(used.first?.minX ?? 0), secondX: Double(used.dropFirst().first?.minX ?? 0))
}

let sizes = [Token.Font.Size.micro, .caption, .body, .lead, .title].map { Double($0.points) }
check(strictlyIncreasing(sizes), "the type scale ascends with no repeated size")
check(Token.Font.Size.caption.points >= 12 && Token.Font.Size.micro.points >= 11, "sentence case starts at 12pt and capitals at 11pt")
check(Token.Leading.compact >= 1.4 && Token.Leading.reading >= 1.5, "wrapped text has 1.4 leading and reading text 1.5")
check(Token.Leading.heading >= 1.2 && Token.Leading.heading < Token.Leading.compact, "headings set tighter than wrapped text, never under 1.2")

let prose = String(repeating: "The interviewer asks about caching strategies, cache invalidation and the trade offs between them. ", count: 4)
for (name, font, leading) in [
    ("body", Token.Font.text(.body), Token.Leading.compact), ("caption", Token.Font.text(.caption), Token.Leading.compact),
    ("lead", Token.Font.text(.lead), Token.Leading.reading), ("code", Token.Font.mono(.code), Token.Leading.compact)
] {
    let laid = wrap(Token.Text.attributed(prose, font: font, color: .white, leading: leading), width: 240)
    check(laid.lines >= 3 && abs(laid.pitch / Double(font.pointSize) - Double(leading)) < 0.03, "\(name) text sets at \(leading) leading, measured \(laid.pitch / Double(font.pointSize))")
}

private let reading = wrap(Token.Text.attributed(prose, font: Token.Font.text(.lead), color: .white, leading: Token.Leading.reading), width: Token.Measure.reading)
check((55...75).contains(reading.fullLineChars), "the answer column holds 55-75 characters a line, not \(reading.fullLineChars)")
private let quoted = wrap(Token.Text.attributed(prose, font: Token.Font.text(.body), color: .white, leading: Token.Leading.compact), width: Token.Measure.caption)
check((55...75).contains(quoted.fullLineChars), "the quoted question holds 55-75 characters a line, not \(quoted.fullLineChars)")

let bulletFont = Token.Font.text(.lead)
let bullet = NSAttributedString(string: "•\u{00A0}" + prose, attributes: [
    .font: bulletFont,
    .paragraphStyle: Token.Text.paragraph(for: bulletFont, leading: Token.Leading.reading, hangingIndent: Token.Text.bulletIndent(for: bulletFont))
])
private let hung = wrap(bullet, width: 300)
check(hung.lines >= 2 && hung.secondX > hung.firstX + 5, "a wrapped bullet starts its second line under its words")

let overline = Token.Text.overline("ready", detail: "1.5s", color: .white)
let overlineAttributes = overline.attributes(at: 0, effectiveRange: nil)
check(overline.string == "READY 1.5s", "capitals are set from natural case and the unit keeps its case")
check((overlineAttributes[.kern] as? NSNumber)?.doubleValue ?? 0 > 0, "capitals carry letter-spacing")
check((overlineAttributes[.font] as? NSFont)?.fontName.hasPrefix(".SFNS") == true, "changing digits are tabular")
check(Token.Text.separator.contains("\u{2002}") && !Token.Text.separator.contains(" "), "one typographic separator, not runs of spaces")

// MARK: Layout

// Gaps inside a group are the base; the space between groups is at least twice that, so the eye can
// tell where one group ends: the strip's label belongs to the strip.
check(Token.FocusLayout.cardToLabel >= 2 * Token.FocusLayout.labelToStrip, "the strip's label sits at least twice as far from the card as from the strip")
check(Token.CommandBar.groupGap >= 2 * Token.CommandBar.itemGap, "the command bar's groups sit at least twice the item gap apart")
check(Token.Space.md >= 12 && Token.Space.inset >= 16, "filled controls sit 12 apart and surfaces inset 16")
check(Token.FocusLayout.labelIndent == Token.Space.inset, "text outside a card sits in a frame on the same edge as the text fields inside it")

// Everything in the bar has to fit the smallest window: 760 wide with the bar's margin on both sides.
private let barControls = 4 * Token.Sizing.control + Token.CommandBar.primaryWidth + Token.CommandBar.sourceControlWidth
    + Token.Sizing.control + Token.CommandBar.capsuleWidth + 2 * Token.Sizing.control
private let barGaps = 8 * Token.CommandBar.itemGap + 2 * Token.CommandBar.groupGap
private let barPadding = Token.CommandBar.padding.left + Token.CommandBar.padding.right
check(barControls + barGaps + barPadding <= 760 - 2 * Token.CommandBar.sideMargin, "the command bar fits the smallest window")
// Header row: the icon, the title (the app name and the interview profile), a gap of one inset, the capsule.
// The voice view is 12 in from each window edge and the header is one inset in from the voice view.
private let headerTitleRoom = (760 - 24) - 2 * Token.Space.inset - Token.Header.titleX - Token.Space.inset - Token.Header.capsuleWidth
check(headerTitleRoom >= Token.Header.minimumTitleWidth, "the header keeps room for the app name and the profile in the smallest window")

// Density: the question list takes the height of its rows and the answer takes the rest. In the
// smallest window (500 tall, the voice view 12 in from every edge) with three stacked questions, the
// answer region keeps its minimum height, and a CV strip squeezed to its digest still leaves the
// answer its own minimum.
private let smallestBarTop = Token.CommandBar.bottomMargin + Token.CommandBar.height - 12
private let smallestStack = 3 * Token.FocusLayout.stripRowHeight + Token.FocusLayout.labelBlock
private let smallestCard = (500 - 24) - Token.FocusLayout.contentTop - Token.FocusLayout.contentBottom(barTop: smallestBarTop) - smallestStack
check(smallestCard >= Token.FocusLayout.minimumCardHeight, "the smallest window leaves the answer region its minimum height beside three questions")
check(smallestCard - Token.FocusLayout.briefingGap - Token.FocusLayout.briefingMinimum >= Token.FocusLayout.minimumAnswerHeight, "a digest-only CV strip leaves the answer its minimum in the smallest window")
check(3 * Token.FocusLayout.stripRowHeight < Token.FocusLayout.minimumCardHeight, "three stacked questions are shorter than the smallest answer region")
check(Token.FocusLayout.stripRowHeight >= 32, "a question row is a comfortable target")

// MARK: Loading

// A wait shorter than the delay gets no indicator, a placeholder passes its highlight slowly, and
// content fades in quickly; a placeholder bar is no taller than the line of text it stands in for.
check(Token.Motion.loadingDelay >= 0.1 && Token.Motion.loadingDelay <= 0.5, "a wait gets an indicator after a moment, not at once and not late")
check(Token.Motion.fadeIn >= 0.1 && Token.Motion.fadeIn <= 0.3, "content fades in quickly")
check(Token.Motion.shimmer >= 1.2 && Token.Motion.shimmer <= 2.5, "the highlight passes slowly enough not to flicker")
check(Token.Motion.clockTick == 1, "a wait counts whole seconds")
check(Token.Skeleton.lineHeight <= Token.Font.Size.lead.points, "an answer placeholder bar is no taller than the line it stands in for")
check(Token.Skeleton.smallLineHeight < Token.Skeleton.lineHeight, "small text and code are shorter bars than answer text")
check(Token.Sizing.notice < 34, "a notice fits inside the 34 point header row")
check(Token.Sizing.notice >= Token.Sizing.control - 4, "a notice is tall enough to hold a button")
check(alpha(Token.Color.bgSkeletonSweep) > alpha(Token.Color.bgSkeleton), "the highlight is brighter than the bar it passes over")
check(alpha(Token.Color.bgSkeletonSweepClear) == 0 && alpha(Token.Color.bgSkeleton) > 0, "the highlight fades to nothing at its ends")

// MARK: Component styles

let widgets = [Token.SurfaceStyle.card, .codePanel, .strip, .briefing]
check(widgets.allSatisfy { $0.radius == Token.Radius.widget }, "every widget shares the widget radius")
check(widgets.allSatisfy { $0.shadow != nil && $0.border?.isEqual(Token.Color.borderWidget) == true }, "widgets rest on a shadow with only a faint edge")
check(Token.SurfaceStyle.stepCard.radius + Token.Space.inset == Token.SurfaceStyle.codePanel.radius, "a step card is concentric with the panel it sits in")
check(Token.SurfaceStyle.commandBar.radius == Token.Radius.full(Token.CommandBar.height), "the command bar is a full pill")
check(Token.SurfaceStyle.segment.border == nil && Token.SurfaceStyle.highlight.border == nil, "the selected question is a wash and a bar, not a ring")
check(Token.Selection.inset + Token.Selection.barInset + Token.Selection.barWidth + Token.Space.xs <= Token.Space.inset,
      "the selection bar ends at least 4 points before the question number")

check(alpha(Token.ControlStyle.ghost.background) == 0 && Token.ControlStyle.ghost.borderWidth == 0, "a ghost button is invisible at rest")
check([Token.ControlStyle.ghostSelected, .primary(.success), .chip(), .selected(.code)].allSatisfy { $0.borderWidth == 0 },
      "buttons are filled, never outlined")
let primary = Token.ControlStyle.primary(.success)
check(primary.glyph?.isEqual(Token.Hue.success.text) == true, "a primary button draws its glyph in the hue's text step")
check(alpha(primary.hover) > alpha(primary.background) && alpha(primary.press) > alpha(primary.hover), "primary buttons deepen on hover and press")
let chip = Token.ControlStyle.chip()
check(chip.glyph == nil, "chips color their own title")
check(alpha(chip.hover) > alpha(chip.background) && alpha(chip.press) > alpha(chip.hover), "chips deepen on hover and press")

// MARK: Source hygiene

// Views hold no raw color, alpha, size, radius, border, shadow or delay. They name a token, so a
// change of look is made in Presentation/Styling/DesignTokens.swift and nowhere else.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func source(_ path: String) -> String { (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)) ?? "" }
let guarded = [
    "Presentation/Components/InterviewFocusComponents.swift",
    "Presentation/Components/SkeletonView.swift",
    "Presentation/Components/FocusNoticeView.swift",
    "Presentation/Components/CodePanelView.swift",
    "Presentation/InterviewFocusController.swift",
    "Presentation/CodePanelController.swift"
]
let banned: [(pattern: String, what: String)] = [
    (#"withAlphaComponent\("#, "a raw alpha; use tint(_:), edge(_:) or a Token.Color alias"),
    (#"NSColor\((white|red|calibrated|deviceWhite|srgbRed|displayP3Red)"#, "a raw color; add it to Token.Global.Palette"),
    (#"NSColor\.(white|black|apple[A-Z]\w*|claude[A-Z]\w*|system(Blue|Green|Red|Orange|Yellow|Purple|Pink|Gray|Teal|Indigo|Mint|Cyan|Brown))\b"#, "a palette color; use a Token.Hue or Token.Color alias"),
    (#"(?<![\w)\]])\.(white|black|apple[A-Z]\w*|system(Blue|Green|Red|Orange|Yellow|Purple|Pink|Gray|Teal|Indigo|Mint|Cyan|Brown))\b"#, "an implicit palette color; use a Token.Hue or Token.Color alias"),
    (#"\b(secondary|tertiary|quaternary)?LabelColor\b"#, "a system label color; use a Token.Color text step"),
    (#"(textColor|contentTintColor|foregroundColor)\b[^\n]*\.solid\b"#, "a solid hue as text; words and glyphs use the hue's text step"),
    (#"ofSize: *[0-9]"#, "a font size; use Token.Font"),
    (#"pointSize: *[0-9]"#, "a symbol size; use Token.Font.symbol"),
    (#"cornerRadius = *[0-9]"#, "a corner radius; use Token.Radius or a SurfaceStyle"),
    (#"borderWidth = *[0-9]"#, "a border width; use Token.Border or a style"),
    (#"shadow(Opacity|Radius|Offset|Color) *="#, "a shadow; use Token.Elevation"),
    (#"asyncAfter\(deadline: *\.now\(\) *\+ *[0-9]"#, "a raw delay; use Token.Motion"),
    (#"Token\.Global\."#, "a global token; views use alias or component tokens"),
    (#"Token\.Font\.(text|digits|mono)\([^)]*\.(bold|heavy|black|light|thin|ultraLight)\b"#, "a weight outside regular, medium and semibold"),
    (#"\x22[A-Z]{3,}( [A-Z]+)*\x22"#, "capitals in a string; store natural case and set capitals with Token.Text.overline"),
    (#"\x22[^\x22]*\.\.\.[^\x22]*\x22"#, "three periods; use the ellipsis character"),
    (#"\x22[^\x22]* +· +[^\x22]*\x22"#, "a middle dot between spaces; use Token.Text.separator")
]
for file in guarded {
    let text = source(file)
    check(!text.isEmpty, "\(file) is readable from the repo root")
    check(text.contains("Token."), "\(file) uses tokens")
    for (number, line) in text.components(separatedBy: "\n").enumerated() {
        let code = line.trimmingCharacters(in: .whitespaces)
        if code.hasPrefix("//") { continue }
        for (pattern, what) in banned {
            let range = NSRange(line.startIndex..., in: line)
            let hit = (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: line, range: range) != nil
            check(!hit, "\(file):\(number + 1) has \(what): \(code)")
        }
    }
}

// MARK: Writing
// The window says things one way. A string that says it another way (a second word for the same action, a
// shrug in place of a cause, a title in Title Case) is found here, in the files that hold the window's copy.
let copyFiles = guarded + [
    "Presentation/VoiceInterviewController.swift",
    "Presentation/ScreenshotManager.swift",
    "Presentation/InterviewExport.swift",
    "Presentation/AudioSourceController.swift",
    "Presentation/TimelineManager.swift",
    "Presentation/MenuBarSetup.swift",
    "Domain/Model/FeedbackNotice.swift",
    "Domain/Model/AudioSourceSelection.swift",
    "Domain/Model/ScreenshotPresentation.swift",
    "Domain/Model/WaitProgress.swift",
    "Domain/Model/TopicTitle.swift"
]
let bannedCopy: [(pattern: String, what: String)] = [
    (#"\x22[^\x22]*\b(Oops|Whoops)\b[^\x22]*\x22"#, "an interjection; say what happened"),
    (#"\x22[^\x22]*\bPlease\b[^\x22]*\x22"#, "please; state the action"),
    (#"\x22[^\x22]*[A-Za-z]!(?=[ \x22])[^\x22]*\x22"#, "an exclamation mark"),
    (#"\x22[^\x22]*Something went wrong[^\x22]*\x22"#, "a shrug; say what failed"),
    (#"\x22[^\x22]*\bQuestion burst\b[^\x22]*\x22"#, "Question burst; the window says Questions"),
    (#"\x22[^\x22]*\bInterview Assistant\b[^\x22]*\x22"#, "Interview Assistant; the app is Interview Master"),
    (#"\x22[^\x22]*Command-Shift[^\x22]*\x22"#, "a spelled-out shortcut; shortcuts are glyphs (⌘⇧M)"),
    (#"\x22Retry\x22"#, "Retry; the window says Try again"),
    (#"\x22[^\x22]*\bshots?\b[^\x22]*\x22"#, "shot; the window says screenshot"),
    (#"\x22[^\x22]*\b[Rr]esume\b(?! saved)[^\x22]*\x22"#, "resume; the window says CV"),
    (#"(messageText *= *|showAlert\(title: *)\x22[A-Z]\w*( [A-Z]\w*){2,}\x22"#, "an alert title in Title Case; alert titles are sentence case (menu items keep the platform's Title Case)")
]
let notCopy = ["StealthLogger", "NSLog", "debugLog", "print(", "Notification.Name", "forKey", "UserDefaults"]
for file in copyFiles {
    for (number, line) in source(file).components(separatedBy: "\n").enumerated() {
        let code = line.trimmingCharacters(in: .whitespaces)
        if code.hasPrefix("//") || notCopy.contains(where: { line.contains($0) }) { continue }
        for (pattern, what) in bannedCopy {
            let range = NSRange(line.startIndex..., in: line)
            let hit = (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: line, range: range) != nil
            check(!hit, "\(file):\(number + 1) has \(what): \(code)")
        }
    }
}

// The consent dialog names the service that gets the screenshots; it must not hardcode one company.
let screenshotManager = source("Presentation/ScreenshotManager.swift")
check(!screenshotManager.contains("Anthropic's Claude AI service") && screenshotManager.contains("recipient.service"),
      "the consent dialog names the provider in use, not a fixed company")

// The mute button is drawn by the audio controller, which also holds timeouts that are not styling.
let audioController = source("Presentation/AudioSourceController.swift")
check(audioController.contains("audioMuteButton?.contentTintColor") && audioController.contains("Token.Hue.success.text"),
      "the mute button takes its glyph color from the tokens")
check(!audioController.contains("appleGreen") && !audioController.contains("systemOrange") && !audioController.contains("secondaryLabelColor"),
      "the mute button holds no raw color")

// MARK: Appearance

let windowFactory = source("Presentation/Windows/WindowFactory.swift")
let mainWindow = windowFactory.components(separatedBy: "static func createMainWindow").dropFirst().first?.components(separatedBy: "static func").first ?? ""
check(mainWindow.contains("window.appearance = NSAppearance(named: .darkAqua)"),
      "the main window pins the dark appearance; its text tokens are white and its glass would turn light on a light system")

// MARK: Code colors

// Syntax colors are read token by token: Lc 60 on the code well, plain code 75. Comments are the
// quietest token and stay neutral, so they never share a hue with types or decorators.
let highlighter = source("Presentation/Styling/SyntaxHighlighter.swift")
private var syntax: [String: RGB] = [:]
let syntaxPattern = try! NSRegularExpression(pattern: #"private let (\w+) = NSColor\(red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+), alpha: 1\.0\)"#)
for match in syntaxPattern.matches(in: highlighter, range: NSRange(highlighter.startIndex..., in: highlighter)) {
    func group(_ i: Int) -> String { String(highlighter[Range(match.range(at: i), in: highlighter)!]) }
    syntax[group(1)] = RGB(r: Double(group(2))!, g: Double(group(3))!, b: Double(group(4))!)
}
for name in ["keyword", "type", "string", "number", "comment", "function", "plain", "decorator"] {
    check(syntax[name] != nil, "the highlighter defines \(name)")
}
for (name, glass) in backdrops {
    let well = over(Token.Color.bgCode, over(Token.Color.bgInset, over(Token.Color.bgCard, glass)))
    for (token, color) in syntax {
        check(lc(color, well) >= (token == "plain" ? bodyLc : labelLc), "\(token) code is readable on the code well over \(name)")
    }
}
if let comment = syntax["comment"] {
    check(max(comment.r, comment.g, comment.b) - min(comment.r, comment.g, comment.b) < 0.12, "comments are neutral, not a hue another token owns")
}

let buildSources = source("build.sh")
check(buildSources.contains("Presentation/Styling/DesignTokens.swift"), "the app builds the token file")

print("DesignTokens: \(checks) checks passed")
