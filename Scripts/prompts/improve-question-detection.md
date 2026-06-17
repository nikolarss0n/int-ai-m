# Task: Reduce Question-To-Answer Latency

Optimize InterviewMaster for real visible answer speed. The previous goal was question detection coverage; the new goal is getting useful answer text onto the card in about one second after the interviewer question is detected, then refining or appending as more interviewer speech arrives.

The current `latency=...ms` metric is not enough. It can show around 900ms while the user still sees an answer card with a loading spinner for several seconds. Treat the real metric as:

- `card_start_ms`: when the answer card appears.
- `first_answer_text_ms`: when the first useful answer text is visible in the card.
- `answer_complete_ms`: when the streamed answer is complete.

Primary target:

- P0: first useful answer text in under 1000ms from question detection when the topic is clear.
- P1: keep answer completion fast, but do not block first useful text on a perfect final answer.
- P1: when the interviewer keeps speaking or adds detail, append/update the existing answer instead of starting an unrelated duplicate answer.

For every loop attempt:

1. Read `quality-score.md`, `latency-samples.tsv`, app logs, processor tests, and live classification logs when present.
2. Identify the slowest visible step: STT end to classification, card to first chunk, first chunk to complete, UI throttling, model choice, prompt size, token budget, or buffering.
3. Add or update deterministic coverage for the behavior being changed when possible.
4. Make the smallest production change that should improve real visible latency or progressive update behavior.
5. Run the verifier again and leave latency metrics or coverage better than the previous attempt.

Allowed experiments:

- Try different answer/classification models, including faster Groq/OpenAI-compatible models, smaller Anthropic models, or split-model routing.
- Change `AppConstants.Models`, token limits, prompts, streaming flow, buffering thresholds, and answer update strategy when justified by logs.
- Add a fast provisional answer path for strong local question signals before the final model response finishes.
- Start with a short direct answer immediately, then append/refine if the interviewer adds more context or the model produces a stronger answer.
- Reuse previous topic/context for follow-ups, but be careful not to answer candidate speech or filler.

Important constraints:

- Do not hardcode API keys.
- Do not remove the existing question-detection safeguards.
- Do not fake latency metrics; measure card start, first text, and completion separately.
- Do not hide spinner delays by renaming UI states. The user-visible card must receive useful text faster.
- Do not commit changes.
- Keep artifacts in `.codex-loop/`.
