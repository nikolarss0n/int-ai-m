Styling (C# Port)
=================

This folder contains Windows-friendly, UI-agnostic ports of the macOS styling utilities.

Files
-----
- `SyntaxHighlighter.cs` — One Dark style syntax highlighter that returns `StyledText` runs.
- `MarkdownRenderer.cs` — Markdown renderer that produces `StyledText` runs, supports headers, bold, italic, inline code, code blocks, links, lists, and dividers.
- `TextStyling.cs` — Common styled-run types and HTML output helper.

Usage (simple)
-------------
```csharp
var renderer = new MarkdownRenderer(MarkdownRenderer.Style.Notes);
var styled = renderer.Render(markdownText);
var html = styled.ToHtml();
File.WriteAllText("rendered.html", html);
```

Notes
-----
- These are framework-neutral data models that can be bound to WPF or WinUI text rendering.
- The included `ToHtml()` is a quick way to visualize output without UI.
- For WinUI or WPF, map `StyledRun` objects to Runs/Inline elements or text blocks.

