# Jev for InterviewMaster decisions

**Recommendation: evaluate Jev on ambiguous speech decisions first. Do not route every utterance through it or replace answer generation.** This is a research assessment of the working checkout on 21 September 2026, not an implemented integration or measured speed improvement.

## Conversation and evidence reviewed

Reviewed the AmbientQA Codex task **“Explain Jev platform use cases”**, ID `01a0c38b-b903-7823-9cd1-46a6163ee5e6`. Its proposed split is Jev for bounded judgments and existing models/tools for generation and execution.

The completed [AmbientQA evaluation](../../playwright-autopilot-api/output/jev-evaluation-20260921/RESULTS.md) reports 29 scored scenarios repeated five times, with 145/145 matching assigned labels. These cover failure diagnosis, patch safety, and intent routing—not interview speech. Repetitions are not independent examples. Reported 104–145 ms timings are vendor evaluation times for batches, excluding network/browser overhead. They establish neither interview accuracy nor faster visible answers here. The newer replacement comparison was still in progress when inspected.

The earlier [AmbientQA assessment](../../playwright-autopilot-api/architecture/jev-decision-layer-assessment-20260920.md) treated access as a blocker; subsequent authenticated Playground tests supersede that blocker. Its important design warning still applies: replacing an exact local check with a remote judgment introduces cost and errors without an established benefit.

## What this app actually does

- Audio becomes text through Groq Whisper: `Infrastructure/Speech/GroqInterviewClient.swift:57`.
- Clear questions already use local topic/question detection and stream an answer directly through Groq: `Application/VoiceInterviewProcessor.swift:1015`, `Application/VoiceInterviewProcessor.swift:1258`.
- Ambiguous turns use one combined classification-and-answer stream: `Application/VoiceInterviewProcessor.swift:1313`, `Infrastructure/API/AnthropicClient.swift:411`.
- Despite the historical Haiku names/comments, that client defaults to xAI Grok, with Anthropic available as another provider: `Infrastructure/API/AnthropicClient.swift:29`, `Presentation/VoiceInterviewController.swift:170`. Configured model constants are in `Domain/Model/Constants.swift:63`.
- Local guards enforce incomplete buffering and candidate-statement rejection after classification: `Application/VoiceInterviewProcessor.swift:1369`.

Consequently there is no universal standalone classifier call to swap out. Splitting the existing combined stream into Jev followed by an answer model might improve ambiguous decisions, but might also delay answers.

## Ranked opportunities

| Priority | Judgment for Jev | Proposed choices | Practical value and constraint |
|---|---|---|---|
| First | What should happen to this ambiguous utterance? | question / incomplete / statement / filler / uncertain | Closest match to an existing model judgment; question generates, incomplete buffers, statement preserves context. Keep the local vetoes. |
| Second | What response form fits? | concise explanation / comparison / coding steps / experience answer / uncertain | Could improve ambiguous routing into existing answer flows. Clear coding requests already have a local detector at `Domain/Model/CodingInterviewSteps.swift:11`. |
| Second | How does this relate to the active question? | continuation / follow-up / new topic / uncertain | Could reduce unnecessary cards or lost context. Wrong merges are costly; retain turn IDs, sequence checks, and source boundaries. |
| Later | Which supplied resume evidence is relevant? | relevance score per existing resume chunk | Helps select grounded talking points; Jev must select actual supplied material, never invent experience. Existing code is in `Domain/Model/InterviewBriefing.swift:193`. |

These are hypotheses for evaluation. The latter three currently have local behavior, so inserting Jev does not automatically save an LLM call. Choosing answer models is also possible, but only useful once tests establish which question types require which model.

Do not delegate microphone/source identity, audio silence detection, cancellation, duplicate turn IDs, buffer expiry, permissions, or exact study-card scoring to Jev. Text judgment also cannot establish who physically spoke. Retain Whisper for transcription and generative models for answers, code, summaries, and screenshot interpretation.

## Proposed integration boundary

Keep the clear-question route intact. For ambiguous turns only, an experimental decision client could receive the current transcript, buffered text, a short recent conversation window, last topic, and known capture source. Include an explicit uncertain option and positively worded criteria. Speech is evidence to classify, not instructions for operating the router.

Map validated decisions to existing application actions. A question still needs an answer-only generation call with the same conversation and resume grounding. Unknown topics must remain representable; do not force every new subject into a closed topic list. Invalid responses, timeouts, uncertain decisions, or disagreement with strong local safeguards fall back to the current combined path.

Attach results to the originating turn generation and sequence. Drop stale results after cancellation/source changes. Keep buffer mutation and card creation in the processor rather than the API adapter. Use Foundation URLSession and Codable for the documented HTTP endpoint; no new production package is necessary. Keep any API key in existing private configuration conventions, not source control.

Exact API capabilities, sources, and vendor limitations are recorded in [the primary-source research](jev-primary-source-research-2026-09-21.md).

## Trial that answers whether it helps

1. Build a fixed, manually labeled corpus from existing `Tests/test_processor.swift` cases and additional sanitized multi-turn transcripts. Include candidate statements, incomplete stems, comparisons, Bulgarian/mixed speech, noisy RAG transcription, context-free follow-ups, negation, unfamiliar topics, and coding-versus-explanation requests. Keep labels outside requests; split tuning cases from held-out evaluation.
2. Compare the current full decision policy against the proposed Jev policy, including the same local guards. Measure missed questions, false answers to candidate statements, premature answers, wrong follow-up merges, uncertainty/fallback rates, and relevant per-class precision/recall. Repeat to inspect variability without inflating sample count.
3. Benchmark current combined generation against Jev plus answer-only generation on identical ambiguous turns. Record end-to-end first useful visible text and completion at p50/p95, plus total requests/cost including fallbacks. Preserve clear-path latency. Vendor server timings are not a substitute.
4. Begin with offline replay, then a flag-controlled observational trial that cannot change displayed answers. Enable decisions only if held-out quality improves without unacceptable latency or false-answer regressions. Calibrate any confidence threshold on this corpus rather than treating a vendor score as probability of correctness.

For implementation, run `bash build.sh`, `bash Tests/test.sh`, and `./Scripts/verify-interview-quality.sh`; live classification and audio checks require their explicit opt-in flags. Verify actual UI answer timing separately from card creation. The existing script extracts timing proxies from logs, so check turn association and actual rendered text before using them as acceptance evidence.

## Work completed and limits

Read the Codex conversation, completed AmbientQA report, current app routing/callers, deterministic cases, and vendor sources. Added research notes only. Existing worktree changes were preserved. No Swift changes, app build, test run, live InterviewMaster Jev call, or audio benchmark was performed. InterviewMaster-specific quality and latency are the remaining evidence needed before adoption.
