# Design QA — Interview Focus / Question Burst

## Comparison target

- Source visual truth: `/Users/nklars0/.codex/generated_images/01a04311-43de-75f3-b79c-3827082e61d7/exec-1e9cbc40-405e-490f-81c2-330e6f6a9c93.png`
- User override: the newest spoken question is always selected in slot 1; the previous two questions shift to slots 2 and 3.
- Final implementation capture: `/Users/nklars0/Projects/int-ai-m/.codex-loop/design-qa/implementation-newest-final.png`
- Full-view comparison: `/Users/nklars0/Projects/int-ai-m/.codex-loop/design-qa/full-comparison-final.png`
- Focused comparison: `/Users/nklars0/Projects/int-ai-m/.codex-loop/design-qa/focused-comparison-final.png`

## Normalization

- Intended native content viewport: 700 × 500 points, dark appearance, active interview.
- Source pixels: 1484 × 1060.
- Implementation pixels: 1420 × 1092, including the native titlebar and window shadow, captured at Retina density from a 700 × 500-point content window.
- Density normalization: both source and implementation were proportionally fitted into equal comparison panels; neither image was stretched.
- State: three-question burst; newest question selected and streaming in slot 1; slots 2 and 3 ready; recording active; gold `AI working` waveform visible.

## Full-view comparison evidence

The final implementation preserves the source hierarchy: compact identity/status header, three-part horizontal burst strip, one dominant answer surface, profile metadata, and a single floating command bar. The native window is denser because it targets the app’s real 700 × 500-point utility-window size rather than reproducing the larger generated canvas. This is an intentional platform constraint, and no persistent controls or answer text are clipped.

The source’s teal/amber bokeh is moodboard context. Production uses a real `NSVisualEffectView` with behind-window blending, so the visible blurred color depends on the desktop beneath the app. Text remains on separate high-contrast scrims and stays sharp.

## Focused comparison evidence

- Header and burst: app identity, red recording dot, gold AI sparkle/waveform, elapsed time, explicit states, selection outline, and two-line question wrapping are present.
- Answer surface: green answer badge, strong heading, white bullet markers, readable body text, streaming cursor, and `Answering 1 of 3` state are present.
- Command bar: Context, Timeline, End interview, AI working, Export, and Settings are all present with native SF Symbols and stable hover/press styling.
- The command bar remains outside the voice content view, so Context never removes the visible route back to Timeline.

## Required fidelity surfaces

- Fonts and typography: native SF Pro/system type is used throughout. The implementation keeps clear semibold hierarchy, 12.5-point burst text, 15-point answer copy, monospaced elapsed digits, two-line question wrapping, and opaque primary text.
- Spacing and layout rhythm: 16-point content insets, 74-point burst strip, 14-point answer radius, 52-point command bar, and stable vertical spacing match the selected composition at native scale. Default and enlarged captures showed no overlap.
- Colors and visual tokens: semantic gold AI/generating, green ready/answer, blue selection, and red recording/end states match the design intent. State words and symbols prevent color-only communication.
- Image quality and asset fidelity: the real InterviewMaster app icon is used. All interface icons are native SF Symbols. No placeholder imagery, handcrafted SVG, emoji, or fake logo asset is used.
- Copy and content: the three questions, answer cue bullets, position label, profile metadata, and command labels are coherent in the standalone app state.
- Accessibility and behavior: burst segments are labeled buttons, answer and activity surfaces expose accessibility roles/labels, state changes post noninterruptive value notifications, Reduce Motion disables waveform animation, and selected-answer scroll position resets when changing questions.

## Comparison history

### Pass 1

- Evidence: `.codex-loop/design-qa/implementation-pass1b.png`
- [P2] Question summaries truncated to a single line.
- [P2] Compact command-bar AI status truncated.
- [P2] Profile metadata used a text glyph instead of a native visual treatment.
- [P2] Focus-answer bullet markers competed with the gold AI semantic color.

Fixes: enabled two-line word wrapping; stabilized the compact `AI working` label; removed the text-glyph decoration; normalized focus-answer bullets to white.

### Pass 2

- Evidence: `.codex-loop/design-qa/implementation-final.png`
- Earlier visual issues were fixed.
- User then changed the interaction rule from preserved selection to newest-first selection.

