WinUI 3 integration guide (WindowsAudioCapture + WebRtcVad)
===========================================================

This short guide shows how to wire `WindowsAudioCapture` and `WebRtcVadWrapper` into a WinUI3 app (MVVM-friendly). The `WindowsAudioCapture` class exposes async `StartAsync/StopAsync` and events for `StatusChanged`, `LevelUpdated`, and `SpeechSegmentReady`.

Example ViewModel (C#)
----------------------
```csharp
using System;
using System.Windows.Input;
using Microsoft.UI.Dispatching; // for dispatcher
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using InterviewMasterApp.Infrastructure.Speech;

public partial class AudioViewModel : ObservableObject
{
    private WindowsAudioCapture _capture;
    private WebRtcVadWrapper _vad;
    private DispatcherQueue _dispatcher;

    public IRelayCommand StartCommand { get; }
    public IRelayCommand StopCommand { get; }

    public string Status { get; private set; }

    public AudioViewModel(DispatcherQueue dispatcher)
    {
        _dispatcher = dispatcher;
        _vad = new WebRtcVadWrapper(2);
        _capture = new WindowsAudioCapture(_vad);

        _capture.StatusChanged += s => _dispatcher.TryEnqueue(() => Status = s);
        _capture.LevelUpdated += (lvl, spk) => _dispatcher.TryEnqueue(() => { /* update UI level */ });
        _capture.SpeechSegmentReady += bytes => _dispatcher.TryEnqueue(() => { /* handle WAV bytes */ });

        StartCommand = new RelayCommand(async () => await _capture.StartAsync());
        StopCommand = new RelayCommand(async () => await _capture.StopAsync());
    }
}
```

UI wiring (XAML)
----------------
```
<Button Content="Start" Command="{x:Bind ViewModel.StartCommand}" />
<Button Content="Stop" Command="{x:Bind ViewModel.StopCommand}" />
<TextBlock Text="{x:Bind ViewModel.Status}" />
```

Notes
-----
- Ensure your WinUI app has microphone capability enabled in the package manifest:
  - In `Package.appxmanifest`, add the `microphone` capability under `Capabilities`.
- `DispatcherQueue` is used to marshal event updates back to the UI thread. The example uses `Microsoft.UI.Dispatching.DispatcherQueue`.
- For unit testing, you can replace `_vad` with a mock implementing `IVadEngine`.

Switching to Silero ONNX later
-----------------------------
- When you obtain a compatible Silero ONNX model, place it at `Models/silero-vad-onnx/silero_vad.onnx` and install `Microsoft.ML.OnnxRuntime` package in your app.
- Replace instantiation of `_vad` with `new SileroOnnxVAD()` (ensure `SileroOnnxVAD` successfully loads the model), and `WindowsAudioCapture` will forward chunks to it automatically.

