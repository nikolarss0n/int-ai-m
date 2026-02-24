Windows VAD Demo
=================

This demo captures microphone audio on Windows using NAudio and runs a WebRTC VAD (Voice Activity Detector) to detect speech segments.

Quick start
-----------
1. Open PowerShell and run:

```powershell
cd C:\Users\Pipo\IdeaProjects\int-ai-m\Tools\WindowsVadDemo
dotnet restore
dotnet run
```

2. Allow microphone permission when Windows prompts.
3. The console prints VAD-level updates and notifies when a speech segment is captured.
4. Press Enter to stop.

Notes
-----
- The demo uses `NAudio` for capture and `WebRtcVad` (NuGet) for VAD decisions.
- The capture resamples audio to 16 kHz and chunks it into 576-sample blocks; this chunking matches Silero-style expectations (useful if later switching to an ONNX Silero model).
- Speech segments are returned as WAV bytes (16 kHz mono PCM16) via the `OnSpeechSegment` callback.

Troubleshooting
---------------
- If no audio appears, confirm microphone permissions for the app or console host.
- If build fails, run `dotnet restore` and check network access for NuGet.

Files of interest
-----------------
- `Infrastructure/Speech/WindowsAudioCapture.cs` — capture + resample + chunking, designed for UI integration.
- `Infrastructure/Speech/WebRtcVadWrapper.cs` — VAD wrapper using `WebRtcVad` NuGet.
- `Tools/WindowsVadDemo/Program.cs` — simple console demo wiring capture+VAD.

Next steps
----------
- Integrate `WindowsAudioCapture` into your WinUI app. See `Infrastructure/Speech/WinUI_INTEGRATION.md` for a code example.
- Optionally add Silero ONNX (place at `Models/silero-vad-onnx/silero_vad.onnx`) and switch VAD engine to `SileroOnnxVAD` for higher accuracy.

