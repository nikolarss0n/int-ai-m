# InterviewMaster Improvement Plan

Baseline score: **6.4/10** vs 2026 world-class standards.
Target score: **~8/10** after completing all phases.

---

## Phase 1: Thread Safety & Crash Prevention (P0/P1)

### 1.1 Fix data races in VoiceInterviewProcessor
- **File**: `Application/VoiceInterviewProcessor.swift`
- **Problem**: `utteranceBuffer`, `streamingContent`, `questionEndTime`, `shouldStreamAnswer` accessed from background Task threads and main thread without synchronization
- **Fix**: Add a serial dispatch queue (or convert to actor) to protect all mutable state
- **Scope**: ~30 lines changed, same file only

### 1.2 Fix ApiKeyManager queue configuration
- **File**: `Infrastructure/Storage/ApiKeyManager.swift`
- **Problem**: Queue created without `.concurrent` attribute, making `.barrier` flags on writes ineffective (everything serialized anyway)
- **Fix**: Change queue init to `DispatchQueue(label: ..., attributes: .concurrent)`
- **Scope**: 1 line change

### 1.3 Replace force-unwrapped `lastError!` in retry loops
- **Files**: `Infrastructure/API/AnthropicClient.swift`, `Infrastructure/API/GroqInterviewClient.swift`
- **Problem**: `throw lastError!` in 6 places — crashes if `lastError` is nil in edge case
- **Fix**: Replace with `throw lastError ?? NSError(domain: "InterviewMaster", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error after retries"])`
- **Scope**: 6 one-line changes across 2 files

### 1.4 Protect SystemAudioCapture.recordedSamples
- **File**: `Infrastructure/Speech/SystemAudioCapture.swift`
- **Problem**: `recordedSamples` accessed from ScreenCaptureKit callback thread and VAD processing without synchronization
- **Fix**: Add NSLock around all `recordedSamples` access
- **Scope**: ~10 lines, same file

### 1.5 Reduce implicitly unwrapped optionals in main delegate
- **File**: `interview_master.swift`
- **Problem**: 68 `var x: Type!` properties — crash if setupUI() fails partially
- **Fix**: Convert to proper optionals (`Type?`) for non-UI properties; for UI properties that are always set in setupUI(), group into a struct initialized once:
  ```swift
  struct UIComponents {
      let textView: NSTextView
      let statusLabel: NSTextField
      // ...
  }
  var ui: UIComponents! // Single IUO instead of 68
  ```
- **Scope**: Large refactor of interview_master.swift, touch most extension files

---

## Phase 2: Architecture Improvements (P1)

### 2.1 Extract state into InterviewState
- **File**: New `Domain/Model/InterviewState.swift`, modify `interview_master.swift`
- **Problem**: 40+ boolean/enum state properties scattered across main delegate
- **Fix**: Create a single state struct:
  ```swift
  struct InterviewState {
      var isActive: Bool = false
      var currentTab: Tab = .voice
      var isSearchVisible: Bool = false
      var isGhostMode: Bool = false
      // ... all state in one place
  }
  ```
- **Scope**: New file + refactor property access across extensions

### 2.2 Extract coordinator from InterviewMasterDelegate
- **Problem**: 1290-line god object with 90+ properties mixing window management, UI setup, API config, audio callbacks
- **Fix**: Extract into focused managers:
  - `AudioManager` — VAD, system audio, recording lifecycle
  - `WindowManager` — window positioning, visibility, ghost mode
  - Keep `InterviewMasterDelegate` as thin coordinator
- **Scope**: 3 new files, significant refactor of interview_master.swift and extensions
- **Note**: Do incrementally — extract one manager at a time, build + test between each

### 2.3 Add protocol abstractions for swappable services
- **Files**: New `Domain/Protocols/TranscriptionService.swift`, `Domain/Protocols/LLMService.swift`
- **Problem**: `VoiceInterviewProcessor` hardcoded to Groq + Anthropic
- **Fix**:
  ```swift
  protocol TranscriptionService {
      func transcribe(_ audio: Data) async throws -> (String, TimeInterval)
  }
  protocol LLMService {
      func stream(prompt: String, ...) async throws -> AsyncStream<String>
  }
  ```
  Make GroqClient and AnthropicClient conform. Processor accepts protocols.
- **Scope**: 2 new protocol files, conform existing clients, modify processor init

---

## Phase 3: Testing & CI (P0 reliability)

### 3.1 Set up GitHub Actions CI
- **File**: New `.github/workflows/build.yml`
- **Fix**: Run `bash build.sh` and `bash Tests/test.sh` on every push/PR
- **Scope**: 1 new file (~20 lines)

### 3.2 Add integration tests for API clients
- **File**: New `Tests/test_api_clients.swift`
- **Fix**: Mock HTTP responses to test:
  - Successful API call
  - 4xx error (no retry)
  - 5xx error (retry with backoff)
  - Network timeout
  - Rate limiting (429)
  - Malformed JSON response
- **Scope**: ~200 lines, new file

### 3.3 Add concurrency tests
- **File**: New `Tests/test_thread_safety.swift`
- **Fix**: Test concurrent access to:
  - ConversationContext (simultaneous reads + writes)
  - ApiKeyManager (concurrent key lookups)
  - VoiceInterviewProcessor state mutations
