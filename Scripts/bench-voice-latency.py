#!/usr/bin/env python3
"""File-based interview latency bench: STT + streamed answer.

Measures the production-critical visible metrics:
  stt_ms                 transcription round-trip
  llm_first_text_ms      first visible answer token after STT
  llm_complete_ms        last token after STT
  e2e_first_text_ms      STT start -> first answer text
  e2e_complete_ms        STT start -> answer complete

Usage:
  python3 Scripts/bench-voice-latency.py --generate
  python3 Scripts/bench-voice-latency.py --audio path.wav
  python3 Scripts/bench-voice-latency.py --compare
  python3 Scripts/bench-voice-latency.py --record 8
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / ".codex-loop" / "voice-bench"
CLIPS = ARTIFACT / "clips"
KEYS_FILE = Path.home() / ".interview-master-keys"

# Python.org builds on macOS do not ship a CA bundle. Use the system certs.
SSL_CTX = ssl.create_default_context(cafile="/etc/ssl/cert.pem")

CURRENT_ANSWER_MODEL = "openai/gpt-oss-20b"
CURRENT_CLASSIFY_MODEL = "openai/gpt-oss-20b"
STT_MODEL = "whisper-large-v3-turbo"

ANSWER_PROMPT = """Cue-card interview answer the candidate can say out loud.
3-5 bullets only. Every line starts with "- ". Under 90 characters.
No preamble, headings, disclaimers, or hedges. First person when natural.
Point first, then one example or trade-off. Do not start with "I would say" or "I'd say".
For "What is X?", first bullet defines X with the acronym expanded.
Position: Senior QA / SDET
Programming Language: Python
Tech Stack: Playwright, TypeScript, API Testing, CI
PLAYWRIGHT: prefer `await expect(locator).toBeVisible()`, getByRole/getByLabel, no waitForTimeout.
Q: "{question}"
Topic: {topic}
OUTPUT LANGUAGE: English. Answer every candidate-facing bullet in English.
"""

CLIPS_SPEC = [
    {
        "id": "arraylist",
        "say": "What is the difference between an ArrayList and a LinkedList?",
        "topic": "arrayList",
        "keywords": ["arraylist", "linkedlist", "index", "insert"],
    },
    {
        "id": "hashmap",
        "say": "How does a hash map work internally?",
        "topic": "hashMap",
        "keywords": ["hash", "bucket", "collision", "key"],
    },
    {
        "id": "playwright",
        "say": "How do you wait for an element in Playwright?",
        "topic": "playwright",
        "keywords": ["expect", "locator", "visible", "auto"],
    },
]


def load_keys() -> dict[str, str]:
    keys: dict[str, str] = {}
    if KEYS_FILE.exists():
        for line in KEYS_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, value = line.split("=", 1)
            keys[name.strip()] = value.strip()
    for name in ("GROQ_API_KEY", "DEEPGRAM_API_KEY", "XAI_API_KEY"):
        env = os.environ.get(name, "").strip()
        if env:
            keys[name] = env
    return keys


def groq_key() -> str:
    key = load_keys().get("GROQ_API_KEY", "")
    if not key:
        sys.exit("GROQ_API_KEY missing from ~/.interview-master-keys or env")
    return key


def reasoning_fields(model: str) -> dict:
    if model.startswith("openai/gpt-oss"):
        return {"reasoning_effort": "low", "include_reasoning": False}
    if model.startswith("qwen/"):
        return {"reasoning_effort": "none"}
    return {}


def chat_messages(prompt: str) -> list[dict]:
    return [
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": "- "},
    ]


HEADERS = {
    "User-Agent": "InterviewMaster-voice-bench/1.0",
    "Content-Type": "application/json",
}


def read_http_error(exc: urllib.error.HTTPError) -> str:
    body = exc.read().decode("utf-8", errors="replace")
    return f"HTTP {exc.code}: {body[:500]}"


def transcribe(audio_path: Path, language: str = "en") -> tuple[str, float]:
    started = time.perf_counter()
    cmd = [
        "curl", "-sS",
        "https://api.groq.com/openai/v1/audio/transcriptions",
        "-H", f"Authorization: Bearer {groq_key()}",
        "-F", f"file=@{audio_path}",
        "-F", f"model={STT_MODEL}",
        "-F", f"language={language}",
        "-F", "response_format=json",
    ]
    raw = subprocess.check_output(cmd, cwd=str(ROOT))
    elapsed = (time.perf_counter() - started) * 1000
    data = json.loads(raw.decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    text = (data.get("text") or "").strip()
    if not text:
        raise RuntimeError(f"empty transcript: {data}")
    return text, elapsed


def stream_answer(question: str, topic: str, model: str) -> dict:
    payload = {
        "model": model,
        "messages": chat_messages(ANSWER_PROMPT.format(question=question, topic=topic)),
        "max_tokens": 280,
        "temperature": 0.3,
        "stream": True,
        **reasoning_fields(model),
    }
    body = json.dumps(payload).encode()
    req = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=body,
        headers={
            **HEADERS,
            "Authorization": f"Bearer {groq_key()}",
        },
        method="POST",
    )
    started = time.perf_counter()
    first_ms = None
    chunks: list[str] = []
    try:
        resp_cm = urllib.request.urlopen(req, timeout=60, context=SSL_CTX)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(read_http_error(exc)) from exc
    with resp_cm as resp:
        while True:
            line = resp.readline()
            if not line:
                break
            decoded = line.decode("utf-8", errors="replace").strip()
            if not decoded.startswith("data: "):
                continue
            data = decoded[6:]
            if data == "[DONE]":
                break
            try:
                obj = json.loads(data)
            except json.JSONDecodeError:
                continue
            if obj.get("error"):
                raise RuntimeError(obj["error"])
            delta = ((obj.get("choices") or [{}])[0].get("delta") or {})
            content = delta.get("content") or ""
            if content:
                if first_ms is None:
                    first_ms = (time.perf_counter() - started) * 1000
                    trimmed = content.lstrip()
                    if not trimmed.startswith("-"):
                        content = "- " + content
                chunks.append(content)
    complete_ms = (time.perf_counter() - started) * 1000
    answer = "".join(chunks).strip()
    return {
        "llm_first_text_ms": None if first_ms is None else round(first_ms),
        "llm_complete_ms": round(complete_ms),
        "answer": answer,
        "chars": len(answer),
        "model": model,
    }


def score_answer(answer: str, keywords: list[str]) -> dict:
    lines = [line.strip() for line in answer.splitlines() if line.strip()]
    bullets = [line for line in lines if line.startswith("- ")]
    lowered = answer.lower()
    forbidden = [
        "i would say",
        "i'd say",
        "you might mean",
        "as an ai",
        "i cannot",
        "doesn't exist",
    ]
    keyword_hits = [word for word in keywords if word.lower() in lowered]
    score = 0
    reasons = []
    if 3 <= len(bullets) <= 6:
        score += 2
        reasons.append("3-5 bullets")
    elif len(bullets) >= 2:
        score += 1
        reasons.append("some bullets")
    else:
        reasons.append("missing bullets")
    if bullets and all(len(bullet) <= 140 for bullet in bullets):
        score += 1
        reasons.append("glanceable")
    if not any(token in lowered for token in forbidden):
        score += 1
        reasons.append("no hedges")
    if keyword_hits:
        score += 2
        reasons.append("on-topic:" + ",".join(keyword_hits[:3]))
    else:
        reasons.append("off-topic-or-weak")
    return {
        "score": score,
        "max": 6,
        "bullets": len(bullets),
        "keyword_hits": keyword_hits,
        "reasons": reasons,
    }


def generate_clips() -> list[Path]:
    CLIPS.mkdir(parents=True, exist_ok=True)
    paths = []
    for spec in CLIPS_SPEC:
        aiff = CLIPS / f"{spec['id']}.aiff"
        wav = CLIPS / f"{spec['id']}.wav"
        subprocess.check_call(["say", "-o", str(aiff), spec["say"]])
        subprocess.check_call(
            ["ffmpeg", "-y", "-i", str(aiff), "-ar", "16000", "-ac", "1", str(wav)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        paths.append(wav)
        print(f"generated {wav.name}: {spec['say']}")
    return paths


def record_clip(seconds: int) -> Path:
    CLIPS.mkdir(parents=True, exist_ok=True)
    out = CLIPS / "recorded.wav"
    print(f"Recording {seconds}s from default microphone into {out}")
    print("Speak one interview question, then wait.")
    subprocess.check_call(
        [
            "ffmpeg", "-y",
            "-f", "avfoundation",
            "-i", ":default",
            "-t", str(seconds),
            "-ar", "16000",
            "-ac", "1",
            str(out),
        ]
    )
    print(f"saved {out}")
    return out


def spec_for_audio(audio: Path) -> dict:
    for spec in CLIPS_SPEC:
        if spec["id"] in audio.stem:
            return spec
    return {
        "id": audio.stem,
        "say": "",
        "topic": "unknown",
        "keywords": [],
    }


def run_one(audio: Path, model: str, warmup: bool = False) -> dict:
    spec = spec_for_audio(audio)
    transcript, stt_ms = transcribe(audio)
    topic = spec["topic"] if spec["topic"] != "unknown" else "general"
    llm = stream_answer(transcript, topic, model)
    quality = score_answer(llm["answer"], spec["keywords"])
    first = llm["llm_first_text_ms"]
    complete = llm["llm_complete_ms"]
    result = {
        "audio": str(audio.relative_to(ROOT)) if audio.is_relative_to(ROOT) else str(audio),
        "clip": spec["id"],
        "expected": spec["say"],
        "transcript": transcript,
        "stt_ms": round(stt_ms),
        "warmup": warmup,
        **llm,
        "e2e_first_text_ms": None if first is None else round(stt_ms + first),
        "e2e_complete_ms": round(stt_ms + complete),
        "quality": quality,
    }
    return result


def print_result(result: dict) -> None:
    quality = result["quality"]
    print(
        f"{result['clip']:12} {result['model']:28} "
        f"stt={result['stt_ms']:4}ms  "
        f"first={result['llm_first_text_ms'] or '-':>5}ms  "
        f"last={result['llm_complete_ms']:5}ms  "
        f"e2e_first={result['e2e_first_text_ms'] or '-':>5}ms  "
        f"e2e_last={result['e2e_complete_ms']:5}ms  "
        f"q={quality['score']}/{quality['max']}"
    )
    print(f"  transcript: {result['transcript']}")
    preview = " | ".join(
        line.strip() for line in result["answer"].splitlines() if line.strip()
    )[:240]
    print(f"  answer: {preview}")


def compare(audio_paths: list[Path], models: list[str], runs: int) -> list[dict]:
    ARTIFACT.mkdir(parents=True, exist_ok=True)
    results: list[dict] = []
    for audio in audio_paths:
        for model in models:
            print(f"\nwarmup {model} / {audio.name}")
            try:
                warm = run_one(audio, model, warmup=True)
                print_result(warm)
                results.append(warm)
            except Exception as exc:
                print(f"  warmup failed: {exc}")
            for i in range(runs):
                print(f"run {i + 1}/{runs} {model} / {audio.name}")
                try:
                    result = run_one(audio, model, warmup=False)
                    print_result(result)
                    results.append(result)
                except Exception as exc:
                    print(f"  run failed: {exc}")
                    results.append(
                        {
                            "audio": str(audio),
                            "clip": audio.stem,
                            "model": model,
                            "error": str(exc),
                            "warmup": False,
                        }
                    )
    out = ARTIFACT / "latest.json"
    out.write_text(json.dumps(results, indent=2))
    write_summary(results)
    print(f"\nwrote {out}")
    return results


def write_summary(results: list[dict]) -> None:
    measured = [row for row in results if not row.get("warmup") and "error" not in row]
    lines = ["# Voice latency bench", ""]
    grouped: dict[str, list[dict]] = {}
    for row in measured:
        grouped.setdefault(row["model"], []).append(row)
    lines.append("| model | n | median first | median last | median e2e first | median e2e last | median quality |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|")
    for model, rows in grouped.items():
        def med(key: str) -> str:
            values = sorted(r[key] for r in rows if r.get(key) is not None)
            if not values:
                return "-"
            return str(values[len(values) // 2])

        q = sorted(r["quality"]["score"] for r in rows)
        qmed = q[len(q) // 2] if q else "-"
        lines.append(
            f"| `{model}` | {len(rows)} | {med('llm_first_text_ms')} | {med('llm_complete_ms')} | "
            f"{med('e2e_first_text_ms')} | {med('e2e_complete_ms')} | {qmed}/6 |"
        )
    lines.append("")
    lines.append("Target: first useful answer text under ~1000ms after STT for clear questions.")
    summary = ARTIFACT / "latest.md"
    summary.write_text("\n".join(lines) + "\n")
    print(summary.read_text())


def default_models() -> list[str]:
    return [
        CURRENT_ANSWER_MODEL,
        CURRENT_CLASSIFY_MODEL,
        "qwen/qwen3.6-27b",
        "qwen/qwen3.8-27b",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Interview voice latency bench")
    parser.add_argument("--audio", action="append", default=[], help="Audio file (repeatable)")
    parser.add_argument("--generate", action="store_true", help="Generate spoken clips with macOS say")
    parser.add_argument("--record", type=int, metavar="SECONDS", help="Record from default mic")
    parser.add_argument("--compare", action="store_true", help="Compare Groq answer models")
    parser.add_argument("--model", action="append", default=[], help="Model id (repeatable)")
    parser.add_argument("--runs", type=int, default=1, help="Measured runs per clip/model after warmup")
    args = parser.parse_args()

    audio_paths = [Path(item).expanduser().resolve() for item in args.audio]
    if args.generate:
        audio_paths.extend(generate_clips())
    if args.record:
        audio_paths.append(record_clip(args.record))
    if not audio_paths:
        existing = sorted(CLIPS.glob("*.wav"))
        if existing:
            audio_paths = existing
        else:
            audio_paths = generate_clips()

    models = args.model or ([CURRENT_ANSWER_MODEL] if not args.compare else default_models())
    compare(audio_paths, models, max(1, args.runs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
