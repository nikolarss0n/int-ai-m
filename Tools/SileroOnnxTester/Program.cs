using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

if (args.Length < 2)
{
    Console.WriteLine("Usage: SileroOnnxTester <model.onnx> <mono16k.wav>");
    return 1;
}

var modelPath = args[0];
var wavPath = args[1];

if (!File.Exists(modelPath)) { Console.WriteLine("Model not found: " + modelPath); return 2; }
if (!File.Exists(wavPath)) { Console.WriteLine("WAV not found: " + wavPath); return 2; }

using var session = new InferenceSession(modelPath);

// Read WAV PCM samples (assumes 16-bit PCM mono)
byte[] wav = File.ReadAllBytes(wavPath);
int sampleRate = 16000;

// Simple WAV parse to get sample data (skip header)
int dataIndex = -1;
for (int i = 0; i < wav.Length - 4; i++)
{
    if (wav[i] == (byte)'d' && wav[i+1] == (byte)'a' && wav[i+2] == (byte)'t' && wav[i+3] == (byte)'a') { dataIndex = i + 8; break; }
}
if (dataIndex < 0) { Console.WriteLine("Failed to find data chunk"); return 2; }

int sampleCount = (wav.Length - dataIndex) / 2; // int16
float[] samples = new float[sampleCount];
for (int i = 0; i < sampleCount; i++) samples[i] = BitConverter.ToInt16(wav, dataIndex + i*2) / 32767f;

// Silero default chunk: 576 samples
int chunk = 576;
for (int offset = 0; offset + chunk <= samples.Length; offset += chunk)
{
    var chunkSamples = samples.Skip(offset).Take(chunk).ToArray();
    var tensor = new DenseTensor<float>(new[] {1, chunk});
    for (int i = 0; i < chunk; i++) tensor[0,i] = chunkSamples[i];

    var named = NamedOnnxValue.CreateFromTensor("input", tensor);
    var inputs = new List<NamedOnnxValue> { named };
    using var results = session.Run(inputs);
    var first = results.First();
    var outTensor = first.AsTensor<float>();
    var prob = outTensor.GetValue(0);
    Console.WriteLine($"offset={offset} prob={prob}");

    // NamedOnnxValue is not disposable in all versions; rely on collection disposal
}

return 0;