Fix: assigned speech-order sequences at turn commit, sorted the visible burst newest-first, always selected slot 1, shifted the prior two turns to slots 2 and 3, and propagated sequence through context, floating Q&A, and export ordering.

### Final pass

- Evidence: `.codex-loop/design-qa/implementation-newest-final.png`, `.codex-loop/design-qa/full-comparison-final.png`, and `.codex-loop/design-qa/focused-comparison-final.png`.
- No actionable P0, P1, or P2 fidelity issue remains.
- Residual P3/expected variance: the sampled blur colors depend on the user’s real desktop rather than a bundled bokeh backdrop; the native stealth window’s traffic lights appear inactive because it intentionally does not take keyboard focus.

## Interaction and verification evidence

- Question-burst reducer tests cover newest-first order, stable slots 2/3, out-of-order model callbacks, interleaved per-turn answers, three-item clipping, and reference-counted AI activity.
- Context navigation was exercised in the isolated native QA build; the global command bar remained visible with Context selected and retained the Timeline return action.
- `bash build.sh`: passed.
- `bash Tests/test.sh`: 471/471 passed.
- `./Scripts/verify-interview-quality.sh`: passed.
- `git diff --check`: passed.
- Live API classification and audio playback smoke tests were not enabled.

## Findings

No actionable P0/P1/P2 findings remain.

## Open questions

None blocking. The existing Swift compiler still reports lower-severity non-Sendable capture warnings in the legacy callback architecture; they do not block this build or the verified behavior.

## Implementation checklist

- [x] Native Liquid Glass focus layout.
- [x] Newest question always selected in slot 1.
- [x] Previous two questions preserved in slots 2 and 3.
- [x] Turn-keyed streaming and failure cleanup.
- [x] Gold AI-working waveform and explicit labels.
- [x] Global Context/Timeline navigation.
- [x] Build, deterministic tests, quality gate, and visual comparison.

## Follow-up polish

- P3: consider a future Swift concurrency cleanup to remove the remaining non-Sendable warnings.

final result: passed

---

# Design QA — Practice Active Recall

## Comparison target

- Source visual truth: `/Users/nklars0/Projects/int-ai-m/.codex-loop/practice-redesign/reference-active-recall.png`
- Final implementation capture: `/Users/nklars0/Projects/int-ai-m/.codex-loop/practice-redesign/implementation-review-final.png`
- Full-view comparison: `/Users/nklars0/Projects/int-ai-m/.codex-loop/practice-redesign/comparison-final.png`
- State: Active Recall review, question 4 of 10, typed response frozen, two of three key ideas covered, review rating not yet chosen.

## Normalization

- Intended native content viewport: 700 × 500 points in the existing compact macOS utility window.
- Source pixels: 1536 × 1024.
- Implementation pixels: 760 × 500, including native window chrome in the capture surface.
- Comparison normalization: source was proportionally scaled to 750 × 500; implementation remained 760 × 500; the two equal-height images were joined with a 16-pixel separator. No content was stretched or cropped.
- CSS size/device density: not applicable to this native AppKit implementation.

## Full-view comparison evidence

The implementation preserves the selected design's hierarchy: Interview Master identity, Practice title and Active Recall pill, compact question progress, one dominant dark learning surface, question prompt, response/key-ideas split, coverage statement, learner-controlled scheduling prompt, and four bottom actions. The real 700 × 500-point window requires a denser vertical rhythm than the generated 1536 × 1024 canvas, but no question, key idea, status, or persistent action is clipped.

The implementation intentionally corrects an inconsistency in the generated source: the source shows three green checks while claiming two of three ideas were covered. Production shows two green covered states and one gold review state, so text, color, and iconography agree.

## Focused comparison evidence

A separate crop was not needed. At the normalized 500-pixel comparison height, question copy, the response, all three key ideas, coverage status, native symbols, and all four action labels remain legible in the full-view comparison.

## Required fidelity surfaces

