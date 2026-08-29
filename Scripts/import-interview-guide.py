#!/usr/bin/env python3
"""Convert interview-questions-qa.json into a Practice bank pack."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path.home() / "Downloads" / "interview-questions-qa.json"
REPO_SOURCE = ROOT / "Resources" / "practice" / "sources" / "interview-questions-qa.json"
OUT = ROOT / "Resources" / "practice" / "interview-guide.json"


def slug(text: str) -> str:
    s = text.lower().replace("&", " and ")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


# Topic-heading tabs: titles like "Data Types" become "Explain Data Types."
# Coding/logic tabs keep the original prompt text, including line breaks.
HEADING_TABS = {
    "jr-javascript",
    "mid-javascript",
    "senior-javascript",
    "oop",
    "devops",
}

QUESTION_STARTERS = (
    "what ", "how ", "why ", "explain ", "describe ", "when ", "which ",
    "find ", "write ", "implement ", "compare ", "list ", "design ",
)


def tidy_lines(text: str) -> str:
    lines = [re.sub(r"[ \t]+", " ", line).rstrip() for line in text.strip("\n").splitlines()]
    return "\n".join(line for line in lines if line).strip()


def polish_question(text: str, group_id: str) -> str:
    q = tidy_lines(text)
    if not q:
        return q
    if "?" in q:
        return q
    lower = q.lower()
    if lower.startswith(QUESTION_STARTERS):
        if "\n" not in q and q[-1] not in ".!?":
            return q + "."
        return q
    if "\n" in q or "problem:" in lower:
        return q
    if group_id in HEADING_TABS and len(q) <= 90:
        return f"Explain {q}."
    return q


def polish_answer(text: str) -> str:
    a = text.strip()
    if a.lower().startswith("core explanation:"):
        a = a.split(":", 1)[1].strip()
    return a


def convert(source: Path) -> dict:
    data = json.loads(source.read_text(encoding="utf-8"))
    groups = []
    questions = []
    seen_groups = set()
    for tab in data.get("tabs", []):
        name = (tab.get("name") or "General").strip()
        group_id = slug(name)
        if group_id not in seen_groups:
            groups.append({"id": group_id, "title": name})
            seen_groups.add(group_id)
        for index, item in enumerate(tab.get("items") or []):
            raw_q = (item.get("question") or "").strip()
            if not raw_q:
                continue
            answer = polish_answer(item.get("answer") or "")
            follow = [tidy_lines(str(f)) for f in (item.get("follow_ups") or []) if str(f).strip()]
            if not answer and follow:
                answer = "Follow-up questions:\n" + "\n".join(f"- {f}" for f in follow)
            section = (item.get("section") or "").strip()
            questions.append({
                "id": f"{group_id}-{index}",
                "packId": "interview-guide",
                "groupId": group_id,
                "topicId": slug(section) if section else group_id,
                "topicTitle": section or name,
                "text": polish_question(raw_q, group_id),
                "hints": follow[:5],
                "rubric": answer,
                "answer": answer,
            })
    return {
        "packs": [{
            "id": "interview-guide",
            "title": data.get("title") or "Interview guide",
            "blurb": "Questions and answers from the interview guide doc, kept close to the original wording.",
            "groups": groups,
            "questions": questions,
        }],
        "positions": [],
    }


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else (DEFAULT_SOURCE if DEFAULT_SOURCE.exists() else REPO_SOURCE)
    if not source.exists():
        raise SystemExit(f"Source not found: {source}")
    if source != REPO_SOURCE:
        REPO_SOURCE.parent.mkdir(parents=True, exist_ok=True)
        REPO_SOURCE.write_bytes(source.read_bytes())
    bank = convert(source)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(bank, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    pack = bank["packs"][0]
    print(f"Wrote {OUT}")
    print(f"groups={len(pack['groups'])} questions={len(pack['questions'])}")
    print(" ".join(g["id"] for g in pack["groups"]))


if __name__ == "__main__":
    main()
