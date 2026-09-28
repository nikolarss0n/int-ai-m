# Direct Jev API A/B performance — 21 September 2026

**Result: the current serial Jev integration made answer text arrive later. Keep it disabled when speed is the objective.** This replaces the earlier Playground-based estimate with measured calls through the real Swift clients and live APIs.

| Metric | Jev off: combined xAI | Jev on: direct Jev + xAI |
|---|---:|---:|
| Median first answer chunk | 661 ms | 836 ms |
| Median first 40 answer characters | 804 ms | 940 ms |
| p95 first 40 answer characters | 941 ms | 1,061 ms |
| Median answer completion | 1,935 ms | 2,164 ms |
| p95 answer completion | 2,234 ms | 2,460 ms |
| Failures / missing answers | 0 / 0 | 0 / 0 |

Median elapsed time to 40 characters increased by **136 ms (16.9%)**. Jev was faster in only **2 of 20 matched pairs**. Median paired difference was +136 ms. The Jev request itself took a median **286 ms**, p95 **333 ms**. All **20/20 decisions were accepted**, with **zero fallback or unavailable-provider events** in the measured runs. Unlike the earlier Playground trial, fallback did not explain this result.

Jev did produce its classification callback earlier (287 ms median versus 646 ms), but answer text arrived later. Earlier card creation must not be reported as faster useful answers.

## Method

- Compiled the actual production Swift clients and processor into a temporary harness; no response mocks or latency estimates were used.
- Models: pinned `jev-1.13.0`, configured xAI `grok-4.20-0309-non-reasoning`.
- Two prompts that the current processor confirmed miss the local fast path: “How would you debug a lease renewal race?” and “What would you check before choosing that approach?”
- Ten repetitions per prompt and mode: 20 matched pairs, 40 measured calls. Baseline/Jev order alternated across cases and repetitions. No concurrent measurement calls.
- One excluded direct Jev smoke request verified access; one excluded warm-up per combined/Jev-enabled client warmed both paths. Measurements describe warmed service behavior.
- The Jev-enabled path used `JevDecisionClient.configured()` with the real private API key and existing timeout/acceptance policy. The off path used the same answer client without Jev.
- Monotonic timing started immediately before the production classify/stream call. The 40-character measure is accumulated answer content at the client callback, not physical UI paint or a semantic quality score.
- All 40 final statuses were question and all answers were nonempty. This checks the two fixtures' routing, not general classifier accuracy. Answer quality was not independently scored.

## Limits

This is a small, two-prompt benchmark using empty history, no resume, and the harness defaults. p95 is the nearest-rank sample percentile, not a stable production tail estimate. Microphone capture, silence detection, Whisper transcription, UI rendering, and long interview histories are outside the timing boundary. Clear questions still use their existing fast path and are not represented in this ambiguous-route comparison.

No production code or app preferences changed. Jev was enabled only in the benchmark process. The app remains at its previous setting. No full rebuild/test-suite rerun was needed for this artifact-only measurement; the benchmark compiled against the current production sources and all 40 live calls succeeded.

## Evidence and reproduction

Artifacts: `.codex-loop/jev-direct-performance/benchmark.swift`, `build-benchmark.sh`, `observations.json`, `annotated-observations.json`, `run.log`, `summary.json`, and `summarize.py`. Secrets are read privately and are absent from the saved artifacts. Logs record per-turn Jev latency and acceptance; observations preserve generated answers for inspection.

From the repository root, build with `bash .codex-loop/jev-direct-performance/build-benchmark.sh`, then run the binary from `.codex-loop/jev-direct-performance` with `IM_RUN_LIVE_CLASSIFICATION=1 IM_JEV_ENABLED=1`. This makes real API calls and overwrites that directory's observation/log files if redirected to the same paths.
