using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using InterviewMasterApp.Infrastructure;

namespace InterviewMasterApp.Infrastructure.Speech
{
    /// <summary>
    /// Silero VAD v5 ONNX model wrapper.
    /// Input requires context prefix: float[1, 576] = 64 context samples + 512 audio samples.
    /// State: float[2, 1, 128] carried between calls.
    /// sr: int64[1] sample rate.
    /// Output: float[1,1] speech probability + float[2,1,128] updated state.
    /// </summary>
    public class SileroOnnxVAD : IDisposable
    {
        private InferenceSession? _session;
        private float[] _state;    // [2, 1, 128] = 256 floats
        private float[] _context;  // last 64 samples from previous input, prepended to next chunk

        private const int StateSize = 2 * 1 * 128;  // 256
        private const int ContextSize = 64;          // context prefix for 16kHz
        public const int WindowSize = 512;           // audio chunk size for 16kHz
        private const int InputSize = ContextSize + WindowSize; // 576
        private const int SampleRate = 16000;

        public bool IsLoaded => _session != null;

        public SileroOnnxVAD()
        {
            _state = new float[StateSize];
            _context = new float[ContextSize];

            var modelPath = Path.Combine(AppContext.BaseDirectory, "Models", "silero-vad-onnx", "silero_vad.onnx");
            DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio, $"SileroOnnxVAD: looking for model at {modelPath}");
            if (!File.Exists(modelPath))
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error, $"SileroOnnxVAD: model NOT FOUND at {modelPath}");
                return;
            }

            try
            {
                var options = new SessionOptions();
                options.InterOpNumThreads = 1;
                options.IntraOpNumThreads = 1;
                _session = new InferenceSession(modelPath, options);
                ResetState();
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Audio,
                    $"SileroOnnxVAD: model loaded (context={ContextSize}, window={WindowSize}, input={InputSize})");
            }
            catch (Exception ex)
            {
                _session = null;
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error, $"SileroOnnxVAD: failed to load model: {ex.Message}");
            }
        }

        /// <summary>
        /// Reset hidden state and context to zeros (start fresh).
        /// </summary>
        public void ResetState()
        {
            Array.Clear(_state, 0, _state.Length);
            Array.Clear(_context, 0, _context.Length);
        }

        /// <summary>
        /// Predict speech probability from a 512-sample audio chunk.
        /// Internally prepends 64-sample context to form the 576-sample model input.
        /// Returns probability 0.0-1.0, or -1 if error.
        /// </summary>
        public float Predict(float[] chunk)
        {
            if (_session == null) return -1f;

            try
            {
                // Build input: [context(64) + audio chunk(512)] = 576 samples
                var inputData = new float[InputSize];
                Array.Copy(_context, 0, inputData, 0, ContextSize);
                Array.Copy(chunk, 0, inputData, ContextSize, Math.Min(chunk.Length, WindowSize));

                var inputTensor = new DenseTensor<float>(inputData, new[] { 1, InputSize });

                // State tensor: [2, 1, 128]
                var stateTensor = new DenseTensor<float>(
                    (float[])_state.Clone(), new[] { 2, 1, 128 });

                // Sample rate tensor: [1]
                var srTensor = new DenseTensor<long>(
                    new long[] { SampleRate }, new[] { 1 });

                var inputs = new List<NamedOnnxValue>
                {
                    NamedOnnxValue.CreateFromTensor("input", inputTensor),
                    NamedOnnxValue.CreateFromTensor("state", stateTensor),
                    NamedOnnxValue.CreateFromTensor("sr", srTensor)
                };

                using var results = _session.Run(inputs);

                // Extract probability and updated state
                float prob = -1f;
                foreach (var r in results)
                {
                    if (r.Name == "output")
                    {
                        prob = r.AsTensor<float>().GetValue(0);
                    }
                    else if (r.Name == "stateN")
                    {
                        var t = r.AsTensor<float>();
                        for (int i = 0; i < StateSize && i < t.Length; i++)
                            _state[i] = t.GetValue(i);
                    }
                }

                // Update context: last 64 samples of this input for next call
                Array.Copy(inputData, InputSize - ContextSize, _context, 0, ContextSize);

                return prob;
            }
            catch (Exception ex)
            {
                DebugLogger.Shared.Log(DebugLogger.LogCategory.Error,
                    $"SileroOnnxVAD.Predict EXCEPTION: {ex.Message}");
                return -1f;
            }
        }

        public void Dispose()
        {
            _session?.Dispose();
            _session = null;
        }
    }
}
