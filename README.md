# Interview Master

Interview Master is a native macOS interview copilot. It captures interviewer/system audio, transcribes it with Groq Whisper, detects questions, and streams concise answer cues with xAI Grok (Anthropic Claude as fallback). It can also capture coding-problem screenshots and analyze them with the same LLM.

The project is an AppKit/Swift application compiled directly with `swiftc`. It is not an Xcode project or a Swift Package, and it has no third-party runtime dependencies.

## Requirements

- macOS 14 Sonoma or newer
- Apple Command Line Tools or Xcode, including `swiftc`
- Internet access
- A [Groq API key](https://console.groq.com/keys)
- An [xAI API key](https://console.x.ai) (preferred) or an [Anthropic API key](https://console.anthropic.com/settings/keys) as fallback
- Accessibility and Screen Recording permission for full functionality

Put keys only in `~/.interview-master-keys` on your machine. Never commit them. Groq is required for transcription and the fast classify/answer path. xAI Grok is the preferred model for interview answers and screenshot analysis; Anthropic is used only when `XAI_API_KEY` is missing.

## Quick start

### 1. Clone the repository

```bash
git clone https://github.com/nikolarss0n/int-ai-m.git
cd int-ai-m
```

### 2. Install and verify the Swift toolchain

If `swiftc` is not already available, install Apple's Command Line Tools:

```bash
xcode-select --install
```

Verify the active toolchain:

```bash
xcode-select -p
swiftc --version
```

If Xcode is installed but the command-line tools point somewhere invalid, select Xcode explicitly:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 3. Configure API keys

The development build reads keys from `~/.interview-master-keys` when the app starts. Create it with permissions that allow only your macOS user to read it:

```bash
umask 077
touch "$HOME/.interview-master-keys"
chmod 600 "$HOME/.interview-master-keys"
nano "$HOME/.interview-master-keys"
```

Add the keys as plain `KEY=value` entries, without quotes. A checked-in template is in [`interview-master-keys.example`](interview-master-keys.example):

```text
GROQ_API_KEY=replace_with_your_groq_key
XAI_API_KEY=replace_with_your_xai_key
```

`ANTHROPIC_API_KEY` is optional and used only if `XAI_API_KEY` is unset. Environment variables with the same names override the file at process start.

Save the file, then enforce its permissions:

```bash
chmod 600 "$HOME/.interview-master-keys"
```

If the keys are already available through securely injected environment variables, an automation agent can create the file without placing literal secrets in its command history:

```bash
umask 077
printf 'GROQ_API_KEY=%s\nXAI_API_KEY=%s\n' \
  "$GROQ_API_KEY" "$XAI_API_KEY" > "$HOME/.interview-master-keys"
```

Do not commit this file, paste its contents into logs, or print the keys during setup. The development build treats `~/.interview-master-keys` as the persistent source of truth. API-key changes made in the app's Settings window affect the running process only; edit the file and restart the app to persist them.

### 4. Build and run

```bash
./start.sh
```

`start.sh` performs the complete local workflow:

- Compiles the Swift sources when needed
- Builds `build/InterviewMaster.app`
- Copies the app icon, privacy manifest, resources, and bundled Silero VAD Core ML model
- Uses an available Apple signing identity or falls back to ad-hoc signing
- Launches the app as a background user job

On success, the command prints the process ID and log location. Interview Master is a menu-bar app with no Dock icon. Look for **IM** in the macOS menu bar if its window is hidden.

Use this after changing a build script or resource, or whenever a clean recompilation is useful:

```bash
INTERVIEWMASTER_FORCE_BUILD=1 ./start.sh
```

## First-run macOS setup

The app displays a **Setup Required** panel until the required permissions and consent are complete:

1. Enable **Accessibility** for Interview Master. This allows global shortcuts.
2. Enable **Screen Recording** for Interview Master. macOS groups screenshot and system-audio capture under this permission.
3. Grant the in-app **AI Data Sharing** consent.
4. Restart the app after changing Screen Recording permission:

   ```bash
   ./stop.sh
   ./start.sh
   ```

You can also manage permissions directly in **System Settings → Privacy & Security → Accessibility** and **System Settings → Privacy & Security → Screen Recording**.

If macOS shows an older InterviewMaster permission entry, remove it, run `./start.sh`, and enable the newly created **Interview Master** app. Rebuilding an ad-hoc-signed app can occasionally require permission to be granted again.

Microphone permission may also be requested when local microphone capture is used. The standard interview flow captures system audio and requires Screen Recording permission.

## Configure the interview profile

Open Settings with `⌘,` or from the **IM** menu-bar item. Select the target role, programming language, listening language, response language, and relevant frameworks/tools. These profile settings are stored in macOS user defaults and shape transcription vocabulary and answer generation.

To use the voice workflow:

1. Open the **Timeline** tab (`⌘2`).
2. Click **Start Interview**.
3. Play or join the interview audio through the Mac.
4. Detected questions and streamed answer cues appear in the timeline.

To analyze a coding problem:

1. Capture one or more screenshots with `⌘S`.
2. Analyze the screenshots with `⌘Return`.
3. Review the generated solution in the app.

## Useful commands

| Goal | Command |
| --- | --- |
| Build and launch | `./start.sh` |
| Stop all local instances | `./stop.sh` |
| Compile the standalone binary | `bash build.sh` |
| Force a rebuild and launch | `INTERVIEWMASTER_FORCE_BUILD=1 ./start.sh` |
| Optimized local build and launch | `INTERVIEWMASTER_RELEASE_BUILD=1 INTERVIEWMASTER_FORCE_BUILD=1 ./start.sh` |
| Launch and immediately start listening | `IM_AUTO_START_INTERVIEW=1 ./start.sh` |
| Run deterministic processor tests | `bash Tests/test.sh` |
| Run the standard local quality gate | `./Scripts/verify-interview-quality.sh` |

The standard quality gate builds the app, runs deterministic processor tests, and writes logs and a summary under `.codex-loop/latest/` by default.

Live checks are opt-in because they call external APIs:

```bash
IM_RUN_LIVE_CLASSIFICATION=1 ./Scripts/verify-interview-quality.sh
```

The audio playback smoke test is also opt-in and requires working app permissions, API keys, and an audio fixture:

```bash
IM_RUN_AUDIO_SMOKE=1 IM_START_APP=1 ./Scripts/verify-interview-quality.sh
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘B` | Toggle the main window |
| `⌘S` | Capture a screenshot |
| `⌘Return` | Analyze captured screenshots |
| `⌘1` | Open the Context tab |
| `⌘2` | Open the Timeline tab |
| `⌘F` | Find in notes |
| `⌘G` | Clear captured screenshots |
| `⌘,` | Open Settings |
| `⌘I` | Toggle ghost mode |
| `⌘Arrow` | Move the window while it is focused |

Global shortcuts require Accessibility permission. Without it, the app uses a limited fallback monitor and may not be able to intercept shortcuts from other applications.

## Logs and troubleshooting

### The app exits immediately

Inspect the launcher and debug logs:

```bash
tail -n 100 /tmp/interviewmaster.out
tail -n 100 interview_debug.log
```

Then force a rebuild:

```bash
INTERVIEWMASTER_FORCE_BUILD=1 ./start.sh
```

### The app is running but no window is visible

The app intentionally has no Dock icon. Click **IM** in the menu bar and choose **Show Window**, or press `⌘B` after Accessibility permission is enabled.

Confirm that the process is running:

```bash
pgrep -x InterviewMaster
```

### An API key appears to be missing

Confirm the configuration file exists, is private, and contains the expected variable names without displaying their values:

```bash
test -f "$HOME/.interview-master-keys"
test "$(stat -f '%Lp' "$HOME/.interview-master-keys")" = "600"
grep -q '^GROQ_API_KEY=.' "$HOME/.interview-master-keys"
grep -qE '^(XAI_API_KEY|ANTHROPIC_API_KEY)=.' "$HOME/.interview-master-keys"
```

Do not quote the values in the file. Restart the app after every key-file change because keys are loaded at process startup.

### Audio is not transcribed

- Confirm the Groq key is configured and the Mac is online.
- Confirm Screen Recording permission is enabled for the current `build/InterviewMaster.app`.
- Stop and restart the app after granting permission.
- Check `interview_debug.log` for `TRANSCRIBE`, `SystemAudio`, or Groq HTTP errors.

### Global shortcuts do not work

Enable Accessibility permission for Interview Master, then restart it. If a stale permission entry remains after a rebuild, remove the entry and grant access to the new app bundle.

### macOS repeatedly forgets permissions

For a more stable local code-signing identity, list the available identities:

```bash
security find-identity -v -p codesigning
```

Then launch with the exact identity name:

```bash
INTERVIEWMASTER_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./start.sh
```

Ad-hoc signing still works when no Apple signing identity is installed.

## Repository map for coding agents

The main production path for voice interview behavior is:

- `Application/VoiceInterviewProcessor.swift` — buffering, question detection, routing, and answer streaming
- `Infrastructure/Speech/GroqInterviewClient.swift` — Groq transcription and chat requests
- `Infrastructure/API/AnthropicClient.swift` — xAI Grok (or Anthropic fallback) classification, answers, and screenshot analysis
- `.grok/settings.json` — workspace Grok coding-agent model pin (no API keys)
- `Domain/Model/ConversationContext.swift` — conversation history and follow-up context
- `Presentation/VoiceInterviewController.swift` — audio capture and UI coordination

Other important entry points:

- `interview_master.swift` — application delegate and primary UI composition
- `Domain/Model/AppSettings.swift` — persisted role, language, and profile settings
- `Domain/Model/Constants.swift` — API endpoints, model names, limits, and thresholds
- `Infrastructure/Storage/ApiKeyManager.swift` — startup key-file loading
- `start.sh` — local build, bundle, sign, and launch workflow
- `build.sh` — standalone compiler command
- `Tests/test_processor.swift` — deterministic behavior tests
- `AGENTS.md` — repository-specific rules for coding agents

After Swift production changes, run:

```bash
bash build.sh
```

After question detection, answer formatting, latency routing, role/profile, or conversation-context changes, also run:

```bash
bash Tests/test.sh
```

Use the full local gate before handing work back:

```bash
./Scripts/verify-interview-quality.sh
```

Keep API keys out of source, logs, commits, and test fixtures. Preserve unrelated working-tree changes, and place automated-loop artifacts under `.codex-loop/`.

## Release builds

Local development does not require an Apple Developer account. Signing and notarizing a distributable DMG does. See [README-RELEASE.md](README-RELEASE.md) for the separate release workflow.

## Privacy and external services

Interview audio is sent to Groq for transcription and the fast classify/answer path. Cue-card answers, classification, and screenshots go to xAI when `XAI_API_KEY` is set, otherwise Anthropic. Review the repository's [privacy policy](PRIVACY_POLICY.md) before using the app with sensitive or third-party information, and obtain any consent required for recording or processing interview content.