- **Scope**: ~100 lines, new file

### 3.4 Add audio pipeline tests
- **File**: New `Tests/test_audio.swift`
- **Fix**: Test with sample WAV data:
  - Audio format conversion (WAV → M4A)
  - Buffer handling edge cases (empty buffer, max size)
  - VAD threshold sensitivity
- **Scope**: ~150 lines + test fixtures

### 3.5 Implement log rotation
- **File**: `Infrastructure/DebugLogger.swift`
- **Problem**: `interview_debug.log` grows unbounded
- **Fix**: Check file size on app start, rotate if >10MB, keep 1 backup
- **Scope**: ~15 lines added to existing file

---

## Phase 4: Error Recovery & Resilience (P1)

### 4.1 Add circuit breaker for API calls
- **File**: New `Infrastructure/API/CircuitBreaker.swift`, modify API clients
- **Fix**: After 5 consecutive failures within 60s, stop calling API for 30s cooldown. Show user status: "API temporarily unavailable, retrying in Xs"
- **Scope**: 1 new file (~50 lines), small changes to each API client

### 4.2 Add degraded mode
- **File**: `Application/VoiceInterviewProcessor.swift`, `Presentation/VoiceInterviewController.swift`
- **Fix**: When LLM API fails, still show transcription (STT may work independently). When STT fails, show "Transcription unavailable" instead of silent failure
- **Scope**: ~20 lines across 2 files

### 4.3 Improve error specificity
- **File**: New `Domain/Model/InterviewError.swift`
- **Fix**: Replace generic `NSError` with typed errors:
  ```swift
  enum InterviewError: LocalizedError {
      case networkUnavailable
      case apiRateLimited(retryAfter: TimeInterval)
      case transcriptionFailed(reason: String)
      case audioDeviceDisconnected
      case permissionDenied(Permission)
  }
  ```
- **Scope**: 1 new file, update error handling in API clients and processor

### 4.4 Auto-recover from audio stream errors
- **File**: `Infrastructure/Speech/SystemAudioCapture.swift`
- **Problem**: `stream(_:didStopWithError:)` logs error but doesn't retry
- **Fix**: Attempt automatic restart (max 3 times). If fails, notify user with actionable message
- **Scope**: ~20 lines in existing file

---

## Phase 5: UI/UX Polish (P1/P2)

### 5.1 Add basic accessibility
- **Files**: `interview_master.swift`, `Presentation/Timeline/MessageViewFactory.swift`
- **Fix**:
  - Add accessibility labels to all icon-only buttons
  - Add accessibility roles to message cards
  - Add keyboard tab navigation between major controls
  - Post accessibility notifications on dynamic content changes
- **Scope**: ~50 lines spread across UI files

### 5.2 Add destructive action confirmations
- **Files**: `Presentation/ScreenshotManager.swift`, `interview_master.swift`
- **Problem**: Cmd+G (Clear All) has no confirmation
- **Fix**: Show confirmation alert before clearing screenshots/resetting tabs
- **Scope**: ~15 lines

### 5.3 Fix documentation mismatch
- **File**: `SUPPORT.md`
- **Problem**: Documents Cmd+L for hide/show but code uses Cmd+B
- **Fix**: Update docs to match actual shortcuts
- **Scope**: 1 line change

### 5.4 Add spring animations
- **Files**: `interview_master.swift` (tab transitions), `Presentation/GhostMode.swift`
- **Fix**: Replace linear easeOut with CASpringAnimation for tab pill movement and window show/hide
- **Scope**: ~20 lines across 2 files

### 5.5 Add empty states
- **File**: `Presentation/TimelineManager.swift`
- **Problem**: Timeline shows generic message when empty
- **Fix**: Show contextual guidance: "Press record to start your interview" with icon
- **Scope**: ~15 lines

---

## Phase 6: Build System (P2)

### 6.1 Add SwiftLint
- **Files**: New `.swiftlint.yml`, update `build.sh`
- **Fix**: Add SwiftLint with rules matching existing code style. Run as part of build
- **Scope**: 1 config file, 1 line in build.sh

### 6.2 Evaluate SPM migration
- **Note**: Only if external dependencies become needed. Current swiftc approach works for the project's scale. Revisit when:
  - Adding Sentry/crash reporting SDK
  - Adding test framework (XCTest)
  - Build time exceeds 10 seconds
  - Team grows beyond 2 developers

---

## Execution Order

```
Phase 1 (Thread Safety)     ██████████  Week 1
Phase 3.1 (CI)              ███         Week 1 (parallel)
Phase 1.5 (IUO refactor)    ████████    Week 2
Phase 2.1-2.2 (State/Coord) ██████████  Week 2-3
Phase 3.2-3.5 (Tests)       ████████    Week 3 (parallel with Phase 2)
Phase 4 (Error Recovery)     ██████      Week 4
Phase 5 (UI/UX)             ██████      Week 4 (parallel with Phase 4)
Phase 6 (Build)             ███         When needed
```

Phases 1 and 3.1 are independent and should be done first. Phase 2 depends on Phase 1.5. Phases 4 and 5 can run in parallel after Phase 2.
