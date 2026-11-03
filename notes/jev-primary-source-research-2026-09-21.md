# Jev for InterviewMaster: primary-source research

Checked 2026-09-21. Documentation research only; no API calls, paid evaluations, or production changes. Recommendations below are engineering inferences, not measured results in this app.

## Fit

Jev is a plausible classifier and routing layer after transcription: decide whether an utterance is an interviewer question, candidate statement, incomplete fragment, or continuation; then let Swift choose the next action. It cannot transcribe audio, write interview answers, generate normalized question text, or explain its reasoning. Keep those responsibilities in the current transcription and generative clients. Its intended interface is a bounded decision over supplied state. [System One](https://docs.typesafe.ai/concepts/system-one)

For an initial evaluation, use separate questions for utterance intent and relation to the active question, with explicit unknown/insufficient-context options. Supply the current transcript, a few relevant preceding turns, and the active question. This is a proposed design: all questions in a request evaluate the same state independently, so Swift must reconcile incompatible results. [State](https://docs.typesafe.ai/concepts/state)

## Verified API and Swift integration

- HTTP: `POST https://api.typesafe.ai/v1/systemone`, bearer API key, JSON body containing `model`, `state`, and a named `questions` map.
- `choice` takes an option-to-description `criteria` map and returns `choice`, `probabilities`, and `confidence`. `score` takes ordered rubric levels and returns a probability-weighted score. `noul` returns a yes-probability without a separate confidence field.
- Responses include resolved `model`, keyed `answers`, and input/output usage. Choice supports 255 options; Score supports 2–10 levels. Documented errors include 401, 422, 429, and 529. [HTTP API](https://docs.typesafe.ai/api)

The published SDKs are Python and JavaScript/TypeScript; direct HTTP is explicitly supported from other languages. A small Swift `URLSession` + `Codable` client is therefore sufficient in principle, without another production dependency. Implement explicit timeout, cancellation, response validation, and current-classifier fallback. Limit retries to the live interaction deadline; do not let generic backoff stall the interview. This integration design has not been compiled or exercised. [SDK support](https://docs.typesafe.ai/sdk)

## Models, cost, and context

Current documented model: `jev-1.13.0`; both `jev-latest` and `jev-preview` resolve to it. Pin the version when evaluating thresholds. Price is $0.042 per million input tokens, with free output. Thus 1,000 requests of 2,000 billed input tokens would cost about $0.084 (illustration, excluding any other services). Limits: 64k tokens for the complete request and 32k for state plus the longest question. Published rates are 1,200 requests/minute and 250,000 tokens/second, explicitly subject to change. English performs best; other languages require local validation. [Models](https://docs.typesafe.ai/models)

## Confidence and limitations

Confidence summarizes the answer distribution; it is not an independent verifier. Calibration is assessed over groups of predictions, not a guarantee that an individual decision is correct. Thresholds must be learned against this app's labelled cases, separately for each question and version. [Confidence](https://docs.typesafe.ai/confidence), [System One](https://docs.typesafe.ai/concepts/system-one)

Vendor-documented weaknesses include literal interpretation, multi-hop reasoning, numeric precision, irrelevant long context, and adversarial text in state. Independent questions need not obey complementary probability identities. The documented lack of text generation also means Jev cannot replace any classification operation that simultaneously rewrites or extracts arbitrary free text. [Jev 1.13 limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13)

## Latency: claim versus evidence

TypeSafe reports 70–500ms end-to-end calls and says published evaluations generally ran from West Coast laptops near its service. Its headline 193.6× speedup comes from selected multi-question workflows, and the vendor describes it as toward the high end of likely gains. The comparison uses model-derived reference probabilities, not interview ground truth. Its “zero hallucinations” claim concerns schema matching; it does not establish semantic correctness. These are vendor results, not InterviewMaster measurements or a documented latency SLA. [Launch report and methodology](https://typesafe.ai/blog/introducing-system-one-models-and-jev)

Measure local p50/p95 request latency, false question triggers, missed short/mixed-language prompts, duplicate answer cards, and first useful answer text. A faster classifier does not prove a faster overall answer: transcription, buffering, and generation remain in the path. Begin with opt-in shadow evaluation that cannot alter live decisions, then compare against the current classifier on the same transcripts.

## Data handling

The privacy policy says input is not used for model training/fine-tuning; services are hosted in the US, and retention lasts as reasonably necessary rather than a stated fixed short period. [Privacy policy](https://typesafe.ai/legal/privacy-policy) The DPA similarly defines retention by processing purpose and legal requirements. [DPA](https://typesafe.ai/legal/data-processing) Zero-data-retention is offered for enterprise customers, not stated as the default. [Legal documentation](https://docs.typesafe.ai/legal)

Send only the transcript/context required for the decision; this would add another external processor to the interview path. Verify account-specific retention if real interviews contain confidential content. No account entitlement, regional latency, domain accuracy, or live cost was verified in this research.
