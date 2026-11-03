"""Contrast audit for the interview window, from the driver's `*.colors.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>
    python3 Scripts/focus-ui-qa/colors.py <dir> [--all]

Every visible piece of text or glyph is measured against the fills painted behind it (its own layers
composited bottom to top) on three window backdrops. The window is glass: its `.menu` material at 0.8
alpha over a black, a typical and a white desktop composites to roughly 0.09, 0.26 and 0.44 gray, and
the layer fills above it are what this script knows exactly. Glass materials inside cards are treated
as transparent, which is the pessimistic choice for light text on dark fills.

Thresholds are APCA Lc (absolute value), from the better-colors skill:
    body text 75, labels 60, UI components and glyphs 30, disabled or dimmed 30.
Syntax-highlighted code is read token by token, so it is held to the label threshold (60), not the
body threshold. Markdown heading markers ("##") are decorative and not measured.
WCAG 2 ratios are printed beside them for reference (4.5 text, 3 components).
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

BACKDROPS = {"dark": 0.09, "typical": 0.26, "light": 0.44}
THRESHOLDS = {"body": 75, "label": 60, "code": 60, "glyph": 30, "dim": 30}


def over(top, base):
    r, g, b, a = top
    return tuple(top[i] * a + base[i] * (1 - a) for i in range(3))


def channel(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = (max(0.0, min(1.0, c)) ** 2.4 for c in rgb)
    return 0.2126729 * r + 0.7151522 * g + 0.0721750 * b


def wcag(fg, bg):
    def lum(rgb):
        r, g, b = (channel(c) for c in rgb)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    a, b = lum(fg), lum(bg)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def apca(fg, bg):
    """APCA-W3 0.0.98G-4g. Negative Lc means light text on a dark background."""
    y_txt, y_bg = luminance(fg), luminance(bg)
    if y_txt < 0.022:
        y_txt += (0.022 - y_txt) ** 1.414
    if y_bg < 0.022:
        y_bg += (0.022 - y_bg) ** 1.414
    if abs(y_bg - y_txt) < 0.0005:
        return 0.0
    if y_bg > y_txt:
        sapc = (y_bg ** 0.56 - y_txt ** 0.57) * 1.14
        return 0.0 if sapc < 0.1 else (sapc - 0.027) * 100
    sapc = (y_bg ** 0.65 - y_txt ** 0.62) * 1.14
    return 0.0 if sapc > -0.1 else (sapc + 0.027) * 100


def background(item, gray):
    bg = (gray, gray, gray)
    for layer in item["layers"]:
        if "rgba" in layer:
            fill = layer["rgba"]
            bg = over((fill[0], fill[1], fill[2], fill[3] * item["alpha"]), bg)
    return bg


def classify(item, run):
    if item["alpha"] < 0.99:
        return "dim"
    if item["kind"] in ("icon", "ring"):
        return "glyph"
    sample = run.get("sample", "").strip()
    if sample and set(sample) == {"#"}:
        return "decorative"
    if sample and not any(ch.isalnum() for ch in sample):
        return "glyph"
    if item["kind"] == "textview":
        return "code" if "mono" in run.get("font", "").lower() else "body"
    if run.get("size", 0) >= 13 and len(item.get("text", "")) >= 28:
        return "body"
    return "label"


def measurements(directory):
    for path in sorted(Path(directory).glob("*.colors.json")):
        for item in json.loads(path.read_text()):
            runs = item.get("runs") or [{"rgba": item["rgba"], "size": 0, "font": "", "sample": item.get("text", "")}]
            for run in runs:
                yield path.name.replace(".colors.json", ""), item, run


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_all = "--all" in sys.argv
    directory = args[0] if args else ".codex-loop/focus-ui-qa/shots"
    groups = defaultdict(lambda: {"states": set(), "example": None})
    for state, item, run in measurements(directory):
        klass = classify(item, run)
        if klass == "decorative":
            continue
        fg = run["rgba"]
        key = (klass, tuple(fg), tuple(round(c, 3) for c in background(item, BACKDROPS["typical"])), item["kind"], round(run.get("size", 0), 1))
        group = groups[key]
        group["states"].add(state)
        if group["example"] is None:
            group["example"] = (item["path"], run.get("sample") or item.get("text", ""), item)
    rows = []
    for (klass, fg, bg_typical, kind, size), group in groups.items():
        item = group["example"][2]
        scores = {}
        for name, gray in BACKDROPS.items():
            bg = background(item, gray)
            fg_eff = over((fg[0], fg[1], fg[2], fg[3] * item["alpha"]), bg)
            scores[name] = (abs(apca(fg_eff, bg)), wcag(fg_eff, bg))
        need = THRESHOLDS[klass]
        failing = [n for n, (lc, _) in scores.items() if lc < need]
        rows.append((min(lc for lc, _ in scores.values()) - need, klass, need, fg, kind, size, scores, failing, group))
    rows.sort(key=lambda r: r[0])
    fails = [r for r in rows if r[7]]
    print(f"{directory}: {len(rows)} distinct pairs, {len(fails)} below threshold on at least one backdrop")
    print(f"{'need':>5} {'dark':>6} {'typ':>6} {'light':>6} {'wcag@typ':>8}  class  size  foreground rgba                      example")
    for margin, klass, need, fg, kind, size, scores, failing, group in rows:
        if not failing and not show_all:
            continue
        example = group["example"]
        mark = "".join("!" if n in failing else "." for n in BACKDROPS)
        print(
            f"{need:>5} {scores['dark'][0]:6.1f} {scores['typical'][0]:6.1f} {scores['light'][0]:6.1f} {scores['typical'][1]:8.2f}  "
            f"{klass:5s} {size:5.1f}  {[round(c, 3) for c in fg]!s:36s} {mark} {example[1][:26]!r} ({len(group['states'])} states)"
        )
    for name in BACKDROPS:
        count = sum(1 for r in rows if name in r[7])
        print(f"backdrop {name:8s} ({BACKDROPS[name]:.2f}): {count} pairs below threshold")


if __name__ == "__main__":
    main()
