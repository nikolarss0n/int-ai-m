# Jev implementation and verification — 21 September 2026

Implemented an opt-in Jev decision path for ambiguous voice turns. Clear local questions still use the existing direct answer path. Jev supplies an intent label; the existing xAI/Anthropic client generates question answers without the classification header. Accepted incomplete, statement, and filler decisions flow through the existing processor callbacks. Strong local question signals prevent Jev from suppressing an answer. Candidate-statement and incomplete guards remain in place.

## Implementation

- `Infrastructure/API/JevDecisionClient.swift`: pinned `jev-1.13.0`, bounded context, response/distribution validation, 1.5-second transport deadline, no retries, cancellation, and conservative acceptance thresholds. Thresholds are experimental, not calibrated correctness probabilities.
- `Infrastructure/API/AnthropicClient.swift`: optional decision client; invalid, uncertain, unavailable, or locally conflicting decisions use the original combined classification/answer stream. Jev answer generation keeps the existing multi-turn context, style and resume grounding.
- `Application/VoiceInterviewProcessor.swift`: passes permission to suppress an answer only when the combined current/buffered local signal is weak.
- `Presentation/VoiceInterviewController.swift`: configures Jev when explicitly enabled and a private key is present.
- `Tests/test_jev.swift`: links real production clients with mocked HTTP transport; covers validated decisions, uncertainty, malformed output, oversized input, HTTP errors, timeout fallback, local-signal protection, answer-only streaming, and cancellation.
- `Tests/test_jev_live.swift` / `Scripts/evaluate-jev.sh`: separate opt-in live evaluation with raw observations. Not part of default test execution.

## Results

`bash build.sh` passed. `bash Tests/test.sh` passed, including 35 Jev checks and 79 existing real-processor integration checks. The full `Scripts/verify-interview-quality.sh` gate also passed its build and deterministic tests. Audio/microphone/live legacy-classification checks were skipped by their default opt-in settings. See `.codex-loop/jev-verification/summary.md`.

Live Typesafe Playground evaluation: 12 curated utterance cases × 5 distinct requests; **60/60 selected labels matched**. These are repetitions of 12 examples, not 60 independent examples and not production accuracy. Cases include incomplete speech, candidate explanations, mixed Bulgarian/English questions, a buffered comparison, follow-ups, and coding requests. Gold labels stayed local. The batch export uses the production rubric and state builder but embeds each sample's state in its own structured question instructions; it is not identical to the single-request production transport.

Raw responses were replayed through the actual Swift response validator and acceptance policy: **52 accepted, 8 conservative fallbacks, 0 invalid responses**. No threshold was lowered to accept the remaining results. All returned model IDs were `jev-1.13.0`. Vendor batch evaluation times ranged from 95–686ms; these exclude network overhead and do not measure first useful app answer text.

Evidence: `.codex-loop/jev-live/questions.json`, `labels.json`, `playground-1.json` through `playground-5.json`, and `playground-summary.json`. Each response records a distinct request ID. The production API shape was checked against https://docs.typesafe.ai/api.

## Activation and remaining evidence

The feature defaults off. Add `TYPESAFE_API_KEY=...` to `~/.interview-master-keys`, then enable `defaults write com.nikolayprosenikov.interviewmaster jevDecisionsEnabled -bool true` and restart the app. Use `false` to disable. Environment `IM_JEV_ENABLED=1` or `0` overrides the setting in the app process.

There was no Typesafe API key in the app configuration, so the direct Swift live runner reported its credential prerequisite and made no live API request. The Playground used the already authenticated browser session. Direct Swift API transport, live microphone/system-audio behavior, and first-visible-answer latency remain unmeasured. The deterministic tests exercise the real Swift transport and combined-answer integration using mocked HTTP responses, not real network service latency.

Existing unrelated working-tree changes were preserved. Nothing was committed.