- Fonts and typography: native SF Pro/system type is used throughout. The implementation keeps a 17-point identity label, 20-point Practice title, 10-point uppercase mode/captions, 17-point question, 15-point response, 13-point idea rows, and 11–12-point status/action copy. Hierarchy and wrapping remain stable at the minimum window size.
- Spacing and layout rhythm: the selected two-column comparison is preserved with a central divider, 20-point card padding, 24-point question badge, compact segmented progress, and a single full-width action row. The first QA pass's oversized question region was tightened so the response and ideas receive the intended visual weight.
- Colors and visual tokens: existing semantic AppKit colors map to the source intent: blue focus/response, gold key ideas/hard review, green covered/got-it state, red again/end, and white alpha tiers for primary and secondary text. The outer real glass color varies with the desktop; the learning surface retains the near-black high-contrast scrim.
- Image quality and asset fidelity: the real Interview Master icon is used. Every interface icon is a native SF Symbol with an accessibility description. No generated placeholder, handcrafted SVG, emoji, or simulated raster icon is present.
- Copy and content: Active Recall, question position, response, key ideas, coverage statement, scheduling intervals, and Edit response copy are coherent as a standalone learning state. The compact implementation keeps interval information on the first button line rather than adding a clipped second line.
- Accessibility and behavior: the captured accessibility tree exposes the response text area, Key Ideas, coverage state, and Again/Hard/Got it/Edit response as labeled controls. Covered and missed ideas use words/symbols as well as color. Full Keyboard Access and VoiceOver traversal still merit a manual device pass; screenshot evidence does not claim full accessibility compliance.

## Comparison history

### Pass 1

- Evidence: `.codex-loop/practice-redesign/implementation-review-v1.png` and `.codex-loop/practice-redesign/comparison-v1.png`.
- [P2] The selected source's Interview Master identity bar was missing from the active Practice state.
- [P2] The reviewed response still looked like an editable inset input instead of plain comparison content.
- [P2] The question region consumed too much vertical space at the compact viewport, compressing the key-idea comparison.

Fixes: reused the existing app icon/title treatment during active practice, removed the response input border after reveal, increased active metadata contrast, and tightened the question/divider proportions to give the comparison region more room.

### Final pass

- Evidence: `.codex-loop/practice-redesign/implementation-review-final.png` and `.codex-loop/practice-redesign/comparison-final.png`.
- Earlier P2 differences are fixed.
- No actionable P0, P1, or P2 fidelity issue remains.
- Expected variance: the native utility window uses real glass instead of the generated solid-black outer backdrop; required End run and Timeline actions remain visible; the inconsistent generated three-check state is corrected to two covered and one missed.

## Interaction and verification evidence

- Active Recall now follows `answering → reviewing → rated → next question`; there is no timed auto-advance.
- Confidence is captured before reveal; coverage is explicitly labeled as estimated and can be corrected manually.
- One-gap repair preserves the first response, requires Save or explicit Cancel, and keeps rating controls locked while a repair draft is active.
- Again/Hard/Got it use adaptive intervals, bounded retries, prior independent recalls, confidence, and an optional interview target date.
- Today’s Plan, New/Learning/Solid/Due mastery, weak-concept rounds, and evidence-backed contrast pairs are derived from saved recall history.
- Voice Rehearsal shares the learning loop with spoken answers; Interview mode keeps its separate scored-answer path and locks submitted text.
- In-progress work, Undo, safe exit, and crash-resume state are persisted atomically; malformed snapshots are preserved as recovery files.
- `bash build.sh`: passed.
- `bash Tests/test.sh`: passed (524 processor checks and 304 Practice checks).
- `./Scripts/verify-interview-quality.sh`: passed.
- `git diff --check`: passed.
- Live classification and audio smoke checks were not enabled because this change does not require them.

## Findings

No actionable P0/P1/P2 findings remain.

## Open questions

None blocking. A manual VoiceOver and Full Keyboard Access pass would be useful follow-up validation on the user's preferred macOS accessibility settings.

## Implementation checklist

- [x] Selected key-ideas-on-the-right composition.
- [x] Typed Active Recall response and learner-controlled reveal.
- [x] Deterministic local key-idea extraction and coverage.
- [x] Again/Hard/Got it scheduling plus bounded retry.
- [x] Confidence, estimated/manual coverage, preserved first response, and one-gap repair.
- [x] Today’s Plan, mastery states, adaptive target-date spacing, weak rounds, and contrast rounds.
- [x] Voice Rehearsal, autosave/resume, safe exit, and single-level rating Undo.
- [x] Legacy history decoding and mode-aware records.
- [x] Native build, deterministic tests, quality gate, and visual comparison.

## Follow-up polish

- P3: consider a future manual VoiceOver pass with long real-world questions and increased text size.

final result: passed
