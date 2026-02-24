Timeline (C# Port)
==================

This folder contains C# ports of the macOS timeline helpers. The implementation is UI-agnostic and produces view models and styled text that can be rendered by WPF/WinUI.

Files
-----
- `MessageViewFactory.cs` — creates `TimelineMessageViewModel` objects with styled content.
- `StreamingMessageHandler.cs` — manages streaming message state and updates the message list.

Usage (quick)
-------------
```csharp
var factory = new MessageViewFactory(new MarkdownRenderer(MarkdownRenderer.Style.Notes));
var vm = factory.CreateMessageViewModel(message);

var handler = new StreamingMessageHandler(factory, delegateRef);
handler.AddStreamingMessage(InterviewMessage.MessageType.Answer, "hashMap", 150);
handler.UpdateStreamingMessage("Partial content...");
handler.FinalizeStreamingMessage("Final content");
```

Notes
-----
- These classes do not create UI controls. They return data you can bind to your UI.
- For a working console demo, see `Tools/TimelineDemo`.

