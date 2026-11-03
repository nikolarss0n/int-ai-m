# Microphone / System-Audio Source Switch — Design

Date: 2026-09-21
Status: implemented locally; real-room microphone calibration and live capture verification pending

Implementation note: the local microphone adapter currently uses explicitly unmeasured `Tuning.microphoneExperimental` (the existing system tuning), with an in-app disclosure. No across-table sensitivity claim is validated. A measurement helper lives under `.codex-loop/mic-source-measurement/`; it has been compiled and self-tested without recording. The default quality gate exercises production detector, converter, lifecycle, and processor code using synthetic audio and fake API/capture dependencies. The measurement delivery gate below remains open.

## Problem

Interview Master captures only system audio, via ScreenCaptureKit (`Infrastructure/Speech/SystemAudioCapture.swift:50-96`). That covers a remote interviewer on Zoom or Teams and nothing else. An in-person interview, or a phone screen taken on a handset, produces zero audio through the Mac — `SCStream` taps the display's audio output, so there is literally nothing to capture.

Add a microphone source alongside it, with an exclusive switch the user can flip mid-interview.

## Decisions

These are settled. Do not re-litigate them during implementation.

1. **Mic means the interviewer is in the room.** Mic audio is classified and answered exactly like system audio. This is the opposite of what the code encodes today.
2. **Exclusive.** Exactly one source is live at a time, never both. `SUGGESTIONS.md:10-15` documents that running both produced duplicate transcriptions of the same utterance — that is why the mic was disabled upstream.
3. **Live mid-interview switching.** The session, transcript, and turn numbering continue across a flip. No session boundary, no autosave.
4. **Shared VAD.** A new `MicrophoneCapture` feeds `SystemAudioCapture`'s existing dB/RMS detector. Not Silero, not `SCStreamConfiguration.captureMicrophone`. Deployment target stays macOS 14.0 (`build.sh:4`).
5. **Push-to-talk mute** at the capture layer, ⌘⇧M, hold-or-tap-to-latch. Deterministic, not heuristic.
6. **Default input device only.** No device picker, no enumeration UI.
7. **Local build only** (`./start.sh`). Already provisioned: `InterviewMaster.local.entitlements` has `com.apple.security.device.audio-input`, `start.sh:190-191` has `NSMicrophoneUsageDescription`, and the local app is unsandboxed. Release/App Store work is out of scope — `build-release.sh` is separately broken (missing 6+ source files, cannot compile today).
8. **Window widens to 760pt** (from 700, `Presentation/Windows/WindowFactory.swift:158`) to fit the source control.
9. **Practice learning behavior stays unchanged.** Its `AVAudioRecorder` (`Presentation/Practice/PracticeTabController.swift:2536-2546`) gets only the shared microphone reservation integration described below. Practice recording remains available during a system-audio interview.

## The core insight: rename, don't add

`AudioSource` (`Domain/Model/InterviewMessage.swift:4-7`) claims to describe *who spoke* — its cases are commented "Your voice" and "Interviewer voice" — while actually describing *what captured it*. That conflation produced the dead-end at `Application/VoiceInterviewProcessor.swift:1145-1157`, where every mic segment is filed into conversation context and returns before classification. Flipping the enum yields silence; a comment there says "Show directly as user response" but `TimelineManager.addUserResponseMessage` (`:313-314`) has zero callers.

Under decisions 2 and 5, speaker identity is a constant: every segment that reaches the pipeline is the interviewer, whichever device produced it. A per-segment `SpeakerRole` would be a field that is always `.interviewer`. A third enum case would be a third way to say the same thing.

Rename the device and delete the early-return. Classification and answer behavior are shared between devices; capture provenance still travels with each turn through the processor, timeline, and export.

```swift
// Domain/Model/InterviewMessage.swift
/// Which device captured the audio. NOT who spoke — under an exclusive
/// source switch with push-to-talk mute, every captured segment is the
/// interviewer regardless of device.
enum CaptureDevice: String, CaseIterable {
    case microphone = "microphone"   // in-person interviewer, or phone on speaker
    case systemAudio = "system"      // remote interviewer (Zoom/Teams output)

    var displayName: String {
        switch self {
        case .microphone: return "Microphone"
        case .systemAudio: return "System Audio"
        }
    }
}
```

The raw values preserve today's export spellings. `Application/UseCases/ExportInterviewUseCase.swift:116` currently writes `msg.audioSource.map { $0 == .microphone ? "microphone" : "system" }`. Keep the JSON key `audioSource`, its optionality, and these strings unchanged; renaming the enum does not itself establish whole-file byte equality or add a session importer.

