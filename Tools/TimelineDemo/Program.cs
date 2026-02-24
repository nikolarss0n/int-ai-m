using System;
using System.Collections.Generic;
using System.IO;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Timeline;

var demo = new DemoDelegate();
var renderer = new MarkdownRenderer(MarkdownRenderer.Style.Notes);
var factory = new MessageViewFactory(renderer, 640);
var handler = new StreamingMessageHandler(factory, demo);

// Add a streaming message and update it
handler.AddStreamingMessage(InterviewMessage.MessageType.Answer, "hashMap", 120);
handler.UpdateStreamingMessage("**Definition:** A hash map stores key/value pairs.\n- O(1) average lookup\n- Handles collisions");
handler.FinalizeStreamingMessage("**Definition:** A hash map stores key/value pairs.\n- O(1) average lookup\n- Handles collisions\n`put(key, value)`");

// Render the last message to HTML
var last = demo.VoiceMessages[^1];
var vm = factory.CreateMessageViewModel(last);
var html = vm.StyledContent.ToHtml();
var output = Path.Combine(Directory.GetCurrentDirectory(), "timeline_demo.html");
File.WriteAllText(output, html);

Console.WriteLine("Wrote: " + output);
Console.WriteLine("Message count: " + demo.VoiceMessages.Count);
