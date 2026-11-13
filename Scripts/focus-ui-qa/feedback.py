"""Feedback audit for the interview window, from the driver's `*.layout.json` and `*.type.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>                     (or QA_WINDOW / QA_WIDEN as for layout.py)
    python3 Scripts/focus-ui-qa/feedback.py <dir> [<dir> ...]

Checks, from the feedback-patterns skill, on what the laid-out views say:
    status     the capsule says what is true: "Muted" when muted, "No audio" when there is none, never "Ready"
    error      a failure reaches the window as words and an icon, with a close button because it stays;
               a confirmation does not cover it, and hearing a question again clears it
    confirm    a confirmation is words and an icon and goes by itself: no close button
    undo       clearing something says what went and offers "Undo"
    card       a failed answer says why and offers "Try again"; asking again leaves no failure behind
    cut        the words of a notice cut short by their own frame
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

CLIPPING = {2, 3, 4, 5}   # NSLineBreakMode values that clip or truncate


def load(directory):
    states = {}
    for path in sorted(Path(directory).glob("*.layout.json")):
        name = re.sub(r"^\d+-", "", path.name.replace(".layout.json", ""))
        data = json.loads(path.read_text())
        typed = path.with_name(path.name.replace(".layout.json", ".type.json"))
        data["typed"] = json.loads(typed.read_text()) if typed.exists() else []
        states[name] = data
    return states


def within(data, marker, kind=None):
    return [i for i in data["items"] if marker in i["path"] and (kind is None or i["kind"] == kind)]


def audit(directory):
    findings = defaultdict(dict)
    states = load(directory)

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    def capsule(state):
        data = states.get(state)
        return [t["text"] for t in within(data, "AIActivityCapsuleView", "text")] if data else []

    def notice(state):
        data = states.get(state)
        if not data:
            return None
        return {
            "text": [t["text"] for t in within(data, "FocusNoticeView", "text")],
            "icons": within(data, "FocusNoticeView", "image"),
            "buttons": [b["text"] for b in within(data, "FocusNoticeView", "button")],
        }

    def expect_capsule(state, pattern, label):
        if states.get(state) is not None and not any(re.search(pattern, t) for t in capsule(state)):
            note("status", (state,), f"{state}: the capsule should say {label}, it says {capsule(state)}", state)

    expect_capsule("feedback-audio-muted", r"^Muted$", "Muted")
    expect_capsule("feedback-audio-unavailable", r"^No audio$", "No audio")
    expect_capsule("feedback-audio-restored", r"^Listening$", "Listening")
    for state in ("feedback-audio-muted", "feedback-audio-unavailable"):
        if any(t == "Ready" for t in capsule(state)):
            note("status", (state, "ready"), f"{state}: the capsule says Ready while nothing can be heard", state)

    def expect_notice(state, pattern, label, dismissable, action=None):
        found = notice(state)
        if found is None:
            return
        if not any(re.search(pattern, t) for t in found["text"]):
            note("error" if dismissable else "confirm", (state, "words"), f"{state}: expected {label}, found {found['text']}", state)
            return
        if not found["icons"]:
            note("error" if dismissable else "confirm", (state, "icon"), f"{state}: the notice is words and colour only, with no icon", state)
        has_dismiss = "Dismiss" in found["buttons"]
        if dismissable and not has_dismiss:
            note("error", (state, "dismiss"), f"{state}: an error that stays has no close button", state)
        if not dismissable and has_dismiss:
            note("confirm", (state, "dismiss"), f"{state}: a notice that goes by itself has a close button", state)
        if action and action not in found["buttons"]:
            note("undo", (state, action), f"{state}: expected a {action!r} button, found {found['buttons']}", state)

    expect_notice("feedback-error", r"^Couldn't transcribe\. Check your conn", "the transcription error, with its fix", True)
    expect_notice("feedback-error-kept", r"^Couldn't transcribe\. Check your conn", "the error still showing after a confirmation", True)
    expect_notice("feedback-confirmation", r"^Screenshot captured$", "the screenshot confirmation", False)
    expect_notice("feedback-undo", r"^Cleared 2 screenshots and the pinned", "what was cleared", False, action="Undo")

    expect_notice("feedback-error-key", r"^Groq API key rejected$", "the rejected key", True, action="Open Settings")
    expect_notice("feedback-error-screenshot", r"^Couldn't capture the screenshot$", "the failed screenshot", True, action="Try again")

    # Every real notice keeps its fix on the line, and none is cut short beside the busiest capsule.
    expect_notice("notice-widest-analyze", r"^No screenshots yet\. Press", "the empty analyze notice", False)
    expect_notice("notice-widest-busy", r"^Transcription is busy\. Ask again", "the busy notice, with its fix", True)
    expect_notice("notice-widest-timeout", r"^Transcription timed out\. Ask again", "the timeout notice, with its fix", True)
    expect_notice("notice-widest-session", r"^Couldn't save the session$", "the failed save", True, action="Export")
    expect_notice("notice-widest-saved", r"^Session saved$", "the saved session", False, action="Show in Finder")
    expect_notice("notice-widest-exported", r"^Exported interview_2026", "the export", False)
    expect_notice("notice-widest-nothing", r"^Nothing to export yet$", "the empty export", False)

    resolved = notice("feedback-error-resolved")
    if resolved is not None and resolved["text"]:
        note("error", ("resolved",), f"feedback-error-resolved: the error is still there after a question was heard: {resolved['text']}", "feedback-error-resolved")

    failed = states.get("feedback-answer-failed")
    if failed is not None:
        card = [t["text"] for t in within(failed, "FocusAnswerView", "text")]
        buttons = [b["text"] for b in within(failed, "FocusAnswerView", "button")]
        if "Couldn't generate the answer" not in card:
            note("card", ("failed",), "the failed card does not say the answer failed", "feedback-answer-failed")
        if not any(re.match(r"The model took too long", t) for t in card):
            note("card", ("reason",), f"the failed card gives no reason: {card}", "feedback-answer-failed")
        if "Try again" not in buttons:
            note("card", ("retry",), f"the failed card offers no way to try again: {buttons}", "feedback-answer-failed")
    retried = states.get("feedback-answer-retried")
    if retried is not None:
        card = [t["text"] for t in within(retried, "FocusAnswerView", "text")]
        buttons = [b["text"] for b in within(retried, "FocusAnswerView", "button")]
        if "Couldn't generate the answer" in card or "Try again" in buttons:
            note("card", ("retried",), "asking again left the failure on the card", "feedback-answer-retried")
        # The wait is the placeholder, with the word on the card or as the pill in the question's row.
        waiting = any(re.match(r"(Generating|Still generating|\d+s$)", t) for t in card) or (
            within(retried, "FocusAnswerView", "skeleton")
            and any(t["text"].lower() == "generating" for t in within(retried, "QuestionBurstStripView", "text")))
        if not waiting:
            note("card", ("waiting",), f"asking again shows no wait: {card}", "feedback-answer-retried")

    for state, data in states.items():
        for label in data["typed"]:
            if label["kind"] == "label" and int(label["breaks"]) in CLIPPING and "toolTip" in label \
                    and label["text"].startswith(("Couldn't", "Screenshot", "Cleared", "Restored", "Session", "Exported", "Nothing to", "No screenshots", "Transcription", "Groq")) \
                    and label.get("cellWidth", label["textWidth"]) > label["width"] + 0.05:
                note("cut", (label["text"][:24],), f'the notice {label["text"][:32]!r} needs {label.get("cellWidth", label["textWidth"]):.0f} pt and has {label["width"]:.0f} pt', state)

    return findings


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for directory in dirs:
        findings = audit(directory)
        count = sum(len(v) for v in findings.values())
        total += count
        print(f"\n== {directory}: {count} findings")
        for kind in ("status", "error", "confirm", "undo", "card", "cut"):
            rows = findings.get(kind, {})
            if not rows:
                continue
            print(f"{kind}: {len(rows)}")
            for entry in rows.values():
                print(f"  {entry['line']}  ({len(entry['states'])} states)")
    print(f"\n{total} findings in total")


if __name__ == "__main__":
    main()
