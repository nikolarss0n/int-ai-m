// Spliced into a copy of interview_master.swift (its own @main removed). Drives the real
// InterviewMasterDelegate UI with canned data: no network, no audio, no API keys.

@available(macOS 14.0, *)
final class FocusQADriver {
    let delegate: InterviewMasterDelegate
    let outDir: URL
    var step = 0
    var queue: [(String, () -> Void)] = []
    var log: [String] = []

    init(delegate: InterviewMasterDelegate, outDir: URL) {
        self.delegate = delegate
        self.outDir = outDir
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func allViews(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(allViews) }

    func visibleTexts() -> [String] {
        guard let root = delegate.window.contentView else { return [] }
        return allViews(root).compactMap { v -> String? in
            guard !v.isHiddenOrHasHiddenAncestor else { return nil }
            if let t = v as? NSTextField { return "[label] " + t.stringValue }
            if let b = v as? NSButton, !b.title.isEmpty { return "[btn] " + b.title }
            if let tv = v as? NSTextView { return "[text] " + tv.string.replacingOccurrences(of: "\n", with: " ⏎ ") }
            return nil
        }.filter { !$0.hasSuffix("] ") }
    }

    func geometry() -> String {
        let d = delegate
        func f(_ v: NSView?) -> String {
            guard let v else { return "nil" }
            return "\(Int(v.frame.minX)),\(Int(v.frame.minY)) \(Int(v.frame.width))x\(Int(v.frame.height)) hidden=\(v.isHidden)"
        }
        let asked = allViews(d.window.contentView!).compactMap { $0 as? NSTextField }
            .first { $0.stringValue.hasPrefix("“") && $0.frame.width > 300 && !$0.isHiddenOrHasHiddenAncestor }
        return """
        askedQuestion \(asked.map { "\(Int($0.frame.width))x\(Int($0.frame.height)) lines=\($0.maximumNumberOfLines) wrap=\($0.lineBreakMode.rawValue)" } ?? "none")
        window \(Int(d.window.frame.width))x\(Int(d.window.frame.height))
        voiceContentView \(f(d.voiceContentView))
        burstStrip \(f(d.focusQuestionBurstView))
        answerScroll \(f(d.focusBodyScrollView))
        codePanel \(f(d.focusCodePanel))
        codeButton hidden=\(d.focusCodeButton?.isHidden ?? true)
        """
    }

    /// Every style a token can own, per view: colors, radius, border, shadow, fonts, alpha. Diffing
    /// two runs shows exactly which values a styling refactor moved, which pixels alone cannot.
    func styleManifest() -> String {
        func rgba(_ color: NSColor?) -> String {
            guard let c = color?.usingColorSpace(.sRGB) else { return "nil" }
            return String(format: "%.3f,%.3f,%.3f,%.3f", c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
        }
        func cg(_ color: CGColor?) -> String { rgba(color.flatMap { NSColor(cgColor: $0) }) }
        func font(_ f: NSFont?) -> String { f.map { "\($0.fontName)/\($0.pointSize)" } ?? "nil" }
        func attributes(_ s: NSAttributedString) -> String {
            guard s.length > 0 else { return "" }
            let first = s.attributes(at: 0, effectiveRange: nil)
            let last = s.attributes(at: s.length - 1, effectiveRange: nil)
            func one(_ a: [NSAttributedString.Key: Any]) -> String {
                "\(font(a[.font] as? NSFont)) \(rgba(a[.foregroundColor] as? NSColor))"
            }
            let head = one(first), tail = one(last)
            return head == tail ? head : "\(head) .. \(tail)"
        }
        func describe(_ v: NSView, path: String) -> String {
            var parts = [path]
            if v.isHidden { parts.append("hidden") }
            if v.alphaValue != 1 { parts.append(String(format: "alpha=%.3f", v.alphaValue)) }
            if let layer = v.layer {
                if layer.cornerRadius != 0 { parts.append(String(format: "radius=%.2f", layer.cornerRadius)) }
                if layer.borderWidth != 0 { parts.append(String(format: "border=%.2f %@", layer.borderWidth, cg(layer.borderColor))) }
                if layer.backgroundColor != nil { parts.append("bg=\(cg(layer.backgroundColor))") }
                if layer.shadowOpacity > 0 {
                    parts.append(String(format: "shadow=%@ o%.3f r%.1f off%.1f,%.1f", cg(layer.shadowColor), layer.shadowOpacity, layer.shadowRadius, layer.shadowOffset.width, layer.shadowOffset.height))
                }
            }
            if let field = v as? NSTextField {
                if field.attributedStringValue.length > 0 && field.attributedStringValue.attributes(at: 0, effectiveRange: nil)[.foregroundColor] != nil {
                    parts.append("text=\(attributes(field.attributedStringValue))")
                } else {
                    parts.append("text=\(font(field.font)) \(rgba(field.textColor))")
                }
            }
            if let textView = v as? NSTextView, let storage = textView.textStorage {
                parts.append("text=\(attributes(storage))")
            }
            if let button = v as? NSButton {
                if button.attributedTitle.length > 0 { parts.append("title=\(attributes(button.attributedTitle))") }
                else if !button.title.isEmpty { parts.append("title=\(font(button.font))") }
                if let tint = button.contentTintColor { parts.append("tint=\(rgba(tint))") }
            }
            if let hover = v as? HoverButton {
                parts.append("states=\(rgba(hover.normalBackgroundColor))|\(rgba(hover.hoverBackgroundColor))|\(rgba(hover.pressBackgroundColor))|\(rgba(hover.normalBorderColor))|\(rgba(hover.hoverBorderColor))")
            }
            if let image = v as? NSImageView, let tint = image.contentTintColor { parts.append("tint=\(rgba(tint))") }
            return parts.joined(separator: " ")
        }
        func walk(_ v: NSView, path: String, into lines: inout [String]) {
            lines.append(describe(v, path: path))
            var counts: [String: Int] = [:]
            for child in v.subviews {
                let name = String(describing: type(of: child))
                let index = counts[name, default: 0]
                counts[name] = index + 1
                walk(child, path: "\(path)>\(name)[\(index)]", into: &lines)
            }
        }
        var lines: [String] = []
        for (label, root) in [("voice", delegate.voiceContentView as NSView?), ("bar", delegate.focusCommandBar as NSView?)] {
            if let root { walk(root, path: label, into: &lines) }
        }
        return lines.joined(separator: "\n")
    }

    /// Every visible piece of text or glyph with the colors it is drawn in and the stack of fills
    /// behind it, so contrast can be computed from the declared layers (`colors.py`). Glass materials
    /// are marked, not modeled: their tint depends on the desktop behind the window.
    func colorAudit() -> String {
        func rgba(_ color: NSColor?) -> [Double]? {
            guard let c = color?.usingColorSpace(.sRGB) else { return nil }
            let channels: [Double] = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)]
            return channels.map { ($0 * 10000).rounded() / 10000 }
        }
        func runs(_ s: NSAttributedString) -> [[String: Any]] {
            var seen: [String: [String: Any]] = [:]
            var order: [String] = []
            s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { attributes, range, _ in
                guard let color = rgba(attributes[.foregroundColor] as? NSColor) else { return }
                let font = attributes[.font] as? NSFont
                let key = "\(font?.fontName ?? "")/\(font?.pointSize ?? 0)/\(color)"
                if seen[key] == nil {
                    order.append(key)
                    let sample = (s.string as NSString).substring(with: range).replacingOccurrences(of: "\n", with: " ")
                    seen[key] = ["font": font?.fontName ?? "", "size": font?.pointSize ?? 0, "rgba": color, "sample": String(sample.prefix(24))]
                    // A step set back while another is typed is dimmed on purpose.
                    if attributes[CodeFileView.setBackKey] != nil { seen[key]?["dim"] = true }
                }
            }
            return order.compactMap { seen[$0] }
        }
        var items: [[String: Any]] = []
        func walk(_ v: NSView, layers: [[String: Any]], alpha: Double, path: String) {
            if v.isHidden { return }
            var layers = layers
            let alpha = alpha * Double(v.alphaValue)
            if v is NSVisualEffectView { layers.append(["path": path, "material": true]) }
            if let cg = v.layer?.backgroundColor, let fill = rgba(NSColor(cgColor: cg)) {
                layers.append(["path": path, "rgba": fill])
            }
            let frame = v.convert(v.bounds, to: nil)
            let height = Double(delegate.window.contentView?.bounds.height ?? 0)
            let box: [Double] = [frame.minX, height - frame.maxY, frame.width, frame.height].map { Double($0) }
            func add(_ kind: String, _ extra: [String: Any]) {
                var item: [String: Any] = ["path": path, "kind": kind, "layers": layers, "alpha": alpha, "box": box]
                extra.forEach { item[$0.key] = $0.value }
                items.append(item)
            }
            if let field = v as? NSTextField, !field.stringValue.isEmpty, !(field.superview is NSButton) {
                let fallback = rgba(field.textColor).map { [["font": field.font?.fontName ?? "", "size": field.font?.pointSize ?? 0, "rgba": $0, "sample": String(field.stringValue.prefix(24))] as [String: Any]] } ?? []
                let attributed = runs(field.attributedStringValue)
                add(field.maximumNumberOfLines == 1 ? "label" : "wrapping", ["runs": attributed.isEmpty ? fallback : attributed, "text": String(field.stringValue.prefix(40))])
            } else if let textView = v as? NSTextView, let storage = textView.textStorage, storage.length > 0 {
                add("textview", ["runs": runs(storage), "text": String(storage.string.prefix(40)).replacingOccurrences(of: "\n", with: " ")])
            } else if let button = v as? NSButton {
                if button.imagePosition == .imageOnly {
                    // The glyph is the whole label; the default "Button" title is never drawn.
                } else if button.attributedTitle.length > 0 {
                    add("button", ["runs": runs(button.attributedTitle), "text": button.title])
                } else if !button.title.isEmpty, let tint = rgba(button.contentTintColor) {
                    add("button", ["runs": [["font": button.font?.fontName ?? "", "size": button.font?.pointSize ?? 0, "rgba": tint, "sample": button.title]], "text": button.title])
                }
                if button.image != nil, let tint = rgba(button.contentTintColor) {
                    add("icon", ["rgba": tint, "text": button.accessibilityLabel() ?? button.title])
                }
            } else if let image = v as? NSImageView, image.image != nil, let tint = rgba(image.contentTintColor) {
                add("icon", ["rgba": tint, "text": image.accessibilityLabel() ?? "image"])
            }
            if let layer = v.layer, layer.borderWidth >= 1.5, let cg = layer.borderColor, let ring = rgba(NSColor(cgColor: cg)) {
                add("ring", ["rgba": ring, "text": "selection ring"])
            }
            var counts: [String: Int] = [:]
            for child in v.subviews {
                let name = String(describing: type(of: child))
                let index = counts[name, default: 0]
                counts[name] = index + 1
                walk(child, layers: layers, alpha: alpha, path: "\(path)>\(name)[\(index)]")
            }
        }
        for (label, root) in [("voice", delegate.voiceContentView as NSView?), ("bar", delegate.focusCommandBar as NSView?)] {
            if let root { walk(root, layers: [], alpha: 1, path: label) }
        }
        let data = (try? JSONSerialization.data(withJSONObject: items, options: [.sortedKeys])) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// How every visible piece of text is set and whether it fits: font, tracking, line pitch, measure,
    /// truncation and tooltip, read from the laid-out views (`type.py` reports on it). Wrapped text is
    /// re-laid-out in a private TextKit stack at the view's width, so the view itself is not disturbed.
    func typeAudit() -> String {
        var items: [[String: Any]] = []
        func metrics(_ text: NSAttributedString, width: CGFloat) -> (lines: Int, pitch: Double, firstLineChars: Int, maxLineChars: Int, usedHeight: Double) {
            guard text.length > 0, width > 0 else { return (0, 0, 0, 0, 0) }
            let storage = NSTextStorage(attributedString: text)
            let manager = NSLayoutManager()
            let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            storage.addLayoutManager(manager)
            manager.ensureLayout(for: container)
            var rects: [NSRect] = []
            var chars: [Int] = []
            var prose: [Bool] = []
            manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, _, _, glyphRange, _ in
                rects.append(rect)
                let range = manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                chars.append(range.length)
                // A line of code does not wrap and is not read as prose, so it is not a measure: a file's
                // text holds its notes and its code in one view.
                let font = range.length > 0 ? storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont : nil
                prose.append(!(font?.isFixedPitch ?? false) && !(font?.fontName.lowercased().contains("mono") ?? false))
            }
            guard let first = rects.first, let last = rects.last else { return (0, 0, 0, 0, 0) }
            let pitch = rects.count > 1 ? Double((last.minY - first.minY) / CGFloat(rects.count - 1)) : Double(first.height)
            let full = zip(chars, prose).dropLast().filter { $0.1 }.map { $0.0 }
            return (rects.count, pitch, chars.first ?? 0, full.max() ?? chars.first ?? 0, Double(manager.usedRect(for: container).height))
        }
        func describe(_ v: NSView, path: String, text: NSAttributedString, kind: String, maxLines: Int, breaks: String, width: CGFloat) {
            guard text.length > 0 else { return }
            let attrs = text.attributes(at: 0, effectiveRange: nil)
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 13)
            let kern = (attrs[.kern] as? NSNumber)?.doubleValue ?? 0
            let paragraph = attrs[.paragraphStyle] as? NSParagraphStyle
            let m = metrics(text, width: width)
            let single = NSAttributedString(attributedString: text).size().width
            let weight = (font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any])?[.weight] as? NSNumber
            let string = text.string
            var item: [String: Any] = [
                "path": path, "kind": kind, "text": String(string.prefix(48)).replacingOccurrences(of: "\n", with: " "),
                "chars": string.count, "font": font.fontName, "size": Double(font.pointSize), "weight": weight?.doubleValue ?? 0,
                "kern": kern, "lineSpacing": Double(paragraph?.lineSpacing ?? 0), "lineHeightMultiple": Double(paragraph?.lineHeightMultiple ?? 0),
                "minLineHeight": Double(paragraph?.minimumLineHeight ?? 0), "headIndent": Double(paragraph?.headIndent ?? 0),
                "firstIndent": Double(paragraph?.firstLineHeadIndent ?? 0), "breakStrategy": paragraph?.lineBreakStrategy.rawValue ?? 0,
                "lines": m.lines, "usedHeight": m.usedHeight, "pitch": m.pitch, "firstLineChars": m.firstLineChars, "maxLineChars": m.maxLineChars,
                "maxLines": maxLines, "breaks": breaks, "width": Double(v.frame.width), "height": Double(v.frame.height),
                "textWidth": Double(single), "toolTip": v.toolTip != nil, "upper": { let words = string.split(whereSeparator: { $0 == " " || $0 == "\u{2002}" }).map(String.init).filter { $0.contains(where: { $0.isLetter }) && !$0.contains(where: { $0.isNumber }) }; return !words.isEmpty && words.allSatisfy { $0 == $0.uppercased() } }(),
                "hasDigits": string.contains(where: { $0.isNumber })
            ]
            item["tabular"] = font.fontName.hasPrefix(".SFNS") || font.fontName.lowercased().contains("mono")
            var paragraphs: [[String: Any]] = []
            var location = 0
            for line in string.components(separatedBy: "\n") {
                let length = (line as NSString).length
                defer { location += length + 1 }
                guard length > 0 else { continue }
                let range = NSRange(location: location, length: length)
                let start = text.attributes(at: location, effectiveRange: nil)
                let style = start[.paragraphStyle] as? NSParagraphStyle
                let lead = line.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
                paragraphs.append([
                    "text": String(line.prefix(28)), "bullet": ["•", "▸", "·", "-", "*"].contains(lead),
                    "headIndent": Double(style?.headIndent ?? 0), "firstIndent": Double(style?.firstLineHeadIndent ?? 0),
                    "lines": metrics(text.attributedSubstring(from: range), width: width).lines,
                    "spacingAfter": Double(style?.paragraphSpacing ?? 0)
                ])
            }
            item["paragraphs"] = paragraphs
            items.append(item)
        }
        func walk(_ v: NSView, path: String) {
            if v.isHidden { return }
            if let field = v as? NSTextField, !field.stringValue.isEmpty, !(field.superview is NSButton) {
                let text = field.attributedStringValue
                let inset: CGFloat = 4
                let wraps = field.maximumNumberOfLines != 1 && field.lineBreakMode == .byWordWrapping
                let width = wraps ? max(1, field.frame.width - inset) : 100000
                describe(field, path: path, text: text, kind: wraps ? "wrapping" : "label", maxLines: field.maximumNumberOfLines,
                         breaks: "\(field.lineBreakMode.rawValue)", width: width)
                if var last = items.last, last["path"] as? String == path {
                    let needed = field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: 100000, height: max(field.frame.height, 100))).width ?? 0
                    last["cellWidth"] = Double(needed)
                    items[items.count - 1] = last
                }
            } else if let textView = v as? NSTextView, let storage = textView.textStorage, storage.length > 0 {
                let width = textView.textContainer?.containerSize.width ?? textView.frame.width
                describe(textView, path: path, text: storage, kind: "textview", maxLines: 0, breaks: "0", width: min(width, 100000))
            } else if let button = v as? NSButton, button.attributedTitle.length > 0, button.imagePosition != .imageOnly {
                describe(button, path: path, text: button.attributedTitle, kind: "button", maxLines: 1, breaks: "\(button.lineBreakMode.rawValue)", width: 100000)
            }
            var counts: [String: Int] = [:]
            for child in v.subviews {
                let name = String(describing: type(of: child))
                let index = counts[name, default: 0]
                counts[name] = index + 1
                walk(child, path: "\(path)>\(name)[\(index)]")
            }
        }
        for (label, root) in [("voice", delegate.voiceContentView as NSView?), ("bar", delegate.focusCommandBar as NSView?)] {
            if let root { walk(root, path: label) }
        }
        let data = (try? JSONSerialization.data(withJSONObject: items, options: [.sortedKeys])) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Where everything sits, in window coordinates with the origin at the top left: text, controls,
    /// surfaces and scroll views, each with the surface it sits on. `layout.py` reads it for overlaps,
    /// clipping, shared edges, gaps between groups and content that scrolls out of sight without a cue.
    func layoutAudit() -> String {
        var items: [[String: Any]] = []
        let height = Double(delegate.window.contentView?.bounds.height ?? 0)
        let width = Double(delegate.window.contentView?.bounds.width ?? 0)
        func rectOf(_ v: NSView) -> CGRect {
            let f = v.convert(v.bounds, to: nil)
            return CGRect(x: f.minX, y: height - f.maxY, width: f.width, height: f.height)
        }
        func list(_ r: CGRect) -> [Double] { [r.minX, r.minY, r.width, r.height].map { Double($0 * 100).rounded() / 100 } }
        var dropped: [String] = []
        var moving: [[String: Any]] = []
        func animationKeys(_ layer: CALayer) -> [String] {
            (layer.animationKeys() ?? []) + (layer.sublayers ?? []).flatMap(animationKeys)
        }
        func walk(_ v: NSView, path: String, surface: String?, clip: CGRect?) {
            if v.isHidden {
                // A quick action that was laid out and then hidden is an action the reader never sees.
                if let button = v as? HoverButton, button.identifier?.rawValue == "quickAction", let parent = v.superview, !parent.isHiddenOrHasHiddenAncestor {
                    dropped.append(button.title)
                }
                return
            }
            var surface = surface
            var clip = clip
            let frame = rectOf(v)
            let hasFill = v.layer.map { ($0.backgroundColor?.alpha ?? 0) > 0.02 || $0.borderWidth > 0 } ?? false
            var record: [String: Any]?
            if v is NSVisualEffectView || (hasFill && !(v is NSControl)) || v.identifier?.rawValue.hasPrefix("burstSegment-") == true {
                record = ["kind": "surface", "text": ""]
            }
            if let field = v as? NSTextField, !field.stringValue.isEmpty, !(field.superview is NSButton) {
                // An attributed string carries its own paragraph alignment, which wins over the field's.
                var alignment = field.alignment
                if let style = field.attributedStringValue.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle, style.alignment != .natural {
                    alignment = style.alignment
                }
                record = ["kind": "text", "text": String(field.stringValue.prefix(40)), "align": alignment.rawValue, "lines": field.maximumNumberOfLines]
            } else if let textView = v as? NSTextView, (textView.textStorage?.length ?? 0) > 0 {
                record = ["kind": "text", "text": String(textView.string.prefix(40)), "align": 0, "lines": 0]
            } else if let button = v as? NSButton {
                let visible = button.image != nil || !button.title.isEmpty && button.imagePosition != .imageOnly
                if visible {
                    var fill = false
                    if let hover = button as? HoverButton {
                        fill = hover.normalBackgroundColor.alphaComponent > 0.02 || hover.normalBorderColor.alphaComponent > 0.02
                    }
                    record = ["kind": "button", "text": button.title.isEmpty ? (button.accessibilityLabel() ?? "") : button.title, "filled": fill]
                } else {
                    record = ["kind": "overlay", "text": ""]
                }
            } else if v is NSSegmentedControl {
                record = ["kind": "button", "text": "segmented", "filled": true]
            } else if let skeleton = v as? SkeletonView {
                // Where each bar sits in the window, so a placeholder can be held against the content that replaces it.
                let pieces: [[Double]] = skeleton.pieces.map { piece in
                    let width: CGFloat
                    switch piece.width {
                    case .points(let points): width = points
                    case .share(let share): width = max(0, frame.width - piece.x) * share
                    }
                    return list(CGRect(x: frame.minX + piece.x, y: frame.minY + piece.top, width: width, height: piece.height))
                }
                record = ["kind": "skeleton", "text": "", "pieces": pieces, "animating": skeleton.isAnimating]
            } else if v is NSImageView || v is NSProgressIndicator {
                record = ["kind": "image", "text": String(describing: type(of: v))]
            } else if let scroll = v as? NSScrollView {
                let content = Double(scroll.documentView?.frame.height ?? 0)
                let visible = Double(scroll.contentView.bounds.height)
                let siblings = (scroll.superview?.subviews ?? []) + scroll.subviews
                record = ["kind": "scroll", "text": "", "contentHeight": content, "visibleHeight": visible,
                          "atEnd": Double(scroll.contentView.bounds.maxY) >= content - 1,
                          "hasCue": siblings.contains { $0.identifier?.rawValue == "overflowCue" && !$0.isHidden }]
                let viewport = rectOf(scroll.contentView)
                clip = clip.map { $0.intersection(viewport) } ?? viewport
            }
            if var item = record {
                let visible = clip.map { frame.intersection($0) } ?? frame
                item["path"] = path
                item["surface"] = surface ?? ""
                item["box"] = list(frame)
                item["visible"] = visible.isNull || visible.isEmpty ? [] : list(visible)
                items.append(item)
                if item["kind"] as? String == "surface" { surface = path }
            }
            if let layer = v.layer {
                let keys = animationKeys(layer).filter { $0 == "sweep" || $0 == "activity" }
                if !keys.isEmpty { moving.append(["path": path, "keys": Array(Set(keys)).sorted()]) }
            }
            var counts: [String: Int] = [:]
            for child in v.subviews {
                let name = String(describing: type(of: child))
                let index = counts[name, default: 0]
                counts[name] = index + 1
                walk(child, path: "\(path)>\(name)[\(index)]", surface: surface, clip: clip)
            }
        }
        for (label, root) in [("voice", delegate.voiceContentView as NSView?), ("bar", delegate.focusCommandBar as NSView?)] {
            if let root { walk(root, path: label, surface: nil, clip: nil) }
        }
        let wrapper: [String: Any] = [
            "window": [width, height], "items": items, "dropped": dropped,
            "moving": moving, "reduceMotion": Token.Motion.reducesMotion()
        ]
        let data = (try? JSONSerialization.data(withJSONObject: wrapper, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func snap(_ name: String) {
        guard let view = delegate.window.contentView else { return }
        // The follow-up actions show under the pointer; reveal them so a run does not depend on where it is.
        let reduces = Token.Motion.reducesMotion
        Token.Motion.reducesMotion = { true }
        delegate.focusCodePanel?.setQuickActionsRevealed(true)
        Token.Motion.reducesMotion = reduces
        view.layoutSubtreeIfNeeded()
        delegate.window.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let file = String(format: "%02d-%@", step, name)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: outDir.appendingPathComponent(file + ".png"))
        }
        let text = geometry() + "\n---\n" + visibleTexts().joined(separator: "\n")
        try? text.write(to: outDir.appendingPathComponent(file + ".txt"), atomically: true, encoding: .utf8)
        try? styleManifest().write(to: outDir.appendingPathComponent(file + ".style.txt"), atomically: true, encoding: .utf8)
        try? colorAudit().write(to: outDir.appendingPathComponent(file + ".colors.json"), atomically: true, encoding: .utf8)
        try? typeAudit().write(to: outDir.appendingPathComponent(file + ".type.json"), atomically: true, encoding: .utf8)
        try? layoutAudit().write(to: outDir.appendingPathComponent(file + ".layout.json"), atomically: true, encoding: .utf8)
        log.append("snap \(file)")
    }

    func add(_ name: String, _ f: @escaping () -> Void) { queue.append((name, f)) }

    func run() {
        guard !queue.isEmpty else {
            try? log.joined(separator: "\n").write(to: outDir.appendingPathComponent("driver.log"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
            return
        }
        let (name, f) = queue.removeFirst()
        step += 1
        f()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [self] in
            snap(name)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.run() }
        }
    }
}

