# InterviewMaster Agent Guide

## Project Shape

- This is a macOS/AppKit Swift app built with direct `swiftc` scripts, not an Xcode project or SwiftPM package.
- The app listens to interview audio, transcribes via Groq Whisper, classifies interviewer utterances, and streams concise answer help.
- Main production path for voice behavior:
  - `Application/VoiceInterviewProcessor.swift`
  - `Infrastructure/Speech/GroqInterviewClient.swift`
  - `Infrastructure/API/AnthropicClient.swift`
  - `Domain/Model/ConversationContext.swift`
  - `Presentation/VoiceInterviewController.swift`

## Build And Verification

- Always run `bash build.sh` after Swift production changes.
- Always run `bash Tests/test.sh` after question detection, answer formatting, latency-routing, role/profile, or conversation-context changes.
- Use `./Scripts/verify-interview-quality.sh` as the default local gate for Codex loops.
- Live API classification checks are optional and must be explicitly enabled with `IM_RUN_LIVE_CLASSIFICATION=1`.
- Audio playback smoke tests are optional and must be explicitly enabled with `IM_RUN_AUDIO_SMOKE=1`; they require the app to have the needed macOS audio/screen permissions.

## Question Detection Rules

- Prefer small, test-backed changes to local guards before changing model prompts.
- Do not promote candidate answer statements such as "I have experience..." into questions just because they contain technical terms.
- Preserve short technical interviewer prompts, comparisons, mixed-language prompts, and contextual follow-ups.
- Keep incomplete utterances buffered instead of answering early when the local signal is weak.
- When classification and local signals disagree, only override classification if the local signal is strong and covered by tests.
- Add or update deterministic cases in `Tests/test_processor.swift` for every detection edge case fixed.

## Answer Quality Rules

- Answers should be glanceable cue cards: 3-5 short bullets for normal interview answers.
- Avoid intro phrases, disclaimers, and uncertainty hedges when the topic is known.
- For personal/background questions, use the user's background only; do not invent experience.
- Preserve code blocks when the answer includes code.
- Keep answer cleanup in `conversationalDisplayAnswer` deterministic and covered by tests.

## Latency Optimization Rules

- Optimize for user-visible first useful answer text, not only the internal `latency=...ms` card-start metric.
- Track and compare `card_start_ms`, `first_answer_text_ms`, and `answer_complete_ms` from logs when available.
- Target first useful answer text under about 1000ms after question detection for clear questions.
- It is acceptable to show a short provisional answer first, then append or refine the same answer if the interviewer adds more context.
- Avoid duplicate answer cards for continued interviewer speech; update the active answer when it is clearly the same question.
- Model experimentation is allowed for this goal. Codex may try faster classification/answer models, split-model routing, smaller token budgets, and prompt changes, provided quality safeguards and tests remain intact.
- Do not fake speed by hiding the spinner or changing labels while the answer body is still empty.

## Automation Safety

- Do not auto-commit from local loops. Leave reviewable diffs for the user.
- Do not hardcode or print API keys. Keys may live in environment variables or `~/.interview-master-keys`.
- Do not introduce new production dependencies unless the user explicitly asks.
- Respect existing dirty worktree changes; avoid unrelated refactors.
- Keep generated loop artifacts under `.codex-loop/`.