**Carry the captured device through every exported audio question path.** `VoiceInterviewProcessor.swift:1440`, `:2161`, and `:2291` currently pass hard-coded `.systemAudio` to `processorDidReceiveQuestion` in the classifier, direct Haiku, and Groq paths. Replace those constants with the immutable device supplied to `processAudioSegment`; add that parameter to the answer helpers and forward it through fallbacks. Never read the controller's current selection when publishing a delayed question: the user may already have switched sources. `VoiceInterviewController.swift:48-51` forwards this metadata to the timeline, and export serializes it. The coding-steps path (`VoiceInterviewProcessor.swift:2055-2100`) currently updates pinned content without emitting an exported question; adding those missing transcript events is outside this change. Screenshot/manual-question behavior also stays unchanged.

**Unchanged by zero lines**, each argued rather than assumed:

- `ConversationContext.classifySpeaker(text:isQuestion:)` (`Domain/Model/ConversationContext.swift:37`) — it already short-circuits to `.interviewer` on `isQuestion` at `:44-46`, which is the path every answered segment takes.
- `shouldVetoQuestionAsCandidateStatement` (`VoiceInterviewProcessor.swift:910-975`) and its 18 pinning tests at `Tests/test_processor.swift:1326-1368` — push-to-talk is a human action, not a machine guarantee, so the veto still earns its place as the backstop for a forgotten mute.
- `isDuplicateTranscription` (`:328-365`) — the 5-second window is what silently drops the old device's overlapping tail at the moment of a flip. Making it source-aware would break that.
- All four LLM prompts (`Infrastructure/API/AnthropicClient.swift:305`, `:313`; `VoiceInterviewProcessor.swift:2383-2384`). An in-person interviewer is still an interviewer. `AGENTS.md:26` prefers local-guard changes over prompt changes.
- `SessionAnalysisUseCase` and the export legend.

## The risk that gates everything

`absoluteMinSpeechDb: Float = -35.0` (`SystemAudioCapture.swift:15`) is an **absolute, non-adaptive floor**. `isAboveSpeech` requires `db > speechThreshold && db > absoluteMinSpeechDb`. On top of it, `eligibleUtteranceWAV()` (`:315-320`) requires `peakLevel - currentBaseline >= speechMargin * 0.5`, i.e. 9 dB.

Both numbers were tuned against ScreenCaptureKit's post-AGC digital tap, where a Zoom voice arrives near line level. An interviewer across a table at ~1.5m from the MacBook mic plausibly never crosses -35 dBFS.

The failure is silent. `isSpeaking` never flips, no segment is ever committed, no card ever appears — and nothing errors, because the pipeline is working exactly as written. The user sees a green listening icon and an empty timeline.

**Phase 1 is therefore a measurement spike before production implementation.** Instrument a temporary mic probe with the `SysVAD` dB/baseline measurements (`SystemAudioCapture.swift:222-224`), record real across-the-table speech, and derive `Tuning.microphone` from that data. A lower absolute floor is a hypothesis to measure, not an approved value. Compare room noise and speech across supported input formats; microphone delivery is gated on measured detection, not on successfully starting an engine with `Tuning.systemAudio`.

## Architecture

### New files

| Path | Purpose | ~Lines |
|---|---|---|
| `Domain/Speech/SpeechTurnDetector.swift` | The shared VAD + WAV encoder. Foundation-only, so `Tests/test.sh` can link it. | 260 |
| `Infrastructure/Speech/AudioSourceCapture.swift` | Protocol + factory both capture classes implement. | 70 |
| `Infrastructure/Speech/MicrophoneCapture.swift` | AVAudioEngine input tap feeding the shared detector. | 230 |
| `Domain/Model/AudioSourceSelection.swift` | Production state transitions for request identity, capture status, PTT, and microphone reservations. Links into `Tests/test.sh`. | 150 |
| `Presentation/AudioSourceController.swift` | `extension InterviewMasterDelegate` — handlers, permission flow, mute plumbing, UI sync. | 220 |
| `Tests/test_speech_turn.swift` | Real behavioral tests for the extracted detector. | 180 |
| `Tests/test_audio_source.swift` | Deterministic capture lifecycle, buffer isolation, ownership, and provenance integration tests with fake capture/API dependencies. | 220 |

### Deleted

`Infrastructure/Speech/SileroVADRecorder.swift` and `Infrastructure/Speech/VADAudioRecorder.swift`. Both are dead: the Silero recorder is constructed at `Presentation/VoiceInterviewController.swift:170` with its callbacks commented out at `:179-182` and `startListening()` commented at `:212-213`; `VADAudioRecorder` has zero call sites. Removing the Silero construction also reclaims a CoreML model load on every interview start.

### SpeechTurnDetector