@available(macOS 14.0, *)
@main
struct FocusCodePanelQA {
    static func main() {
        let outPath = ProcessInfo.processInfo.environment["QA_OUT"] ?? "/tmp/focus-ui-qa"
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let d = InterviewMasterDelegate()
        d.setupWindow()
        d.setupUI()
        // Default: the app as shipped. QA_APPEARANCE=aqua makes the whole system light, which the
        // main window's own dark pin must survive; aqua-window forces the window light, which is what
        // the interface looked like before it pinned the appearance.
        switch ProcessInfo.processInfo.environment["QA_APPEARANCE"] {
        case "aqua": NSApp.appearance = NSAppearance(named: .aqua)
        case "aqua-window": d.window.appearance = NSAppearance(named: .aqua)
        default: break
        }
        // QA_WINDOW=1440x900 sets the content size before anything is shown.
        let environment = ProcessInfo.processInfo.environment
        if let size = environment["QA_WINDOW"]?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
            d.window.setContentSize(NSSize(width: size[0], height: size[1]))
        }
        // QA_REDUCE_MOTION=1 runs the whole window as it is for someone who asked the system for less motion.
        if environment["QA_REDUCE_MOTION"] == "1" { Token.Motion.reducesMotion = { true } }
        d.window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let qa = FocusQADriver(delegate: d, outDir: URL(fileURLWithPath: outPath))

