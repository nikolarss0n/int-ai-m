Windows (C# Port)
=================

This folder contains WPF-friendly ports of the macOS window helpers.

Files
-----
- `FloatingSolutionWindowController.cs` — floating window for pinned solution + last Q/A.
- `ScreenshotAlertWindow.cs` — screenshot alert window with thumbnails.
- `PermissionsPanelController.cs` — setup panel for permissions and data consent.
- `WindowFactory.cs` — `StealthWindow` and `StealthLogger` helpers, plus `CreateGlassBackground`.

Usage (basic)
-------------
```csharp
// Show floating solution window
var controller = new FloatingSolutionWindowController(dataSource);
controller.Show();

// Create and show screenshot alert
var alert = new ScreenshotAlertWindow();
var created = alert.CreateWindow();
if (created != null)
{
    alert.CreateThumbnails(screenshots);
    alert.Show(created.Value.window);
}
```

Notes
-----
- These implementations are WPF-oriented. If you target WinUI 3, I can port them to Microsoft.UI.Xaml.
- Global hotkeys and non-activating window behavior are best-effort in WPF.

