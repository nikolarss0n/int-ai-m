#!/bin/bash
cd "$(dirname "$0")"

swiftc -o InterviewMaster \
    interview_master.swift \
    Domain/ValueObjects/Tab.swift \
    Domain/ValueObjects/AnalysisMode.swift \
    Domain/Model/AppSettings.swift \
    Domain/Model/Constants.swift \
    Domain/Model/ConversationContext.swift \
    Domain/Model/InterviewMessage.swift \
    Domain/Model/InterviewTemplate.swift \
    Domain/Model/BuiltInTemplates.swift \
    Domain/Entities/Screenshot.swift \
    Infrastructure/API/AnthropicClient.swift \
    Infrastructure/API/OpenAIClient.swift \
    Infrastructure/Capture/ScreenCaptureService.swift \
    Infrastructure/Speech/VADAudioRecorder.swift \
    Infrastructure/Speech/SileroVADRecorder.swift \
    Infrastructure/Speech/SystemAudioCapture.swift \
    Infrastructure/Speech/GroqInterviewClient.swift \
    Infrastructure/QADatabase.swift \
    Infrastructure/Storage/KeychainApiKeyStore.swift \
    Infrastructure/Storage/ApiKeyManager.swift \
    Presentation/Settings/SettingsWindowController.swift \
    Presentation/Styling/SyntaxHighlighter.swift \
    Presentation/Styling/MarkdownRenderer.swift \
    Presentation/Extensions/AppKitExtensions.swift \
    Presentation/Components/FlippedView.swift \
    Presentation/Components/ScrollCaptureView.swift \
    Presentation/Components/HoverButton.swift \
    Presentation/Components/ClaudeLogoView.swift \
    Presentation/Timeline/MessageViewFactory.swift \
    Presentation/Timeline/StreamingMessageHandler.swift \
    Presentation/Windows/ScreenshotAlertWindow.swift \
    Presentation/Windows/WindowFactory.swift \
    Presentation/Windows/FloatingSolutionWindowController.swift \
    Presentation/Windows/PermissionsPanelController.swift \
    Application/VoiceInterviewProcessor.swift \
    Application/UseCases/ExportInterviewUseCase.swift \
    Infrastructure/DebugLogger.swift \
    Presentation/MenuBarSetup.swift \
    Presentation/HotkeyManager.swift \
    Presentation/GhostMode.swift \
    Presentation/SearchController.swift \
    Presentation/FormattingToolbar.swift \
    Presentation/NotesEditor.swift \
    Presentation/ScreenshotManager.swift \
    Presentation/VoiceInterviewController.swift \
    Presentation/InterviewExport.swift \
    Presentation/TimelineManager.swift \
    Presentation/RecordingIndicator.swift \
    Presentation/MonitoringServices.swift \
    Presentation/TemplateSelector.swift \
    -framework Cocoa \
    -framework Carbon \
    -framework ScreenCaptureKit \
    -framework AVFoundation \
    -framework Speech \
    -framework CoreML

if [ $? -eq 0 ]; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi
