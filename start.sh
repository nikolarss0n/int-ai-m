#!/bin/bash
# Simple one-command startup for Interview Master
cd "$(dirname "$0")"

# Clear debug log file
rm -f interview_debug.log
echo "🗑️  Cleared debug log"

compiler_flags=()
build_mode="debug"
launch_label="com.interviewmaster.local"
app_name="InterviewMaster"
bundle_id="com.nikolayprosenikov.interviewmaster"
app_bundle="build/${app_name}.app"
app_executable="${app_bundle}/Contents/MacOS/${app_name}"
local_entitlements="InterviewMaster.local.entitlements"

if [[ "${INTERVIEWMASTER_RELEASE_BUILD:-0}" == "1" ]]; then
    compiler_flags=(-O)
    build_mode="release (-O)"
fi

needs_build=1
if [[ -x InterviewMaster && "${INTERVIEWMASTER_FORCE_BUILD:-0}" != "1" ]]; then
    changed_source=$(find . -type f -name '*.swift' -newer InterviewMaster -print -quit)
    if [[ -z "$changed_source" ]]; then
        needs_build=0
    fi
fi

if [[ "$needs_build" == "1" ]]; then
    build_started=$SECONDS
    echo "🔨 Building Interview Master ($build_mode)..."

    swiftc "${compiler_flags[@]}" -target arm64-apple-macosx14.0 -o InterviewMaster \
        interview_master.swift \
        Domain/ValueObjects/Tab.swift \
        Domain/ValueObjects/AnalysisMode.swift \
        Domain/Model/AppSettings.swift \
        Domain/Model/Constants.swift \
        Domain/Model/ConversationContext.swift \
        Domain/Model/InterviewMemory.swift \
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
        Infrastructure/Storage/MemoryStore.swift \
        Infrastructure/Storage/ApiKeyManager.swift \
        Infrastructure/DebugLogger.swift \
        Application/VoiceInterviewProcessor.swift \
        Application/UseCases/ExportInterviewUseCase.swift \
        Application/UseCases/MemoryRetrievalUseCase.swift \
        Application/UseCases/SessionAnalysisUseCase.swift \
        Presentation/Settings/SettingsWindowController.swift \
        Presentation/Styling/SyntaxHighlighter.swift \
        Presentation/Styling/MarkdownRenderer.swift \
        Presentation/Extensions/AppKitExtensions.swift \
        Presentation/Components/FlippedView.swift \
        Presentation/Components/ScrollCaptureView.swift \
        Presentation/Components/HoverButton.swift \
        Presentation/Components/ClaudeLogoView.swift \
        Presentation/Components/InterviewFocusComponents.swift \
        Presentation/Timeline/MessageViewFactory.swift \
        Presentation/Timeline/StreamingMessageHandler.swift \
        Presentation/Windows/ScreenshotAlertWindow.swift \
        Presentation/Windows/WindowFactory.swift \
        Presentation/Windows/FloatingSolutionWindowController.swift \
        Presentation/Windows/PermissionsPanelController.swift \
        Presentation/MenuBarSetup.swift \
        Presentation/HotkeyManager.swift \
        Presentation/GhostMode.swift \
        Presentation/SearchController.swift \
        Presentation/FormattingToolbar.swift \
        Presentation/NotesEditor.swift \
        Presentation/ScreenshotManager.swift \
        Presentation/VoiceInterviewController.swift \
        Presentation/InterviewFocusController.swift \
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

    if [ $? -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi

    build_duration=$((SECONDS - build_started))
    echo "✅ Build successful in ${build_duration}s! Starting Interview Master..."
else
    echo "⏭️  Existing binary is up to date; skipping build."
fi

if pgrep -x InterviewMaster > /dev/null; then
    echo "🔁 Stopping existing InterviewMaster process..."
    launchctl remove "$launch_label" 2>/dev/null || true
    pkill -TERM -x InterviewMaster 2>/dev/null || true
    for _ in {1..20}; do
        if ! pgrep -x InterviewMaster > /dev/null; then
            break
        fi
        sleep 0.1
    done
    if pgrep -x InterviewMaster > /dev/null; then
        pkill -KILL -x InterviewMaster 2>/dev/null || true
    fi
fi

echo "📦 Preparing local app bundle..."
mkdir -p "${app_bundle}/Contents/MacOS" "${app_bundle}/Contents/Resources"
cp InterviewMaster "$app_executable"

if [[ -d Resources ]]; then
    cp -R Resources/. "${app_bundle}/Contents/Resources/"
fi
if [[ -d SileroVAD.mlmodelc ]]; then
    cp -R SileroVAD.mlmodelc "${app_bundle}/Contents/Resources/"
fi
if [[ -f PrivacyInfo.xcprivacy ]]; then
    cp PrivacyInfo.xcprivacy "${app_bundle}/Contents/Resources/"
fi
if [[ -f AppIcon.icns ]]; then
    cp AppIcon.icns "${app_bundle}/Contents/Resources/"
fi

cat > "${app_bundle}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${app_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Interview Master</string>
    <key>CFBundleDisplayName</key>
    <string>Interview Master</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Interview Master needs Screen Recording permission to capture interviewer audio and screenshots during technical interviews.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Interview Master needs microphone permission only when local microphone listening is enabled.</string>
</dict>
</plist>
EOF
printf 'APPL????' > "${app_bundle}/Contents/PkgInfo"

xattr -cr "$app_bundle" 2>/dev/null || true

signing_identity="${INTERVIEWMASTER_CODESIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    signing_identity=$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development:/{print $2; exit}')
fi
if [[ -z "$signing_identity" ]]; then
    signing_identity=$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application:/{print $2; exit}')
fi
if [[ -n "$signing_identity" ]]; then
    if ! codesign --force --deep --sign "$signing_identity" --options runtime --entitlements "$local_entitlements" "$app_bundle" >/dev/null; then
        echo "❌ Code signing failed"
        exit 1
    fi
    echo "🔏 Signed local app bundle as: $signing_identity"
else
    if ! codesign --force --deep --sign - "$app_bundle" >/dev/null; then
        echo "❌ Ad-hoc code signing failed"
        exit 1
    fi
    echo "🔏 Signed local app bundle with ad-hoc identity"
fi

# Drop any leftover launchd job first. `launchctl submit` sets KeepAlive, so
# Quit from the menu would exit 0 and launchd would immediately relaunch the app.
launchctl remove "$launch_label" 2>/dev/null || true
launchctl remove "com.codex.interviewmaster" 2>/dev/null || true

# Detach from this shell without KeepAlive so menu Quit is a real process exit.
nohup /usr/bin/env "IM_AUTO_START_INTERVIEW=${IM_AUTO_START_INTERVIEW:-0}" "$PWD/$app_executable" >> /tmp/interviewmaster.out 2>&1 &
disown

app_pid=""
for _ in {1..30}; do
    app_pid=$(pgrep -x InterviewMaster | head -n 1)
    if [[ -n "$app_pid" ]]; then
        break
    fi
    sleep 0.1
done

if [[ -n "$app_pid" ]] && ps -p "$app_pid" > /dev/null; then
    echo "🚀 Running in background as PID $app_pid (no dock icon)"
    echo "📄 Logs: /tmp/interviewmaster.out"
else
    echo "❌ App exited immediately. Recent logs:"
    tail -n 20 /tmp/interviewmaster.out
    exit 1
fi
