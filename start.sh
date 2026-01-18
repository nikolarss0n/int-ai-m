#!/bin/bash
# Simple one-command startup for Interview Master
cd "$(dirname "$0")"

# Clear debug log file
rm -f interview_debug.log
echo "🗑️  Cleared debug log"

# Compile with optimizations
swiftc -O \
    interview_master.swift \
    Domain/ValueObjects/Tab.swift \
    Domain/ValueObjects/AnalysisMode.swift \
    Domain/Model/AppSettings.swift \
    Domain/Model/ConversationContext.swift \
    Domain/Model/InterviewMessage.swift \
    Domain/Entities/Screenshot.swift \
    Domain/Model/ValueObjects/ScreenshotId.swift \
    Infrastructure/API/AnthropicClient.swift \
    Infrastructure/API/OpenAIClient.swift \
    Infrastructure/Capture/ScreenCaptureService.swift \
    Infrastructure/Capture/MacScreenCapture.swift \
    Infrastructure/Speech/VADAudioRecorder.swift \
    Infrastructure/Speech/SileroVADRecorder.swift \
    Infrastructure/Speech/SystemAudioCapture.swift \
    Infrastructure/Speech/GroqInterviewClient.swift \
    Infrastructure/QADatabase.swift \
    Infrastructure/Storage/KeychainApiKeyStore.swift \
    Infrastructure/Storage/ApiKeyManager.swift \
    Infrastructure/DebugLogger.swift \
    Application/VoiceInterviewProcessor.swift \
    Presentation/Settings/SettingsWindowController.swift \
    Presentation/Styling/SyntaxHighlighter.swift \
    Presentation/Styling/MarkdownRenderer.swift \
    Presentation/Extensions/AppKitExtensions.swift \
    Presentation/Components/FlippedView.swift \
    Presentation/Components/HoverButton.swift \
    Presentation/Components/ClaudeLogoView.swift \
    Presentation/Components/ScrollCaptureView.swift \
    Presentation/Timeline/MessageViewFactory.swift \
    Presentation/Timeline/StreamingMessageHandler.swift \
    Presentation/Windows/ScreenshotAlertWindow.swift \
    Presentation/Windows/WindowFactory.swift \
    Presentation/Windows/FloatingSolutionWindowController.swift \
    Presentation/Windows/PermissionsPanelController.swift \
    -o InterviewMaster \
    -framework Cocoa \
    -framework Carbon \
    -framework ScreenCaptureKit \
    -framework AVFoundation \
    -framework Speech \
    -framework CoreML

# Run if compilation succeeded
if [ $? -eq 0 ]; then
    echo "✅ Build successful! Starting Interview Master..."
    # Launch in background, detach from terminal, suppress output
    nohup ./InterviewMaster > /dev/null 2>&1 &
    disown
    echo "🚀 Running in background (no dock icon)"
else
    echo "❌ Build failed!"
    exit 1
fi
