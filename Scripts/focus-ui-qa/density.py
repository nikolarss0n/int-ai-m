"""Information-density audit for the interview window, from the driver's `*.layout.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>      (or QA_WINDOW=WxH QA_WIDEN=0|1 QA_OUT=<dir> the driver)
    python3 Scripts/focus-ui-qa/density.py <dir> [<dir> ...]

Checks, from the critique-information-density skill, on boxes measured in the laid-out views (points):
    duplicates     the same words in two places at once (a status in the header and again in the bar)
    status         no activity status in view at all (the capsule follows the reader to the tab without a header)
    priority       the question list is taller than the answer it points at, or the answer has too
                   little room to read a few lines
    dead space     a list that holds its rows at the top and leaves the rest of its box empty
    empty          a surface with nothing in it: a box that claims space and says nothing
Reported, not judged: how many pieces of text and controls each state shows.
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

LEAVES = {"text", "button", "image"}
MIN_ANSWER_HEIGHT = 120
MIN_EMPTY_AREA = 2000


def region(item):
    path = item["path"]
    if "AIActivityCapsuleView" in path:
        return "bar capsule" if path.startswith("bar") else "header capsule"
    for token, name in (("FocusAnswerView", "answer"), ("InterviewBriefingView", "cv"),
                        ("QuestionBurstStripView", "strip"), ("CodePanelView", "code")):
        if token in path:
            return name
    return "bar" if path.startswith("bar") else "chrome"


def words(text):
    return re.sub(r"[^a-z]+", " ", text.lower()).strip()


def box(item):
    x, y, w, h = item["visible"] or item["box"]
    return x, y, w, h


def load(directory):
    for path in sorted(Path(directory).glob("*.layout.json")):
        data = json.loads(path.read_text())
        yield path.name.replace(".layout.json", ""), data["window"], data["items"]


def audit(directory):
    findings = defaultdict(dict)
    load_counts = {}

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    for state, (win_w, win_h), items in load(directory):
        leaves = [i for i in items if i["kind"] in LEAVES and i.get("visible", [1])]
        load_counts[state] = sum(1 for i in leaves if i["kind"] in ("text", "button"))

        # duplicates: the same words in two regions. The strip repeats a question the answer quotes on
        # purpose (one is clipped to a line, the other shows what was asked), so that pair is allowed.
        seen = defaultdict(set)
        for item in leaves:
            if item["kind"] != "text":
                continue
            key = words(item["text"])
            if len(key) >= 4:
                seen[key].add(region(item))
        for key, regions in seen.items():
            regions = regions - {"chrome"} if len(regions) > 1 else regions
            if len(regions) >= 2 and regions != {"answer", "strip"}:
                note("duplicates", (key,), f'"{key}" appears in {" and ".join(sorted(regions))}', state)

        # status: the activity capsule is in the header on the live tab and in the bar where the header is out of sight
        capsules = {region(i) for i in leaves if i["kind"] == "text" and "AIActivityCapsuleView" in i["path"]}
        if not capsules:
            note("status", ("capsule",), "no activity status is in view: the header's capsule is hidden and the bar's is too", state)

        # priority: the answer is what is being read
        answer = next((i for i in items if i["kind"] == "surface" and i["path"].endswith("FocusAnswerView[0]")), None)
        strip = next((i for i in items if i["kind"] == "surface" and i["path"].endswith("QuestionBurstStripView[0]")), None)
        if answer and answer.get("visible", [1]):
            answer_height = box(answer)[3]
            if answer_height < MIN_ANSWER_HEIGHT:
                note("priority", ("floor",), f"the answer card shows {answer_height:.0f} pt, under {MIN_ANSWER_HEIGHT} pt", state)
            if strip and box(strip)[3] > answer_height + 0.5:
                note("priority", ("strip",), f"the question list ({box(strip)[3]:.0f} pt) is taller than the answer ({answer_height:.0f} pt)", state)

        # dead space: rows that hug the top of a box taller than they are
        if strip:
            rows = [i for i in items if i["kind"] == "surface" and i["path"].startswith(strip["path"] + ">") and i["path"].count(">") == strip["path"].count(">") + 1]
            if rows:
                sx, sy, sw, sh = strip["box"]
                slack = (sy + sh) - max(r["box"][1] + r["box"][3] for r in rows)
                if slack > 12:
                    note("dead space", ("strip",), f"the question list leaves {slack:.0f} pt of its box empty below its rows", state)

        # empty: a surface with no text, control, glyph or surface inside it
        for surface in items:
            if surface["kind"] != "surface" or surface["path"] in ("bar",):
                continue
            x, y, w, h = surface["box"]
            if w * h < MIN_EMPTY_AREA:
                continue
            inside = [i for i in items if i is not surface and i["path"].startswith(surface["path"] + ">")]
            if not inside:
                note("empty", (surface["path"][-40:],), f'an empty {w:.0f} x {h:.0f} pt box ({surface["path"].split(">")[-1]})', state)

    return findings, load_counts


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for directory in dirs:
        findings, load_counts = audit(directory)
        count = sum(len(v) for v in findings.values())
        total += count
        busiest = max(load_counts.items(), key=lambda kv: kv[1]) if load_counts else ("-", 0)
        mean = sum(load_counts.values()) / max(1, len(load_counts))
        print(f"\n== {directory}: {count} findings   (text and controls per state: mean {mean:.0f}, most {busiest[1]} in {busiest[0]})")
        for kind in ("duplicates", "status", "priority", "dead space", "empty"):
            rows = findings.get(kind, {})
            if not rows:
                continue
            print(f"{kind}: {len(rows)}")
            for entry in rows.values():
                print(f"  {entry['line']}  ({len(entry['states'])} states)")
    print(f"\n{total} findings in total")


if __name__ == "__main__":
    main()
