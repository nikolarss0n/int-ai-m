# Silero VAD (ONNX) — Windows migration helper

This folder is a placeholder for an ONNX conversion of the Silero VAD model used on macOS as CoreML.

Purpose
- Provide an ONNX model file (silero_vad.onnx) that can be executed on Windows with the Microsoft.ML.OnnxRuntime
- Used by `Infrastructure/Speech/SileroOnnxVAD.cs` to run VAD inference on audio chunks

How to get a compatible ONNX model
1. Download an official Silero VAD ONNX build from the Silero project or Hugging Face (if available).
2. Alternatively, convert the PyTorch model to ONNX using the Silero repo conversion scripts.
3. Place the ONNX file as: `Models/silero-vad-onnx/silero_vad.onnx`.

Notes on model shape and state
- Several Silero VAD variants expect a fixed input chunk size (e.g. 576 samples at 16 kHz).
- Some variants include recurrent LSTM state inputs/outputs (hidden/cell). The C# wrapper tries to handle the simple, stateless case first. For stateful models additional wiring will be necessary.

NuGet packages to install in your .NET project
- Microsoft.ML.OnnxRuntime
  - `dotnet add package Microsoft.ML.OnnxRuntime`
- For GPU (DirectML) acceleration (optional):
  - `dotnet add package Microsoft.ML.OnnxRuntime.DirectML`

Example usage (after placing model file)
- The app will automatically detect `Models/silero-vad-onnx/silero_vad.onnx` and use it for VAD if present.

If you want, I can also provide conversion commands or a small Python script to convert the PyTorch model to ONNX — tell me which source model you have and I will generate the conversion steps.