        let q1 = UUID(), q2 = UUID(), q3 = UUID(), q4 = UUID(), q5 = UUID(), q6 = UUID()

        func ask(_ id: UUID, seq: Int, _ text: String, topic: String) {
            d.processorDidReceiveQuestion(text, topic: topic, messageType: .answer, source: .microphone, turnID: id, sequence: seq)
            d.processorDidStartStreaming(messageType: .answer, topic: topic, latencyMs: 640, turnID: id, sequence: seq)
        }
        func answer(_ id: UUID, _ text: String) {
            d.processorDidReceiveAnswerChunk(text, turnID: id)
            d.processorDidFinishAnswer(text, totalLatencyMs: 1480, turnID: id)
        }
        func codeInfo(_ id: UUID, _ request: String, refinement: Bool = false) -> CodingTaskInfo {
            CodingTaskInfo(turnID: id, request: request, isRefinement: refinement, allowsChanges: true)
        }

        let partialSteps = """
        STEP 1 — file: main.py
        Why: Slice the string backwards.
        ```python
        def reverse(text):
            return te
        """
        let steps = """
        STEP 1 — file: main.py
        Why: Slice the string backwards.
        ```python
        def reverse(text):
            return text[::-1]
        ```

        STEP 2 — file: main.py
        Why: Call it with a sample and print the result so the interviewer sees it work.
        ```python
        if __name__ == "__main__":
            print(reverse("interview"))  # weweaverni
            print(reverse(""))
        ```
        """
        let refined = steps + """


        STEP 3 — file: test_main.py
        Why: One test for the empty string edge case the interviewer mentioned earlier in the call.
        ```python
        from main import reverse

        def test_empty_string_returns_empty_string_without_raising_any_error_at_all():
            assert reverse("") == ""
        ```
        """
        let typeScriptSteps = """
        STEP 1 — file: reverse.ts
        Why: Split into characters, reverse, join.
        ```typescript
        export function reverse(text: string): string {
          return text.split("").reverse().join("");
        }
        ```
        """
        let cutOffSteps = """
        STEP 1 — file: reverse.ts
        Why: Walk the string from the end with two indexes.
        ```typescript
        export function reverse(text: string): string {
          const chars = text.split("");
          let left = 0;
          let right = chars.length - 1;
          while (left < right) {
            [chars[left], chars[right]] = [chars[right], chars[left]];
        """
        let analysis = "## Analysis\nThe screenshot shows a two-sum problem.\n- Use a dict of value -> index\n- One pass, O(n)"

