import Cocoa

/// Design tokens for the interview window: the answer card, question burst, command bar and the
/// docked code panel.
///
/// Three tiers, each built only from the one above it:
/// - Global: raw values (palette, opacity ramp, scales). Only this file reads them.
/// - Alias: what a value means (text, background, border, hue). Views use these.
/// - Component: one component's decisions, composed from aliases (surface and control styles).
///
/// Views hold no raw color, alpha, radius, font size or shadow; `Tests/test_design_tokens.swift` checks.
/// Names read {category}{Property}{Variant}{State}, for example `Token.Color.borderDefault`.
/// Scales reuse `LayoutConstants` wherever its steps already fit.
///
/// The palette is light on dark: the window pins the dark appearance so the glass behind it is dark.
/// Contrast is APCA Lc, measured from the rendered layers by `Scripts/focus-ui-qa/colors.py`:
/// body text needs 75, labels 60, glyphs and outlines 30.
enum Token {

    // MARK: - Tier 1: Global

    enum Global {
        enum Palette {
            static let white = NSColor.white
            static let black = NSColor.black
            static let green = NSColor.appleGreen
            static let greenLight = NSColor(red: 0.412, green: 0.905, blue: 0.512, alpha: 1)
            static let gold = NSColor.appleGold
            static let red = NSColor.appleRed
            static let redLight = NSColor(red: 1.0, green: 0.88, blue: 0.86, alpha: 1)
            /// The Calendar widget's event color: the app's accent.
            static let magenta = NSColor(red: 0.80, green: 0.27, blue: 0.93, alpha: 1)
            static let magentaLight = NSColor(red: 0.93, green: 0.68, blue: 1.0, alpha: 1)
            /// The cool end of the Weather widget's temperature bar: code.
            static let cyan = NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1)
            static let cyanLight = NSColor(red: 0.62, green: 0.89, blue: 1.0, alpha: 1)
            static let charcoal = NSColor(white: 0.035, alpha: 1)
            static let slate = NSColor(red: 0.075, green: 0.085, blue: 0.10, alpha: 1)
            /// The near-black of a macOS widget (Calendar), for the surfaces that are read.
            static let graphite = NSColor(red: 0.105, green: 0.105, blue: 0.115, alpha: 1)
            /// The cool gray of a macOS widget (Weather), for the surfaces that are glanced at.
            static let storm = NSColor(red: 0.15, green: 0.16, blue: 0.185, alpha: 1)
        }