Extract the VAD state, RMS calculation, turn policy, and WAV encoding from `SystemAudioCapture.swift:11-48` and `:165-378`, parameterized by status labels, sample rate, and tuning. Capture callbacks and the `SCStreamDelegate` method within that range stay in the capture adapter; the detector stays Foundation-only. `dispatchSpeechTurn` is duplicated in `SystemAudioCapture.swift:322-341` and `SileroVADRecorder.swift:338-357`, while their eligibility gates have diverged: the system path gates on peak-above-baseline and the Silero path does not. Preserve the system path's behavior in the shared detector.

```swift
final class SpeechTurnDetector {
    struct Labels { let idle, speaking, processing, muted: String
                    static let systemAudio: Labels   // byte-identical to today's literals
                    static let microphone: Labels }

    struct Tuning {
        let speechMargin, silenceMargin, absoluteMinSpeechDb: Float
        let minSpeechDuration, silenceTimeout, speculativeSilenceTimeout: TimeInterval
        let baselineWindowSize, baselineUpdateInterval: Int
        let levelCallbackInterval: TimeInterval
        static let systemAudio: Tuning   // exactly SystemAudioCapture.swift:12-38
        static let microphone: Tuning    // DERIVED FROM PHASE 1 MEASUREMENT
    }

    init(labels: Labels, tuning: Tuning, logTag: String,
         now: @escaping () -> Date = Date.init,
         emitTurn: @escaping (SpeechTurnEmit, Data?) -> Void,
         emitLevel: @escaping (Float, Bool) -> Void,
         emitStatus: @escaping (String) -> Void)

    func ingest(_ samples: UnsafeBufferPointer<Float>)   // runs stateQueue.sync
    func setSampleRate(_ rate: Double)
    func setMuted(_ muted: Bool)                          // push-to-talk gate
    func reset()                                          // full state clear
    func shutdown()                                       // drop sinks
}
```

Detector state is confined to one serial `stateQueue`. Capture lifecycle state needs its own serialized access: `isCapturing` is written today from the SCStream delegate thread (`:185`) and from `:98`/`:113` while being read on the sample queue (`:123`). Moving VAD fields alone does not fix that race. Start, stop, error, and configuration-change handling must use the capture's lifecycle synchronization and prevent a late startup/configuration callback from restarting a stopped capture. Never hold a detector lock across an `await` or invoke controller callbacks while holding it.

**Clock injection:** all four `Date()` call sites in the detector become calls to the injected clock: `processVAD:217`, `eligibleUtteranceWAV:316`, and the preview/final log timestamps. Without this, an injected 1970 speech-start time against a real `Date()` yields a 1.8e9-second duration that passes every duration gate. Preserve the existing strict `>` comparisons and elapsed-duration semantics in the extraction phase; mute behavior is added later.

**Sinks are held weakly.** Each injected closure captures `[weak self]` on the capture object. Otherwise `capture → detector (stored let) → sink closure → capture` is a strong cycle, and since `shutdown()` is only reachable from the stop path, a capture object whose `startCapturing()` threw would be immortal — and would later resurrect itself on an `AVAudioEngineConfigurationChange`, lighting the orange mic indicator with no interview running.

### AudioSourceCapture

```swift
@available(macOS 13.0, *)
protocol AudioSourceCapture: AnyObject {
    var captureDevice: CaptureDevice { get }

    // Identical surface to SystemAudioCapture.swift:41-45 — no signature changes.
    var onLevelUpdate: ((Float, Bool) -> Void)? { get set }
    var onSpeechPreview: ((Data) -> Void)? { get set }
    var onSpeechCancelled: (() -> Void)? { get set }
    var onSpeechSegment: ((Data) -> Void)? { get set }
    var onStatusChange: ((String) -> Void)? { get set }
    var onCaptureFailed: ((Error) -> Void)? { get set }   // new; unset = today's behavior

    func startCapturing() async throws
    func stopCapturing() async
    func stopCapturingSync()     // for applicationWillTerminate, which returns before any Task schedules
    func setMuted(_ muted: Bool)
}
```

`startCapturing()` stays `async throws`. `AVAudioEngine.start()` can be called inside that body without a continuation. The existing system-audio startup still needs lifecycle guards and cleanup around its suspension points; keeping its method signature does not make its current implementation safe against stop/start races.

`setMuted` is implemented on **both** classes (`detector.setMuted(muted)`, one line each). Push-to-talk on system audio is genuinely useful too — room echo bleeds through the loopback, which is exactly why the candidate-statement veto exists in the first place.

### MicrophoneCapture

AVAudioEngine `inputNode.installTap`, 20ms buffers, default input device only.