        qa.add("welcome") {}
        qa.add("question-answered") {
            ask(q1, seq: 1, "What is polymorphism?", topic: "polymorphism")
            answer(q1, "- Polymorphism means one interface with many implementations.\n- I use it to swap strategies without touching callers.\n- Compile-time overloads and run-time overrides are the two forms.")
        }
        qa.add("coding-question-writing") {
            d.processorShowLoading("💻 Writing code...", color: .applePurple, turnID: q2)
            ask(q2, seq: 2, "Write a function that reverses a string", topic: "coding")
            d.processorDidStartCodingTask(codeInfo(q2, "Write a function that reverses a string"))
        }
        qa.add("coding-partial-step") {
            d.processorDidUpdateCodingTask(partialSteps)
            d.processorDidReceiveAnswerChunk("- Restating: take a string, return it reversed.", turnID: q2)
        }
        qa.add("coding-finished") {
            d.processorDidUpdateCodingTask(steps)
            answer(q2, "- Restating: take a string, return it reversed.\n- Assumption: an empty string returns an empty string.\n- O(n) time, O(n) space.\n- Code is in the panel on the right (2 steps).")
            d.processorDidFinishCodingTask(.complete)
            d.processorHideLoading(turnID: q2)
        }
        qa.add("question-while-code-up") {
            ask(q3, seq: 3, "Why did you use slicing instead of a loop?", topic: "unknown")
            answer(q3, "- Slicing is the idiomatic Python way and runs in C, so it is faster.\n- A loop is clearer for languages without slicing.\n- Both are O(n); I would pick slicing here.")
        }
        qa.add("code-refined") {
            d.processorDidStartCodingTask(codeInfo(q2, "Write a function that reverses a string", refinement: true))
            d.processorDidUpdateCodingTask(refined)
            d.processorDidFinishCodingTask(.complete)
        }
        qa.add("language-switched") {
            d.processorShowLoading("💻 Writing code...", color: .applePurple, turnID: q4)
            ask(q4, seq: 4, "Okay, now can you write it in TypeScript?", topic: "coding")
            d.processorDidStartCodingTask(codeInfo(q4, "Okay, now can you write it in TypeScript?"))
            d.processorDidUpdateCodingTask(typeScriptSteps)
            answer(q4, "- Same logic in TypeScript: split, reverse, join.\n- Strings are immutable there too, so it is O(n) space.\n- Code is in the panel on the right (1 step).")
            d.processorDidFinishCodingTask(.complete)
            d.processorHideLoading(turnID: q4)
        }
        qa.add("older-version-via-burst") { d.selectQuestionBurstEntry(q2) }
        qa.add("back-to-latest") { _ = d.focusCodePanel.selectVersion(id: q4) }
        qa.add("incomplete-with-retry") {
            ask(q5, seq: 5, "Is there another way to reverse it?", topic: "coding")
            d.processorDidStartCodingTask(codeInfo(q5, "Is there another way to reverse it?"))
            d.processorDidUpdateCodingTask(cutOffSteps)
            answer(q5, "- Swap characters from both ends.\n- The code stopped early. Use Try again in the panel.")
            d.processorDidFinishCodingTask(.incomplete("The reply was cut off before the last step ended."))
        }
        qa.add("many-questions-vertical-burst") {
            ask(q6, seq: 6, "What is the time complexity of the two pointer version, and does it change with unicode input?", topic: "unknown")
            answer(q6, "- Two pointers is O(n) time and O(n) space because the string is copied into a list first.\n- Unicode combining marks need grapheme-aware handling; plain code points break them.")
        }
        qa.add("interview-stopped-locks-changes") {
            _ = d.focusCodePanel.selectVersion(id: q4)
            d.focusCodePanel.lockChanges()
        }
        qa.add("panel-closed") { d.hideFocusCodePanel(byUser: true) }
        qa.add("panel-reopened-by-button") { d.toggleFocusCodePanel() }
        qa.add("analysis-fallback") {
            d.processorDidStartCodingTask(CodingTaskInfo(turnID: UUID(), request: "Screenshot analysis", isRefinement: false, allowsChanges: false))
            d.processorDidUpdateCodingTask(analysis)
            d.processorDidFinishCodingTask(.complete)
        }
        qa.add("reset") { d.resetInterviewFocusUI() }
        qa.add("empty-panel-via-button") { d.toggleFocusCodePanel() }
        // Every phase pill and the red states, which the coding flow above never reaches.
        let q7 = UUID(), q8 = UUID(), q9 = UUID(), q10 = UUID()
        qa.add("phases-queued-generating-answering") {
            d.receiveFocusQuestion(turnID: q7, sequence: 7, text: "Can you walk me through your last project?", topic: "unknown")
            d.receiveFocusQuestion(turnID: q8, sequence: 8, text: "How would you test a rate limiter?", topic: "testing")
            d.beginFocusAIWork(turnID: q8)
            d.receiveFocusQuestion(turnID: q9, sequence: 9, text: "What is polymorphism?", topic: "polymorphism")
            d.beginFocusAIWork(turnID: q9)
            d.startFocusAnswer(turnID: q9)
            d.updateFocusAnswer(turnID: q9, content: "- Polymorphism means one interface with many implementations.")
        }
        qa.add("failed-turn") {
            d.receiveFocusQuestion(turnID: q10, sequence: 10, text: "Explain how the event loop schedules callbacks.", topic: "javascript")
            d.beginFocusAIWork(turnID: q10)
            // The pipeline reports a failure as text; the window turns it into a reason.
            d.processorDidReceiveAnswerChunk("Error: The request timed out.", turnID: q10)
            d.selectQuestionBurstEntry(q10)
        }
        qa.add("cv-briefing") {
            d.processorDidUpdateBriefing(InterviewBriefing(
                thread: "qa",
                digest: "Senior QA engineer moving toward AI evaluation, with a decade of test automation behind it",
                talkingPoints: [
                    "Built the regression suite for a payments platform that ran on every merge",
                    "Led the move from Selenium to Playwright and cut flaky runs by two thirds",
                    "Now evaluating LLM answers with rubric checks and a small labelled set"
                ]
            ))
        }
        qa.add("interview-running") {
            // The driver has no audio device; a running interview would be listening to something.
            d.qaAudioPresentation = .listening(.systemAudio)
            d.isInterviewActive = true
            d.recordingStartTime = Date().addingTimeInterval(-73)
            d.refreshInterviewFocusUI()
        }