        /// One opacity ramp shared by text, lines, washes and scrims.
        enum Opacity {
            static let o06: CGFloat = 0.06
            static let o10: CGFloat = 0.10
            static let o16: CGFloat = 0.16
            static let o28: CGFloat = 0.28
            static let o30: CGFloat = 0.30
            static let o45: CGFloat = 0.45
            static let o55: CGFloat = 0.55
            static let o66: CGFloat = 0.66
            static let o72: CGFloat = 0.72
            static let o80: CGFloat = 0.80
            static let o85: CGFloat = 0.85
            static let o90: CGFloat = 0.90
            static let o94: CGFloat = 0.94
        }
    }

    // MARK: - Tier 2: Alias

    /// How strongly a hue washes the surface behind its content.
    enum Tint {
        case faint, soft, medium, strong

        var alpha: CGFloat {
            switch self {
            case .faint: return Global.Opacity.o06
            case .soft: return Global.Opacity.o10
            case .medium: return Global.Opacity.o16
            case .strong: return Global.Opacity.o28
            }
        }
    }

    /// How strongly a hue outlines a surface.
    enum Edge {
        case faint, soft, regular, strong, active

        var alpha: CGFloat {
            switch self {
            case .faint: return Global.Opacity.o16
            case .soft: return Global.Opacity.o30
            case .regular: return Global.Opacity.o45
            case .strong: return Global.Opacity.o55
            case .active: return Global.Opacity.o80
            }
        }
    }

    enum Color {
        // Text on the cards, strongest to weakest. There is no step below `textMuted`: the ones that
        // were (0.66, 0.55) measured Lc 38-59 and are gone. Dimmed controls use `State.dimmedAlpha`.
        static let textPrimary = Global.Palette.white
        static let textStrong = Global.Palette.white.withAlphaComponent(Global.Opacity.o94)
        /// Reading text. Lc 84 on a card.
        static let textBody = Global.Palette.white.withAlphaComponent(Global.Opacity.o85)
        /// Labels and captions. Lc 66 on a card. Text drawn straight on the glass uses `textBody`.
        static let textMuted = Global.Palette.white.withAlphaComponent(Global.Opacity.o72)

        static let iconDefault = textBody
        static let iconSelected = textPrimary

        /// The filled surfaces of the Solid level.
        static let bgCard = Global.Palette.graphite
        static let bgWidget = Global.Palette.storm
        static let bgCodePanel = Global.Palette.graphite
        static let bgCode = Global.Palette.slate
        static let bgChrome = Global.Palette.graphite
        /// The dark layer over the blur, which the background slider strengthens.
        static func bgGlassFloor(alpha: CGFloat) -> NSColor { Global.Palette.graphite.withAlphaComponent(alpha) }
        /// Behind everything when the system asks for less transparency.
        static let bgSolidWindow = Global.Palette.graphite
        /// The two ends of the fade that says a card has more below.
        static let bgFadeClear = Global.Palette.graphite.withAlphaComponent(0)
        static var bgFadeSolid: NSColor { Transparency.floating ? bgFadeClear : bgCard }
        /// A card resting on a card.
        static let bgInset = Global.Palette.white.tint(.faint)
        static let bgHover = Global.Palette.white.tint(.soft)
        static let bgPressed = Global.Palette.white.tint(.medium)
        static let bgSelected = Global.Palette.white.tint(.medium)
        /// A bar standing where a line of text will be, and the highlight that passes over it.
        static let bgSkeleton = Global.Palette.white.tint(.soft)
        static let bgSkeletonSweep = Global.Palette.white.tint(.medium)
        static let bgSkeletonSweepClear = Global.Palette.white.withAlphaComponent(0)
        /// The color of a shape that only cuts an area out of another layer; it is never seen.
        static let maskOpaque = Global.Palette.white

        static let borderSubtle = Global.Palette.white.withAlphaComponent(Global.Opacity.o10)
        /// The light catching a widget's edge: seen, never read as a line.
        static let borderWidget = Global.Palette.white.withAlphaComponent(Global.Opacity.o06)
        static let borderDefault = Global.Palette.white.edge(.faint)
        static let borderHover = Global.Palette.white.edge(.soft)
        static let separator = Global.Palette.white.edge(.faint)
    }

    /// A hue and the two ways it is used. `solid` is for fills, dots, washes and outlines. `text` is
    /// for words, glyphs and rings drawn on those washes: a solid hue is too dark to read as text there
    /// (green measured Lc 29-57, red 23-40, blue 24-41 against the 60 that labels need).
    struct Hue {
        let solid: NSColor
        let text: NSColor

        func tint(_ level: Tint) -> NSColor { solid.tint(level) }
        func edge(_ level: Edge) -> NSColor { solid.edge(level) }

        /// The app's own hue: selection, the answer the selection points at, and the app's name. The
        /// magenta of an event in the Calendar widget.
        static let accent = Hue(solid: Global.Palette.magenta, text: Global.Palette.magentaLight)
        /// The second accent, for code only, so the code panel reads apart from the answer card.
        static let code = Hue(solid: Global.Palette.cyan, text: Global.Palette.cyanLight)
        /// Ready, listening, go.
        static let success = Hue(solid: Global.Palette.green, text: Global.Palette.greenLight)
        /// Working, or needs attention. Gold is already light enough to be its own text.
        static let warning = Hue(solid: Global.Palette.gold, text: Global.Palette.gold)
        /// Failed, stop.
        static let danger = Hue(solid: Global.Palette.red, text: Global.Palette.redLight)
        static let neutral = Hue(solid: Global.Palette.white, text: Color.textBody)
    }

    enum Space {
        static let xs = LayoutConstants.Spacing.xs
        static let sm = LayoutConstants.Spacing.sm
        static let md = LayoutConstants.Spacing.md
        /// Window and column inset.
        static let inset: CGFloat = 16
    }

    enum Sizing {
        static let control = LayoutConstants.IconButton.size
        static let controlSmall: CGFloat = 26
        static let badge: CGFloat = 24
        static let badgeSmall: CGFloat = 20
        static let dot: CGFloat = 8
        /// Height of a status pill.
        static let pill: CGFloat = 16
        /// Height of the notice in the header: a little under the header's 34.
        static let notice: CGFloat = 28
    }

    /// The bars of a loading placeholder: as tall as the line of text they stand in for.
    enum Skeleton {
        /// A line of answer text.
        static let lineHeight: CGFloat = 12
        /// A line of small text or of code.
        static let smallLineHeight: CGFloat = 9
        /// The bullet in front of an answer line.
        static let dot: CGFloat = 6
    }

    enum Radius {
        static let sm = LayoutConstants.CornerRadius.small
        static let md = LayoutConstants.CornerRadius.medium
        static let lg = LayoutConstants.CornerRadius.large
        /// A widget's corner, as on the macOS desktop. What sits inside one an inset in is `widget - inset`.
        static let widget: CGFloat = 22
        /// Concentric with a widget for something `inset` points inside it.
        static func inside(widget inset: CGFloat) -> CGFloat { widget - inset }
        /// Full rounding for a shape this tall, so its ends are semicircles.
        static func full(_ side: CGFloat) -> CGFloat { side / 2 }
    }

    enum Border {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
    }

    /// Sizes are points (one css px each). Sentence-case text starts at `caption`; `micro` is only for
    /// capitals, which stand taller than lowercase at the same size. Weights are regular, medium and
    /// semibold: emphasis is one step up, never bold.
    enum Font {
        struct Size {
            let points: CGFloat
            static let micro = Size(points: LayoutConstants.Typography.captionSmall)
            static let caption = Size(points: 12)
            static let body = Size(points: LayoutConstants.Typography.caption)
            static let lead = Size(points: LayoutConstants.Typography.body)
            static let title = Size(points: LayoutConstants.Typography.bodyLarge)
            static let code = Size(points: 14)
        }

        static func text(_ size: Size, _ weight: NSFont.Weight = .regular) -> NSFont {
            .systemFont(ofSize: size.points, weight: weight)
        }

        static func digits(_ size: Size, _ weight: NSFont.Weight = .regular) -> NSFont {
            .monospacedDigitSystemFont(ofSize: size.points, weight: weight)
        }

        static func mono(_ size: Size, _ weight: NSFont.Weight = .regular) -> NSFont {
            .monospacedSystemFont(ofSize: size.points, weight: weight)
        }

        static func symbol(_ size: Size, _ weight: NSFont.Weight = .semibold) -> NSImage.SymbolConfiguration {
            NSImage.SymbolConfiguration(pointSize: size.points, weight: weight)
        }
    }

    /// Line height as a multiple of the font size.
    enum Leading {
        /// Text read in lines: the live answer.
        static let reading: CGFloat = 1.5
        /// Wrapped labels, descriptions, quotes and code.
        static let compact: CGFloat = 1.4
        /// Headings: large type sets tight, like the widgets' titles.
        static let heading: CGFloat = 1.25
    }

    /// The longest line of text, about 74 characters at the size it is set in.
    enum Measure {
        /// The live answer, in `Font.Size.lead`. Ordinary prose holds about 71 characters here; a line of
        /// narrow letters (a long bullet that begins with a run of short words) held 76 at 488.
        static let reading: CGFloat = 470
        /// The question quoted above it, and the CV strip, in `Font.Size.body`.
        static let caption: CGFloat = 440
        /// The line under a code step's file name, in `Font.Size.caption`.
        static let note: CGFloat = 400
    }

    enum Text {
        /// Between the parts of a meta line. Two spaces would collapse or double; an en space does not.
        static let separator = "\u{2002}·\u{2002}"
        /// Capitals get a twentieth of an em of letter-spacing so they do not crowd.
        static let capsTracking: CGFloat = 0.05

        /// Small capitals are stored in natural case and set in capitals here. `detail` is left as it is
        /// (a latency such as "1.5s" keeps its lowercase unit) and its digits stay tabular.
        static func overline(_ caps: String, detail: String = "", joiner: String = " ", color: NSColor) -> NSAttributedString {
            let font = Font.digits(.micro, .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .kern: Font.Size.micro.points * capsTracking
            ]
            let text = NSMutableAttributedString(string: caps.uppercased(with: .current), attributes: attributes)
            if !detail.isEmpty { text.append(NSAttributedString(string: joiner + detail, attributes: attributes)) }
            return text
        }

        /// Space between lines that brings a font's natural line height up to `leading` times its size.
        static func lineSpacing(for font: NSFont, leading: CGFloat) -> CGFloat {
            max(0, font.pointSize * leading - ceil(NSLayoutManager().defaultLineHeight(for: font)))
        }

        /// A paragraph style for wrapped text. `hangingIndent` sets the wrapped lines of a bullet under
        /// its text. Lines break so a last line is never a single short word.
        static func paragraph(for font: NSFont, leading: CGFloat, hangingIndent: CGFloat = 0, spacingAfter: CGFloat = 0) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = lineSpacing(for: font, leading: leading)
            style.headIndent = hangingIndent
            style.paragraphSpacing = spacingAfter
            style.lineBreakStrategy = .pushOut
            return style
        }

        /// How far a wrapped bullet line indents: the width of "• " in the text's font, so the second
        /// line starts under the words and not under the bullet.
        static func bulletIndent(for font: NSFont) -> CGFloat {
            ceil(("•\u{00A0}" as NSString).size(withAttributes: [.font: font]).width)
        }

        static func attributed(_ string: String, font: NSFont, color: NSColor, leading: CGFloat, alignment: NSTextAlignment = .natural) -> NSAttributedString {
            let style = paragraph(for: font, leading: leading)
            style.alignment = alignment
            return NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        }
    }

    struct Shadow {
        let color: NSColor
        let opacity: Float
        let radius: CGFloat
        let offset: CGSize
    }

    enum Elevation {
        /// A widget resting on the desktop: a wide, soft shadow and no outline.
        static let raised = Shadow(color: Global.Palette.black, opacity: 0.16, radius: 12, offset: CGSize(width: 0, height: -3))
        static let floating = Shadow(color: Global.Palette.black, opacity: 0.32, radius: 20, offset: CGSize(width: 0, height: -6))
        /// Follows the shape of the text itself, because the view behind it has no fill.
        static let textHalo = Shadow(color: Global.Palette.black, opacity: 0.75, radius: 3, offset: .zero)
    }

    /// The selected question, drawn like an event in the Calendar widget: a wash in the accent with a bar
    /// down its leading edge.
    enum Selection {
        /// How far the wash sits inside its row.
        static let inset: CGFloat = 6
        static let barWidth: CGFloat = 3
        /// From the wash's leading edge to the bar.
        static let barInset: CGFloat = 3
        /// From the wash's top and bottom to the bar's ends.
        static let barVerticalInset: CGFloat = 7
        static let wash = Hue.accent.tint(.medium)
        /// The accent's text step: the solid measured Lc 19-30 against the list.
        static let bar = Hue.accent.text
        static let radius = Radius.inside(widget: inset)
    }

    enum Motion {
        /// How long the "Copied" checkmark stays before the copy icon returns.
        static let feedbackHold: TimeInterval = 1.2
        /// How long "Answer ready" stays in the activity capsule.
        static let readyHold: TimeInterval = 1.4
        /// A wait shorter than this gets no indicator: it would flash and be gone.
        static let loadingDelay: TimeInterval = 0.2
        /// Content that arrives fades in over this long, and the placeholder it replaces fades out.
        static let fadeIn: TimeInterval = 0.18
        /// One pass of the highlight across a placeholder.
        static let shimmer: TimeInterval = 1.6
        /// How often a wait counts its seconds.
        static let clockTick: TimeInterval = 1
        /// Whether the person asked the system for less motion. The QA driver replaces it to check both.
        static var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    }

    enum State {
        /// A control with nothing to act on right now (no code to copy, no version to step to). Its
        /// glyph still measures Lc 33, above the 30 that disabled controls need.
        static let disabledAlpha: CGFloat = Global.Opacity.o55
        /// A control that is available but has nothing to show yet.
        static let idleAlpha: CGFloat = Global.Opacity.o55
    }

    // MARK: - Tier 3: Component

    /// How a card, strip, pill or bar looks: shape, fill, outline and lift.
    struct SurfaceStyle {
        var radius: CGFloat
        var background: NSColor?
        var border: NSColor?
        var borderWidth: CGFloat = Border.hairline
        var shadow: Shadow?
        var curve: CALayerCornerCurve = .continuous

        /// Text with nothing behind it: only the halo that carries it over a bright background.
        static let floatingText = SurfaceStyle(radius: 0, shadow: Elevation.textHalo)

        private static func filled(_ radius: CGFloat, _ background: NSColor, border: NSColor? = Color.borderWidget) -> SurfaceStyle {
            Transparency.floating ? floatingText : SurfaceStyle(radius: radius, background: background, border: border)
        }

        static var card: SurfaceStyle { filled(Radius.widget, Color.bgCard) }
        static var codePanel: SurfaceStyle { filled(Radius.widget, Color.bgCodePanel) }
        static var briefing: SurfaceStyle { filled(Radius.widget, Color.bgWidget) }
        static var strip: SurfaceStyle { filled(Radius.widget, Color.bgWidget) }
        static var commandBar: SurfaceStyle { filled(Radius.full(CommandBar.height), Color.bgChrome, border: nil) }
        /// A step card sits one inset inside the code panel, so its corner is the panel's less that inset.
        static let stepCard = SurfaceStyle(radius: Radius.inside(widget: Space.inset), background: Color.bgInset)
        static var codeWell: SurfaceStyle { SurfaceStyle(radius: Radius.sm, background: Transparency.floating ? nil : Color.bgCode) }
        static var banner: SurfaceStyle { SurfaceStyle(radius: Radius.md, background: Transparency.floating ? nil : Hue.warning.tint(.soft)) }

        static func badge(_ hue: Hue) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(Sizing.badge), background: hue.tint(.medium), curve: .circular)
        }

        static func badgeSmall(_ hue: Hue) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(Sizing.badgeSmall), background: hue.tint(.medium), curve: .circular)
        }

        static func tag(_ hue: Hue) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.sm, background: hue.tint(.medium), curve: .circular)
        }

        static func pill(_ hue: Hue, height: CGFloat) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(height), background: Transparency.floating ? nil : hue.tint(.soft), curve: .circular)
        }

        /// The activity capsule; `update` colors its wash and outline by state.
        static func capsule(height: CGFloat) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(height))
        }

        /// A line of feedback in the header: washed in the hue of what it says.
        static func notice(_ hue: Hue) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(Sizing.notice), background: Transparency.floating ? nil : hue.tint(.soft), curve: .circular)
        }

        static func dot(_ hue: Hue) -> SurfaceStyle {
            SurfaceStyle(radius: Radius.full(Sizing.dot), background: hue.solid, curve: .circular)
        }

        /// One question in the list. The row itself is bare; the selected one draws `highlight` inside it.
        static let segment = SurfaceStyle(radius: Radius.md)

        /// The wash behind the selected question.
        static var highlight: SurfaceStyle { SurfaceStyle(radius: Selection.radius, background: Transparency.floating ? nil : Selection.wash) }

        /// The bar down the selected question's leading edge.
        static let highlightBar = SurfaceStyle(radius: Radius.full(Selection.barWidth), background: Selection.bar, curve: .circular)
    }

    /// How a hover button looks at rest, hovered, pressed and outlined.
    struct ControlStyle {
        var glyph: NSColor?
        var background: NSColor
        var hover: NSColor
        var press: NSColor
        var border: NSColor
        var hoverBorder: NSColor
        var borderWidth: CGFloat

        static let ghost = ControlStyle(
            glyph: Color.iconDefault, background: .clear, hover: Color.bgHover, press: Color.bgPressed,
            border: .clear, hoverBorder: Color.borderHover, borderWidth: 0
        )

        /// Controls have no resting fill while content floats; hover still answers the pointer.
        private static func rest(_ fill: NSColor) -> NSColor { Transparency.floating ? .clear : fill }

        static var ghostSelected: ControlStyle { ControlStyle(
            glyph: Color.iconSelected, background: rest(Color.bgSelected), hover: Color.bgHover, press: Color.bgPressed,
            border: .clear, hoverBorder: .clear, borderWidth: 0
        ) }

        /// A ghost button whose panel is open: lit in the panel's hue.
        static func selected(_ hue: Hue) -> ControlStyle {
            ControlStyle(
                glyph: hue.text, background: rest(hue.tint(.medium)), hover: hue.tint(.strong), press: hue.tint(.strong),
                border: .clear, hoverBorder: .clear, borderWidth: 0
            )
        }

        /// The main action of a bar, tinted in the hue of what it does: a filled capsule, no outline.
        static func primary(_ hue: Hue) -> ControlStyle {
            ControlStyle(
                glyph: hue.text, background: rest(hue.tint(.soft)), hover: hue.tint(.medium), press: hue.tint(.strong),
                border: .clear, hoverBorder: .clear, borderWidth: 0
            )
        }

        /// A button inside a notice, which is already washed in its hue: a fainter wash of the same hue.
        static func noticeAction(_ hue: Hue) -> ControlStyle {
            ControlStyle(
                glyph: nil, background: rest(hue.tint(.faint)), hover: hue.tint(.medium), press: hue.tint(.strong),
                border: .clear, hoverBorder: .clear, borderWidth: 0
            )
        }

        /// A small text action, filled like a macOS gray button; neutral unless given a hue.
        static func chip(_ hue: Hue = .neutral) -> ControlStyle {
            ControlStyle(
                glyph: nil, background: rest(hue.tint(.soft)), hover: hue.tint(.medium), press: hue.tint(.strong),
                border: .clear, hoverBorder: .clear, borderWidth: 0
            )
        }
    }

    enum Header {
        /// The most the status capsule grows to: the recording dot, the sparkle, "AI working · Q9", the
        /// waveform and a timer past two hours. It is as wide as what it says, so it is usually less.
        static let capsuleWidth: CGFloat = 300
        /// Where the title starts from the app icon's left edge.
        static let titleX: CGFloat = 30
        /// The title keeps at least this much room in the smallest window: the app name, then as much
        /// of the interview profile as fits.
        static let minimumTitleWidth: CGFloat = 260
    }

    enum CommandBar {
        static let height: CGFloat = 44
        static let bottomMargin: CGFloat = 14
        static let sideMargin: CGFloat = 28
        static let itemGap: CGFloat = 6
        static let padding = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        /// Between the groups of the bar (navigation, start, audio); inside a group the gap is `itemGap`.
        static let groupGap: CGFloat = 16
        static let capsuleWidth: CGFloat = 162
    }

    /// Vertical geometry of the interview window's left column, bottom to top: the bar, the question
    /// list (16 above the bar), the list's label (6 above the list) and the card (16 above the label).
    /// Gaps inside a group are 6, between groups 16 or more, so the label belongs to the list. The list
    /// takes what its rows need and the card takes everything else, because the card is what is read.
    enum FocusLayout {
        /// Space from the top of the content to the first card, clear of the title row.
        static let contentTop: CGFloat = 26
        /// The strip when its questions sit side by side (one column, code panel closed).
        static let burstHeight: CGFloat = 74
        /// One question in the strip when they are stacked (code panel open): number, state, one line.
        static let stripRowHeight: CGFloat = 40
        /// The card region (the answer, and the CV strip above it) never gets less than this.
        static let minimumCardHeight: CGFloat = 160
        /// Of the answer card at least this much stays in view beside the CV strip: its title row, the
        /// question and a few lines of the answer.
        static let minimumAnswerHeight: CGFloat = 120
        /// The gap between the CV strip and the answer card under it.
        static let briefingGap: CGFloat = Space.sm
        /// The CV strip squeezed to its digest line alone.
        static let briefingMinimum: CGFloat = 44
        static let labelHeight: CGFloat = 14
        static let stripToBar: CGFloat = Space.inset
        static let labelToStrip: CGFloat = 6
        static let cardToLabel: CGFloat = 16
        /// Text outside a card sits in a frame one inset in, like the text fields inside the cards and
        /// the strip, so both start their glyphs on the same edge (a text field draws 2 points inside).
        static let labelIndent: CGFloat = Space.inset
        static let labelBlock: CGFloat = labelToStrip + labelHeight + cardToLabel

        /// Where the strip's bottom edge sits, measured from the bottom of the voice content view.
        static func contentBottom(barTop: CGFloat) -> CGFloat { barTop + stripToBar }
    }

    /// The bars of the activity capsule.
    /// Content floats straight on the desktop: no cards, pills, outlines or dark tint. Text never fades,
    /// and a soft halo carries it over bright backgrounds. Solid is the way back to filled surfaces.
    enum Transparency {
        /// The level in force, set from the setting and the system's Reduce Transparency.
        static var level: SurfaceTransparency = .balanced
        static var floating: Bool { level != .solid }

        /// The first stretch of the slider fades the blur in; the rest darkens it.
        private static let blurShare = 0.3

        /// How strong the blur of the desktop is at a background transparency from 0 to 1.
        static func blurAlpha(transparency: Double) -> CGFloat {
            CGFloat(min(1, (1 - transparency) / blurShare))
        }

        /// How dark the layer over the blur is at a background transparency from 0 to 1.
        static func tintAlpha(transparency: Double) -> CGFloat {
            CGFloat(max(0, (1 - transparency - blurShare) / (1 - blurShare))) * Global.Opacity.o94
        }
    }

    enum Waveform {
        static let barWidth: CGFloat = 2
        static let barHeights: [CGFloat] = [5, 9, 13, 8, 15, 10, 13, 8, 5]
        static let activeAlpha = Global.Opacity.o94
        static let idleAlpha = Global.Opacity.o66
        static let restScale: CGFloat = 0.42
        static let peakScaleEven: CGFloat = 1.0
        static let peakScaleOdd: CGFloat = 0.78
        static let period: TimeInterval = 0.28
        static let periodStep: TimeInterval = 0.055
        static let stagger: TimeInterval = 0.035
        /// The working dot breathes slowly: it says "still going", it does not ask to be looked at.
        static let pulsePeriod: TimeInterval = 0.9
        static let pulseLowOpacity: Float = 0.4

        static func barColor(_ hue: Hue, animated: Bool) -> NSColor {
            hue.solid.withAlphaComponent(animated ? activeAlpha : idleAlpha)
        }
    }
}

// MARK: - Applying tokens

extension NSColor {
    /// This hue as a wash behind content.
    func tint(_ level: Token.Tint) -> NSColor { withAlphaComponent(level.alpha) }

    /// This hue as an outline.
    func edge(_ level: Token.Edge) -> NSColor { withAlphaComponent(level.alpha) }
}

extension CALayer {
    func apply(_ shadow: Token.Shadow) {
        shadowColor = shadow.color.cgColor
        shadowOpacity = shadow.opacity
        shadowRadius = shadow.radius
        shadowOffset = shadow.offset
    }
}

extension NSView {
    func applySurface(_ style: Token.SurfaceStyle) {
        wantsLayer = true
        guard let layer else { return }
        layer.cornerRadius = style.radius
        layer.cornerCurve = style.curve
        layer.backgroundColor = style.background?.cgColor
        layer.borderWidth = style.border == nil ? 0 : style.borderWidth
        layer.borderColor = style.border?.cgColor
        if let shadow = style.shadow { layer.apply(shadow) } else { layer.shadowOpacity = 0 }
    }
}

extension NSVisualEffectView {
    /// The frosted look shared by the cards and the command bar.
}
