"""Layout audit for the interview window, from the driver's `*.layout.json` snapshots.

    QA_WINDOW=760x500 QA_WIDEN=0 QA_OUT=<dir> focus-ui-qa-driver     (or build-driver.py <dir> for the default)
    python3 Scripts/focus-ui-qa/layout.py <dir> [<dir> ...]

Checks, from the better-layout skill, on boxes measured in the laid-out views (points):
    overlap        two pieces of text or controls occupy the same space
    out of bounds  something sticks out of the surface it sits on, or out of the window
    hidden         content scrolls out of sight with nothing to hint at it, or a control is dropped
    margins        text in a column or row presses against its trailing edge
    edges          two pieces of text start 1-4 points apart, in one surface or in neighbouring ones
                   (a label above a card and the card's own text): a stray edge, not a shared one;
                   or text is indented past the surface's inset with nothing in the gutter it leaves
    targets        borderless controls closer than their own size to each other, filled ones closer than 12
    groups         the gap between groups is at least twice the gap within one (checked on the command bar)
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

LEAVES = {"text", "button", "image"}
INSET = 16  # Token.Space.inset


def rect(item):
    x, y, w, h = item["visible"] or item["box"]
    return x, y, x + w, y + h


def shown(item):
    """False when a scroll view clips the item away entirely."""
    return bool(item.get("visible", [1]))


def overlap_area(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return max(w, 0) * max(h, 0)


def load(directory):
    for path in sorted(Path(directory).glob("*.layout.json")):
        data = json.loads(path.read_text())
        yield path.name.replace(".layout.json", ""), data["window"], data["items"], data.get("dropped", [])


def audit(directory):
    findings = defaultdict(dict)

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    for state, (win_w, win_h), items, dropped in load(directory):
        by_path = {item["path"]: item for item in items}
        leaves = [i for i in items if i["kind"] in LEAVES and shown(i)]
        surfaces = [i for i in items if i["kind"] == "surface"]

        # controls laid out and then hidden
        for name in dropped:
            note("hidden", ("dropped", name), f'control {name!r} is dropped from view when it does not fit', state)

        # overlap
        for index, a in enumerate(leaves):
            for b in leaves[index + 1:]:
                if a["path"].startswith(b["path"]) or b["path"].startswith(a["path"]):
                    continue
                area = overlap_area(rect(a), rect(b))
                if area > 6:
                    note("overlap", (a["text"][:18], b["text"][:18]),
                         f'{a["kind"]} {a["text"][:22]!r} and {b["kind"]} {b["text"][:22]!r} share {area:.0f} pt²', state)

        # out of bounds
        for item in leaves:
            x0, y0, x1, y1 = rect(item)
            if x0 < -0.5 or y0 < -0.5 or x1 > win_w + 0.5 or y1 > win_h + 0.5:
                note("out of bounds", (item["text"][:18], "window"), f'{item["kind"]} {item["text"][:26]!r} leaves the window', state)
            parent = by_path.get(item["surface"])
            if parent:
                px0, py0, px1, py1 = rect(parent)
                over = max(px0 - x0, py0 - y0, x1 - px1, y1 - py1)
                if over > 0.75:
                    note("out of bounds", (item["text"][:18], parent["path"][-24:]),
                         f'{item["kind"]} {item["text"][:26]!r} sticks out of its surface by {over:.1f} pt', state)

        # margins: text and glyphs in a column or row keep 8 points from its trailing edge
        for item in leaves:
            parent = by_path.get(item["surface"])
            if parent and "QuestionBurstStripView" in parent["path"] and parent["path"].count(">") > parent["path"].index("QuestionBurstStripView") // 1 - 1000:
                if parent["path"].endswith("QuestionBurstStripView[0]"):
                    continue
                gap = (parent["box"][0] + parent["box"][2]) - (item["box"][0] + item["box"][2])
                if item["kind"] in ("text", "image") and gap < 8 - 0.01:
                    note("margins", (item["text"][:16], "column"), f'{item["text"][:22]!r} ends {gap:.0f} pt from the edge of its column', state)

        # content that scrolls out of sight
        for item in items:
            if item["kind"] == "scroll" and item["contentHeight"] > item["visibleHeight"] + 12 and not item["hasCue"]:
                note("hidden", (item["path"][-40:],),
                     f'scroll view holds {item["contentHeight"]:.0f} pt in {item["visibleHeight"]:.0f} pt with no cue', state)

        # stray edges: leading edges within a surface that differ by 1-4 points
        groups = defaultdict(list)
        for item in leaves:
            if item["kind"] == "text" and item.get("align", 0) in (0, 4):
                groups[item["surface"]].append(item)
            elif item["kind"] == "image":
                groups[item["surface"]].append(item)
        for surface, members in groups.items():
            edges = sorted({round(m["box"][0], 1) for m in members})
            for a, b in zip(edges, edges[1:]):
                if 1.0 <= b - a <= 4.0:
                    left = [m for m in members if round(m["box"][0], 1) == a][0]
                    right = [m for m in members if round(m["box"][0], 1) == b][0]
                    note("edges", (surface[-24:], a, b),
                         f'{left["text"][:20]!r} starts at {a:g}, {right["text"][:20]!r} at {b:g} in {surface.split(">")[-1] or "root"}', state)

        # stray edges across surfaces: left-aligned text stacked above or below other text keeps its edge
        texts = [i for i in leaves if i["kind"] == "text" and i.get("align", 0) in (0, 4) and i["text"].strip()]
        for index, a in enumerate(texts):
            for b in texts[index + 1:]:
                if a["surface"] == b["surface"]:
                    continue
                ax0, ay0, ax1, ay1 = rect(a)
                bx0, by0, bx1, by1 = rect(b)
                stacked = min(ax1, bx1) - max(ax0, bx0) >= 40 and max(ay0 - by1, by0 - ay1) <= 80
                gap = abs(a["box"][0] - b["box"][0])
                if stacked and 1.0 <= gap <= 4.0:
                    left, right = sorted((a, b), key=lambda t: t["box"][0])
                    note("edges", (left["text"][:16], right["text"][:16]),
                         f'{left["text"][:20]!r} starts at {left["box"][0]:g}, {right["text"][:20]!r} at {right["box"][0]:g} in the surface above or below', state)

        # holes: text indented more than a step past the surface's inset needs an icon, badge, number or
        # dot in the gutter it leaves; an indent with nothing in it reads as a third, unexplained edge
        gutter_items = [i for i in items if i["kind"] in LEAVES | {"surface"} and shown(i)]
        for item in texts:
            parent = by_path.get(item["surface"])
            if not parent or "AIActivityCapsuleView" in item["path"]:
                continue
            px, py, pw, ph = parent["box"]
            x, top, w, height = item["box"]
            start = px + INSET
            if x - start <= 12 or (px + pw) - (x + w) < 24:
                continue  # not indented, or anchored to the trailing edge
            filled = any(
                other is not item and other["path"] != parent["path"]
                and other["box"][0] + other["box"][2] > start - 2 and other["box"][0] < x
                and other["box"][2] < pw - 8
                and min(other["box"][1] + other["box"][3], top + height) - max(other["box"][1], top) >= 0.5 * min(other["box"][3], height)
                for other in gutter_items
            )
            if not filled:
                note("edges", (item["text"][:20], "hole"),
                     f'{item["text"][:24]!r} is indented {x - start:.0f} pt past the inset of its surface with nothing in the gutter', state)

        # targets: neighbours in one row
        controls = [i for i in leaves if i["kind"] == "button"]
        rows = defaultdict(list)
        for c in controls:
            rows[(c["surface"], round(c["box"][1] / 4))].append(c)
        for row in rows.values():
            row.sort(key=lambda c: c["box"][0])
            for a, b in zip(row, row[1:]):
                gap = b["box"][0] - (a["box"][0] + a["box"][2])
                if gap < 0:
                    continue
                filled = a.get("filled") and b.get("filled")
                # Compact chrome: borderless icon buttons of 26 points or more may sit 6 apart.
                need = 12 if filled else (6 if min(a["box"][2], a["box"][3], b["box"][2], b["box"][3]) >= 26 else 24)
                if gap < need - 0.75 and not (a["box"][2] > 60 and b["box"][2] > 60):
                    note("targets", (a["text"][:14], b["text"][:14]),
                         f'{a["text"][:18]!r} to {b["text"][:18]!r}: {gap:.0f} pt ({"filled" if filled else "borderless"})', state)

        # vertical groups: the strip's label belongs to the strip, so it sits twice as far from the card above
        label = next((i for i in leaves if i["kind"] == "text" and i["text"].startswith("QUESTIONS")), None)
        strip = next((i for i in surfaces if i["path"].endswith("QuestionBurstStripView[0]")), None)
        cards = [i for i in surfaces if i["path"].endswith(("FocusAnswerView[0]", "InterviewBriefingView[0]"))]
        if label and strip and cards:
            above = max(rect(c)[3] for c in cards if shown(c))
            inside = strip["box"][1] - (label["box"][1] + label["box"][3])
            between = label["box"][1] - above
            if between < 2 * inside - 0.01:
                note("groups", ("label",), f'the strip label is {inside:.0f} pt from the strip and {between:.0f} pt from the card above it', state)

        # groups on the command bar: navigation | start | audio | utilities, twice the gap inside a group
        bar = sorted([i for i in leaves if i["path"].startswith("bar") and i["kind"] == "button"], key=lambda c: c["box"][0])
        names = [b["text"] for b in bar]
        boundaries = [i for i, n in enumerate(names[:-1]) if n in ("Code", "Start interview", "End interview")]
        if boundaries and len(bar) > 3:
            gaps = {i: bar[i + 1]["box"][0] - (bar[i]["box"][0] + bar[i]["box"][2]) for i in range(len(bar) - 1)}
            within = min(g for i, g in gaps.items() if i not in boundaries and g >= 0)
            for i in boundaries:
                if gaps[i] < 2 * within - 0.01:
                    note("groups", ("bar", names[i]), f'command bar: {names[i]!r} to {names[i + 1]!r} is {gaps[i]:g} pt, the gap inside a group is {within:g} pt', state)

    return findings


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for directory in dirs:
        findings = audit(directory)
        count = sum(len(v) for v in findings.values())
        total += count
        print(f"\n== {directory}: {count} findings")
        for kind in ("overlap", "out of bounds", "hidden", "margins", "edges", "targets", "groups"):
            rows = findings.get(kind, {})
            if not rows:
                continue
            print(f"{kind}: {len(rows)}")
            for entry in rows.values():
                print(f"  {entry['line']}  ({len(entry['states'])} states)")
    print(f"\n{total} findings in total")


if __name__ == "__main__":
    main()