        // Content that grows: a question of two sentences, a topic name as long as they come, a two-hour
        // timer, eleven versions of the code and a file path that will not fit.
        let q11 = UUID()
        qa.add("stress-long-answer") {
            d.hideFocusCodePanel(byUser: false)
            d.receiveFocusQuestion(turnID: q11, sequence: 11, text: "Could you walk me through how you would design the evaluation harness for a retrieval augmented system, including how you would build the labelled set and keep it from drifting?", topic: "machineLearningFundamentalsAndOperations")
            d.beginFocusAIWork(turnID: q11)
            d.startFocusAnswer(turnID: q11)
            let longAnswer = [
                "- Start from real questions: sample them from production logs, strip anything personal and label a few hundred by hand.",
                "- Split the harness in two: retrieval metrics (recall at k, mean reciprocal rank) and answer metrics (faithfulness, relevance, completeness).",
                "- Keep the labelled set honest: freeze a version, add new cases in a separate file and review disagreements between labelers before merging.",
                "- Run it on every change to the prompt, the chunker or the embedding model, and fail the build when a metric drops by more than its noise floor.",
                "- Track drift: compare the live question mix against the labelled mix each week and add cases where they diverge.",
                "- Report a table per slice, not one number, so a regression in a rare but important slice is not averaged away.",
                "- Close the loop: every production complaint becomes a test case with the expected answer attached."
            ].joined(separator: "\n")
            d.updateFocusAnswer(turnID: q11, content: longAnswer)
            d.finishFocusAnswer(turnID: q11, content: longAnswer, latencyMs: 123456)
        }
        qa.add("stress-many-versions") {
            for index in 1...11 {
                let id = UUID()
                d.processorDidStartCodingTask(CodingTaskInfo(turnID: id, request: "Version \(index) of a request that is written the way people actually dictate one", isRefinement: false, allowsChanges: true))
                d.processorDidUpdateCodingTask(typeScriptSteps)
                d.processorDidFinishCodingTask(.complete)
            }
        }
        qa.add("stress-long-file-and-timer") {
            let id = UUID()
            d.processorDidStartCodingTask(CodingTaskInfo(turnID: id, request: "Write the service", isRefinement: false, allowsChanges: true))
            d.processorDidUpdateCodingTask("""
            STEP 1 — file: src/services/interview/evaluation/very_long_module_name_for_layout_testing.py
            Why: This step wires the retrieval metrics into the harness and keeps the labelled set frozen so a change in the numbers can only come from the change under test.
            ```python
            def evaluate(cases, retriever, judge, k=5):
                return [judge(case, retriever(case.question, k)) for case in cases]
            ```
            """)
            d.processorDidFinishCodingTask(.complete)
            d.isInterviewActive = true
            d.recordingStartTime = Date().addingTimeInterval(-7300)
            d.refreshInterviewFocusUI()
        }

