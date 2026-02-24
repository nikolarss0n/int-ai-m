using System;
using System.Collections.Generic;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Timeline;

public class DemoDelegate : IStreamingMessageHandlerDelegate
{
    public List<InterviewMessage> VoiceMessages { get; set; } = new();
    public void UpdateFloatingQA() => Console.WriteLine("[Demo] UpdateFloatingQA called");
}