- **Permission before the engine.** `AVCaptureDevice.requestAccess(for: .audio)` runs before any engine work. A probe confirmed `inputNode.outputFormat(forBus:0)` reads a valid 48000 Hz format while TCC status is `.notDetermined`, so no format check can stand in for a permission check. A tap installed pre-grant delivers silence.
- **Format.** The probed MacBook default input is 48000 Hz / 1ch / Float32 non-interleaved — identical to what ScreenCaptureKit delivers, so the common path is passthrough. A non-48k device (a 44.1 kHz USB headset) takes an `AVAudioConverter` branch. **The tap handler must ingest the *converted* buffer**, and `detector.setSampleRate` must carry the *output* rate, or `createWAVHeader` (`:355-378`) writes 48000 into a 44.1 kHz clip and Groq decodes it 8.8% fast and pitch-shifted, producing hallucinated fragments with no error logged anywhere.
- **Config changes.** An `AVAudioEngineConfigurationChange` observer handles input changes. Serialize recovery with capture start/stop and re-check the capture's running intent before reinstalling or restarting. Rebuild the format decision, reset detector utterance/noise-floor state, and reapply the current mute state before ingest resumes; a device change must not unmute a held or latched mute. A stopped capture must ignore queued configuration notifications.
- **Every throw path after the observer is registered calls `stopCapturingSync()`**, so a failed start cannot leave an orphan engine.

### The hot swap

`switchCaptureDevice(to:)` and its controller mutations run on `MainActor`. Use three distinct identities: `interviewSessionID` changes on session start/stop, `captureRequestID` identifies an in-progress start/switch, and `captureEpoch` identifies callbacks from an installed capture. A request is current only while both its session and request IDs match. The switch latch derives from request ownership; a stale completion cannot clear a newer request's latch.

1. Before **any await**, snapshot the session ID, allocate the request ID, and retain the previous device/capture identity. For a microphone destination, acquire the shared microphone reservation before permission preflight. If Practice owns it, refuse the switch with a visible reason and leave the active source running.
2. `AudioCaptureFactory.preflight(targetDevice)` checks the destination's permission. **The old source remains fully live and answering questions.** Mic `.notDetermined` may show TCC; `.denied`/`.restricted` returns without prompting. Do not change `captureEpoch` yet, because the working source's callbacks remain valid during preflight.
3. Immediately after preflight, re-check session/request identity **before** changing capture state, processor buffers, selection, preferences, alerts, or latches. A stale result may only release its own reservation/resources. On a current denial, offer **Open Settings** (`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone` for mic), restore the displayed active source, release this request's reservation, and finish this request. Nothing was stopped.
4. Acquire the serialized capture lifecycle operation described below, then re-check request identity. Advance `captureEpoch`, detach the old capture's six callbacks, move it from `activeCapture` into owned retiring state, and show capture as stopped/switching. Call `voiceInterviewProcessor.resetCaptureBuffers()`.
5. `await old.stopCapturing()`, then re-check identity. Release an old microphone reservation only after teardown completes. From here zero interview sources are live. If stale, finish owned cleanup and return without starting or recovering another source.
6. Build a **fresh** destination capture, retain it as `pendingCapture` owned by this request, and install callbacks with immutable session ID, epoch, capture identity, and `device`. Accept callbacks only from the committed active capture; pending/stale callbacks cannot show listening or start processing. Apply the current mute state before starting. Recreate rather than reuse detector state from an earlier capture.
7. `try await next.startCapturing()`. On return, validate request identity again. A stale successful start must be explicitly stopped and drained before releasing the pending object/reservation; declining to assign `activeCapture` is insufficient. For a current start, apply the latest mute state again, promote the pending object to `activeCapture`, and commit the actual `captureDevice` and one `.status` row. Persist the preference only when this fulfills an explicit user source selection. Automatic startup resolution and failure recovery update actual capture/UI without overwriting the saved preference. Mute changes during startup also reach `pendingCapture`.
8. On a **current** start failure, stop/drain the failed destination and release only its reservation. If there was a **previously working device in this session**, attempt one fresh capture of it under the same ownership rules; recovery checks existing permission without prompting and reacquires any required reservation. A stale failure must never bump the epoch or launch fallback. Initial startup without a previously working capture has no recovery target. If recovery fails or no target exists, retain the session/transcript/autosave with `activeCapture == nil`, show capture unavailable, and offer an explicit retry through the normal start/switch flow. Do not show listening based solely on `isInterviewActive`.

**Own cleanup across stop/start.** Initial interview start, hot swap, recovery, and stop share one serialized hardware lifecycle. Keep pending and retiring captures reachable until their startup/teardown settles; a new hardware start waits for all older starts to finish and be stopped, and for older stops to finish. Invalidation/cancellation alone is insufficient because an awaited API can still return a successful start. Permission preflight stays outside this hardware operation so a stale TCC dialog cannot block starting a new system-audio session. `stopInterview` invalidates session/request/callback identities immediately, then drains owned captures; late completions clean up their own objects and cannot alter a newer session. Quit synchronously stops owned microphone engines, including pending ones, and disables configuration observers/restart intent.