        qa.add("hearing-speech") {
            d.focusAIActivityCapsule.update(mode: .listening(speaking: true), isRecording: true, elapsed: "12:07")
            d.focusCommandAIActivityCapsule.update(mode: .listening(speaking: true), isRecording: false, elapsed: "")
        }

        // Loading states, one wait at a time. Earlier states left the AI "working", so the first two clear it.
        // Through the same calls the processor makes, so the routing from pipeline to capsule is what is tested.
        let transcribingID = UUID()
        qa.add("loading-transcribing") {
            d.endAllFocusAIWork()
            d.showLoading("🎙️ Transcribing...", color: .systemBlue, turnID: transcribingID)
        }
        qa.add("loading-connecting") {
            d.hideLoading(turnID: transcribingID)
            // hideLoading refreshes on the main queue; the capsule is set after it, as audio that is still starting would be.
            DispatchQueue.main.async {
                d.focusAIActivityCapsule.update(mode: .connecting, isRecording: false, elapsed: "01:12")
                d.focusCommandAIActivityCapsule.update(mode: .connecting, isRecording: false, elapsed: "")
            }
        }
        let waitingID = UUID()
        var waitingSince = Date()
        qa.add("loading-answer-generating") {
            d.receiveFocusQuestion(turnID: waitingID, sequence: 20, text: "How would you design a rate limiter for a public API?", topic: "systemDesign")
            d.beginFocusAIWork(turnID: waitingID)
            d.startFocusAnswer(turnID: waitingID)
            waitingSince = d.questionBurstState.entries.first { $0.id == waitingID }?.detectedAt ?? Date()
        }
        qa.add("loading-answer-slow") {
            FocusAnswerView.now = { waitingSince.addingTimeInterval(6.2) }
            d.refreshInterviewFocusUI()
        }
        qa.add("loading-answer-stalled") {
            FocusAnswerView.now = { waitingSince.addingTimeInterval(12.2) }
            d.refreshInterviewFocusUI()
        }
        qa.add("loading-answer-arrived") {
            FocusAnswerView.now = Date.init
            d.updateFocusAnswer(turnID: waitingID, content: "- Start with a token bucket per API key.\n- Keep the counters in Redis and update them with one atomic script.\n- Return 429 with a Retry-After header when the bucket is empty.")
        }
        qa.add("loading-answer-queued") {
            d.finishFocusAnswer(turnID: waitingID, content: "- Start with a token bucket per API key.\n- Keep the counters in Redis and update them with one atomic script.\n- Return 429 with a Retry-After header when the bucket is empty.", latencyMs: 1620)
            d.receiveFocusQuestion(turnID: UUID(), sequence: 21, text: "And how would you keep the limiter correct across regions?", topic: "systemDesign")
        }
        let codingID = UUID()
        var codingSince = Date()
        qa.add("loading-code-writing") {
            d.receiveFocusQuestion(turnID: codingID, sequence: 22, text: "Write a function that merges two sorted lists.", topic: "coding")
            d.beginFocusAIWork(turnID: codingID)
            d.startFocusAnswer(turnID: codingID)
            d.processorDidStartCodingTask(codeInfo(codingID, "Write a function that merges two sorted lists."))
            codingSince = d.focusCodePanel.versions.last?.startedAt ?? Date()
            waitingSince = d.questionBurstState.entries.first { $0.id == codingID }?.detectedAt ?? Date()
        }
        qa.add("loading-code-slow") {
            FocusAnswerView.now = { waitingSince.addingTimeInterval(6.2) }
            CodePanelView.now = { codingSince.addingTimeInterval(6.2) }
            d.refreshInterviewFocusUI()
            d.focusCodePanel.updateLatest(markdown: "")
        }
        qa.add("loading-code-arrived") {
            FocusAnswerView.now = Date.init
            CodePanelView.now = Date.init
            d.updateFocusAnswer(turnID: codingID, content: "- Walk both lists with two pointers.\n- Code is in the panel on the right (2 steps).")
            d.processorDidUpdateCodingTask(steps)
            d.processorDidFinishCodingTask(.complete)
        }

