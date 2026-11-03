"""Typography audit for the interview window, from the driver's `*.type.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>
    python3 Scripts/focus-ui-qa/type.py <dir> [--all]

Everything is read from the laid-out views: font, tracking, line pitch, characters per line,
whether the text fits its frame, and whether a truncated string has a tooltip. Wrapped text is laid
out again in a private TextKit stack at the view's width, so the numbers describe what is drawn.

Checks, from the better-typography skill, in points (1 pt is 1 css px):
    size            sentence-case text at 12 or more, capitals at 11 or more
    truncation      text that is cut off must have its full value in a tooltip; clipping is never allowed
    fit             wrapped text needs the height its lines take
    tracking        small capitals carry positive letter-spacing (about 0.05 em)
    tabular digits  text with digits that change is set in a tabular-digit font
    line height     body copy 1.5, text of three or more lines at least 1.4, other wrapped text 1.3,
                    headings (17 points or more, semibold, two lines at most) 1.2
    measure         at most 75 characters on a full line
    hanging indent  a bullet that wraps hangs, so the second line starts under the text
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

FLOOR = 12
CAPS_FLOOR = 11
MEASURE = 75
CLIP_MODES = {2: "clips", 3: "truncates head", 4: "truncates tail", 5: "truncates middle"}


def load(directory):
    for path in sorted(Path(directory).glob("*.type.json")):
        for item in json.loads(path.read_text()):
            item["state"] = path.name.replace(".type.json", "")
            yield item


def weight_name(w):
    return {0.0: "regular", 0.23: "medium", 0.3: "semibold", 0.4: "bold"}.get(round(w, 2), f"{w:.2f}")


def is_truncated(item):
    if item["kind"] == "label" or item["kind"] == "button":
        need = item.get("cellWidth", item["textWidth"])
        return int(item["breaks"]) in CLIP_MODES and need > item["width"] + 0.5
    if item["kind"] == "wrapping" and item["maxLines"] > 0:
        return item["lines"] > item["maxLines"] or (
            item["lines"] == item["maxLines"] and item["textWidth"] > (item["width"] - 4) * item["maxLines"] * 1.0 + 0.5)
    return False


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    directory = args[0] if args else ".codex-loop/focus-ui-qa/shots"
    items = list(load(directory))
    findings = defaultdict(dict)

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    for item in items:
        size, upper = item["size"], item["upper"]
        label = f'{item["text"][:30]!r} {size:g}pt {weight_name(item["weight"])}'
        floor = CAPS_FLOOR if upper else FLOOR
        if size < floor and item["chars"] > 1:
            note("size", (size, upper, item["text"][:30]), label + (" caps" if upper else ""), item["state"])
        if is_truncated(item):
            need = item.get("cellWidth", item["textWidth"])
            clipped = int(item["breaks"]) == 2
            if item["toolTip"] and not clipped:
                note("cut, full text on hover", (item["text"][:30], item["width"]), f'{label}: needs {need:.0f}pt, has {item["width"]:.0f}pt', item["state"])
            if clipped or not item["toolTip"]:
                tip = "tooltip" if item["toolTip"] else "NO tooltip"
                mode = CLIP_MODES.get(int(item["breaks"]), "clamped")
                note("truncation", (item["text"][:30], item["width"]), f'{label}: needs {need:.0f}pt, has {item["width"]:.0f}pt ({mode}, {tip})', item["state"])
        if item["kind"] == "wrapping" and item.get("usedHeight", 0) > 0 and item["lines"] > 0:
            shown = min(item["lines"], item["maxLines"]) if item["maxLines"] > 0 else item["lines"]
            needed = item["usedHeight"] * shown / item["lines"]
            if needed > item["height"] + 0.05:
                note("fit", (item["text"][:30], size), f'{label}: {shown} lines need {needed:.1f}pt, frame is {item["height"]:.1f}pt (a line that does not fit is dropped)', item["state"])
        if upper and item["kern"] <= 0 and item["chars"] >= 2:
            note("tracking", (item["text"][:30], size), f'{label}: capitals with no letter-spacing', item["state"])
        if item["hasDigits"] and not item["tabular"] and item["kind"] in ("label", "wrapping", "button"):
            note("digits", (item["text"][:30], size), f'{label}: digits are proportional', item["state"])
        if item["lines"] >= 2 and item["size"] > 0:
            ratio = item["pitch"] / item["size"]
            shown = min(item["lines"], item["maxLines"]) if item["maxLines"] > 0 else item["lines"]
            heading = item["size"] >= 17 and item["weight"] >= 0.3 and shown <= 2
            body = item["size"] >= 15 and not heading
            need = 1.2 if heading else (1.5 if body else (1.4 if item["lines"] >= 3 else 1.3))
            if ratio < need - 0.02:
                note("line height", (item["text"][:30], size), f'{label}: {item["lines"]} lines at {ratio:.2f}, wants {need}', item["state"])
        if item["kind"] in ("wrapping", "textview") and item["maxLineChars"] > MEASURE and item["lines"] >= 2 and "mono" not in item["font"].lower():
            note("measure", (item["text"][:30], size), f'{label}: {item["maxLineChars"]} characters on a full line', item["state"])
        for paragraph in item.get("paragraphs", []):
            if paragraph["bullet"] and paragraph["lines"] >= 2 and paragraph["headIndent"] <= paragraph["firstIndent"]:
                note("hanging indent", (paragraph["text"],), f'{paragraph["text"]!r}: wraps to {paragraph["lines"]} lines under its bullet', item["state"])

    inventory = defaultdict(lambda: {"states": set(), "example": None, "count": 0})
    for item in items:
        family = "mono" if "mono" in item["font"].lower() else ("digits" if item["font"].startswith(".SFNS") else "text")
        key = (item["size"], weight_name(item["weight"]), family)
        entry = inventory[key]
        entry["states"].add(item["state"])
        entry["count"] += 1
        entry["example"] = entry["example"] or item["text"][:28]

    print(f"{directory}: {len(items)} text elements in {len({i['state'] for i in items})} states")
    sizes = sorted({k[0] for k in inventory})
    print(f"sizes in use: {', '.join(f'{s:g}' for s in sizes)}   weights: {', '.join(sorted({k[1] for k in inventory}))}   "
          f"styles (size x weight x face): {len(inventory)}")
    if "--all" in sys.argv:
        for (size, weight, family), entry in sorted(inventory.items()):
            print(f"  {size:>5g}pt {weight:9s} {family:6s} x{entry['count']:<3d} e.g. {entry['example']!r}")
    total = 0
    for kind in ("size", "truncation", "fit", "tracking", "digits", "line height", "measure", "hanging indent", "cut, full text on hover"):
        rows = findings.get(kind, {})
        print(f"\n{kind}: {len(rows)}" + (" (not counted: check each has room to spare)" if kind.startswith("cut") else ""))
        for entry in rows.values():
            print(f"  {entry['line']}  ({len(entry['states'])} states)")
        if not kind.startswith("cut"):
            total += len(rows)
    print(f"\n{total} findings")


if __name__ == "__main__":
    main()
