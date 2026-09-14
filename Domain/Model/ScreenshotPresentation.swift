import Foundation

/// Live Timeline hides the screenshot gallery (`voiceTimelineScrollView`).
/// Analysis results must use the overlay even when the main window is visible.
func shouldPresentScreenshotAnalysisOverlay(mainWindowVisible: Bool) -> Bool {
    _ = mainWindowVisible
    return true
}

func liveScreenshotStatusText(count: Int) -> String {
    switch count {
    case 0: return ""
    case 1: return "1 shot · ⌘↩ analyze"
    default: return "\(count) shots · ⌘↩ analyze"
    }
}