        // Feedback: what the window says about audio, errors, saves and undo. The driver has no audio device,
        // so it names the presentation the window would have.
        qa.add("feedback-audio-muted") {
            d.endAllFocusAIWork()
            d.resetFocusTranscription()
            d.qaAudioPresentation = .muted
            d.refreshInterviewFocusUI()
        }
        qa.add("feedback-audio-unavailable") {
            d.qaAudioPresentation = .unavailable
            d.refreshInterviewFocusUI()
        }
        qa.add("feedback-error") {
            d.qaAudioPresentation = .listening(.systemAudio)
            d.refreshInterviewFocusUI()
            d.processorDidUpdateStatus("Error: Groq transcription network issue. Check connection and try again.")
        }
        // A confirmation does not cover an error.
        qa.add("feedback-error-kept") {
            d.postFocusNotice(.confirmation("screenshot", "Screenshot captured"))
        }
        // Hearing a question again is the thing an error about hearing was waiting for.
        qa.add("feedback-error-resolved") {
            d.processorDidReceiveQuestion("Why did the build fail on main?", topic: "testing", messageType: .answer, source: .systemAudio, turnID: UUID(), sequence: 30)
        }
        qa.add("feedback-confirmation") {
            d.screenshots = [Screenshot(image: NSImage(size: NSSize(width: 160, height: 90)))]
            d.postFocusNotice(.confirmation("screenshot", "Screenshot captured", detail: liveScreenshotStatusText(count: 1)))
        }
        qa.add("feedback-undo") {
            d.screenshots = [Screenshot(image: NSImage(size: NSSize(width: 160, height: 90))), Screenshot(image: NSImage(size: NSSize(width: 160, height: 90)))]
            d.currentPinnedSolution = "def reverse(text):\n    return text[::-1]"
            d.clearScreenshotsFromTimeline()
        }
        // A rejected key is fixed in Settings, so the button is on the error.
        qa.add("feedback-error-key") {
            d.processorDidUpdateStatus("Error: Groq transcription failed: Groq API error (401): Invalid API Key")
        }
        // A failed screenshot is tried again from where it failed.
        qa.add("feedback-error-screenshot") {
            d.postFocusNotice(FeedbackCopy.screenshotFailed(detail: "No display found. Connect or wake a display, then try again."))
        }
        let failedID = UUID()
        qa.add("feedback-answer-failed") {
            d.dismissFocusNotice()
            d.receiveFocusQuestion(turnID: failedID, sequence: 31, text: "How do you keep a flaky test suite stable?", topic: "testing")
            d.beginFocusAIWork(turnID: failedID)
            d.startFocusAnswer(turnID: failedID)
            d.processorDidReceiveAnswerChunk("Error: The request timed out.", turnID: failedID)
        }
        qa.add("feedback-answer-retried") {
            d.retryFocusAnswer(turnID: failedID)
        }
        qa.add("feedback-audio-restored") {
            d.endAllFocusAIWork()
            d.qaAudioPresentation = .listening(.systemAudio)
            d.refreshInterviewFocusUI()
        }

