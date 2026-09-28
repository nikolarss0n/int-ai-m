# Jev performance check — 21 September 2026

Newer evidence: [direct Swift API A/B results](jev-direct-performance-2026-09-21.md) are now available; the figures below are the earlier component estimate.

**Recommendation: keep Jev disabled for latency-sensitive answers. This small component benchmark indicates a likely slowdown with the current serial integration; it is not a live end-to-end Swift Jev measurement.**

## Measurements

| Measurement | Median | Observed maximum |
|---|---:|---:|
| Current combined xAI call: first answer chunk | 628 ms | 745 ms |
| Current combined xAI call: first 40 answer characters | 747 ms | 881 ms |
| Answer-only xAI call, with Jev replaced by an immediate test decision: first 40 characters | 619 ms | 767 ms |
| Current combined xAI call: answer completion | 1,660 ms | 2,013 ms |
| Answer-only xAI call, excluding real Jev: answer completion | 1,572 ms | 1,794 ms |
| Live single-decision Jev: vendor server evaluation | 105 ms | 119 ms |
| Live single-decision Jev: Playground evaluation plus displayed overhead | 339 ms | 370 ms |
| **Estimated serial route: first 40 characters, including actual acceptance/fallback choices** | **1,018 ms** | **1,251 ms** |

The estimate is about 271 ms longer than the current combined median (approximately 36% longer elapsed time). It combines separately measured components; it is not an observed app response time. Playground overhead includes that service/browser path and may differ from direct Swift API overhead.

## Method

The temporary harness in `.codex-loop/jev-performance/benchmark.swift` calls the real `AnthropicClient.classifyAndStreamAnswer` against the configured xAI model, `grok-4.20-0309-non-reasoning`. The baseline uses the combined prompt. The comparison uses the production Jev-enabled answer-only branch, with only the Jev HTTP response replaced by an immediate, valid question decision. This isolates the maximum plausible generation-side benefit before a real Jev call is added. No production code was changed for the benchmark.

Both modes received an excluded warm-up. Three prompts were each repeated three times with alternating baseline/comparison order (18 measured generation calls). The processor identified the CRDT garbage-collection prompt as a local fast-path question; its six client-level measurements are preserved as a control and excluded from the ambiguous-route comparison. The main comparison therefore contains two distinct ambiguous prompts, each repeated three times per mode:

- “How would you debug a lease renewal race?”
- “What would you check before choosing that approach?”

All generation calls completed successfully with nonempty answer text. The fixture uses empty history, no resume, and the harness's default app settings; it does not represent every personalized interview workload. Timings use a monotonic clock. First 40 accumulated characters are a reproducible content-availability proxy, not proof of rendered UI text or semantic usefulness. Classification callback time is not actual card paint time.

The same two prompts were then submitted individually through the authenticated Typesafe Playground, three times each, using the production rubric, criteria, and structured state shape. All six responses resolved to `jev-1.13.0` with distinct request IDs. All chose question. The lease prompt passed the current confidence/probability thresholds in all three runs. The approach prompt failed acceptance in all three runs (question probability 0.87), so its realistic route is **Jev plus the original combined call**, not answer-only generation.

The serial estimate adds each displayed Playground total to the corresponding repetition's measured generation time: answer-only for accepted decisions, combined for fallbacks. It does not divide batch timings by the number of questions or treat a fast classification callback as visible answer speed.

## What this implies

Removing the classification header saved about 128 ms between the generation medians. The observed Jev Playground round trip consumed about 339 ms, exceeding that saving. Half the sampled decisions additionally fell back to the original model. A Jev timeout can also add up to the configured 1.5-second transport budget before fallback. Clear questions continue to bypass Jev and are unaffected by this path.

This evidence does not justify enabling the serial route for speed. A separate trial could investigate whether Jev helps discard non-question speech or improve decision quality. Do not lower uncertainty thresholds merely to improve latency numbers.

## Remaining limitation and evidence

`TYPESAFE_API_KEY` is still missing from the app environment/private key file. Direct Swift-to-Jev transport, microphone/transcription timing, native UI rendering, and total audio-to-answer latency were not measured. The samples are small; reported p95 values in the JSON are nearest-rank maxima, not reliable tail-latency estimates.

Artifacts under `.codex-loop/jev-performance/`: `observations.json` (full model outputs and timings), `jev-1.json` through `jev-6.json` (raw live decisions), `jev-timings.json` (visible timing headers), `summary.json`, `summarize.py`, and the benchmark source/build script. The first timing header was transcribed from the tool's visible snapshot; later snapshots are also saved as `jev-*-dom.txt`. No credentials are included.
