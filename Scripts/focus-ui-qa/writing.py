"""Writing audit for the interview window, from the driver's `*.layout.json` and `*.type.json` snapshots.

    python3 Scripts/focus-ui-qa/build-driver.py <dir>
    python3 Scripts/focus-ui-qa/writing.py <dir> [<dir> ...]

Checks, from the better-writing skill, on the words the laid-out views show (the interviewer's questions,
the answers and the CV are content, not chrome, and are left alone):
    words     nothing the product does not say: no "Oops", "Please" or exclamation marks, no three periods,
              no "Something went wrong"
    terms     one word per idea: "Try again" not "Retry", "screenshot" not "shot", "Questions" not
              "Question burst", "CV" not "resume", "Interview Master" not "Interview Assistant"
    verbs     a button starts with a verb, or names the place it goes (Context, Timeline, Practice, Code, Settings);
              the mute button says what a click does, not only what the audio is doing
    case      one capitalization policy: sentence case for labels and buttons, with names as they are written
    topics    a topic reads as the words people say ("RAG and CAG"), not "Rag Cag" or "ragcag"
    empty     an empty state says what goes here and what to do
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

BANNED = [
    (r"\boops\b|\bwhoops\b", "an interjection; say what happened"),
    (r"\bplease\b", "please; state the action"),
    (r"!", "an exclamation mark"),
    (r"\.\.\.", "three periods; use the ellipsis character"),
    (r"something went wrong", "a shrug; say what failed"),
    (r"\bthe user\b", "the user; say you"),
]
TERMS = [
    (r"\bretry\b", "Retry", "Try again"),
    (r"\bshots?\b", "shot", "screenshot"),
    (r"question burst", "Question burst", "Questions"),
    (r"interview assistant", "Interview Assistant", "Interview Master"),
    (r"command-shift", "Command-Shift-M", "⌘⇧M"),
    (r"\bresume\b", "resume", "CV"),
    (r"\bstopped\b", "stopped", "ended"),
]
VERBS = {"Start", "End", "Try", "Show", "Hide", "Undo", "Open", "Copy", "Export", "Add", "Use", "Optimize",
         "Dismiss", "Previous", "Next", "Close", "Clear", "Save", "Cancel", "Select", "Widen"}
PLACES = {"Context", "Timeline", "Practice", "Code", "Settings"}
NAMES = {"Settings", "Finder", "TypeScript", "JavaScript", "Python", "Java", "Kotlin", "Swift", "Groq", "Anthropic",
         "Claude", "CV", "API", "AI", "LLM", "RAG", "CAG", "Interview", "Master", "Screen", "Recording", "Practice",
         "Playwright", "Test", "System", "Testing"}
MANGLED = re.compile(r"\b(Llm|Rag|Cag|Mlops|Cicd|Jvm|Oop|Aws|Api|Sql|Csharp|Cpp|Dotnet|Genai|Ragcag)\b|\b[A-Z] [A-Z]\b|\b[a-z]+[A-Z]\w*\b")
SEPARATOR = "\u2002·\u2002"
AUDIO_STATUS = ("Audio", "Listening", "Speech", "Switching", "Muted")


def load(directory):
    states = {}
    for path in sorted(Path(directory).glob("*.type.json")):
        name = re.sub(r"^\d+-", "", path.name.replace(".type.json", ""))
        entries = json.loads(path.read_text())
        layout = path.with_name(path.name.replace(".type.json", ".layout.json"))
        buttons = []
        if layout.exists():
            buttons = [i["text"] for i in json.loads(layout.read_text())["items"] if i["kind"] == "button"]
        states[name] = {"entries": entries, "buttons": buttons}
    return states


def is_content(entry):
    text = entry["text"]
    return (
        entry["kind"] == "textview"
        or "InterviewBriefingView" in entry["path"]
        or text.startswith("“")
        or text.rstrip().endswith("?")
        or re.search(r"\.(py|ts|js|java|swift)$", text) is not None
        or re.match(r"^[↳]", text) is not None
        or re.match(r"^\d[\d:/.]*$", text) is not None
    )


def audit(directory):
    findings = defaultdict(dict)
    states = load(directory)

    def note(kind, key, line, state):
        entry = findings[kind].setdefault(key, {"line": line, "states": set()})
        entry["states"].add(state)

    for state, data in states.items():
        chrome = [e for e in data["entries"] if not is_content(e) and e["kind"] in ("label", "button", "wrapping")]
        for entry in chrome:
            text = entry["text"]
            lowered = text.lower()
            for pattern, what in BANNED:
                if re.search(pattern, lowered):
                    note("words", (text[:40], what), f"{text[:60]!r} has {what}", state)
            for pattern, bad, good in TERMS:
                if re.search(pattern, lowered):
                    note("terms", (bad,), f"{text[:60]!r} says {bad!r}; the window says {good!r}", state)
            if MANGLED.search(text) and not entry.get("upper") and SEPARATOR not in text and entry["kind"] == "label" and entry.get("size", 0) >= 14:
                note("topics", (text,), f"{text!r} does not read as words", state)
            words = text.split(" ")
            if len(words) > 1 and not entry.get("upper") and SEPARATOR not in text and re.match(r"^[A-Z]", text):
                for previous, word in zip(words, words[1:]):
                    bare = re.sub(r"[^\w#+./-]", "", word)
                    starts_sentence = previous.endswith((".", "!", "?", ":"))
                    if bare and bare[0].isupper() and not starts_sentence and not bare.isupper() and bare not in NAMES and not re.match(r"^[A-Z]\w*[A-Z]", bare):
                        note("case", (text[:40],), f"{text[:60]!r} capitalizes {bare!r} mid-sentence", state)
                        break
        for text in data["buttons"]:
            if not text or text in ("Button", "NSButton", "segmented"):
                continue
            first = text.split(" ")[0]
            # The link from code to its question quotes the interviewer: content, not copy.
            if re.match(r"^Q\d+\b", text):
                continue
            if first in AUDIO_STATUS:
                if first in ("Listening", "Speech", "Muted") and "mute" not in text.lower():
                    note("verbs", (text,), f"the mute button says {text!r} but not what a click does", state)
                continue
            if first not in VERBS and text not in PLACES and not re.match(r"^[A-Z][a-z]+ (all|this|step|code|panel|version|latest|another|interview|tests?|[A-Z]\w+)\b", text):
                note("verbs", (text,), f"button {text!r} does not start with a verb", state)

    def texts(state):
        data = states.get(state)
        return [e["text"] for e in data["entries"]] if data else None

    welcome = texts("welcome")
    if welcome is not None and not any(t.startswith("Start the interview") for t in welcome):
        note("empty", ("welcome",), "the empty answer card does not say how to fill it", "welcome")
    for state, entries in ((s, texts(s)) for s in states):
        if entries and "Code appears here" in entries and not any(t.startswith("When the interviewer asks for code") for t in entries):
            note("empty", ("code",), "the empty code panel says what it is but not when it fills", state)
    acronym = texts("topic-acronym")
    # The card sets its topic in small capitals, so the rendered topic may be the uppercase of the stored one.
    if acronym is not None and "RAG and CAG" not in acronym and "RAG AND CAG" not in acronym:
        note("topics", ("ragCag",), f"the topic ragCag should read 'RAG and CAG', the card says {[t for t in acronym if 'ag' in t.lower()][:3]}", "topic-acronym")
    return findings


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for directory in dirs:
        findings = audit(directory)
        count = sum(len(v) for v in findings.values())
        total += count
        print(f"\n== {directory}: {count} findings")
        for kind in ("words", "terms", "verbs", "case", "topics", "empty"):
            rows = findings.get(kind, {})
            if not rows:
                continue
            print(f"{kind}: {len(rows)}")
            for entry in rows.values():
                print(f"  {entry['line']}  ({len(entry['states'])} states)")
    print(f"\n{total} findings in total")


if __name__ == "__main__":
    main()