Controller callback checks must run on the main actor at the point of mutation, including after any queued main-thread hop. A failure on the current pending capture marks its startup failed and prevents promotion; it cannot be silently ignored by the active-callback guard. `onCaptureFailed` follows the same ownership checks and serialized cleanup; errors from retiring captures do not trigger recovery for a new capture. Selecting the already-active source is a no-op, but the same selection can retry an unavailable capture. A normal selection change while no interview is active validates permission/reservation availability and persists the preference without starting hardware. Busy capture cleanup is not represented by a freely reset Boolean.

**Why the epoch, and not nil'ing callbacks.** `dispatchSpeechTurn` copies the closures into locals at `SystemAudioCapture.swift:324-326` *before* the `DispatchQueue.main.async` hop at `:327`. Nil'ing the properties (`VoiceInterviewController.swift:257-261`) therefore cannot stop an already-queued block. The existing guards only check `isInterviewActive`, which stays true across a switch. The epoch, captured into each closure at install time, is the only thing that reliably drops a segment queued before the flip.

**Isolate continuation buffers from in-flight work.** Clearing the buffer once is insufficient: old classifier callbacks at `VoiceInterviewProcessor.swift:1335-1338`, `:1359-1363`, and `:1377-1381` can refill it after the switch. Add a processor `bufferGeneration`, separate from session-level `turnGeneration` and capture callback epochs. Snapshot it synchronously when `processAudioSegment` accepts a segment. `resetCaptureBuffers()` increments it and clears `utteranceBuffer` / `bufferTimestamp` / `utteranceBufferSequence` atomically under `processingStateLock`.

Every shared-buffer operation compares the turn's captured generation under that same lock **before** reading, expiring, consuming, clearing, or writing the buffer. This includes the read/timeout path at `:1175-1185` and sequence-based consume at `:1345-1349`. A stale turn gets no new shared continuation text and cannot mutate a new source's buffer. A buffer snapshot already captured before the switch belongs only to that old turn and may finish processing there. An old incomplete classification still returns without answering, even when its buffer write is rejected. Never hold the lock across `await`; use the existing lock order when interacting with turn state.

**Accepted turns may finish.** A segment already accepted into `processAudioSegment` before the flip may finish transcription/classification and answer using its immutable device and local snapshot, including when its answer has not started yet. Existing answers continue streaming. `resetCaptureBuffers()` invalidates and cancels speculative preview work using `cancelPrefetchTranscription()`, but does **not** bump `turnGeneration`, cancel committed processing tasks, or call either API client's shared cancellation method. Session stop still invalidates all turns normally. Preserve `recentTranscriptions`, conversation context, and `nextTurnSequence`; only continuation text is isolated across the source boundary.

**Independent bug to fix while here:** the stale-turn return at `VoiceInterviewProcessor.swift:1082` does not call `processorHideLoading(turnID:)`, unlike every other early return in that function (`:1096`, `:1108`, `:1118`, `:1128`, `:1139`). Today it is masked because the only caller is `reset()` from `stopInterview()`, which hides loading immediately after. Add the missing call.

### Shared microphone ownership with Practice

Use one main-actor reservation owner shared by interview capture and Practice, with an owner kind and unique lease token. Acquire the lease **before** either feature requests microphone permission; retain it while permission is pending, the recorder is starting/running, or hardware teardown is incomplete. System-audio capture never reserves the microphone. Selecting an idle microphone preference does not retain a lease; actual startup re-checks availability and reserves it.

- A pending/active Practice recorder blocks interview microphone startup or switching, with a visible reason; preserve the current interview source and Practice recording. A pending/active interview microphone blocks Practice recording, while typed/card practice continues. Muting interview capture retains its reservation.
- Add narrow acquire/validate/release callbacks to `PracticeTabController`. `startRecording()` (`:2512-2533`) acquires before TCC, carries the lease alongside its existing permission generation/session/question checks, and validates both immediately before `beginRecorder()`. This closes the race where both features have pending permission requests but neither reports `isRecording` yet.
- On denial, failure, cancellation, session replacement, deactivation, or quit, invalidate that feature's pending permission generation and clean up its recorder. Release only its matching token and only after hardware stops; an obsolete permission completion cannot start a recorder or release a newer lease. Cancelling a permission-only request can release immediately once its completion is guaranteed to fail the identity check.
- Switching mic to system releases the old mic lease after confirmed teardown. A failed switch recovering mic must reacquire a lease; if Practice acquired it meanwhile, recovery reports unavailable instead of stealing the microphone. Do not stop Practice as an incidental recovery action.

These checks are application-level ownership, not an assumption that macOS refuses simultaneous recorders. Both recorders could otherwise ingest the candidate's Practice answer.

### Push-to-talk

