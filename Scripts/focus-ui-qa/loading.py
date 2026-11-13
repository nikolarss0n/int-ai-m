"""Loading-state audit for the interview window, from the driver's `*.layout.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>                     (or QA_WINDOW / QA_WIDEN as for layout.py)
    QA_REDUCE_MOTION=1 QA_OUT=<dir2> focus-ui-qa-driver                     (the same window for Reduce Motion)
    python3 Scripts/focus-ui-qa/loading.py <dir> [<dir2> ...]

Checks, from the loading-states skill, on the laid-out views (points):
    spinner   a spinner where a placeholder shaped like the content belongs
    status    a placeholder with no words saying what is happening: on its card, or as the pill of
              its question in the list (the card stays quiet when the row already says it)
    cut       the words of a status (the capsule's, the card's) cut short by their own frame
    shift     the content that replaces a placeholder starts where the placeholder was: the answer's
              first line and bullets, and the code file's name and first row
    motion    with Reduce Motion on nothing moves; with it off the placeholder's highlight does
    story     each loading state the driver walks through shows what it should: the seconds after a few
              seconds, "Still ..." after ten, "Queued", "Transcribing...", "Connecting audio..."
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

SHIFT = 1.5     # points a card may move between its placeholder and its content
LINE = 3.0      # points the first line of text may sit off the first placeholder bar's centre
EDGE = 2.0      # points a line of text may start off its placeholder bar's leading edge
# A question's phase, as the pill in its row of the list writes it (small capitals).
PILL = "QuestionBurstStripView"


STATUS_WORDS = re.compile(r"^(Transcribing|Connecting audio|AI working|Hearing speech|Listening|Answer ready|Ready$|Generating|Still generating|Queued)")
CLIPPING = {2, 3, 4, 5}   # NSLineBreakMode values that clip or truncate


def load(directory):
    states = {}
    for path in sorted(Path(directory).glob("*.layout.json")):
        name = re.sub(r"^\d+-", "", path.name.replace(".layout.json", ""))
        states[name] = json.loads(path.read_text())
        typed = path.with_name(path.name.replace(".layout.json", ".type.json"))
        states[name]["typed"] = json.loads(typed.read_text()) if typed.exists() else []
    return states


def texts(data, within=None):
    return [i for i in data["items"] if i["kind"] == "text" and (within is None or within in i["path"])]


def surface_of(data, marker):
    """The outermost surface whose path ends in `marker[0]` (the view itself, not a part of it)."""
    found = [i for i in data["items"] if i["kind"] == "surface" and i["path"].endswith(marker + "[0]")]
    return min(found, key=lambda i: len(i["path"]), default=None)


def audit(directory):
    findings = defaultdict(dict)
    states = load(directory)

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    for state, data in states.items():
        items = data["items"]
        skeletons = [i for i in items if i["kind"] == "skeleton"]

        for item in items:
            if item["kind"] == "image" and item["text"] == "NSProgressIndicator":
                note("spinner", (item["path"][-40:],), "a spinner is showing; a wait shows a placeholder shaped like the content", state)

        for skeleton in skeletons:
            if "FocusAnswerView" in skeleton["path"]:
                # A narrow card keeps just the seconds ("6s"): the placeholder and the strip say the rest.
                caption = [t for t in texts(data, "FocusAnswerView") if re.match(r"(Generating|Still generating|Queued|\d+m \d+s$|\d+s$)", t["text"])]
                # Said once: while the question's row carries the word, the card adds only the seconds.
                caption += [t for t in texts(data, PILL) if re.match(r"(generating|queued)$", t["text"], re.I)]
                where = "the answer card"
            else:
                caption = [t for t in texts(data, "CodePanelView") if re.match(r"(Writing|Still writing)", t["text"])]
                where = "the code panel"
            if not caption:
                note("status", (where,), f"a placeholder in {where} has no words saying what is happening", state)

        for label in data["typed"]:
            if label["kind"] == "label" and STATUS_WORDS.match(label["text"]) and int(label["breaks"]) in CLIPPING \
                    and label.get("cellWidth", label["textWidth"]) > label["width"] + 0.05:
                note("cut", (label["text"][:24],), f'the status {label["text"][:28]!r} needs {label.get("cellWidth", label["textWidth"]):.0f} pt and has {label["width"]:.0f} pt', state)

        moving = data.get("moving", [])
        if data.get("reduceMotion"):
            for entry in moving:
                note("motion", (entry["path"][-40:],), f'{entry["path"].split(">")[-1]} still moves with Reduce Motion on', state)
            for skeleton in skeletons:
                if skeleton.get("animating"):
                    note("motion", ("skeleton",), "a placeholder still shimmers with Reduce Motion on", state)
        else:
            for skeleton in skeletons:
                if not skeleton.get("animating"):
                    note("motion", ("still",), "a placeholder is not shimmering", state)

    # shift: the placeholder and the content that replaces it
    for before, after in (("loading-answer-generating", "loading-answer-arrived"), ("loading-code-writing", "loading-code-arrived")):
        if before not in states or after not in states:
            continue
        b, a = states[before], states[after]
        skeleton = next((i for i in b["items"] if i["kind"] == "skeleton" and "FocusAnswerView" in i["path"]), None)
        if skeleton and skeleton["pieces"]:
            text = next((i for i in a["items"] if i["kind"] == "text" and "FocusAnswerView" in i["path"] and "NSTextView" in i["path"]), None)
            dot, bar = skeleton["pieces"][0], skeleton["pieces"][1]
            if text is None:
                note("shift", ("answer", "missing"), "the answer never replaced its placeholder", after)
            else:
                centre = bar[1] + bar[3] / 2
                first = text["box"][1] + 9
                if abs(centre - first) > LINE:
                    note("shift", ("answer", "line"), f"the first line of the answer starts {first - centre:+.1f} pt from where its placeholder bar was", after)
                if abs(dot[0] - (text["box"][0] + 1)) > 2:
                    note("shift", ("answer", "edge"), f"the answer's bullets start {text['box'][0] + 1 - dot[0]:+.1f} pt from the placeholder's dots", after)
            card_b, card_a = surface_of(b, "FocusAnswerView"), surface_of(a, "FocusAnswerView")
            if card_b and card_a and any(abs(card_b["box"][k] - card_a["box"][k]) > SHIFT for k in range(4)):
                note("shift", ("answer", "card"), "the answer card changed size or place when its words arrived", after)
        placeholder = next((i for i in b["items"] if i["kind"] == "skeleton" and "CodeStepSkeletonView" in i["path"]), None)
        if placeholder and placeholder["pieces"]:
            in_file = [i for i in a["items"] if i["kind"] == "text" and "CodeFileView" in i["path"]]
            name = next((i for i in in_file if i["path"].split(">")[-1].startswith("NSTextField")), None)
            code = next((i for i in in_file if "NSTextView" in i["path"]), None)
            if name is None or code is None:
                note("shift", ("code", "missing"), "the code never replaced its placeholder", after)
            else:
                # The first bar is the file's name; the bars after it are the rows of the file. A label
                # draws its text 2 pt inside its frame, and a line of 12 pt text is about 16 pt tall.
                first, rows = placeholder["pieces"][0], placeholder["pieces"][1:]
                if abs(first[0] - (name["box"][0] + 2)) > EDGE or abs(first[1] + first[3] / 2 - (name["box"][1] + 8)) > LINE:
                    note("shift", ("code", "name"), "the file's name is not where its placeholder bar was", after)
                starts = [piece for piece in rows if abs(piece[0] - code["box"][0]) <= EDGE]
                if not starts:
                    note("shift", ("code", "edge"), "no placeholder bar starts where the code starts", after)
                else:
                    off = code["box"][1] + 8 - (starts[0][1] + starts[0][3] / 2)
                    if abs(off) > LINE:
                        note("shift", ("code", "line"), f"the first line of the file starts {off:+.1f} pt from where its placeholder bar was", after)

    # story: what each loading state should say
    def expect(state, scope, pattern, label):
        data = states.get(state)
        if data is None:
            return
        if not any(re.search(pattern, t["text"]) for t in texts(data, scope)):
            note("story", (state, label), f"{state}: expected {label}", state)

    def expect_phase(state, word):
        """The question's phase, on its card or as the pill in its row: one of them says it."""
        data = states.get(state)
        if data is None:
            return
        said = [t["text"] for t in texts(data, "FocusAnswerView") + texts(data, PILL)]
        if not any(text.lower() == word.lower() for text in said):
            note("story", (state, word), f"{state}: expected {word} on the card or in the question's row", state)

    expect("loading-transcribing", "AIActivityCapsuleView", r"Transcribing", "Transcribing in the capsule")
    expect("loading-connecting", "AIActivityCapsuleView", r"Connecting audio", "Connecting audio in the capsule")
    expect_phase("loading-answer-generating", "Generating")
    # A card too narrow for the whole line keeps just the seconds.
    expect("loading-answer-slow", "FocusAnswerView", r"^(Generating\W+)?6s$", "Generating and the seconds")
    expect("loading-answer-stalled", "FocusAnswerView", r"^(Still generating\W+)?12s$", "Still generating and the seconds")
    expect_phase("loading-answer-arrived", "Answering")
    expect_phase("loading-answer-queued", "Queued")
    expect("loading-code-writing", "CodePanelView", r"^Writing$", "a plain Writing in the code panel")
    expect("loading-code-slow", "CodePanelView", r"^Writing\W+6s$", "Writing and the seconds in the code panel")

    return findings


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for directory in dirs:
        findings = audit(directory)
        count = sum(len(v) for v in findings.values())
        total += count
        print(f"\n== {directory}: {count} findings")
        for kind in ("spinner", "status", "cut", "shift", "motion", "story"):
            rows = findings.get(kind, {})
            if not rows:
                continue
            print(f"{kind}: {len(rows)}")
            for entry in rows.values():
                print(f"  {entry['line']}  ({len(entry['states'])} states)")
    print(f"\n{total} findings in total")


if __name__ == "__main__":
    main()
