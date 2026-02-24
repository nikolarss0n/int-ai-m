using System;
using System.Threading.Tasks;
using InterviewMasterApp.Infrastructure.Speech;

Console.WriteLine("Windows VAD Demo starting...");

using var vad = new WebRtcVadWrapper(2);
using var capture = new WindowsAudioCapture(vad);

vad.OnLevelUpdate = (level, speaking) => Console.WriteLine($"Level: {level:F2} Speaking: {speaking}");
vad.OnSpeechSegment = (bytes) => Console.WriteLine($"Got speech segment {bytes.Length} bytes");
vad.OnStatusChange = (s) => Console.WriteLine("Status: " + s);

capture.Start();

Console.WriteLine("Press Enter to stop...");
Console.ReadLine();

capture.Stop();
Console.WriteLine("Stopped.");

return 0;