⌘⇧M. No current menu item binds shift+M. Add key-up delivery to the CGEvent tap mask (`Presentation/HotkeyManager.swift:126`) and both local (`:51`) and fallback global (`:337`) NSEvent monitors. Also replace the tap's key-down-only guard (`:177`): masks alone do not route releases. Handle the release of a tracked M press before modifier/modal/Practice guards, because Command or Shift may be released before M. Use one event path when the tap is active and the local/global fallback pair otherwise; suppress autorepeat and duplicate delivery.

From unmuted, key-down mutes immediately; release before 400ms latches, and release at or after 400ms unmutes. From latched, the next accepted press clears the latch; its release must not relatch. The visible button toggles latched mute through the same state reducer. Track held and latched state separately, and apply resulting state to active and pending captures.

The gate lives in the detector, **before** RMS, before the `recordedSamples` append, before `updateBaseline`, and before `processVAD`. The pre-baseline placement is load-bearing: `updateBaseline` (`:196-214`) guards on `!isSpeaking`, so a muted-but-still-running pipeline would adapt `currentBaseline` to the user's own loud voice, raising `speechThreshold` and deafening the detector to the interviewer right after unmute.

Engaging mid-utterance calls `abandonCurrentUtterance()`: if a speculative preview already fired, emit `.speechResumedAfterPreview` (which `SpeechTurnPolicy.action` maps to `.cancelInFlightWork` → `cancelPrefetchTranscription`), then clear the same field set as `:263-267`. It deliberately does **not** commit — the interviewer's half-sentence is not a question yet, and a truncated commit is a worse failure than a lost one.

A 120-second watchdog clears only a still-held press whose key-up never arrived, with a visible status change. A valid key-up cancels it, so intentional latched mute does not expire. Stop invalidates the press/watchdog identity; a delayed release or watchdog from the old session cannot change the next session's mute state.

### UI surface

One control, not two.

- **Source switch:** 2-segment `NSSegmentedControl` (`speaker.wave.2` / `mic`) in the live stack built by `Presentation/InterviewFocusController.swift:145` (`setupInterviewFocusCommandBar`). The old controls at `interview_master.swift:866-975` belong to `voiceControlBar`, hidden by `InterviewFocusController.swift:8` and kept hidden by `interview_master.swift:1431-1434`. Keep that legacy bar hidden. Give both segments accessible names, selection state, and tooltips; synchronize toolbar and menu from actual capture/request state.
- **Window and layout:** set the default width at `WindowFactory.swift:158` and the enforced minimum at `interview_master.swift:298` to 760pt. The current live toolbar's fixed widths, spacing, and insets already consume all 704pt available at that window width. Make Context, Timeline, Practice, Export, and Settings compact icon buttons with accessible names/tooltips, retaining labeled Start/Stop, the AI activity capsule, source selector, and mute button. Use stack constraints and a flexible spacer; verify all controls fit at 760pt without clipping or unsatisfiable constraints. Widening the hidden toolbar or only changing the window default does not solve layout.
- **Mute affordance:** add a dedicated clickable status/mute button to the same live command bar. Derive its icon, tint, accessible state, and tooltip from one capture-state function: idle/unavailable `waveform.slash`, listening-system `speaker.wave.2`, listening-mic `mic`, speaking `waveform`, muted `mic.slash.fill`. **Muted outranks speaking.** Route `TimelineManager.updateStatusIcon` (`:157-180`) and focus refresh/speaking updates through this state so they cannot overwrite mute or imply capture is live merely because the interview session is active. Show pending/unavailable state explicitly. AI generation activity must not hide the mute indicator; an old answer may still be streaming while capture is muted or unavailable.
- **Persistence:** `AppSettings.shared.captureDevice`, following the key-constant + computed-property pattern (`Domain/Model/AppSettings.swift:207-212`, `:241-252`). Persists across launches. `resolveStartupCaptureDevice` downgrades to system audio if mic permission was revoked since, without clearing the stored preference — the app never boots showing Mic while capturing nothing.
- **Not in the Settings window.** The control is a mid-interview action; a Save-button dialog is the wrong shape for it.
- **No fourth permissions-panel row.** `PermissionsPanelController` hides the panel and calls `stopMonitoring()` (`:192`) only when all three conditions pass (`:190-195`). Adding mic to that conjunction would keep the setup panel permanently open for every user who never touches mic mode; adding it as a non-gating row is worse, because `stopMonitoring()` kills the 1s poll (`:198-206`) so the row would never update.
- **Menu bar:** one item with a checkmark, next to Start/Stop Interview (`Presentation/MenuBarSetup.swift:135-137`).
- **Timeline:** one `.status` row per flip, so the switch is a visible event in the transcript rather than a silent state change. This matters because `onStatusChange` is only `debugLog`'d today (`VoiceInterviewController.swift:186-188`), `voiceStatusLabel` is hidden (`interview_master.swift:1023-1024`), and `systemWaveformBars` is permanently empty (`:1027`).

