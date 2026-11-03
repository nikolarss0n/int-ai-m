#!/bin/bash
cd "$(dirname "$0")/.."
set -e

# The two direct swiftc entry points must compile the same production sources.
build_sources=$(sed -n 's/^[[:space:]]*\([^[:space:]]*\.swift\)[[:space:]]*\\$/\1/p' build.sh | sort)
start_sources=$(sed -n 's/^[[:space:]]*\([^[:space:]]*\.swift\)[[:space:]]*\\$/\1/p' start.sh | sort)
if [[ "$build_sources" != "$start_sources" ]]; then
    echo "FAIL: build.sh and start.sh Swift source lists differ"
    exit 1
fi
mkdir -p build/processor-tests
cp Tests/test_processor.swift build/processor-tests/main.swift
swiftc -target arm64-apple-macosx14.0 \
    build/processor-tests/main.swift \
    Domain/Model/InterviewBriefing.swift \
    Domain/Model/WaitProgress.swift \
    Domain/Model/FeedbackNotice.swift \
    Domain/Model/TopicTitle.swift \
    Domain/Model/ScreenshotPresentation.swift \
    Domain/Model/CodingInterviewSteps.swift \
    Domain/Model/CodeFileSections.swift \
    Domain/Model/ConversationUnderstanding.swift \
    Domain/Model/ClassifierStreamParser.swift \
    -o build/test_processor
./build/test_processor
mkdir -p build/design-token-tests
cp Tests/test_design_tokens.swift build/design-token-tests/main.swift
swiftc -target arm64-apple-macosx14.0 \
    build/design-token-tests/main.swift Presentation/Styling/DesignTokens.swift Presentation/Styling/SyntaxHighlighter.swift \
    Presentation/Extensions/AppKitExtensions.swift Domain/Model/Constants.swift \
    -framework Cocoa -o build/test_design_tokens
./build/test_design_tokens
swiftc -target arm64-apple-macosx14.0 \
    -D PRACTICE_STORE_TESTS \
    Tests/test_practice_bank.swift \
    Domain/Practice/PracticeLogic.swift \
    Infrastructure/Practice/PracticeBankLoader.swift \
    Infrastructure/Practice/PracticeStore.swift \
    -o build/test_practice_bank
./build/test_practice_bank

mkdir -p build/speech-turn-tests
cp Tests/test_speech_turn.swift build/speech-turn-tests/main.swift
swiftc -target arm64-apple-macosx14.0 \
    build/speech-turn-tests/main.swift \
    Domain/Speech/SpeechTurnDetector.swift Domain/Model/Constants.swift \
    -o build/test_speech_turn
./build/test_speech_turn

mkdir -p build/microphone-format-tests
cp Tests/test_microphone_format.swift build/microphone-format-tests/main.swift
swiftc -target arm64-apple-macosx14.0 \
    build/microphone-format-tests/main.swift Domain/Model/Constants.swift Domain/Model/InterviewMessage.swift \
    Domain/Speech/SpeechTurnDetector.swift Infrastructure/Speech/AudioSourceCapture.swift \
    Infrastructure/Speech/AudioCaptureFactory.swift Infrastructure/Speech/SystemAudioCapture.swift \
    Infrastructure/Speech/MicrophoneCapture.swift -framework AVFoundation -framework ScreenCaptureKit \
    -o build/test_microphone_format
./build/test_microphone_format

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    Tests/test_audio_source.swift Application/AudioCaptureCoordinator.swift \
    Domain/Model/AudioSourceSelection.swift Domain/Model/InterviewMessage.swift \
    Domain/Model/Constants.swift Infrastructure/Speech/AudioSourceCapture.swift \
    -o build/test_audio_source
./build/test_audio_source

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    Tests/test_capture_processor.swift Application/VoiceInterviewProcessor.swift \
    Application/UseCases/ExportInterviewUseCase.swift Application/UseCases/MemoryRetrievalUseCase.swift \
    Domain/Model/AppSettings.swift Domain/Model/Constants.swift Domain/Model/ConversationContext.swift \
    Domain/Model/InterviewMessage.swift Domain/Model/InterviewMemory.swift Domain/Model/InterviewBriefing.swift \
    Infrastructure/API/JevDecisionClient.swift \
    Domain/Model/CodingInterviewSteps.swift Infrastructure/API/AnthropicClient.swift \
    Domain/Model/ConversationUnderstanding.swift Domain/Model/ClassifierStreamParser.swift Domain/Model/TopicTitle.swift \
    Infrastructure/Speech/GroqInterviewClient.swift Infrastructure/Storage/MemoryStore.swift \
    Infrastructure/DebugLogger.swift Presentation/Extensions/AppKitExtensions.swift \
    -framework Cocoa -o build/test_capture_processor
mkdir -p .codex-loop/capture-processor-tests
(cd .codex-loop/capture-processor-tests && ../../build/test_capture_processor)

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    Tests/test_jev.swift Application/VoiceInterviewProcessor.swift \
    Application/UseCases/ExportInterviewUseCase.swift Application/UseCases/MemoryRetrievalUseCase.swift \
    Domain/Model/AppSettings.swift Domain/Model/Constants.swift Domain/Model/ConversationContext.swift \
    Domain/Model/InterviewMessage.swift Domain/Model/InterviewMemory.swift Domain/Model/InterviewBriefing.swift \
    Infrastructure/API/JevDecisionClient.swift \
    Domain/Model/CodingInterviewSteps.swift Infrastructure/API/AnthropicClient.swift \
    Domain/Model/ConversationUnderstanding.swift Domain/Model/ClassifierStreamParser.swift Domain/Model/TopicTitle.swift \
    Infrastructure/Speech/GroqInterviewClient.swift Infrastructure/Storage/MemoryStore.swift \
    Infrastructure/DebugLogger.swift Presentation/Extensions/AppKitExtensions.swift \
    -framework Cocoa -o build/test_jev
mkdir -p .codex-loop/jev-tests
(cd .codex-loop/jev-tests && ../../build/test_jev)
