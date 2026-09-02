#!/usr/bin/env python3
"""Rewrite leftover quiz stems, drills, and title-only prompts into spoken interview language.

Ids, groups, and topics stay put. Only text / answer / rubric / hints change.
Run after extract-study-book-practice.mjs so a re-extract does not restore MCQ stems.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "Resources" / "practice" / "bank.json"
GUIDE = ROOT / "Resources" / "practice" / "interview-guide.json"

SPOKEN_START = (
    "what ", "what's ", "whats ", "how ", "why ", "when ", "explain ", "describe ",
)

# Study-book quiz stems, fill-ins, and numbered drills → spoken prompts. Same topics.
STUDY_PROMPTS = {
    "ml-fundamentals-quiz-0": "What loss is standard for next-token and classification training?",
    "rag-quiz-0": "What metric measures whether the right chunks were retrieved?",
    "evals-quiz-0": "What is the biggest caveat of using an LLM as a judge?",
    "agents-quiz-0": "What should you do before letting an agent take an irreversible action?",
    "security-quiz-0": "What is a malicious instruction hidden inside a retrieved web page an example of?",
    "model-adaptation-quiz-0": "When knowledge changes weekly and needs citations, which approach do you use?",
    "optimization-quiz-0": "What does the KV cache primarily save you from?",
    "llmops-quiz-0": "When quality regresses after a release, what is the first thing version tracking gives you?",
    "drills-drill-0": "How would you design a customer-support RAG chatbot that uses documents, tickets, permissions, retrieval, citations, and a fallback?",
    "drills-drill-1": "How would you design a document ingestion pipeline for PDFs and HTML, including chunking, embeddings, dedup, and incremental updates?",
    "drills-drill-2": "How would you debug hallucinations in production by inspecting chunks, the prompt, the output, citations, and a stale index?",
    "drills-drill-3": "How would you design a safe tool-using agent, covering tool schema, auth, permissions, approval, logs, and rollback?",
    "drills-drill-4": "How would you estimate cost and latency from tokens per request, price, cache hit rate, concurrency, and streaming?",
    "drills-drill-5": "When would you choose RAG versus fine-tuning, and how do you justify it?",
    "drills-drill-6": "How would you design evals for a feature, covering dataset, metrics, judge rubric, human review, and a CI gate?",
    "drills-drill-7": "How would you build a fraud model end-to-end for imbalanced tabular data?",
    "drills-drill-8": "How would you productionize a model from a notebook to a monitored endpoint?",
    "drills-drill-9": "How should you validate a time-series model, and why does a naive backtest lie?",
    "drills-drill-10": "How would you design a FastAPI RAG query API using path, Pydantic, Depends, authz, async, and tests?",
    "drills-drill-11": "How would you review AI-generated FastAPI that uses sync requests, no Pydantic, an API key in a query param, and an LLM constructed at import?",
    "drills-drill-12": "How would you put hybrid, vector, and keyword retrieval behind one route using the Strategy pattern?",
    "drills-drill-13": "How would you expose agent tools over HTTP, covering tool use, planning, memory, and FastAPI-backed tools?",
    "data-science-stack-quiz-0": "Where do you fit a StandardScaler so you do not leak test-set statistics?",
    "feature-engineering-quiz-0": "For fraud detection with 1% positives, what metric do you trust?",
    "gradient-boosting-quiz-0": "Which library grows trees leaf-wise and is fastest on large datasets?",
    "deep-learning-frameworks-quiz-0": "Which framework is known for define-by-run dynamic graphs?",
    "model-serving-quiz-0": "Which tool optimizes inference specifically for NVIDIA GPUs?",
    "mlops-tooling-quiz-0": "When you need experiment tracking plus a model registry with stages, which tool do you reach for?",
    "pyspark-data-quiz-0": "Which Spark operation forces an expensive network shuffle?",
    "data-quality-quiz-1": "When you need to index 2M policy chunks, which encoder family do you use?",
    "data-quality-quiz-2": "What are the Bedrock Titan and Azure OpenAI embedding model ids and their dimensions?",
    "data-quality-quiz-3": "How do Pinecone, FAISS, and pgvector differ in one line?",
    "data-ingestion-quiz-0": "Should nightly embedding generation be real-time or batch, and why?",
    "python-concurrency-quiz-0": "When your endpoint is I/O-bound with many outbound API calls, what is the best tool?",
    "java-concurrency-quiz-0": "What is the difference between wait() and sleep()?",
    "java-collections-quiz-0": "When you need sorted, unique elements with O(log n) operations, which Set do you use?",
    "fastapi-quiz-0": "In FastAPI, which pair identifies a path operation?",
    "design-patterns-quiz-0": "When you A/B hybrid retrieval versus vector-only behind the same /query route, which pattern do you use?",
    "design-patterns-quiz-2": "When a LangGraph agent is assembled with add_node, add_edge, and compile(), which pattern is that?",
    "design-patterns-quiz-3": "When you want retries and a cache in front of an embeddings API without changing Retriever.search callers, which pattern do you use?",
    "design-patterns-quiz-5": "When token usage, retrieval misses, and tool calls must fan out to logs, metrics, and an eval dataset without coupling the FastAPI handler to each sink, which pattern do you use?",
    "graphrag-quiz-0": "Which Microsoft-style query pattern does Bedrock KB GraphRAG map to?",
    "graphrag-quiz-1": "When would you use CAG instead of RAG?",
    "semantic-layer-quiz-1": "In a very large document-management system, how would you retrieve an answer about Apple's suppliers?",
    "jd-gap-quiz-0": "Against the Senior AI Python Developer JD, which cluster was only a capstone FastAPI or Spring Boot bullet before this edition?",
    "senior-python-interview-quiz-2": "A FastAPI RAG handler is async def, calls requests.post to OpenAI, and checks tenant in the system prompt. What are the two production bugs?",
    "senior-python-interview-quiz-3": "If you need to swap embedding providers and add a cache without touching Retriever.search callers, which pair of patterns do you use?",
    "senior-python-interview-quiz-4": "When you A/B hybrid versus BM25 retrieval on the same FastAPI /query route, which pattern do you use, and where does the choice live?",
    "senior-python-interview-quiz-7": "Copilot generates a FastAPI handler with no Pydantic, an API key in a query param, ChatOpenAI at import, print(prompt), and no tests. What is the first review?",
    "langgraph-quiz-1": "A JD lists LangGraph, CrewAI, and LlamaIndex. Which one is the control-flow graph?",
    "evals-ci-quiz-0": "If faithfulness dropped but context recall is fine, what failed?",
    "dsa-sql-quiz-0": "How do you find the longest substring without repeating characters?",
    "dsa-sql-quiz-1": "What is the distinction between sorted two-sum and hash-map two-sum?",
    "dsa-sql-quiz-2": "After an O(n) preprocess, how do you compute sum(nums[l..r])?",
    "dsa-sql-quiz-3": "To finish piles [3,6,7,11] in 8 hours, what are you binary-searching?",
    "dsa-sql-quiz-5": "What is the first tool for shortest path on an unweighted graph?",
    "dsa-sql-quiz-6": "How do you get the latest invoice per user in SQL?",
    "dsa-sql-quiz-7": "If a window query is slow at 10M invoices, what is the first index you add?",
}

CODING_PROMPTS = {
    "coding-tasks-0": "How do you find a missing number in an array?",
    "coding-tasks-1": "How do you find multiple missing numbers in an array?",
    "coding-tasks-2": "How do you compute the sum of an array?",
    "coding-tasks-3": "How do you find the difference between two arrays?",
    "coding-tasks-4": "How do you find the similarity of two arrays?",
    "coding-tasks-5": "How do you check whether two arrays are equal?",
    "coding-tasks-6": "How do you generate a Fibonacci sequence?",
    "coding-tasks-7": "How do you count word frequency in a string?",
    "coding-tasks-8": "How do you check whether two strings are anagrams?",
    "coding-tasks-9": "How do you check whether one string is a rotation of another?",
    "coding-tasks-10": "How do you find the first unique character in a string?",
    "coding-tasks-11": "How do you compress a string?",
    "coding-tasks-12": "How do you check whether a string is a palindrome?",
    "coding-tasks-13": "How do you find the largest common prefix of a list of strings?",
    "coding-tasks-14": "How do you reverse the words in a string?",
    "coding-tasks-15": "How do you find all permutations of a string?",
    "coding-tasks-16": "How do you find common elements in two arrays?",
    "coding-tasks-17": "How do you find the difference of two arrays?",
    "coding-tasks-18": "How do you check if two arrays are equal?",
    "coding-tasks-19": "How do you find the symmetric difference of two arrays?",
    "coding-tasks-20": "How do you check if one array is a subset of another?",
    "coding-tasks-21": "How do you find missing elements relative to another array?",
    "coding-tasks-22": "How do you compare arrays that contain duplicates?",
    "coding-tasks-23": "How do you find the largest common subarray?",
    "coding-tasks-24": "How do you check if two arrays are rotations of each other?",
    "coding-tasks-25": "How do you find a pair with a given sum in two sorted arrays?",
    "coding-tasks-26": "How do you find duplicates in an array?",
    "coding-tasks-27": "When a problem is about finding pairs, which data structure do you reach for?",
    "coding-tasks-28": "When a problem involves a sorted array, which approach do you consider?",
    "coding-tasks-29": "When you need to track a sequence, which data structure do you think of?",
    "coding-tasks-30": "When a problem is about a substring or subarray, which pattern do you consider?",
    "coding-tasks-31": "How do you find two numbers in an array that add to a target?",
}

CODING_EMPTY_HELP = {
    "coding-tasks-7": "Count how often each word appears. Split on whitespace, normalize case, and tally with a hash map.",
    "coding-tasks-8": "Two strings are anagrams if they contain the same characters with the same counts. Sort both, or count characters in a map.",
    "coding-tasks-9": "A string B is a rotation of A if A + A contains B and the lengths match.",
    "coding-tasks-10": "Walk the string once to count characters, then walk again and return the first character whose count is 1.",
    "coding-tasks-11": "Run-length encode consecutive repeats, e.g. aabcccccaaa → a2b1c5a3. Return the original if compression is not shorter.",
    "coding-tasks-12": "A palindrome reads the same forwards and backwards. Compare two pointers from the ends, skipping non-alphanumerics if asked.",
    "coding-tasks-13": "The largest common prefix is the shared start of every string. Walk character by character until one string diverges.",
    "coding-tasks-14": "Split on spaces, reverse the word list, and join. Watch extra spaces if the interviewer cares about them.",
    "coding-tasks-15": "Generate all permutations by swapping or backtracking. State n! growth out loud.",
    "coding-tasks-16": "Put one array in a set and scan the other. That is O(n + m) average time.",
    "coding-tasks-17": "Elements in A that are not in B. A set for B, then filter A.",
    "coding-tasks-18": "Same length and same elements in the same order, unless the interviewer wants order-insensitive equality.",
    "coding-tasks-19": "Elements in either array but not both. Two sets, then union of the two differences.",
    "coding-tasks-20": "Every element of A is in B. Put B in a set and test membership for each item in A.",
    "coding-tasks-21": "Values expected in a range or in another array that are absent. A set of what you have, then scan what you should have.",
    "coding-tasks-22": "Counts matter. Use frequency maps, not sets, so duplicate copies are not dropped.",
    "coding-tasks-23": "The longest contiguous slice that appears in both arrays. Nested scan or a string/hash of windows.",
    "coding-tasks-24": "Same as string rotation: concatenate one array and look for the other as a contiguous slice, with equal length.",
    "coding-tasks-25": "Two pointers from the ends of each sorted array, or a hash of complements. Name the O(n + m) walk.",
    "coding-tasks-28": "A sorted array is a binary-search tell. Ask if you need an index, a bound, or a monotonic predicate.",
    "coding-tasks-29": "A stack or queue tracks order. Stack for LIFO / matching; queue for BFS and sliding windows of time.",
    "coding-tasks-30": "Sliding window keeps a contiguous range. Expand the right pointer, shrink the left when the constraint breaks.",
}

DEVOPS_PROMPTS = {
    "devops-0": "What automation patterns come up in a DevOps interview?",
    "devops-1": "What is a service layer in a backend or DevOps design?",
    "devops-2": "What Linux topics come up in a DevOps interview?",
}

DEVOPS_ANSWERS = {
    "devops-0": (
        "Automation patterns are repeatable ways to provision, deploy, and operate systems without clicking through consoles.\n\n"
        "- CI/CD pipelines for build, test, and release\n"
        "- Infrastructure as code for environments\n"
        "- Event-driven runbooks for restarts, scaling, and rollback"
    ),
    "devops-1": (
        "A service layer sits between HTTP/API handlers and data stores.\n\n"
        "- Handlers stay thin: auth, validation, status codes\n"
        "- Business rules, retries, and orchestration live in the service\n"
        "- Makes the same logic reusable from jobs, CLIs, and other entrypoints"
    ),
    "devops-2": (
        "Linux is the default host for services and CI runners.\n\n"
        "- Processes, permissions, and systemd\n"
        "- Filesystems, logs, and journalctl\n"
        "- Networking basics: ports, DNS, ssh, and resource limits"
    ),
}


def strip_md(text: str) -> str:
    return re.sub(r"\*\*([^*]+)\*\*", r"\1", text)


def word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def is_spoken(text: str) -> bool:
    t = text.strip()
    if not t:
        return False
    if t.endswith("…") or t.endswith("..."):
        return False
    if "?" in t:
        return True
    return t.lower().startswith(SPOKEN_START)


def content_words(text: str) -> list[str]:
    return [w.lower() for w in re.findall(r"[A-Za-z0-9@+]+", text) if len(w) > 3]


def key_already_in(key: str, rest: str) -> bool:
    bare = key.strip().rstrip(".!?")
    if not bare:
        return True
    if bare.lower() in rest.lower():
        return True
    words = content_words(bare)
    if not words:
        return True
    rest_l = rest.lower()
    return all(w in rest_l for w in words)


def soften_key(key: str) -> str:
    bare = key.strip().rstrip(".!?")
    if len(bare) >= 2 and bare[0].isupper() and bare[1].islower():
        return bare[0].lower() + bare[1:]
    return bare


def weave_key(key: str, rest: str) -> str:
    """Drop the MCQ key line; keep its fact inside the explanation if missing."""
    if key_already_in(key, rest):
        return rest
    insert = f" ({soften_key(key)})"
    match = re.search(r"[.!?]", rest)
    if match:
        return rest[: match.start()] + insert + rest[match.start() :]
    return rest + insert


def maybe_bulletize_arrows(text: str) -> str:
    """Turn real multi-step drill pipelines into bullets. Leave slogans like Red → Green → Refactor inline."""
    if re.search(r"(?m)^\s*[-*]", text):
        return text

    def bulletize_paragraph(para: str) -> str:
        if para.count("→") < 3:
            return para
        parts = [strip_md(p).strip(" .") for p in re.split(r"\s*→\s*", para)]
        parts = [p for p in parts if p]
        if len(parts) < 4:
            return para
        short = sum(1 for p in parts if word_count(p) <= 2)
        if short * 2 > len(parts):
            return para
        return "Walk through it in this order:\n" + "\n".join(f"- {p}" for p in parts)

    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    return "\n\n".join(bulletize_paragraph(p) for p in paras)


def polish_help(answer: str) -> str:
    text = strip_md(answer or "").strip()
    if not text:
        return text
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if len(paras) >= 2 and word_count(paras[0]) <= 12:
        text = weave_key(paras[0], "\n\n".join(paras[1:]))
    return maybe_bulletize_arrows(text)


def polish_hints(question: dict, new_answer: str) -> list[str]:
    hints = [strip_md(h).strip() for h in (question.get("hints") or []) if str(h).strip()]
    # Keep a short fact cue; drop a hint that merely repeats the full Help body.
    out = []
    for hint in hints:
        if hint == new_answer:
            continue
        if hint not in out:
            out.append(hint)
        if len(out) >= 5:
            break
    return out


def polish_study_question(q: dict) -> dict:
    qid = q.get("id") or ""
    text = STUDY_PROMPTS.get(qid, q.get("text") or "")
    if not is_spoken(text):
        stripped = text.strip().rstrip(".…")
        if stripped:
            text = f"Explain {stripped}."
    help_text = polish_help(q.get("answer") or q.get("rubric") or "")
    q["text"] = text
    q["answer"] = help_text
    q["rubric"] = help_text
    q["hints"] = polish_hints(q, help_text)
    return q


def puzzle_to_spoken(text: str) -> str:
    raw = text.strip()
    if is_spoken(raw):
        return raw
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
    problem = ""
    for ln in lines:
        if ln.lower().startswith("problem:"):
            problem = ln.split(":", 1)[1].strip()
            break
    body = problem or (lines[-1] if lines else raw)
    if "?" in body:
        return body if body.endswith("?") else body
    low = body.lower()
    if low.startswith(("connect ", "find ", "draw ", "divide ", "use ", "split ")):
        return f"How do you {body[0].lower() + body[1:].rstrip('.')}?"
    return f"How do you solve this: {body.rstrip('.')}?"


def polish_guide_question(q: dict) -> dict:
    qid = q.get("id") or ""
    group = q.get("groupId") or ""
    if qid in CODING_PROMPTS:
        q["text"] = CODING_PROMPTS[qid]
        help_text = (q.get("answer") or q.get("rubric") or "").strip()
        if not help_text:
            help_text = CODING_EMPTY_HELP.get(qid, "")
        q["answer"] = help_text
        q["rubric"] = help_text
        return q
    if qid in DEVOPS_PROMPTS:
        q["text"] = DEVOPS_PROMPTS[qid]
        q["answer"] = DEVOPS_ANSWERS[qid]
        q["rubric"] = DEVOPS_ANSWERS[qid]
        return q
    if group == "logical-tasks":
        q["text"] = puzzle_to_spoken(q.get("text") or "")
        return q
    if not is_spoken(q.get("text") or ""):
        t = (q.get("text") or "").strip().rstrip(".")
        if t:
            q["text"] = f"Explain {t}."
    return q


def rewrite_bank(path: Path, pack_id: str, fn) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for pack in data.get("packs") or []:
        if pack.get("id") != pack_id:
            continue
        questions = []
        for q in pack.get("questions") or []:
            before = (q.get("text"), q.get("answer"), q.get("rubric"))
            q = fn(q)
            questions.append(q)
            after = (q.get("text"), q.get("answer"), q.get("rubric"))
            if before != after:
                changed += 1
        pack["questions"] = questions
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return changed


def main() -> None:
    study_n = rewrite_bank(BANK, "study-book", polish_study_question)
    guide_n = rewrite_bank(GUIDE, "interview-guide", polish_guide_question)
    print(f"polished study-book={study_n} interview-guide={guide_n}")


if __name__ == "__main__":
    main()