### Disclosure

The macOS orange microphone indicator and the Control Center "Microphone — Interview Master" entry cannot be suppressed by any app. Ghost mode is window-level only (`Presentation/GhostMode.swift:8-47`), and `APP_STORE_METADATA.md:38-39` markets the product as invisible to screen sharing. Mic mode trades that property for a capability. The switch shows a one-line note on first use.

## Phasing

Each phase leaves the build green and the existing system-audio path working.

1. **Measure.** Instrument the mic dB path, record real across-the-table speech, derive `Tuning.microphone`. No production code ships. **Gates everything below.**
2. **Extract `SpeechTurnDetector`.** Pure refactor. System audio behavior provably unchanged.
3. **Rename `AudioSource` → `CaptureDevice`**, delete the early-return at `:1145-1157`, propagate immutable device metadata through all three exported question paths, and fix the missing `processorHideLoading` at `:1082`. Verify existing export field names/raw strings and correct source attribution.
4. **`MicrophoneCapture`** + protocol + factory. Delete `SileroVADRecorder` and `VADAudioRecorder`.
5. **Hot swap** + buffer generations + shared Practice microphone reservations + push-to-talk gate. Exercise request ownership and cleanup with delayed fake captures before connecting the UI.
6. **UI** — live focus command bar, compact layout, visible mute/capture state, permission flow, persistence, menu item, default/minimum window width.

## Verification

Required by `AGENTS.md`: `bash build.sh` after every Swift change, `bash Tests/test.sh` after anything touching detection routing.

**Golden-WAV behavior preservation** is the highest-value test for phase 2. Before extracting, capture committed WAV bytes and emit events for fixed synthesized input with a controlled clock in a reference harness. After extracting, replay identical samples and clock values through the production detector and assert byte-for-byte WAV equality and identical event times. This verifies the detector's behavior and timing, not end-to-end API latency; retain the repository's separate first-useful-answer checks.

**`Tests/test_speech_turn.swift`** adds an invocation to `Tests/test.sh`. Mirror the existing `main.swift` harness convention for a test with top-level expressions — `mkdir -p build/speech-turn-tests && cp Tests/test_speech_turn.swift build/speech-turn-tests/main.swift` — and link the production detector and policy. Cover these actual semantics:

- Preview and commit use strict `>` silence comparisons (`SystemAudioCapture.swift:254`, `:258`). With otherwise eligible speech, test before, at, and after 0.25s/0.65s relative to the last above-threshold sample. No preview at exactly 0.25s; no final commit at exactly 0.65s. A prior preview may already exist at the latter boundary.
- `eligibleUtteranceWAV` (`:316`) measures elapsed time since speech start, **including trailing silence**. Preserve a 0.3s above-threshold speech clip that becomes eligible during its trailing silence and ultimately commits; do not require it to emit nothing. For the injected-clock canary, use a test tuning with a longer minimum duration and a 1970 clock so total elapsed speech-plus-silence remains below that minimum at finalization; it must emit nothing. Also test strict minimum-duration boundaries with otherwise eligible samples.
- Mute mid-utterance abandons without committing; a preview is cancelled, baseline is unchanged while muted, and configuration recovery preserves mute. These are phase 4/5 behavior additions, separate from phase 2's preservation fixtures. Changing minimum duration to voiced time or changing `>` to `>=` requires a separately justified detector change, not a refactor-test adjustment.

**Production state tests.** Link `Domain/Model/AudioSourceSelection.swift` into the deterministic suite. Cover startup resolution, request identity, callback admission, status (including muted-over-speaking and active-session-with-no-capture), PTT, and microphone lease transitions. Tests must call the same state logic used in production, not a copied decision function. PTT cases include repeat suppression, modifiers released before M, app-active fallback, short-tap latch/unlatch, hold release, watchdog expiry only while held, and stale release/watchdog after session restart.

**Lifecycle and processor integration tests.** Add `Tests/test_audio_source.swift` to the default local gate through a dedicated macOS test harness that links the production coordination/processor code with injected fake captures, permission results, API clients, and a recording delegate. Use controllable async completions, not sleeps or live permissions/API calls. Verify:

1. Stop then Start while old permission is pending; resolve the old request with both grant and denial. The new session's capture, buffers, preference, alert state, and request latch are unchanged.
2. Stop/Start during pending capture startup or teardown. A new hardware start waits until every older start has settled and its capture has stopped. A late successful start is stopped; a late failure never starts fallback. A current failure restores the previous device at most once.
3. Old/pending capture callbacks queued before a switch cannot publish afterward, including when the device matches. Change mute while a new capture is starting and verify its current state at activation. Also deliver a late configuration-change notification after stop; it must not restart an engine.
4. Delay old STT/classification across `resetCaptureBuffers()`: an old incomplete result cannot refill the buffer; an old expiration/consume operation cannot erase a new source's continuation. Exercise both directions of source switching and generation check plus mutation under the production lock. Old local snapshots remain confined to their accepted turns, turn numbers stay monotonic, and accepted answers still finish after the flip.
5. Run microphone and system questions through Groq, direct Haiku/fallback, and combined classification paths. Assert delegate/timeline/export source values, including an old-source question published after the selected device changed. Preserve JSON field names and compare fixed export fixtures with stable IDs/timestamps; raw-string grep alone does not verify attribution.
6. Pending, active, and stopping mic ownership blocks the other feature in both directions; Practice plus system audio remains allowed. Cancel an old Practice permission request, acquire a new lease, then deliver the old grant: no recorder starts and the new lease remains owned. Refused switches never interrupt an existing Practice recording.
7. Saved mic preference plus revoked permission resolves startup to system audio without changing the saved preference. Automatic recovery also preserves it; only a successful explicit selection changes it. Initial startup failure with no previous working capture reports unavailable without recursive fallback. A failure callback while the current capture is pending prevents promotion to listening.

**Structural assertions** may check that the mic early-return is removed and each new **production** file appears in both `build.sh` and `start.sh`; test-only sources belong in `Tests/test.sh`. Do not count six textual epoch guards as proof of race safety. The behavioral tests above must cover each callback and suspension point using the real production implementation.

**`IM_RUN_MIC_SMOKE=1`**, opt-in like `IM_RUN_AUDIO_SMOKE`, inserted after `Scripts/verify-interview-quality.sh:386` — **not** after `:378`, which is the `fi` of an inner `if` whose enclosing `else` is at `:379`; inserting there produces `syntax error near unexpected token else` and kills the repo's default local gate. It starts the app with the device overridden and greps for `AUDIO_SOURCE: microphone` and `MIC: engine started`.

**Manual only**, since `verify-interview-quality.sh:341-378` `afplay`s a fixture through system *output* and structurally cannot reach an input device:

1. `tccutil reset Microphone com.nikolayprosenikov.interviewmaster` (`start.sh:13`), `./start.sh`, flip to Mic — the dialog appears **before** any capture starts. Deny → control snaps back, alert offers Open Settings. Grant → capture starts with no relaunch.
2. Start on system audio, confirm an answer card, then flip to mic mid-session and speak a question at the laptop. Expect: no "Interview stopped" row, turn numbers keep incrementing (restarting at 1 is the `reset()`-instead-of-`resetCaptureBuffers()` regression), exactly one question card (two means dedupe or the buffer clear failed).
3. Flip while an answer is streaming — it must finish.
4. Forgotten-mute check: speak a candidate-style answer aloud in mic mode. Expect the veto log at `:1370` and no answer card.
5. Export fresh system and mic questions and inspect `audioSource`: respectively `"system"` and `"microphone"`, including a question completing after a switch. Use fixed fixtures in deterministic tests for serialization compatibility, rather than comparing unrelated live session files byte-for-byte.
6. Quit with ⌘Q mid-interview on mic and during startup — the orange indicator must extinguish. Also verify lifecycle logs/test spies for synchronous microphone teardown; process exit alone can release the microphone and does not prove the stop hook ran.
7. At 760pt, exercise Timeline and Context: source/mute controls are visible in the focus command bar, clickable, accessible, and unclipped. Mute remains visible while an answer streams; failed recovery shows capture unavailable. Practice retains its existing navigation and recording behavior under the ownership rules.
8. Exercise real permission and source-switch flows while Practice recording is pending/active, and in the reverse direction. Refusal shows a clear reason, leaves the current recording/source intact, and still permits Practice recording with a system-audio interview.

**`stopInterview` needs an explicit edit** (`VoiceInterviewController.swift:249-264`): delete the `vadRecorder` lines at `:251-252`, invalidate session/request/callback identities, and detach callbacks for active/pending captures. Clear held/latched mute and invalidate its watchdog identity. Retain capture objects and matching mic leases until serialized teardown completes; do not reset a Boolean and permit a new hardware start to overlap cleanup. An old completion may clear only its own request/lease. Full processor reset still ends the old session; later old-session completions must not clear new-session loading/state. Apply synchronous microphone teardown to `applicationWillTerminate` as well.

## Docs to update

`README.md:3` and `:124`, and `AGENTS.md:6`, all currently define the product as system-audio-only.

## Explicitly out of scope

Release/App Store parity (and the pre-existing `build-release.sh` break). Device picker. Simultaneous dual-source capture. Speaker diarization. Wiring `addUserResponseMessage`. Adding missing coding-steps transcript events. Any prompt change. Any change to the veto or its 18 tests. Practice learning/UI redesign beyond microphone reservation feedback. Changes to the system detector's duration semantics during extraction.