        // The longest things a notice says, each beside the busiest capsule the header can hold.
        let busyID = UUID()
        qa.add("notice-widest-analyze") {
            d.dismissFocusNotice()
            d.receiveFocusQuestion(turnID: busyID, sequence: 41, text: "What would you change first?", topic: "testing")
            d.beginFocusAIWork(turnID: busyID)
            d.postFocusNotice(FeedbackCopy.nothingToAnalyze)
        }
        qa.add("notice-widest-busy") {
            d.dismissFocusNotice()
            d.processorDidUpdateStatus("Error: Groq API error (429): rate limit reached")
        }
        qa.add("notice-widest-timeout") {
            d.dismissFocusNotice()
            d.processorDidUpdateStatus("Error: Groq transcription timed out after 30s")
        }
        qa.add("notice-widest-session") {
            d.dismissFocusNotice()
            d.postFocusNotice(FeedbackCopy.sessionNotSaved(reason: "The file couldn’t be saved because the disk is full"))
        }
        qa.add("notice-widest-saved") {
            d.dismissFocusNotice()
            d.postFocusNotice(FeedbackCopy.sessionSaved(path: "/Users/me/Documents/InterviewMaster/sessions/session.json"))
        }
        qa.add("notice-widest-exported") {
            d.dismissFocusNotice()
            d.postFocusNotice(FeedbackCopy.exported(fileName: "interview_2026-09-29_08-21.md", path: "/Users/me/Documents/interview_2026-09-29_08-21.md"))
        }
        qa.add("notice-widest-nothing") {
            d.dismissFocusNotice()
            d.postFocusNotice(FeedbackCopy.nothingToExport)
            d.finishFocusAnswer(turnID: busyID, content: "- Start with the flakiest tests and fix their shared cause.", latencyMs: 1200)
            d.endAllFocusAIWork()
        }

        // A topic the classifier names in camelCase reads as the words people say.
        let acronymID = UUID()
        qa.add("topic-acronym") {
            ask(acronymID, seq: 42, "How does RAG differ from CAG?", topic: "ragCag")
            answer(acronymID, "- RAG retrieves at question time; CAG preloads the context into the cache.\n- Use RAG for large or changing corpora and CAG for small stable ones.")
        }

        // The header holds the status on the live tab; on the Context tab the bar has to carry it.
        qa.add("notes-tab-status") { d.switchToNotesTab() }
        // Typing along: the second step is the one being typed, the others are set back.
        qa.add("code-step-two") {
            d.switchToVoiceTab()
            let stepping = UUID()
            ask(stepping, seq: 60, "Write a function that reverses a string and test it", topic: "coding")
            d.processorDidStartCodingTask(codeInfo(stepping, "Write a function that reverses a string and test it"))
            d.processorDidUpdateCodingTask(refined)
            d.processorDidFinishCodingTask(.complete)
            d.focusCodePanel.moveStep(forward: true)
        }
        // The last step is below the fold at this size: stepping to it scrolls it to the top.
        qa.add("code-step-three-scrolled") { d.focusCodePanel.moveStep(forward: true) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { qa.run() }
        app.run()
    }
}
