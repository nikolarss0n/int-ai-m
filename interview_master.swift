import Cocoa
import Carbon
import ScreenCaptureKit
import AVFoundation
import UniformTypeIdentifiers

@available(macOS 14.0, *)
class InterviewMasterDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, StreamingMessageHandlerDelegate, PermissionsPanelDelegate, VoiceInterviewProcessorDelegate {
    var window: NSWindow!
    var textView: NSTextView!
    var statusLabel: NSTextField!
    var floatingButton: NSButton!
    var autoHideButton: NSButton!
    var isFloating = true
    var autoHideEnabled = false
    var eventMonitor: Any?
    var visualEffectView: NSVisualEffectView!

    // Tab system
    var currentTab: Tab = .voice
    var notesTabButton: NSButton!
    var codingTabButton: NSButton!
    var voiceTabButton: NSButton!
    var tabContainer: NSVisualEffectView!
    var tabSelectionPill: NSView!  // iOS-style morphing selection pill
    
    // Recording indicator (Dynamic Island style)
    var recordingPill: NSView!
    var recordingDot: NSView!
    var recordingTimeLabel: NSTextField!
    var recordingStartTime: Date?
    var recordingTimer: Timer?

    // API status indicators (in tab bar)
    var anthropicStatusDot: NSView!
    var groqStatusDot: NSView!
    var notesContentView: NSView!
    var codingContentView: NSView!
    var voiceContentView: NSView!
    var voiceControlBar: NSView!

    // Voice tab - Interview assistant
    var voiceTimelineScrollView: NSScrollView!
    var voiceTimelineContainer: NSView!
    var voiceStatusLabel: NSTextField!
    var systemWaveformBars: [NSView] = []   // Gold waveform - system audio (interviewer)
    var systemIndicatorLabel: NSTextField!
    var voiceToggleButton: HoverButton!
    var roleDropdown: NSPopUpButton!
    var programmingLanguageDropdown: NSPopUpButton!
    var speakingLanguageDropdown: NSPopUpButton!
    var voiceMessages: [InterviewMessage] = []
    var typingDotsView: NSView!
    var typingDots: [CALayer] = []

    // Pill-style button
    var nestButtonContainer: NSView!
    var nestButtonInner: CALayer!
    var nestIconView: NSImageView!
    var statusIconView: NSImageView!
    var statusIconContainer: NSView!

    // Tab icons in bottom toolbar
    var contextTabIcon: NSImageView!
    var contextTabContainer: NSView!
    var timelineTabIcon: NSImageView!
    var timelineTabContainer: NSView!

    // API key indicators
    var anthropicKeyDot: NSView!
    var groqKeyDot: NSView!

    // Pinned coding task solution
    var pinnedSolutionContainer: ScrollCaptureView!
    var pinnedSolutionTextView: NSTextView!
    var pinnedSolutionScrollView: NSScrollView!
    var currentPinnedSolution: String?

    // Interview mode - transparent click-through overlay
    var isInterviewModeActive = false
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    var vadRecorder: SileroVADRecorder?
    var systemAudioCapture: SystemAudioCapture?  // Supports both batch and streaming modes
    var groqClient: GroqInterviewClient?
    var conversationContext = ConversationContext()
    var isInterviewActive = false
    var groqApiKey: String? {
        return ApiKeyManager.shared.getKey(.groq)
    }
    var deepgramApiKey: String? {
        return ApiKeyManager.shared.getKey(.deepgram)
    }

    // Voice interview processor (handles transcription, classification, answer generation)
    var voiceInterviewProcessor: VoiceInterviewProcessor!

    // Search
    var searchField: NSTextField!
    var searchContainer: NSVisualEffectView!
    var searchResultsLabel: NSTextField!
    var isSearchVisible = false

    // Formatting toolbar
    var formattingToolbar: NSVisualEffectView!
    var isFormattingToolbarVisible = false

    // Rendering debounce
    var renderTimer: Timer?
    var lastTextLength: Int = 0

    // Coding tab - Screenshot thumbnails
    var screenshotThumbnails: [NSButton] = []
    var screenshotThumbnailsContainer: NSView!
    var screenshots: [Screenshot] = []

    // Coding tab - Analysis
    var analysisTextView: NSTextView!
    var analyzeButton: HoverButton!
    var clearButton: HoverButton!

    // Analysis mode (smart - auto-detects content type)
    var analysisMode: AnalysisMode = .smart

    // AR Annotation overlay (invisible to screen share)
    var arOverlay: ARAnnotationOverlay?

    // API Key storage - managed by ApiKeyManager
    var apiKey: String? {
        return ApiKeyManager.shared.getKey(.anthropic)
    }
    var openAIApiKey: String?

    // Infrastructure services
    var screenCaptureService: ScreenCaptureService
    var anthropicClient: AnthropicClient?
    var openAIClient: OpenAIClient?

    // Presentation components
    var notesMarkdownRenderer: MarkdownRenderer
    var analysisMarkdownRenderer: MarkdownRenderer
    var syntaxHighlighter: SyntaxHighlighter
    var messageViewFactory: MessageViewFactory!
    var streamingMessageHandler: StreamingMessageHandler!
    var alertWindowManager: ScreenshotAlertWindow

    // Screenshot alert
    var alertWindow: NSWindow?
    var settingsWindowController: SettingsWindowController?
    var alertThumbnailsContainer: NSView?
    var screenshotMonitorTimer: Timer?
    var lastScreenshotCount = 0

    // Permissions panel
    var permissionsPanelController: PermissionsPanelController!

    // Persistence
    let notesStorageKey = "InterviewMaster.SavedNotes"
    let dataConsentKey = "InterviewMaster.DataConsentGiven"

    override init() {
        self.screenCaptureService = ScreenCaptureService()
        self.notesMarkdownRenderer = MarkdownRenderer(style: .notes)
        self.analysisMarkdownRenderer = MarkdownRenderer(style: .analysis)
        self.syntaxHighlighter = SyntaxHighlighter(fontSize: 12)
        self.alertWindowManager = ScreenshotAlertWindow()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize debug logging (clears previous log)
        DebugLogger.shared.clear()

        setupMenuBar()
        setupWindow()
        setupUI()
        setupHotkey()
        startScreenShareMonitoring()
        startScreenshotMonitoring()
        startFocusMonitoring()
        
        // Listen for API key updates from Settings
        NotificationCenter.default.addObserver(
            forName: .apiKeysUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleApiKeysUpdated()
        }

        // Listen for interview settings updates from Settings
        NotificationCenter.default.addObserver(
            forName: .interviewSettingsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleInterviewSettingsUpdated()
        }

        // AR overlay now triggers when interview starts (start button)
    }
    
    private func handleApiKeysUpdated() {
        // Show confirmation that keys were updated
        let hasAnthropic = ApiKeyManager.shared.hasKey(.anthropic)
        let hasGroq = ApiKeyManager.shared.hasKey(.groq)

        var message = "API keys updated:\n"
        message += "• Anthropic: \(hasAnthropic ? "✓ Configured" : "Not set")\n"
        message += "• Groq: \(hasGroq ? "✓ Configured" : "Not set")"

        // Update status label if visible
        if !voiceContentView.isHidden {
            voiceStatusLabel.stringValue = hasGroq ? "✓ Groq API ready" : "⚠️ Groq API key needed"
        }
    }

    private func handleInterviewSettingsUpdated() {
        // Sync toolbar dropdowns with settings
        if let index = InterviewRole.allCases.firstIndex(of: AppSettings.shared.role) {
            roleDropdown.selectItem(at: index)
        }
        if let index = ProgrammingLanguage.allCases.firstIndex(of: AppSettings.shared.programmingLanguage) {
            programmingLanguageDropdown.selectItem(at: index)
        }
        if let index = SpeakingLanguage.allCases.firstIndex(of: AppSettings.shared.speakingLanguage) {
            speakingLanguageDropdown.selectItem(at: index)
        }
        NSLog("✅ Interview settings synced to toolbar")
    }

    func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        appMenu.addItem(withTitle: "About Interview Master", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let hideItem = appMenu.addItem(withTitle: "Hide Interview Master", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Interview Master", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        fileMenu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "n")
        fileMenu.addItem(NSMenuItem.separator())
        let captureItem = fileMenu.addItem(withTitle: "Capture Screenshot", action: #selector(captureScreenshotPlaceholder), keyEquivalent: "s")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export Notes...", action: #selector(exportNotes), keyEquivalent: "e")

        // Edit menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let findItem = editMenu.addItem(withTitle: "Find...", action: #selector(toggleSearch), keyEquivalent: "f")
        findItem.keyEquivalentModifierMask = [.command]

        // View menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        viewMenu.addItem(withTitle: "Context", action: #selector(switchToNotesTab), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Timeline", action: #selector(switchToVoiceTab), keyEquivalent: "2")
        viewMenu.addItem(NSMenuItem.separator())
        let toggleItem = viewMenu.addItem(withTitle: "Toggle Window", action: #selector(toggleWindowVisibility), keyEquivalent: "b")
        toggleItem.keyEquivalentModifierMask = [.command]
        let arItem = viewMenu.addItem(withTitle: "AR Annotations", action: #selector(toggleAROverlay), keyEquivalent: "o")
        arItem.keyEquivalentModifierMask = [.command, .shift]
        print("🔍 AR menu item created: ⌘⇧O")

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        // Help menu
        let helpMenu = NSMenu(title: "Help")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        helpMenu.addItem(withTitle: "Interview Master Help", action: #selector(showHelp), keyEquivalent: "?")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: "Keyboard Shortcuts", action: #selector(showKeyboardShortcuts), keyEquivalent: "")
        helpMenu.addItem(withTitle: "Privacy Policy", action: #selector(showPrivacyPolicy), keyEquivalent: "")

        NSApp.mainMenu = mainMenu
        NSApp.helpMenu = helpMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Interview Master"
        alert.informativeText = "Version 1.0.0\n\nAI-powered interview assistant for software engineers.\n\nCapture coding problems and get instant analysis with Claude AI.\n\n© 2024 Nikolay Prosenikov"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Privacy Policy")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            showPrivacyPolicy()
        }
    }

    @objc func showPrivacyPolicy() {
        // Privacy Policy URL - required for App Store (Guideline 5.1.1)
        if let url = URL(string: "https://github.com/nikolayprosenikov/interview-master/blob/main/PRIVACY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func newNote() {
        switchToNotesTab()
        textView.string = "# New Note\n\n"
        renderMarkdown()
        saveNotes()
    }

    @objc func exportNotes() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text, .plainText]
        savePanel.nameFieldStringValue = "interview-notes.md"
        savePanel.title = "Export Notes"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try textView.string.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    @objc func showHelp() {
        if let url = URL(string: "https://github.com/nikolayprosenikov/interview-master") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showKeyboardShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = """
        Global (work from any app):
        ⌘B          Toggle window visibility
        ⌘S          Capture screenshot
        ⌘↩          Analyze screenshots

        Navigation:
        ⌘1          Context tab
        ⌘2          Timeline tab

        Editing:
        ⌘F          Find in notes
        ⌘G          Clear screenshots
        ⌘,          Settings

        Window:
        ⌘←↑↓→       Move window
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }


    func setupWindow() {
        window = WindowFactory.createMainWindow()

        // Use accessory policy - no dock icon
        NSApp.setActivationPolicy(.accessory)

        // Show window on startup
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupUI() {
        guard let contentView = window.contentView else { return }

        // ⭐ GLASS BACKGROUND (NSVisualEffectView) - visionOS style (balanced)
        visualEffectView = NSVisualEffectView(frame: contentView.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .menu  // Balanced material - transparent but readable
        visualEffectView.alphaValue = 0.8  // More opaque for blur effect
        contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

        // Bottom bar with frosted glass - visionOS style (balanced)
        // Bottom bar - HIDDEN (all controls moved to unified bottom toolbar in voice content)
        let bottomBar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: contentView.frame.width, height: 60))
        bottomBar.isHidden = true
        contentView.addSubview(bottomBar)

        // Tab bar - HIDDEN (all controls moved to bottom toolbar)
        let tabBar = NSView(frame: NSRect(x: 20, y: 10, width: contentView.frame.width - 40, height: 44))
        tabBar.autoresizingMask = [.width, .maxYMargin]
        tabBar.isHidden = true  // Hidden - using unified bottom toolbar
        contentView.addSubview(tabBar)

        // Tab switcher container - HIDDEN (tabs moved to bottom toolbar)
        let tabContainerWidth: CGFloat = 240
        tabContainer = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: tabContainerWidth, height: 36))
        tabContainer.isHidden = true  // Hidden - using bottom toolbar tabs instead
        tabContainer.blendingMode = .withinWindow
        tabContainer.material = .menu
        tabContainer.state = .active
        tabContainer.wantsLayer = true
        tabContainer.layer?.cornerRadius = 10
        tabContainer.layer?.borderWidth = 1
        tabContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        tabBar.addSubview(tabContainer)

        // Calculate button widths
        let tabPadding: CGFloat = 3
        let tabButtonWidth = (tabContainerWidth - tabPadding * 2) / 2

        // Selection pill (slides behind selected tab) - iOS style, starts on Timeline
        tabSelectionPill = NSView(frame: NSRect(x: tabPadding + tabButtonWidth, y: 3, width: tabButtonWidth, height: 30))
        tabSelectionPill.wantsLayer = true
        tabSelectionPill.layer?.cornerRadius = 8
        tabSelectionPill.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        // Subtle inner glow
        tabSelectionPill.layer?.shadowColor = NSColor.white.cgColor
        tabSelectionPill.layer?.shadowOpacity = 0.1
        tabSelectionPill.layer?.shadowRadius = 4
        tabSelectionPill.layer?.shadowOffset = .zero
        tabContainer.addSubview(tabSelectionPill)

        // Context tab button - Clean, no background (pill provides it)
        notesTabButton = NSButton(frame: NSRect(x: tabPadding, y: 3, width: tabButtonWidth, height: 30))
        notesTabButton.title = "Context"
        notesTabButton.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Context")
        notesTabButton.imagePosition = .imageLeading
        notesTabButton.imageHugsTitle = true
        notesTabButton.bezelStyle = .rounded
        notesTabButton.isBordered = false
        notesTabButton.font = .systemFont(ofSize: 13, weight: .semibold)
        notesTabButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        notesTabButton.target = self
        notesTabButton.action = #selector(switchToNotesTab)
        notesTabButton.wantsLayer = true
        notesTabButton.contentTintColor = NSColor.white.withAlphaComponent(0.5)  // Dimmed, Timeline is default
        notesTabButton.layer?.backgroundColor = NSColor.clear.cgColor
        tabContainer.addSubview(notesTabButton)

        // Coding tab button - HIDDEN
        codingTabButton = NSButton(frame: .zero)
        codingTabButton.isHidden = true

        // Timeline tab button
        voiceTabButton = NSButton(frame: NSRect(x: tabPadding + tabButtonWidth, y: 3, width: tabButtonWidth, height: 30))
        voiceTabButton.title = "Timeline"
        voiceTabButton.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Timeline")
        voiceTabButton.imagePosition = .imageLeading
        voiceTabButton.imageHugsTitle = true
        voiceTabButton.bezelStyle = .rounded
        voiceTabButton.isBordered = false
        voiceTabButton.font = .systemFont(ofSize: 13, weight: .semibold)
        voiceTabButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        voiceTabButton.target = self
        voiceTabButton.action = #selector(switchToVoiceTab)
        voiceTabButton.wantsLayer = true
        voiceTabButton.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        voiceTabButton.layer?.backgroundColor = NSColor.clear.cgColor
        tabContainer.addSubview(voiceTabButton)
        
        // Recording pill (Dynamic Island style) - hidden by default
        recordingPill = NSView(frame: NSRect(x: tabContainerWidth + 20, y: 4, width: 28, height: 28))
        recordingPill.wantsLayer = true
        recordingPill.layer?.cornerRadius = 14
        recordingPill.layer?.backgroundColor = NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.9).cgColor
        recordingPill.alphaValue = 0
        recordingPill.isHidden = true
        tabBar.addSubview(recordingPill)
        
        // Recording dot inside pill
        recordingDot = NSView(frame: NSRect(x: 10, y: 10, width: 8, height: 8))
        recordingDot.wantsLayer = true
        recordingDot.layer?.cornerRadius = 4
        recordingDot.layer?.backgroundColor = NSColor.white.cgColor
        recordingPill.addSubview(recordingDot)
        
        // Recording time label (shown when pill expands)
        recordingTimeLabel = NSTextField(labelWithString: "00:00")
        recordingTimeLabel.frame = NSRect(x: 24, y: 6, width: 50, height: 16)
        recordingTimeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        recordingTimeLabel.textColor = .white
        recordingTimeLabel.alphaValue = 0
        recordingPill.addSubview(recordingTimeLabel)

        // Settings dropdowns moved to voiceControlBar (bottom toolbar)

        // Main content area - no dark background, clean look
        // (contentPanel removed for cleaner timeline appearance)

        // Notes content view - ON TOP of glass, not inside!
        notesContentView = NSView(frame: NSRect(x: 20, y: 56, width: contentView.frame.width - 40, height: contentView.frame.height - 76))
        notesContentView.autoresizingMask = [.width, .height]
        notesContentView.isHidden = true  // Start with Timeline tab visible
        contentView.addSubview(notesContentView)  // Add to contentView, NOT contentPanel!

        // Text editor for notes
        let scrollView = NSScrollView(frame: NSRect(x: 15, y: 15, width: notesContentView.frame.width - 30, height: notesContentView.frame.height - 30))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        textView = NSTextView(frame: scrollView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor(white: 1.0, alpha: 1.0)  // Pure white
        textView.insertionPointColor = NSColor(white: 1.0, alpha: 1.0)
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)  // Regular weight
        textView.isRichText = true
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Disable automatic text replacements and corrections
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        // Load saved notes or use default text
        if let savedNotes = UserDefaults.standard.string(forKey: notesStorageKey), !savedNotes.isEmpty {
            textView.string = savedNotes
        } else {
            textView.string = """
# Common Interview Questions

## JavaScript/TypeScript

**Q: What is the difference between `let`, `const`, and `var`?**
A: `var` is function-scoped, `let` and `const` are block-scoped. `const` cannot be reassigned.

**Q: Explain closures**
A: Functions that have access to variables from outer scope even after outer function has returned.

**Q: What is event delegation?**
A: Technique of handling events at parent level using event bubbling instead of adding listeners to each child.

## System Design

**Q: Design a URL shortener**
- Hash function (MD5/Base62)
- Database: key-value store (Redis)
- Cache layer
- Load balancer
- Analytics tracking

**Q: Design Twitter feed**
- Fan-out on write vs read
- Timeline service
- Caching strategy
- Pagination

## React

**Q: useEffect vs useLayoutEffect?**
A: useEffect runs after paint, useLayoutEffect runs synchronously before paint.

**Q: What are React keys?**
A: Unique identifiers to help React identify which items changed/added/removed in lists.

---

## Code Example

Here's a sample Python function:

```python
def two_sum(nums, target):
    # Hash map to store value -> index
    seen = {}
    for i, num in enumerate(nums):
        complement = target - num
        if complement in seen:
            return [seen[complement], i]
        seen[num] = i
    return []
```

The function uses a **hash map** for `O(n)` time complexity.

---

**Add your own notes below...**
"""
        }

        scrollView.documentView = textView
        notesContentView.addSubview(scrollView)

        // Formatting toolbar - visionOS style (floating)
        setupFormattingToolbar(in: notesContentView)

        // Voice search feature removed - not working correctly

        // Coding content view - ON TOP of glass, not inside!
        codingContentView = NSView(frame: NSRect(x: 20, y: 8, width: contentView.frame.width - 40, height: contentView.frame.height - 28))
        codingContentView.autoresizingMask = [.width, .height]
        codingContentView.isHidden = true  // Start with notes tab visible
        contentView.addSubview(codingContentView)  // Add to contentView, NOT contentPanel!

        // Screenshot thumbnails bar (top) - visionOS style
        let thumbnailBar = NSVisualEffectView(frame: NSRect(x: 15, y: codingContentView.frame.height - 65, width: codingContentView.frame.width - 30, height: 50))
        thumbnailBar.autoresizingMask = [.width, .minYMargin]
        thumbnailBar.blendingMode = .withinWindow
        thumbnailBar.material = .menu
        thumbnailBar.state = .active
        thumbnailBar.alphaValue = 1.0
        thumbnailBar.wantsLayer = true
        thumbnailBar.layer?.cornerRadius = 12
        thumbnailBar.layer?.borderWidth = 1.0
        thumbnailBar.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        codingContentView.addSubview(thumbnailBar)

        // Scroll view for thumbnails - starts after capture button
        let thumbnailScrollView = NSScrollView(frame: NSRect(x: 160, y: 7.5, width: thumbnailBar.frame.width - 175, height: 35))
        thumbnailScrollView.autoresizingMask = [.width]
        thumbnailScrollView.hasHorizontalScroller = true
        thumbnailScrollView.hasVerticalScroller = false
        thumbnailScrollView.borderType = .noBorder
        thumbnailScrollView.drawsBackground = false
        thumbnailScrollView.backgroundColor = .clear

        screenshotThumbnailsContainer = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 35))
        thumbnailScrollView.documentView = screenshotThumbnailsContainer
        thumbnailBar.addSubview(thumbnailScrollView)

        // Capture button with SF Symbol - rectangular style matching tab buttons
        let captureBtn = NSButton(frame: NSRect(x: 15, y: 10, width: 130, height: 30))
        captureBtn.title = " Capture ⇧⌘S"
        captureBtn.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Capture")
        captureBtn.imagePosition = .imageLeading
        captureBtn.imageHugsTitle = true
        captureBtn.bezelStyle = .rounded
        captureBtn.isBordered = false
        captureBtn.font = .systemFont(ofSize: 13, weight: .bold)
        captureBtn.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        captureBtn.target = self
        captureBtn.action = #selector(captureScreenshotPlaceholder)
        captureBtn.wantsLayer = true
        captureBtn.layer?.cornerRadius = 8
        captureBtn.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.2).cgColor
        captureBtn.layer?.borderWidth = 1.5
        captureBtn.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.4).cgColor
        captureBtn.contentTintColor = NSColor.applePurple
        thumbnailBar.addSubview(captureBtn)

        // Analysis results area
        let analysisScrollView = NSScrollView(frame: NSRect(x: 15, y: 55, width: codingContentView.frame.width - 30, height: codingContentView.frame.height - 175))
        analysisScrollView.autoresizingMask = [.width, .height]
        analysisScrollView.hasVerticalScroller = true
        analysisScrollView.borderType = .noBorder
        analysisScrollView.drawsBackground = false
        analysisScrollView.backgroundColor = .clear

        analysisTextView = NSTextView(frame: analysisScrollView.bounds)
        analysisTextView.autoresizingMask = [.width, .height]
        analysisTextView.drawsBackground = false
        analysisTextView.backgroundColor = .clear
        analysisTextView.textColor = NSColor(white: 1.0, alpha: 1.0)
        analysisTextView.insertionPointColor = NSColor(white: 1.0, alpha: 1.0)
        analysisTextView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        analysisTextView.isEditable = false
        analysisTextView.textContainerInset = NSSize(width: 15, height: 15)
        analysisTextView.string = "💻 AI Analysis will appear here\n\nCapture screenshots (⌘S) and press Analyze (⌘Enter)"

        analysisScrollView.documentView = analysisTextView
        codingContentView.addSubview(analysisScrollView)

        // Permissions panel (shown when permissions are missing)
        permissionsPanelController = PermissionsPanelController(delegate: self)
        permissionsPanelController.setup(in: codingContentView)

        // Action buttons at bottom - equal sizes and spacing
        let buttonY: CGFloat = 15
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 30
        let buttonSpacing: CGFloat = 10
        let startX: CGFloat = 15

        // Analyze button with SF Symbol
        analyzeButton = HoverButton(frame: NSRect(x: startX, y: buttonY, width: buttonWidth, height: buttonHeight))
        analyzeButton.title = " Analyze ⌘↩"
        analyzeButton.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Analyze")
        analyzeButton.imagePosition = .imageLeading
        analyzeButton.imageHugsTitle = true
        analyzeButton.bezelStyle = .rounded
        analyzeButton.isBordered = false
        analyzeButton.font = .systemFont(ofSize: 13, weight: .bold)
        analyzeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        analyzeButton.target = self
        analyzeButton.action = #selector(analyzeScreenshots)
        analyzeButton.wantsLayer = true
        analyzeButton.layer?.cornerRadius = 8
        analyzeButton.layer?.borderWidth = 1.5
        analyzeButton.contentTintColor = .appleGreen
        analyzeButton.configureHoverColors(accent: .appleGreen)
        codingContentView.addSubview(analyzeButton)

        // Clear button with SF Symbol
        clearButton = HoverButton(frame: NSRect(x: startX + buttonWidth + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight))
        clearButton.title = " Clear All ⌘G"
        clearButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear All")
        clearButton.imagePosition = .imageLeading
        clearButton.imageHugsTitle = true
        clearButton.bezelStyle = .rounded
        clearButton.isBordered = false
        clearButton.font = .systemFont(ofSize: 13, weight: .bold)
        clearButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        clearButton.target = self
        clearButton.action = #selector(clearAllScreenshots)
        clearButton.keyEquivalent = "g"
        clearButton.keyEquivalentModifierMask = [.command]
        clearButton.wantsLayer = true
        clearButton.layer?.cornerRadius = 8
        clearButton.layer?.borderWidth = 1.5
        clearButton.contentTintColor = .appleRed
        clearButton.configureHoverColors(accent: .appleRed)
        codingContentView.addSubview(clearButton)

        // === VOICE TAB CONTENT ===
        // Fixed bottom toolbar - always visible, added to contentView directly
        voiceControlBar = NSView(frame: NSRect(x: 20, y: 8, width: contentView.frame.width - 40, height: 40))
        voiceControlBar.autoresizingMask = [.width]
        voiceControlBar.wantsLayer = true
        contentView.addSubview(voiceControlBar)

        // Voice content view - positioned above the fixed toolbar
        voiceContentView = NSView(frame: NSRect(x: 20, y: 56, width: contentView.frame.width - 40, height: contentView.frame.height - 76))
        voiceContentView.autoresizingMask = [.width, .height]
        voiceContentView.wantsLayer = true
        voiceContentView.layer?.cornerRadius = 16
        voiceContentView.layer?.masksToBounds = true
        voiceContentView.isHidden = false  // Start with Timeline tab visible
        contentView.addSubview(voiceContentView)

        let iconBtnSize: CGFloat = 32
        let iconSize: CGFloat = 16
        let btnSpacing: CGFloat = 8
        let dropdownWidth: CGFloat = 75
        let dropdownHeight: CGFloat = 26

        // ========== LEFT SIDE: Dropdowns ==========
        let leftPadding: CGFloat = 10
        let dropdownSpacing: CGFloat = 4

        // Role dropdown (compact)
        let roleWidth: CGFloat = 85
        roleDropdown = NSPopUpButton(frame: NSRect(x: leftPadding, y: (40 - dropdownHeight) / 2, width: roleWidth, height: dropdownHeight), pullsDown: false)
        roleDropdown.removeAllItems()
        for role in InterviewRole.allCases {
            roleDropdown.addItem(withTitle: role.displayName)
        }
        if let index = InterviewRole.allCases.firstIndex(of: AppSettings.shared.role) {
            roleDropdown.selectItem(at: index)
        }
        roleDropdown.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        roleDropdown.target = self
        roleDropdown.action = #selector(roleChanged(_:))
        roleDropdown.wantsLayer = true
        roleDropdown.layer?.cornerRadius = 6
        roleDropdown.isBordered = false
        roleDropdown.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        (roleDropdown.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        voiceControlBar.addSubview(roleDropdown)

        // Programming Language dropdown (compact)
        let progLangX = leftPadding + roleWidth + dropdownSpacing
        let progLangWidth: CGFloat = 70
        programmingLanguageDropdown = NSPopUpButton(frame: NSRect(x: progLangX, y: (40 - dropdownHeight) / 2, width: progLangWidth, height: dropdownHeight), pullsDown: false)
        programmingLanguageDropdown.removeAllItems()
        for lang in ProgrammingLanguage.allCases {
            programmingLanguageDropdown.addItem(withTitle: lang.displayName)
        }
        if let index = ProgrammingLanguage.allCases.firstIndex(of: AppSettings.shared.programmingLanguage) {
            programmingLanguageDropdown.selectItem(at: index)
        }
        programmingLanguageDropdown.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        programmingLanguageDropdown.target = self
        programmingLanguageDropdown.action = #selector(programmingLanguageChanged(_:))
        programmingLanguageDropdown.wantsLayer = true
        programmingLanguageDropdown.layer?.cornerRadius = 6
        programmingLanguageDropdown.isBordered = false
        programmingLanguageDropdown.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        (programmingLanguageDropdown.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        voiceControlBar.addSubview(programmingLanguageDropdown)

        // Speaking Language dropdown (compact)
        let speakingLangX = progLangX + progLangWidth + dropdownSpacing
        let speakingLangWidth: CGFloat = 65
        speakingLanguageDropdown = NSPopUpButton(frame: NSRect(x: speakingLangX, y: (40 - dropdownHeight) / 2, width: speakingLangWidth, height: dropdownHeight), pullsDown: false)
        speakingLanguageDropdown.removeAllItems()
        for lang in SpeakingLanguage.allCases {
            speakingLanguageDropdown.addItem(withTitle: lang.displayName)
        }
        if let index = SpeakingLanguage.allCases.firstIndex(of: AppSettings.shared.speakingLanguage) {
            speakingLanguageDropdown.selectItem(at: index)
        }
        speakingLanguageDropdown.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        speakingLanguageDropdown.target = self
        speakingLanguageDropdown.action = #selector(speakingLanguageChanged(_:))
        speakingLanguageDropdown.wantsLayer = true
        speakingLanguageDropdown.layer?.cornerRadius = 6
        speakingLanguageDropdown.isBordered = false
        speakingLanguageDropdown.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        (speakingLanguageDropdown.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        voiceControlBar.addSubview(speakingLanguageDropdown)

        // ========== CENTER: Tabs + Controls ==========
        let centerGroupWidth = iconBtnSize * 4 + btnSpacing * 3
        let centerX = (voiceControlBar.frame.width - centerGroupWidth) / 2

        // Context Tab
        contextTabContainer = NSView(frame: NSRect(x: centerX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        contextTabContainer.wantsLayer = true
        contextTabContainer.layer?.cornerRadius = iconBtnSize / 2
        contextTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        voiceControlBar.addSubview(contextTabContainer)

        contextTabIcon = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        contextTabIcon.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Context")
        contextTabIcon.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        contextTabIcon.imageScaling = .scaleProportionallyUpOrDown
        contextTabContainer.addSubview(contextTabIcon)

        let contextBtn = HoverButton(frame: NSRect(x: centerX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        contextBtn.title = ""
        contextBtn.isBordered = false
        contextBtn.target = self
        contextBtn.action = #selector(switchToNotesTab)
        contextBtn.wantsLayer = true
        contextBtn.layer?.cornerRadius = iconBtnSize / 2
        voiceControlBar.addSubview(contextBtn)

        // Timeline Tab
        let timelineX = centerX + iconBtnSize + btnSpacing
        timelineTabContainer = NSView(frame: NSRect(x: timelineX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        timelineTabContainer.wantsLayer = true
        timelineTabContainer.layer?.cornerRadius = iconBtnSize / 2
        timelineTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        voiceControlBar.addSubview(timelineTabContainer)

        timelineTabIcon = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        timelineTabIcon.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Timeline")
        timelineTabIcon.contentTintColor = NSColor.white
        timelineTabIcon.imageScaling = .scaleProportionallyUpOrDown
        timelineTabContainer.addSubview(timelineTabIcon)

        let timelineBtn = HoverButton(frame: NSRect(x: timelineX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        timelineBtn.title = ""
        timelineBtn.isBordered = false
        timelineBtn.target = self
        timelineBtn.action = #selector(switchToVoiceTab)
        timelineBtn.wantsLayer = true
        timelineBtn.layer?.cornerRadius = iconBtnSize / 2
        voiceControlBar.addSubview(timelineBtn)

        // Play/Stop Button
        let playX = timelineX + iconBtnSize + btnSpacing
        nestButtonContainer = NSView(frame: NSRect(x: playX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        nestButtonContainer.wantsLayer = true
        voiceControlBar.addSubview(nestButtonContainer)

        nestButtonInner = CALayer()
        nestButtonInner.frame = CGRect(x: 0, y: 0, width: iconBtnSize, height: iconBtnSize)
        nestButtonInner.cornerRadius = iconBtnSize / 2
        nestButtonInner.backgroundColor = NSColor.appleGreen.withAlphaComponent(0.15).cgColor
        nestButtonContainer.layer?.addSublayer(nestButtonInner)

        nestIconView = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        nestIconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Start")
        nestIconView.contentTintColor = NSColor.appleGreen
        nestIconView.imageScaling = .scaleProportionallyUpOrDown
        nestButtonContainer.addSubview(nestIconView)

        voiceToggleButton = HoverButton(frame: NSRect(x: playX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        voiceToggleButton.title = ""
        voiceToggleButton.isBordered = false
        voiceToggleButton.target = self
        voiceToggleButton.action = #selector(toggleInterview)
        voiceToggleButton.wantsLayer = true
        voiceToggleButton.layer?.cornerRadius = iconBtnSize / 2
        voiceControlBar.addSubview(voiceToggleButton)

        // Status Icon
        let statusX = playX + iconBtnSize + btnSpacing
        statusIconContainer = NSView(frame: NSRect(x: statusX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        statusIconContainer.wantsLayer = true
        statusIconContainer.layer?.cornerRadius = iconBtnSize / 2
        statusIconContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        voiceControlBar.addSubview(statusIconContainer)

        statusIconView = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        statusIconView.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "Idle")
        statusIconView.contentTintColor = NSColor.white.withAlphaComponent(0.4)
        statusIconView.imageScaling = .scaleProportionallyUpOrDown
        statusIconContainer.addSubview(statusIconView)

        // ========== RIGHT SIDE: API indicators + Settings + Export ==========
        let rightPadding: CGFloat = 15

        // Export button (rightmost)
        let exportX = voiceControlBar.frame.width - rightPadding - iconBtnSize
        let exportContainer = NSView(frame: NSRect(x: exportX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        exportContainer.autoresizingMask = [.minXMargin]
        exportContainer.wantsLayer = true
        exportContainer.layer?.cornerRadius = iconBtnSize / 2
        exportContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        voiceControlBar.addSubview(exportContainer)

        let exportIcon = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        exportIcon.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export")
        exportIcon.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        exportIcon.imageScaling = .scaleProportionallyUpOrDown
        exportContainer.addSubview(exportIcon)

        let exportButton = HoverButton(frame: NSRect(x: exportX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        exportButton.autoresizingMask = [.minXMargin]
        exportButton.title = ""
        exportButton.isBordered = false
        exportButton.target = self
        exportButton.action = #selector(exportInterview)
        exportButton.wantsLayer = true
        exportButton.layer?.cornerRadius = iconBtnSize / 2
        voiceControlBar.addSubview(exportButton)

        // Settings button (left of export)
        let settingsX = exportX - iconBtnSize - 8
        let settingsContainer = NSView(frame: NSRect(x: settingsX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        settingsContainer.autoresizingMask = [.minXMargin]
        settingsContainer.wantsLayer = true
        settingsContainer.layer?.cornerRadius = iconBtnSize / 2
        settingsContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        voiceControlBar.addSubview(settingsContainer)

        let settingsIcon = NSImageView(frame: NSRect(x: (iconBtnSize - iconSize) / 2, y: (iconBtnSize - iconSize) / 2, width: iconSize, height: iconSize))
        settingsIcon.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsIcon.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        settingsIcon.imageScaling = .scaleProportionallyUpOrDown
        settingsContainer.addSubview(settingsIcon)

        let settingsButton = HoverButton(frame: NSRect(x: settingsX, y: (40 - iconBtnSize) / 2, width: iconBtnSize, height: iconBtnSize))
        settingsButton.autoresizingMask = [.minXMargin]
        settingsButton.title = ""
        settingsButton.isBordered = false
        settingsButton.target = self
        settingsButton.action = #selector(showSettings)
        settingsButton.wantsLayer = true
        settingsButton.layer?.cornerRadius = iconBtnSize / 2
        voiceControlBar.addSubview(settingsButton)

        // API Key indicators with icons (sparkles for Anthropic, bolt for Groq)
        let hasAnthropic = ApiKeyManager.shared.hasKey(.anthropic)
        let hasGroq = ApiKeyManager.shared.hasKey(.groq)
        let apiIconSize: CGFloat = 14
        let apiStatusDotSize: CGFloat = 6
        let apiGroupSpacing: CGFloat = 22  // Space for icon + dot

        // Groq indicator (left of settings) - bolt icon
        let groqX = settingsX - apiGroupSpacing - 16
        let groqIcon = NSImageView(frame: NSRect(x: groqX, y: (40 - apiIconSize) / 2, width: apiIconSize, height: apiIconSize))
        groqIcon.autoresizingMask = [.minXMargin]
        groqIcon.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Groq")
        groqIcon.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        groqIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        groqIcon.toolTip = hasGroq ? "Groq API: Connected" : "Groq API: Not configured"
        voiceControlBar.addSubview(groqIcon)

        groqKeyDot = NSView(frame: NSRect(x: groqX + apiIconSize + 2, y: (40 - apiStatusDotSize) / 2 + 4, width: apiStatusDotSize, height: apiStatusDotSize))
        groqKeyDot.autoresizingMask = [.minXMargin]
        groqKeyDot.wantsLayer = true
        groqKeyDot.layer?.cornerRadius = apiStatusDotSize / 2
        groqKeyDot.layer?.backgroundColor = (hasGroq ? NSColor.appleGreen : NSColor.systemOrange).cgColor
        voiceControlBar.addSubview(groqKeyDot)

        // Anthropic indicator (left of Groq) - sparkles icon
        let anthropicX = groqX - apiGroupSpacing - 10
        let claudeIcon = NSImageView(frame: NSRect(x: anthropicX, y: (40 - apiIconSize) / 2, width: apiIconSize, height: apiIconSize))
        claudeIcon.autoresizingMask = [.minXMargin]
        claudeIcon.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Claude")
        claudeIcon.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        claudeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        claudeIcon.toolTip = hasAnthropic ? "Anthropic API: Connected" : "Anthropic API: Not configured"
        voiceControlBar.addSubview(claudeIcon)

        anthropicKeyDot = NSView(frame: NSRect(x: anthropicX + apiIconSize + 2, y: (40 - apiStatusDotSize) / 2 + 4, width: apiStatusDotSize, height: apiStatusDotSize))
        anthropicKeyDot.autoresizingMask = [.minXMargin]
        anthropicKeyDot.wantsLayer = true
        anthropicKeyDot.layer?.cornerRadius = apiStatusDotSize / 2
        anthropicKeyDot.layer?.backgroundColor = (hasAnthropic ? NSColor.appleGreen : NSColor.systemOrange).cgColor
        voiceControlBar.addSubview(anthropicKeyDot)

        // Hidden compatibility elements
        systemIndicatorLabel = NSTextField(labelWithString: "")
        systemIndicatorLabel.isHidden = true
        voiceControlBar.addSubview(systemIndicatorLabel)

        voiceStatusLabel = NSTextField(labelWithString: "")
        voiceStatusLabel.isHidden = true
        voiceControlBar.addSubview(voiceStatusLabel)

        systemWaveformBars = []

        // Typing dots (hidden by default)
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 6
        let totalWidth = dotSize * 3 + dotSpacing * 2
        let dotsX = (voiceControlBar.frame.width - totalWidth) / 2
        typingDotsView = NSView(frame: NSRect(x: dotsX, y: (40 - dotSize) / 2, width: totalWidth, height: dotSize))
        typingDotsView.autoresizingMask = [.minXMargin, .maxXMargin]
        typingDotsView.wantsLayer = true
        typingDotsView.isHidden = true
        voiceControlBar.addSubview(typingDotsView)

        typingDots = []
        for i in 0..<3 {
            let dot = CALayer()
            dot.frame = CGRect(x: CGFloat(i) * (dotSize + dotSpacing), y: 0, width: dotSize, height: dotSize)
            dot.cornerRadius = dotSize / 2
            dot.backgroundColor = NSColor.appleGreen.cgColor
            typingDotsView.layer?.addSublayer(dot)
            typingDots.append(dot)
        }

        // Pinned solution container (hidden by default, shows at top-right half of screen)
        // NOTE: Added AFTER timeline scroll view so it's on top in z-order
        let halfWidth = voiceContentView.frame.width / 2
        pinnedSolutionContainer = ScrollCaptureView(frame: NSRect(x: halfWidth, y: voiceContentView.frame.height - 65, width: halfWidth - 15, height: 0))
        pinnedSolutionContainer.autoresizingMask = [.minXMargin, .minYMargin]  // Stay anchored to right
        pinnedSolutionContainer.wantsLayer = true
        pinnedSolutionContainer.layer?.cornerRadius = 10
        pinnedSolutionContainer.layer?.masksToBounds = true
        pinnedSolutionContainer.layer?.borderWidth = 1
        pinnedSolutionContainer.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.5).cgColor
        pinnedSolutionContainer.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor
        pinnedSolutionContainer.isHidden = true
        // Don't add to superview yet - will add after timeline so it's on top

        // Pinned solution header
        let pinnedHeader = NSTextField(labelWithString: "CODING TASK")
        pinnedHeader.frame = NSRect(x: 10, y: 0, width: 150, height: 20)
        pinnedHeader.font = .systemFont(ofSize: 11, weight: .bold)
        pinnedHeader.textColor = NSColor.applePurple
        pinnedHeader.tag = 100  // Tag to find and reposition later
        pinnedSolutionContainer.addSubview(pinnedHeader)

        // Pinned solution scroll view with text view (using standard scrollable setup)
        pinnedSolutionScrollView = NSTextView.scrollableTextView()
        pinnedSolutionScrollView.frame = NSRect(x: 5, y: 5, width: pinnedSolutionContainer.frame.width - 10, height: 0)
        pinnedSolutionScrollView.autoresizingMask = [.width, .height]
        pinnedSolutionScrollView.hasVerticalScroller = true
        pinnedSolutionScrollView.hasHorizontalScroller = false
        pinnedSolutionScrollView.borderType = .noBorder
        pinnedSolutionScrollView.drawsBackground = false
        pinnedSolutionScrollView.backgroundColor = .clear
        pinnedSolutionContainer.addSubview(pinnedSolutionScrollView)
        pinnedSolutionContainer.scrollView = pinnedSolutionScrollView  // Link for scroll capture

        // Get the text view from scrollable container
        pinnedSolutionTextView = pinnedSolutionScrollView.documentView as! NSTextView
        pinnedSolutionTextView.isEditable = false
        pinnedSolutionTextView.isSelectable = true
        pinnedSolutionTextView.drawsBackground = false
        pinnedSolutionTextView.backgroundColor = .clear
        pinnedSolutionTextView.textContainerInset = NSSize(width: 5, height: 5)
        pinnedSolutionTextView.font = .systemFont(ofSize: 12)
        pinnedSolutionTextView.textColor = .white

        // Configure text view for proper scrolling
        pinnedSolutionTextView.isVerticallyResizable = true
        pinnedSolutionTextView.isHorizontallyResizable = false
        pinnedSolutionTextView.autoresizingMask = [.width]
        pinnedSolutionTextView.minSize = NSSize(width: 0, height: 0)
        pinnedSolutionTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        pinnedSolutionTextView.textContainer?.widthTracksTextView = true
        pinnedSolutionTextView.textContainer?.heightTracksTextView = false
        pinnedSolutionTextView.textContainer?.containerSize = NSSize(width: pinnedSolutionScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        // Ensure scroll view responds to scroll events
        pinnedSolutionScrollView.scrollsDynamically = true

        // Timeline scroll view (above control bar at bottom)
        let timelineY: CGFloat = 50  // Above control bar
        let timelineHeight = voiceContentView.frame.height - 60
        voiceTimelineScrollView = NSScrollView(frame: NSRect(x: 15, y: timelineY, width: voiceContentView.frame.width - 30, height: timelineHeight))
        voiceTimelineScrollView.autoresizingMask = [.width, .height]
        voiceTimelineScrollView.hasVerticalScroller = true
        voiceTimelineScrollView.borderType = .noBorder
        voiceTimelineScrollView.drawsBackground = false
        voiceTimelineScrollView.backgroundColor = .clear

        // Timeline container (grows as messages are added) - flipped so Y=0 is at top
        voiceTimelineContainer = FlippedView(frame: NSRect(x: 0, y: 0, width: voiceTimelineScrollView.frame.width, height: 100))
        voiceTimelineContainer.autoresizingMask = [.width]
        voiceTimelineScrollView.documentView = voiceTimelineContainer

        // Initialize message view factory with dependencies
        messageViewFactory = MessageViewFactory(syntaxHighlighter: syntaxHighlighter, containerWidth: voiceTimelineContainer.frame.width)

        // Initialize streaming message handler
        streamingMessageHandler = StreamingMessageHandler(
            timelineContainer: voiceTimelineContainer,
            scrollView: voiceTimelineScrollView,
            messageViewFactory: messageViewFactory,
            delegate: self
        )

        // Initialize voice interview processor
        voiceInterviewProcessor = VoiceInterviewProcessor()
        voiceInterviewProcessor.delegate = self

        // Empty state / Welcome message with friendly styling
        addVoiceMessage(type: .status, content: "Interview Assistant Ready\n\nClick Start Interview to begin listening.", topic: nil)

        voiceContentView.addSubview(voiceTimelineScrollView)

        // Add pinned solution container AFTER timeline so it's on top in z-order
        voiceContentView.addSubview(pinnedSolutionContainer)

        // Search bar (hidden by default) - visionOS style
        searchContainer = NSVisualEffectView(frame: NSRect(x: contentView.frame.width / 2 - 200, y: contentView.frame.height - 160, width: 400, height: 50))
        searchContainer.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        searchContainer.blendingMode = .withinWindow
        searchContainer.material = .menu
        searchContainer.state = .active
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 14
        searchContainer.layer?.borderWidth = 1.5
        searchContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        searchContainer.alphaValue = 0
        searchContainer.isHidden = true
        contentView.addSubview(searchContainer)

        // Search field
        searchField = NSTextField(frame: NSRect(x: 15, y: 15, width: 300, height: 24))
        searchField.placeholderString = "Search notes... (e.g., hashmap)"
        searchField.font = .systemFont(ofSize: 13)
        searchField.isBordered = true
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.target = self
        searchField.action = #selector(performSearch)
        searchContainer.addSubview(searchField)

        // Search results label
        searchResultsLabel = NSTextField(frame: NSRect(x: 320, y: 15, width: 70, height: 24))
        searchResultsLabel.stringValue = ""
        searchResultsLabel.isEditable = false
        searchResultsLabel.isBordered = false
        searchResultsLabel.backgroundColor = .clear
        searchResultsLabel.textColor = .appleGreen
        searchResultsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        searchResultsLabel.alignment = .right
        searchContainer.addSubview(searchResultsLabel)

        // API status indicators and settings button moved to bottom toolbar
        // Initialize the status dot references for compatibility with updateStatusBarIndicators
        anthropicStatusDot = NSView(frame: .zero)
        anthropicStatusDot.wantsLayer = true
        anthropicStatusDot.layer?.cornerRadius = 3
        groqStatusDot = NSView(frame: .zero)
        groqStatusDot.wantsLayer = true
        groqStatusDot.layer?.cornerRadius = 3

        // Update status indicators based on current API key state
        updateStatusBarIndicators()

        renderMarkdown()
    }

    @objc func toggleFloating() {
        isFloating.toggle()

        if isFloating {
            window.level = .floating
            floatingButton.title = "⬆️ Floating"
            updateStatus()
        } else {
            window.level = .normal
            floatingButton.title = "⬇️ Normal"
            updateStatus()
        }
    }

    @objc func toggleAutoHide() {
        autoHideEnabled.toggle()
        autoHideButton.title = autoHideEnabled ? "Auto-Hide: ON" : "Auto-Hide: OFF"
        updateStatus()
    }

    func updateStatus() {
        var status = "🔒 Hidden"
        status += isFloating ? " • ⬆️ Floating" : " • ⬇️ Normal"
        status += autoHideEnabled ? " • 👁️ Auto-Hide" : ""
        statusLabel.stringValue = status
    }

    func createTabButton(frame: NSRect, title: String, isSelected: Bool) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .semibold)  // Semibold for crisp text

        if isSelected {
            // Crisp yellow text (#FFD700)
            button.contentTintColor = .appleGold
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            button.layer?.cornerRadius = 6
        } else {
            // Pure white for inactive tabs (like other text)
            button.contentTintColor = NSColor(white: 1.0, alpha: 0.8)
        }

        return button
    }

    // MARK: - Apple Watch / visionOS Style Buttons
    func createCircularButton(diameter: CGFloat, icon: String, tintColor: NSColor = .white) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        button.title = icon
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = .systemFont(ofSize: diameter * 0.4, weight: .medium)
        button.contentTintColor = tintColor
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        button.layer?.cornerRadius = diameter / 2  // Perfect circle
        button.layer?.borderWidth = 1.5
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor

        // Hover effect
        button.layer?.masksToBounds = true

        return button
    }

    func createCapsuleButton(width: CGFloat, height: CGFloat, title: String, icon: String = "", isSelected: Bool = false) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
        button.title = icon.isEmpty ? title : "\(icon) \(title)"
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = height / 2  // Capsule shape

        if isSelected {
            button.contentTintColor = .appleGold
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            button.layer?.borderWidth = 2.0
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        } else {
            button.contentTintColor = NSColor.white
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            button.layer?.borderWidth = 1.5
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        }

        return button
    }

    func createBorderedCircleButton(diameter: CGFloat, icon: String, isSelected: Bool = false) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        button.title = icon
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = .systemFont(ofSize: diameter * 0.45, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = diameter / 2

        if isSelected {
            button.contentTintColor = .appleGold
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            button.layer?.borderWidth = 2.5
            button.layer?.borderColor = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.8).cgColor
        } else {
            button.contentTintColor = NSColor.white
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            button.layer?.borderWidth = 2.0
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        }

        return button
    }

    @objc func switchToNotesTab() {
        currentTab = .notes
        notesContentView.isHidden = false
        codingContentView.isHidden = true
        voiceContentView.isHidden = true

        // Update bottom toolbar tab icons
        updateToolbarTabIcons(contextSelected: true)

        // Animate pill to Context tab with spring physics
        animateTabPill(to: notesTabButton)
    }

    @objc func switchToCodingTab() {
        currentTab = .coding
        notesContentView.isHidden = true
        codingContentView.isHidden = false
        voiceContentView.isHidden = true
        hideFormattingToolbar()
    }

    @objc func switchToVoiceTab() {
        currentTab = .voice
        notesContentView.isHidden = true
        codingContentView.isHidden = true
        voiceContentView.isHidden = false
        hideFormattingToolbar()

        // Update bottom toolbar tab icons
        updateToolbarTabIcons(contextSelected: false)

        // Animate pill to Timeline tab with spring physics
        animateTabPill(to: voiceTabButton)
    }

    /// Update toolbar tab icons to show selected state
    private func updateToolbarTabIcons(contextSelected: Bool) {
        if contextSelected {
            contextTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
            contextTabIcon.contentTintColor = NSColor.white
            timelineTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            timelineTabIcon.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        } else {
            contextTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            contextTabIcon.contentTintColor = NSColor.white.withAlphaComponent(0.5)
            timelineTabContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
            timelineTabIcon.contentTintColor = NSColor.white
        }
    }
    
    /// Animate the selection pill to the target tab button with fast spring animation
    private func animateTabPill(to targetButton: NSButton) {
        let targetFrame = NSRect(
            x: targetButton.frame.origin.x,
            y: tabSelectionPill.frame.origin.y,
            width: targetButton.frame.width,
            height: tabSelectionPill.frame.height
        )

        // Fast spring animation using NSAnimationContext
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.tabSelectionPill.animator().frame = targetFrame
        }

        // Update button text colors with fade
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            
            if targetButton === notesTabButton {
                notesTabButton.contentTintColor = .white
                voiceTabButton.contentTintColor = NSColor.white.withAlphaComponent(0.5)
            } else {
                voiceTabButton.contentTintColor = .white
                notesTabButton.contentTintColor = NSColor.white.withAlphaComponent(0.5)
            }
        })
    }
    
    // MARK: - Recording Indicator (Dynamic Island Style)
    
    /// Show the recording pill with expand animation
    func showRecordingIndicator() {
        recordingStartTime = Date()
        recordingPill.isHidden = false

        // Start with small pill
        recordingPill.frame = NSRect(x: recordingPill.frame.origin.x, y: recordingPill.frame.origin.y, width: 28, height: 28)
        recordingPill.layer?.cornerRadius = 14

        // Fade in fast
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            recordingPill.animator().alphaValue = 1.0
        })

        // Expand to show time quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.expandRecordingPill()
        }

        // Start pulsing animation on the dot - faster pulse
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.4
        pulse.duration = 0.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        recordingDot.layer?.add(pulse, forKey: "pulse")

        // Start timer to update time
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingTime()
        }
    }

    /// Expand pill to show recording time
    private func expandRecordingPill() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            recordingPill.frame = NSRect(
                x: recordingPill.frame.origin.x,
                y: recordingPill.frame.origin.y,
                width: 80,
                height: 28
            )
            recordingPill.layer?.cornerRadius = 14
            recordingTimeLabel.animator().alphaValue = 1.0
        })
    }
    
    /// Update the recording time display
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        recordingTimeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Hide the recording pill with collapse animation
    func hideRecordingIndicator() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDot.layer?.removeAnimation(forKey: "pulse")

        // Collapse first
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            recordingTimeLabel.animator().alphaValue = 0
            recordingPill.frame = NSRect(
                x: recordingPill.frame.origin.x,
                y: recordingPill.frame.origin.y,
                width: 28,
                height: 28
            )
        }) { [weak self] in
            // Then fade out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                self?.recordingPill.animator().alphaValue = 0
            }) {
                self?.recordingPill.isHidden = true
            }
        }
    }
    
    // MARK: - Status Bar Updates

    /// Update the bottom toolbar API indicators
    func updateStatusBarIndicators() {
        let hasAnthropic = ApiKeyManager.shared.hasKey(.anthropic)
        let hasGroq = ApiKeyManager.shared.hasKey(.groq)

        let greenColor = NSColor.appleGreen.cgColor
        let orangeColor = NSColor.systemOrange.cgColor

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            // Update bottom toolbar key dots
            anthropicKeyDot?.layer?.backgroundColor = hasAnthropic ? greenColor : orangeColor
            groqKeyDot?.layer?.backgroundColor = hasGroq ? greenColor : orangeColor
            // Legacy compatibility
            anthropicStatusDot?.layer?.backgroundColor = hasAnthropic ? greenColor : orangeColor
            groqStatusDot?.layer?.backgroundColor = hasGroq ? greenColor : orangeColor
        })
    }

    // Voice search feature removed - not working correctly

    @objc func toggleSearch() {
        isSearchVisible.toggle()

        if isSearchVisible {
            // Show search
            searchContainer.isHidden = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                searchContainer.animator().alphaValue = 1
            }, completionHandler: {
                self.searchField.becomeFirstResponder()
            })
        } else {
            // Hide search
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                searchContainer.animator().alphaValue = 0
            }, completionHandler: {
                self.searchContainer.isHidden = true
                self.searchField.stringValue = ""
                self.searchResultsLabel.stringValue = ""
                self.clearSearchHighlights()
            })
        }
    }

    @objc func performSearch() {
        let searchTerm = searchField.stringValue.lowercased()
        guard !searchTerm.isEmpty else {
            clearSearchHighlights()
            searchResultsLabel.stringValue = ""
            return
        }

        // Search in notes
        let text = textView.string.lowercased()
        var matchCount = 0
        var searchStartIndex = text.startIndex

        // Count matches
        while let range = text.range(of: searchTerm, range: searchStartIndex..<text.endIndex) {
            matchCount += 1
            searchStartIndex = range.upperBound
        }

        // Update results label
        if matchCount > 0 {
            searchResultsLabel.stringValue = "✓ \(matchCount)"
            searchResultsLabel.textColor = .appleGreen
            highlightSearchResults(searchTerm: searchTerm)
        } else {
            searchResultsLabel.stringValue = "✗ 0"
            searchResultsLabel.textColor = .appleRed
            clearSearchHighlights()
        }
    }

    func highlightSearchResults(searchTerm: String) {
        guard let storage = textView.textStorage else { return }
        let text = storage.string
        let lowercasedText = text.lowercased()

        clearSearchHighlights()

        var searchStartIndex = lowercasedText.startIndex
        var firstMatchRange: NSRange?

        while let range = lowercasedText.range(of: searchTerm, range: searchStartIndex..<lowercasedText.endIndex) {
            let nsRange = NSRange(range, in: text)

            // Store first match for scrolling
            if firstMatchRange == nil {
                firstMatchRange = nsRange
            }

            storage.addAttributes([
                .backgroundColor: NSColor.appleGold.withAlphaComponent(0.5),
                .foregroundColor: NSColor.black
            ], range: nsRange)
            searchStartIndex = range.upperBound
        }

        // Scroll to first match with a delay to ensure rendering is complete
        if let firstMatch = firstMatchRange {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.textView.scrollRangeToVisible(firstMatch)
                self.textView.setSelectedRange(firstMatch)
                self.textView.showFindIndicator(for: firstMatch)
            }
        }
    }

    func clearSearchHighlights() {
        renderMarkdown() // Re-render to clear highlights
    }

    func setupHotkey() {
        // Use CGEvent tap to INTERCEPT and CONSUME hotkeys (prevents VSCode/browser from receiving them)
        setupEventTap()

        // Local hotkey for when app is active (still needed for some actions)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // ESC = Close search
            if event.keyCode == 53 && self.isSearchVisible {
                self.toggleSearch()
                return nil
            }

            // ⌘+Arrow Keys = Move window (only when app is focused)
            if event.modifierFlags.contains(.command) {
                let moveDistance: CGFloat = 20
                var newOrigin = self.window.frame.origin

                switch event.keyCode {
                case 123: // Left arrow
                    newOrigin.x -= moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 124: // Right arrow
                    newOrigin.x += moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 125: // Down arrow
                    newOrigin.y -= moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                case 126: // Up arrow
                    newOrigin.y += moveDistance
                    self.window.setFrameOrigin(newOrigin)
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }

    /// Set up CGEvent tap to intercept and consume global hotkeys
    /// This prevents shortcuts from reaching VSCode, browsers, etc.
    func setupEventTap() {
        // Event mask for key down events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Create event tap - intercepts at session level
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Get self reference from refcon
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let delegate = Unmanaged<InterviewMasterDelegate>.fromOpaque(refcon).takeUnretainedValue()

                // Handle the event
                return delegate.handleGlobalKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            StealthLogger.shared.log("❌ Failed to create event tap - need Accessibility permission")
            // Fall back to NSEvent monitor (won't block shortcuts)
            setupFallbackHotkeys()
            return
        }

        self.eventTap = tap

        // Add to run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = runLoopSource

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        StealthLogger.shared.log("✅ CGEvent tap installed - hotkeys will be intercepted")
    }

    /// Handle global key events - return nil to consume, return event to pass through
    func handleGlobalKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check if it's a key event
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)

        // Only intercept ⌘ combinations
        guard hasCommand else {
            return Unmanaged.passRetained(event)
        }

        // ⌘+I = Toggle ghost mode (transparent + click-through) - does NOT start/stop interview
        if keyCode == 34 && !hasShift { // 'I' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+I (ghost mode) - CONSUMED")
            DispatchQueue.main.async { self.toggleInterviewMode() }
            return nil // Consume - don't pass to other apps
        }

        // ⌘+B = Toggle window visibility
        if keyCode == 11 && !hasShift { // 'B' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+B (toggle window) - CONSUMED")
            DispatchQueue.main.async { self.toggleWindowVisibility() }
            return nil // Consume
        }

        // ⌘+S = Capture screenshot (GLOBAL)
        if keyCode == 1 && !hasShift { // 'S' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+S (screenshot) - CONSUMED")
            DispatchQueue.main.async {
                if self.currentTab != .voice {
                    self.switchToVoiceTab()
                }
                self.captureScreenshotPlaceholder()
            }
            return nil // Consume
        }

        // ⌘+Enter = Analyze screenshots (GLOBAL)
        if keyCode == 36 && !hasShift { // Enter key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+Enter (analyze) - CONSUMED")
            DispatchQueue.main.async {
                if self.window.isVisible && self.currentTab != .voice {
                    self.switchToVoiceTab()
                }
                self.analyzeScreenshots()
            }
            return nil // Consume
        }

        // ⌘+G = Clear/Reset (when visible)
        if keyCode == 5 && !hasShift && self.window.isVisible { // 'G' key
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+G (clear) - CONSUMED")
            DispatchQueue.main.async {
                if self.currentTab == .voice {
                    self.clearScreenshotsFromTimeline()
                } else if self.currentTab == .coding {
                    self.resetCodingTab()
                }
            }
            return nil // Consume
        }

        // ⌘+1 = Notes tab (when visible)
        if keyCode == 18 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+1 (notes) - CONSUMED")
            DispatchQueue.main.async { self.switchToNotesTab() }
            return nil
        }

        // ⌘+2 = Voice tab (when visible)
        if keyCode == 19 && !hasShift && self.window.isVisible {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+2 (voice) - CONSUMED")
            DispatchQueue.main.async { self.switchToVoiceTab() }
            return nil
        }

        // ⌘+F = Search (when visible in notes)
        if keyCode == 3 && !hasShift && self.window.isVisible && self.currentTab == .notes {
            StealthLogger.shared.log("⌨️ HOTKEY: ⌘+F (search) - CONSUMED")
            DispatchQueue.main.async { self.toggleSearch() }
            return nil
        }

        // Pass through all other shortcuts
        return Unmanaged.passRetained(event)
    }

    /// Fallback to NSEvent monitor if CGEvent tap fails (no accessibility permission)
    func setupFallbackHotkeys() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            guard event.modifierFlags.contains(.command) else { return }

            switch event.keyCode {
            case 34: // I - ghost mode only (no interview start/stop)
                self.toggleInterviewMode()
            case 11: // B
                self.toggleWindowVisibility()
            case 1: // S
                if self.currentTab != .voice { self.switchToVoiceTab() }
                self.captureScreenshotPlaceholder()
            case 36: // Enter
                if self.window.isVisible && self.currentTab != .voice { self.switchToVoiceTab() }
                self.analyzeScreenshots()
            default:
                break
            }
        }
    }

    // MARK: - Interview Mode (Transparent Click-Through Overlay)

    /// Toggle interview mode - makes window transparent and click-through
    /// ⌘+I to toggle
    @objc func toggleInterviewMode() {
        isInterviewModeActive.toggle()

        if isInterviewModeActive {
            // Enter ghost mode - transparent + click-through, but keep all UI visible
            StealthLogger.shared.log("👻 GHOST MODE: ON (transparent + click-through)")

            // Make window transparent but keep text readable
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window.animator().alphaValue = 0.75
            })

            // Make background more transparent
            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.alphaValue = 0.4
                effectView.material = .hudWindow
            }

            // Enable click-through - you can type through the window
            window.ignoresMouseEvents = true
            window.level = .floating

            // Subtle border to show ghost mode is active
            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.layer?.borderWidth = 2
                effectView.layer?.borderColor = NSColor.systemCyan.withAlphaComponent(0.5).cgColor
            }

        } else {
            // Exit ghost mode
            StealthLogger.shared.log("👻 GHOST MODE: OFF (normal)")

            // Restore normal opacity
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window.animator().alphaValue = 1.0
            })

            // Restore background opacity and material
            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.alphaValue = 0.8
                effectView.material = .menu
            }

            // Disable click-through - can interact with window again
            window.ignoresMouseEvents = false

            // Remove border
            if let effectView = window.contentView?.subviews.first as? NSVisualEffectView {
                effectView.layer?.borderWidth = 0
            }
        }
    }

    @objc func toggleWindowVisibility() {
        if window.isVisible {
            // Fade out animation
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.window.animator().alphaValue = 0
            }, completionHandler: {
                self.window.orderOut(nil)
                self.window.alphaValue = 1

                // Hide from dock when window is hidden
                NSApp.setActivationPolicy(.accessory)

                // Reset interview mode when hiding
                if self.isInterviewModeActive {
                    self.isInterviewModeActive = false
                    self.window.ignoresMouseEvents = false
                }
            })
        } else {
            // Keep as accessory (no dock icon) for stealth mode
            // Browser keeps focus - undetectable by proctoring

            window.alphaValue = 0
            window.orderFront(nil)  // Show WITHOUT stealing focus

            // Hide alert when main window becomes visible
            hideScreenshotAlert()

            // Fade in animation
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.window.animator().alphaValue = 1
            })
        }
    }

    // MARK: - AR Annotation Overlay

    /// Toggle AR annotation overlay (⌘⇧O)
    @objc func toggleAROverlay() {
        debugLog("🎯 toggleAROverlay called")
        if arOverlay?.isShowing == true {
            debugLog("🎯 Dismissing AR overlay")
            arOverlay?.dismiss()
        } else {
            debugLog("🎯 Showing AR overlay")
            showAROverlay()
        }
    }

    /// Show AR overlay with annotations from current pinned solution
    func showAROverlay() {
        debugLog("🎯 showAROverlay called")

        // For real use: parse annotations from AI solution
        // For testing: overlay will auto-detect visible lines and create sample annotations
        if arOverlay == nil {
            arOverlay = ARAnnotationOverlay()
        }

        // Show with auto-detected test annotations (Vision finds visible lines)
        arOverlay?.showWithAutoTest()
        debugLog("🎯 AR overlay show() returned")
    }

    /// Parse line-based comments from code solution
    /// Extracts: line number -> comment text
    func parseAnnotationsFromSolution(_ solution: String) -> [(line: Int, comment: String)] {
        var annotations: [(line: Int, comment: String)] = []

        // Extract ALL code lines from code blocks and show them as suggestions
        let codeBlockPattern = "```[a-z]*\\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let matches = regex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))

            var lineCounter = 1
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: solution) {
                    let codeBlock = String(solution[codeRange])
                    let lines = codeBlock.components(separatedBy: "\n")

                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        // Skip empty lines and pure file headers
                        if trimmed.isEmpty { continue }
                        if trimmed.hasPrefix("//") && !trimmed.contains(" ") { continue }

                        // Add code line as annotation
                        let displayText = trimmed.count > 60 ? String(trimmed.prefix(57)) + "..." : trimmed
                        annotations.append((line: lineCounter, comment: displayText))
                        lineCounter += 1

                        // Limit to first 20 lines to avoid clutter
                        if lineCounter > 20 { break }
                    }
                }
                if lineCounter > 20 { break }
            }
        }

        debugLog("📝 Parsed \(annotations.count) code lines as annotations")
        return annotations
    }

    /// Parse code review issues from AI response
    /// New format: ➤ LINE: `exact line` \n FIX: description \n ```code```
    func parseCodeSuggestions(_ solution: String) -> [(searchPattern: String, replacementCode: [String])] {
        var suggestions: [(searchPattern: String, replacementCode: [String])] = []

        debugLog("🔍 Parsing solution (\(solution.count) chars): '\(solution.prefix(200))...'")

        // Strategy 1A: Split-based parsing for L{number}: format
        // Split by issue markers (➤ L or start of line L) and parse each block
        let issuePattern = "(?:^|\\n)(?:➤\\s*)?L(\\d+):\\s*`?([^`\\n]+)`?"
        if let issueRegex = try? NSRegularExpression(pattern: issuePattern, options: []) {
            let issueMatches = issueRegex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))
            debugLog("  Found \(issueMatches.count) L[num] issue markers")

            for (i, match) in issueMatches.enumerated() {
                guard let lineNumRange = Range(match.range(at: 1), in: solution),
                      let lineTextRange = Range(match.range(at: 2), in: solution) else { continue }

                let lineNum = Int(String(solution[lineNumRange])) ?? 0
                let lineText = String(solution[lineTextRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Find the content between this match and the next (or end)
                let startIdx = match.range.upperBound
                guard startIdx < solution.count else { continue }

                let endIdx: Int
                if i + 1 < issueMatches.count {
                    endIdx = issueMatches[i + 1].range.lowerBound
                } else {
                    // Find delimiter or end
                    let delimiters = ["───", "✅", "📋", "CHECK:", "FORBIDDEN:"]
                    var minDelim = solution.count
                    let searchStart = solution.index(solution.startIndex, offsetBy: min(startIdx, solution.count))
                    for delim in delimiters {
                        if let range = solution.range(of: delim, range: searchStart..<solution.endIndex) {
                            let pos = solution.distance(from: solution.startIndex, to: range.lowerBound)
                            minDelim = min(minDelim, pos)
                        }
                    }
                    endIdx = minDelim
                }

                guard startIdx < endIdx && endIdx <= solution.count else { continue }
                let blockStart = solution.index(solution.startIndex, offsetBy: startIdx)
                let blockEnd = solution.index(solution.startIndex, offsetBy: endIdx)
                let blockContent = String(solution[blockStart..<blockEnd])

                // Extract FIX description and code from block
                let lines = blockContent.components(separatedBy: "\n")
                var fixText = ""
                var codeLines: [String] = []
                var foundFix = false

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("FIX:") {
                        fixText = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                        foundFix = true
                    } else if foundFix && !trimmed.isEmpty && !trimmed.hasPrefix("```") {
                        // Skip markdown code block markers
                        if !trimmed.hasPrefix("```") {
                            codeLines.append(trimmed)
                        }
                    }
                }

                guard !lineText.isEmpty && !fixText.isEmpty else { continue }

                let searchKey = lineNum > 0 ? "L\(lineNum):\(lineText)" : lineText
                debugLog("  Parsed: L\(lineNum)='\(lineText.prefix(30))' FIX='\(fixText.prefix(20))' code=\(codeLines.count) lines")

                var result = [fixText]
                result.append(contentsOf: Array(codeLines.prefix(3)))

                suggestions.append((searchPattern: searchKey, replacementCode: result))
            }

            if !suggestions.isEmpty {
                debugLog("📝 Parsed \(suggestions.count) issues from L[num] format")
                return suggestions
            }
        }

        // Strategy 1B: Old LINE: format (text-based matching)
        let patternOldLine = "➤\\s*LINE:\\s*`?([^`\\n]+)`?\\s*\\n\\s*FIX:\\s*([^\\n]+)(?:\\s*\\n\\s*```[a-z]*\\n([\\s\\S]*?)```)?"
        if let regex = try? NSRegularExpression(pattern: patternOldLine, options: []) {
            let matches = regex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))
            debugLog("  Pattern OldLine: \(matches.count) matches")

            for match in matches {
                guard let lineRange = Range(match.range(at: 1), in: solution),
                      let fixRange = Range(match.range(at: 2), in: solution) else { continue }

                let lineText = String(solution[lineRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let fixText = String(solution[fixRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                var codeBlock = ""
                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound,
                   let codeRange = Range(match.range(at: 3), in: solution) {
                    codeBlock = String(solution[codeRange])
                }

                let codeLines = codeBlock.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                guard !lineText.isEmpty else { continue }

                debugLog("  Found: LINE='\(lineText.prefix(40))' FIX='\(fixText.prefix(30))' code=\(codeLines.count)")

                var result = [fixText]
                result.append(contentsOf: Array(codeLines.prefix(3)))

                suggestions.append((searchPattern: lineText, replacementCode: result))
            }

            if !suggestions.isEmpty {
                debugLog("📝 Parsed \(suggestions.count) issues from LINE format")
                return suggestions
            }
        }

        // Strategy 2: Old format fallback - → `method()` ... ✅ Fix:
        let oldFormatPattern = "→\\s*`([^`]+)`[\\s\\S]*?✅\\s*Fix:\\s*([^\\n]+)"
        if let regex = try? NSRegularExpression(pattern: oldFormatPattern, options: []) {
            let matches = regex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))

            // Also extract code blocks for fallback
            var codeBlocks: [[String]] = []
            let codeBlockPattern = "```[a-z]*\\n([\\s\\S]*?)```"
            if let cbRegex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
                let cbMatches = cbRegex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))
                for cbMatch in cbMatches {
                    if let codeRange = Range(cbMatch.range(at: 1), in: solution) {
                        let lines = String(solution[codeRange]).components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }
                            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        if !lines.isEmpty { codeBlocks.append(lines) }
                    }
                }
            }

            for match in matches {
                guard let methodRange = Range(match.range(at: 1), in: solution),
                      let fixRange = Range(match.range(at: 2), in: solution) else { continue }

                let methodName = String(solution[methodRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let fixText = String(solution[fixRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                guard !methodName.isEmpty && !fixText.isEmpty else { continue }

                let searchTerm = methodName.replacingOccurrences(of: "()", with: "")

                // Try to find matching code block
                var matchingCode: [String] = []
                for block in codeBlocks {
                    if block.joined(separator: " ").lowercased().contains(searchTerm.lowercased()) {
                        matchingCode = Array(block.prefix(3))
                        break
                    }
                }
                if matchingCode.isEmpty && !codeBlocks.isEmpty {
                    matchingCode = Array(codeBlocks[0].prefix(3))
                }

                var result = [fixText]
                result.append(contentsOf: matchingCode)

                suggestions.append((searchPattern: searchTerm, replacementCode: result))
            }
        }

        if !suggestions.isEmpty {
            debugLog("📝 Parsed \(suggestions.count) issues from old format")
            return suggestions
        }

        // Strategy 3: Just code blocks (for coding problems)
        let codeBlockPattern = "```[a-z]*\\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let matches = regex.matches(in: solution, range: NSRange(solution.startIndex..., in: solution))

            for (index, match) in matches.enumerated() {
                guard let codeRange = Range(match.range(at: 1), in: solution) else { continue }
                let lines = String(solution[codeRange]).components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                guard let firstLine = lines.first(where: { $0.count > 5 && !$0.hasPrefix("//") && !$0.hasPrefix("#") }) else { continue }

                var result = ["Solution \(index + 1)"]
                result.append(contentsOf: Array(lines.prefix(4)))

                suggestions.append((searchPattern: firstLine, replacementCode: result))
                if suggestions.count >= 5 { break }
            }
        }

        debugLog("📝 Parsed \(suggestions.count) code suggestions")
        return suggestions
    }

    /// Parse the "HOW TO USE" section from Claude's response
    func parseUsageExample(_ solution: String) -> [String]? {
        // Look for 📋 HOW TO USE: section followed by code block
        let patterns = [
            "📋\\s*HOW TO USE:?\\s*\\n```[a-z]*\\n([\\s\\S]*?)```",
            "HOW TO USE:?\\s*\\n```[a-z]*\\n([\\s\\S]*?)```",
            "Usage:?\\s*\\n```[a-z]*\\n([\\s\\S]*?)```"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: solution, range: NSRange(solution.startIndex..., in: solution)),
               let codeRange = Range(match.range(at: 1), in: solution) {
                let lines = String(solution[codeRange])
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                if !lines.isEmpty {
                    debugLog("📋 Parsed usage example: \(lines.count) lines")
                    return Array(lines.prefix(5))  // Max 5 lines
                }
            }
        }
        return nil
    }

    // MARK: - VoiceInterviewProcessorDelegate

    var userBackground: String {
        return textView.string
    }

    var pinnedSolution: String? {
        return currentPinnedSolution
    }

    func processorShowLoading(_ message: String, color: NSColor) {
        showLoading(message, color: color)
    }

    func processorHideLoading() {
        hideLoading()
    }

    func processorDidReceiveQuestion(_ text: String, topic: String, messageType: InterviewMessage.MessageType, source: AudioSource) {
        debugLog(.delegate, "processorDidReceiveQuestion: '\(text.prefix(50))...' topic=\(topic)")
        addVoiceMessage(type: .question, content: text, topic: topic, audioSource: source)
    }

    func processorDidStartStreaming(messageType: InterviewMessage.MessageType, topic: String, latencyMs: Int?) {
        if let latency = latencyMs {
            debugLog(.delegate, "processorDidStartStreaming: type=\(messageType) topic=\(topic) latency=\(latency)ms")
        } else {
            debugLog(.delegate, "processorDidStartStreaming: type=\(messageType) topic=\(topic)")
        }
        streamingMessageHandler.addStreamingMessage(type: messageType, topic: topic, latencyMs: latencyMs)
    }

    func processorDidReceiveAnswerChunk(_ fullContent: String) {
        // Only log occasionally to avoid spam
        if fullContent.count < 50 || fullContent.count % 200 == 0 {
            debugLog(.stream, "processorDidReceiveAnswerChunk: \(fullContent.count) chars")
        }
        streamingMessageHandler.updateStreamingMessage(fullContent)
    }

    func processorDidFinishAnswer(_ fullAnswer: String) {
        debugLog(.delegate, "processorDidFinishAnswer: \(fullAnswer.count) chars")
        streamingMessageHandler.finalizeStreamingMessage(fullAnswer)
    }

    func processorDidUpdateStatus(_ message: String) {
        voiceStatusLabel.stringValue = message
    }

    func startScreenShareMonitoring() {
        guard autoHideEnabled else { return }

        // Monitor for screen recording (simplified version)
        // In production, you'd use more sophisticated detection
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.autoHideEnabled else { return }

            // Check if screen is being captured
            // This is a simplified check - real implementation would monitor actual screen sharing
            if CGPreflightScreenCaptureAccess() {
                // Hide window when screen sharing detected
                if self.window.isVisible {
                    self.window.orderOut(nil)
                }
            }
        }
    }

    /// Monitor which app has focus - proves browser keeps focus during interactions
    func startFocusMonitoring() {
        var lastFrontApp = ""

        // Check frontmost app every 500ms
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let appName = frontApp.localizedName ?? "Unknown"
                let bundleId = frontApp.bundleIdentifier ?? "?"

                // Only log when frontmost app changes
                if appName != lastFrontApp {
                    lastFrontApp = appName
                    // Note: "frontmost" = visual layer, NOT keyboard focus
                    // Our app can be frontmost without stealing keyboard focus
                    // Browser blur/visibilitychange events depend on KEYBOARD focus, not frontmost
                    StealthLogger.shared.log("🎯 FRONTMOST APP: \(appName) [\(bundleId)] (visual only, not keyboard)")
                }
            }
        }

        // This is the critical one - monitors KEYBOARD focus
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                let isOurs = window is StealthWindow
                if isOurs {
                    StealthLogger.shared.log("🔴 KEYBOARD FOCUS STOLEN: \(window.title) - THIS IS BAD!")
                } else {
                    StealthLogger.shared.log("🔑 KEYBOARD FOCUS: \(window.title) (not our window - OK)")
                }
            }
        }

        StealthLogger.shared.log("👁️ Focus monitoring started")
        StealthLogger.shared.log("   📺 'FRONTMOST APP' = visual layer (OK to be us)")
        StealthLogger.shared.log("   ⌨️ 'KEYBOARD FOCUS' = what triggers browser blur (should NEVER be us)")
    }

    // MARK: - Formatting Toolbar
    func setupFormattingToolbar(in parentView: NSView) {
        // Floating toolbar container - visionOS style
        formattingToolbar = NSVisualEffectView(frame: NSRect(
            x: (parentView.frame.width - 360) / 2,
            y: parentView.frame.height - 60,
            width: 360,
            height: 44
        ))
        formattingToolbar.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        formattingToolbar.blendingMode = .withinWindow
        formattingToolbar.material = .hudWindow
        formattingToolbar.state = .active
        formattingToolbar.alphaValue = 0
        formattingToolbar.isHidden = true
        formattingToolbar.wantsLayer = true
        formattingToolbar.layer?.cornerRadius = 12
        formattingToolbar.layer?.borderWidth = 1.5
        formattingToolbar.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        parentView.addSubview(formattingToolbar)

        let buttonWidth: CGFloat = 40
        let spacing: CGFloat = 4
        var xOffset: CGFloat = 8

        // Heading button
        let headingBtn = createFormattingButton(
            icon: "textformat.size",
            tooltip: "Heading",
            action: #selector(insertHeading)
        )
        headingBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(headingBtn)
        xOffset += buttonWidth + spacing

        // Bold button
        let boldBtn = createFormattingButton(
            icon: "bold",
            tooltip: "Bold",
            action: #selector(insertBold)
        )
        boldBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(boldBtn)
        xOffset += buttonWidth + spacing

        // Italic button
        let italicBtn = createFormattingButton(
            icon: "italic",
            tooltip: "Italic",
            action: #selector(insertItalic)
        )
        italicBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(italicBtn)
        xOffset += buttonWidth + spacing

        // Code button
        let codeBtn = createFormattingButton(
            icon: "chevron.left.forwardslash.chevron.right",
            tooltip: "Code",
            action: #selector(insertCode)
        )
        codeBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(codeBtn)
        xOffset += buttonWidth + spacing

        // Code block button
        let codeBlockBtn = createFormattingButton(
            icon: "curlybraces",
            tooltip: "Code Block",
            action: #selector(insertCodeBlock)
        )
        codeBlockBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(codeBlockBtn)
        xOffset += buttonWidth + spacing

        // List button
        let listBtn = createFormattingButton(
            icon: "list.bullet",
            tooltip: "Bullet List",
            action: #selector(insertList)
        )
        listBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(listBtn)
        xOffset += buttonWidth + spacing

        // Link button
        let linkBtn = createFormattingButton(
            icon: "link",
            tooltip: "Link",
            action: #selector(insertLink)
        )
        linkBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(linkBtn)
        xOffset += buttonWidth + spacing

        // Divider button
        let dividerBtn = createFormattingButton(
            icon: "minus",
            tooltip: "Divider",
            action: #selector(insertDivider)
        )
        dividerBtn.frame.origin = NSPoint(x: xOffset, y: 7)
        formattingToolbar.addSubview(dividerBtn)
    }

    func createFormattingButton(icon: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)
        button.bezelStyle = .rounded
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.target = self
        button.action = action
        button.toolTip = tooltip
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.contentTintColor = .white
        return button
    }

    func showFormattingToolbar() {
        guard let toolbar = formattingToolbar, !isFormattingToolbarVisible else { return }
        isFormattingToolbarVisible = true

        toolbar.isHidden = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            toolbar.animator().alphaValue = 0.95
        })
    }

    func hideFormattingToolbar() {
        guard let toolbar = formattingToolbar, isFormattingToolbarVisible else { return }
        isFormattingToolbarVisible = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            toolbar.animator().alphaValue = 0
        }, completionHandler: {
            toolbar.isHidden = true
        })
    }

    // MARK: - Formatting Actions
    @objc func insertHeading() {
        insertMarkdownWrapper(prefix: "## ", suffix: "", placeholder: "Heading")
    }

    @objc func insertBold() {
        insertMarkdownWrapper(prefix: "**", suffix: "**", placeholder: "bold text")
    }

    @objc func insertItalic() {
        insertMarkdownWrapper(prefix: "*", suffix: "*", placeholder: "italic text")
    }

    @objc func insertCode() {
        insertMarkdownWrapper(prefix: "`", suffix: "`", placeholder: "code")
    }

    @objc func insertCodeBlock() {
        insertMarkdownWrapper(prefix: "```\n", suffix: "\n```", placeholder: "code block")
    }

    @objc func insertList() {
        let range = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: range)

        guard !selectedText.isEmpty else { return }

        // Split by lines and add bullet to each line
        let lines = selectedText.components(separatedBy: .newlines)
        let bulletedText = lines.map { line in
            line.isEmpty ? "" : "- \(line)"
        }.joined(separator: "\n")

        textView.insertText(bulletedText, replacementRange: range)

        DispatchQueue.main.async {
            self.renderMarkdown()
        }
    }

    @objc func insertLink() {
        insertMarkdownWrapper(prefix: "[", suffix: "](url)", placeholder: "link text")
    }

    @objc func insertDivider() {
        let range = textView.selectedRange()
        textView.insertText("\n\n---\n\n", replacementRange: range)
        renderMarkdown()
    }

    func insertMarkdownWrapper(prefix: String, suffix: String, placeholder: String) {
        let range = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: range)

        // Only format if there's selected text
        guard !selectedText.isEmpty else { return }

        let textToInsert = prefix + selectedText + suffix
        textView.insertText(textToInsert, replacementRange: range)

        // Force re-render markdown
        DispatchQueue.main.async {
            self.renderMarkdown()
        }
    }

    // MARK: - Markdown Rendering (Basic)
    func renderMarkdown() {
        guard let storage = textView.textStorage else { return }
        notesMarkdownRenderer.render(in: storage)
    }

    // MARK: - Markdown Rendering for Analysis View
    func renderAnalysisMarkdown() {
        guard let storage = analysisTextView.textStorage else { return }
        analysisMarkdownRenderer.render(in: storage)
    }

    // MARK: - NSTextViewDelegate
    func textDidChange(_ notification: Notification) {
        // Re-render markdown with debounce to prevent conflicts
        guard let currentTextView = notification.object as? NSTextView else { return }
        if currentTextView == textView {
            let currentLength = textView.string.count
            let textGrew = currentLength > lastTextLength

            // Only auto-continue lists when text grew (not when deleting)
            if textGrew {
                handleListAutoContinuation()
            }

            lastTextLength = currentLength

            // Auto-save notes to UserDefaults
            saveNotes()

            renderTimer?.invalidate()
            renderTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.renderMarkdown()
            }
        }
    }

    // MARK: - Persistence
    func saveNotes() {
        UserDefaults.standard.set(textView.string, forKey: notesStorageKey)
    }

    func handleListAutoContinuation() {
        let text = textView.string as NSString
        let cursorLocation = textView.selectedRange().location

        // Check if user just pressed Enter (newline at cursor-1)
        guard cursorLocation > 0,
              cursorLocation <= text.length,
              text.character(at: cursorLocation - 1) == 10 else { return } // 10 = newline

        // Find the start of the previous line
        var lineStart = cursorLocation - 2
        while lineStart > 0 && text.character(at: lineStart) != 10 {
            lineStart -= 1
        }
        if lineStart > 0 { lineStart += 1 }

        // Get the previous line
        let lineLength = cursorLocation - lineStart - 1
        guard lineLength > 0 else { return }
        let previousLine = text.substring(with: NSRange(location: lineStart, length: lineLength))

        // Check if previous line starts with "- " or is just "- "
        if previousLine.hasPrefix("- ") {
            let content = String(previousLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            // If previous line was just "- " (empty bullet), remove it and stop list
            if content.isEmpty {
                // Remove the bullet line and the newline we just added
                textView.undoManager?.beginUndoGrouping()
                let removeRange = NSRange(location: lineStart, length: lineLength + 1)
                textView.shouldChangeText(in: removeRange, replacementString: "")
                textView.replaceCharacters(in: removeRange, with: "")
                textView.didChangeText()
                textView.undoManager?.endUndoGrouping()
            } else {
                // Add new bullet for next item
                textView.insertText("- ", replacementRange: NSRange(location: cursorLocation, length: 0))
            }
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        // Show toolbar when editing notes
        guard let currentTextView = notification.object as? NSTextView else { return }
        if currentTextView == textView && currentTab == .notes {
            showFormattingToolbar()
        }
    }

    @objc func captureScreenshotPlaceholder() {
        // Only allow screenshots during active interview
        guard isInterviewActive else {
            return
        }

        // Check permission first
        if !CGPreflightScreenCaptureAccess() {
            showPermissionAlert()
            return
        }

        Task {
            await captureScreenshot()
        }
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Interview Master needs Screen Recording permission to capture screenshots.\n\n1. Click 'Open Settings' below\n2. Enable 'InterviewMaster' in Screen Recording\n3. Restart the app"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings > Privacy & Security > Screen Recording
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    func captureScreenshot() async {
        let result = await screenCaptureService.captureScreen()

        switch result {
        case .success(let screenshot):
            // Generate thumbnail for timeline (larger)
            let timelineThumbnailSize = NSSize(width: 200, height: 112)
            let timelineThumbnail = screenshot.generateThumbnail(size: timelineThumbnailSize)

            // Add to screenshots array
            screenshots.append(screenshot)

            // Add thumbnail to voice timeline (main UI)
            await MainActor.run {
                addScreenshotToTimeline(thumbnail: timelineThumbnail, screenshotId: screenshot.id)
            }

        case .failure(let error):
            await MainActor.run {
                let message: String
                switch error {
                case .noDisplayFound:
                    message = "No display found"
                case .captureFailed(let underlyingError):
                    message = "Error: \(underlyingError.localizedDescription)"
                }
                showAlert(title: "Screenshot Failed", message: message)
            }
        }
    }


    func addThumbnailToUI(thumbnail: NSImage, id: UUID) {
        let thumbnailHeight: CGFloat = 35
        let thumbnailWidth: CGFloat = 62  // Proportional 16:9 to height
        let spacing: CGFloat = 10
        let xOffset = CGFloat(screenshotThumbnails.count) * (thumbnailWidth + spacing)

        let thumbnailButton = NSButton(frame: NSRect(x: xOffset, y: 0, width: thumbnailWidth, height: thumbnailHeight))
        thumbnailButton.image = thumbnail
        thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
        thumbnailButton.isBordered = false
        thumbnailButton.bezelStyle = .rounded
        thumbnailButton.tag = screenshotThumbnails.count
        thumbnailButton.wantsLayer = true
        thumbnailButton.layer?.cornerRadius = 6
        thumbnailButton.layer?.borderWidth = 1.5
        thumbnailButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        thumbnailButton.layer?.masksToBounds = true

        screenshotThumbnailsContainer.addSubview(thumbnailButton)
        screenshotThumbnails.append(thumbnailButton)

        // Update container width
        screenshotThumbnailsContainer.frame.size.width = CGFloat(screenshotThumbnails.count) * (thumbnailWidth + spacing)
    }

    @objc func resetCodingTab() {
        // Clear all screenshots
        screenshots.removeAll()

        // Remove all thumbnail buttons from UI
        for thumbnail in screenshotThumbnails {
            thumbnail.removeFromSuperview()
        }
        screenshotThumbnails.removeAll()

        // Reset container width
        screenshotThumbnailsContainer.frame.size.width = 0

        // Clear analysis text
        analysisTextView.string = ""
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func analyzeScreenshots() {
        guard !screenshots.isEmpty else {
            showAlert(title: "No Screenshots", message: "Please capture at least one screenshot first (⌘S)")
            return
        }

        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            showAlert(title: "API Key Required", message: "Please configure your Anthropic API key in settings (⚙️ API Key)")
            return
        }

        // Check for data consent (required by App Store Guideline 5.1.2)
        if !UserDefaults.standard.bool(forKey: dataConsentKey) {
            let consentGiven = showDataConsentDialog()
            if !consentGiven {
                return
            }
            UserDefaults.standard.set(true, forKey: dataConsentKey)
        }

        Task {
            await performAnalysis(apiKey: apiKey)
        }
    }

    func showDataConsentDialog() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Data Sharing Consent"
        alert.informativeText = """
        To analyze your screenshots, Interview Master will send them to Anthropic's Claude AI service.

        What is shared:
        • Screenshot images you capture
        • Analysis prompts

        What is NOT shared:
        • Your notes
        • Personal information
        • API keys

        Anthropic processes data according to their privacy policy. Screenshots are not stored permanently.

        Do you consent to share screenshot data with Anthropic for AI analysis?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "I Consent")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Privacy Policy")

        let response = alert.runModal()

        if response == .alertThirdButtonReturn {
            // Show Anthropic privacy policy
            if let url = URL(string: "https://www.anthropic.com/privacy") {
                NSWorkspace.shared.open(url)
            }
            // Show dialog again after viewing privacy policy
            return showDataConsentDialog()
        }

        return response == .alertFirstButtonReturn
    }

    func performAnalysis(apiKey: String) async {
        // Convert screenshots to base64
        var base64Images: [String] = []
        for screenshot in screenshots {
            if let base64 = screenshot.toBase64() {
                base64Images.append(base64)
            }
        }

        // Show loading state in pinned header
        await MainActor.run {
            setPinnedSolution("🔍 Detecting code lines...")
        }

        // Use Tesseract to detect gutter line numbers from the code window
        // This matches what AR overlay uses, ensuring consistent line numbers
        var ocrLines: [(lineNumber: Int, text: String)] = []
        let tesseract = TesseractLineDetector()
        if let windowInfo = tesseract.findTargetWindow() {
            if let result = await tesseract.detectCodeLines(windowID: windowInfo.windowID, windowBounds: windowInfo.bounds) {
                // Extract unique line numbers from detected lines
                let uniqueLines = Dictionary(grouping: result.lines.filter { $0.lineNumber != nil }) { $0.lineNumber! }
                    .mapValues { $0.first! }
                    .sorted { $0.key < $1.key }
                ocrLines = uniqueLines.map { (lineNumber: $0.key, text: $0.value.text) }
                debugLog("📝 Tesseract detected \(ocrLines.count) visible lines for Claude: \(ocrLines.map { $0.lineNumber })")
            }
        }

        await MainActor.run {
            setPinnedSolution("🤔 Analyzing \(screenshots.count) screenshot\(screenshots.count == 1 ? "" : "s")...")
        }

        // Always create fresh client with current API key
        let client = AnthropicClient(apiKey: apiKey)

        // Build prompt with OCR context for better line matching
        let prompt = analysisMode.buildPrompt(ocrLines: ocrLines.isEmpty ? nil : ocrLines)
        let prefill = analysisMode.prefill
        debugLog("📨 Sending prompt with \(ocrLines.count) OCR lines to Claude")

        // Collect full response for pinning
        var fullResponse = ""

        // Stream the response directly to pinned solution
        let result = await client.sendMessageStream(
            images: base64Images,
            prompt: prompt,
            prefill: prefill
        ) { [weak self] chunk in
            fullResponse += chunk
            Task { @MainActor in
                guard let self = self else { return }
                // Update pinned solution with streaming content
                self.updatePinnedSolutionContent(fullResponse)
            }
        }

        if case .failure(let error) = result {
            await MainActor.run {
                showAlert(title: "Analysis Failed", message: error.localizedDescription)
                setPinnedSolution("❌ Analysis failed: \(error.localizedDescription)")
            }
        } else {
            // Final update
            await MainActor.run {
                // Update the coding task in timeline with final content
                updatePinnedSolutionContent(fullResponse)

                // Clear screenshots for next task
                screenshots.removeAll()

                // Archive old gallery so new screenshots create a fresh entry
                if let oldGallery = self.voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
                    oldGallery.identifier = NSUserInterfaceItemIdentifier("screenshotGallery_archived_\(UUID().uuidString)")
                }
            }
        }
    }

    /// Update pinned solution content in timeline during streaming
    func updatePinnedSolutionContent(_ content: String) {
        currentPinnedSolution = content

        // Parse code suggestions and send to AR overlay
        let suggestions = parseCodeSuggestions(content)
        let usageExample = parseUsageExample(content)

        if !suggestions.isEmpty || usageExample != nil {
            // Initialize AR overlay if not already created
            if arOverlay == nil {
                arOverlay = ARAnnotationOverlay()
                debugLog("🎯 AR overlay initialized for code suggestions")
            }
            arOverlay?.setCodeSuggestions(suggestions, usageExample: usageExample)
            debugLog("📝 Sent \(suggestions.count) code suggestions + usage to AR overlay")
        }

        // Find existing coding task view in timeline
        guard let codingTaskView = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "codingTask" }) else {
            // No existing view, create one via setPinnedSolution
            setPinnedSolution(content)
            return
        }

        // Find the text view inside the coding task container
        guard let contentView = codingTaskView.subviews.first(where: { $0 is NSTextView }) as? NSTextView else { return }

        // Update content
        let attributedContent = messageViewFactory.formatMessageContent(content, isQuestion: false)
        contentView.textStorage?.setAttributedString(attributedContent)

        // Get actual height from layout manager
        let cardWidth = voiceTimelineContainer.frame.width - 40
        let textWidth = cardWidth - 24
        contentView.textContainer?.containerSize = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        contentView.layoutManager?.ensureLayout(for: contentView.textContainer!)
        let actualHeight = contentView.layoutManager?.usedRect(for: contentView.textContainer!).height ?? 30
        let newViewHeight = max(actualHeight, 30)

        // Only resize if height changed significantly
        let heightDiff = newViewHeight - codingTaskView.frame.height
        if abs(heightDiff) > 10 {
            // Update coding task view height
            codingTaskView.frame.size.height = newViewHeight

            // Update content view frame - no padding
            contentView.frame = NSRect(x: 12, y: 0, width: textWidth, height: actualHeight)

            // Update accent bar height
            if let accentBar = codingTaskView.subviews.first(where: { $0.frame.width == 3 }) {
                accentBar.frame.size.height = newViewHeight
            }

            // Shift other messages up/down
            for subview in voiceTimelineContainer.subviews {
                if subview !== codingTaskView && subview.frame.origin.y > codingTaskView.frame.origin.y {
                    subview.frame.origin.y += heightDiff
                }
            }

            // Recalculate container height
            var maxY: CGFloat = 0
            for subview in voiceTimelineContainer.subviews {
                maxY = max(maxY, subview.frame.maxY)
            }
            voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
        }

        // Scroll to top to show newest (Y=0 in flipped view)
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    /// Clear timeline messages when a new coding task is pinned
    func clearTimelineForNewTask() {
        // Remove all subviews from timeline
        for subview in voiceTimelineContainer.subviews {
            subview.removeFromSuperview()
        }
        voiceMessages.removeAll()

        // Add status message indicating new task
        addVoiceMessage(type: .status, content: "New coding task loaded\n\nAsk follow-up questions about the solution above.", topic: nil)
    }

    @objc func clearAllScreenshots() {
        screenshots.removeAll()
        screenshotThumbnails.forEach { $0.removeFromSuperview() }
        screenshotThumbnails.removeAll()
        screenshotThumbnailsContainer.frame.size.width = 100
        analysisTextView.string = "💻 AI Analysis will appear here\n\nCapture screenshots (⌘S) and press Analyze (⌘Enter)"
    }

    /// Clear screenshots from voice timeline
    func clearScreenshotsFromTimeline() {
        // Clear screenshots array
        screenshots.removeAll()

        // Remove screenshot containers from timeline
        for subview in voiceTimelineContainer.subviews {
            if let identifier = subview.identifier?.rawValue, identifier.hasPrefix("screenshot_") {
                subview.removeFromSuperview()
            }
        }

        // Remove screenshot messages from array
        voiceMessages.removeAll { $0.type == .screenshot }

        // Hide pinned solution if showing
        clearPinnedSolution()

        // Recalculate timeline height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
    }

    @objc func showSettings() {
        // Show settings window for API keys configuration
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController.create()
        }
        settingsWindowController?.showWindow(self)
        settingsWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    func maskApiKey(_ key: String) -> String {
        guard key.count > 10 else { return "sk-ant-***" }
        let prefix = String(key.prefix(7))
        let suffix = String(key.suffix(3))
        return "\(prefix)***\(suffix)"
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        screenshotMonitorTimer?.invalidate()
    }

    // MARK: - Screenshot Alert System
    func startScreenshotMonitoring() {
        // Monitor for new screenshots
        screenshotMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check if we have new screenshots and app is not focused
            if self.screenshots.count > self.lastScreenshotCount && !self.window.isKeyWindow {
                self.showScreenshotAlert()
            }

            self.lastScreenshotCount = self.screenshots.count
        }
    }

    func showScreenshotAlert() {
        // Don't show if alert already visible
        if let existingAlert = alertWindow, existingAlert.isVisible {
            if let container = alertThumbnailsContainer {
                alertWindowManager.createThumbnails(for: screenshots, in: container)
            }
            return
        }

        // Create alert window with container
        guard let (window, container) = alertWindowManager.createWindow() else { return }
        
        alertWindow = window
        alertThumbnailsContainer = container
        
        // Populate thumbnails
        alertWindowManager.createThumbnails(for: screenshots, in: container)
        
        // Show with animation
        alertWindowManager.show(window)
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            self.alertWindowManager.hide(window)
        }
    }

    func updateAlertThumbnails() {
        guard let container = alertThumbnailsContainer else { return }
        alertWindowManager.createThumbnails(for: screenshots, in: container)
    }

    func hideScreenshotAlert() {
        guard let window = alertWindow else { return }
        alertWindowManager.hide(window)
    }

    // MARK: - Voice Interview Methods

    @objc func toggleInterview() {
        if isInterviewActive {
            stopInterview()
        } else {
            startInterview()
        }
    }

    func startInterview() {
        // Check for Anthropic API key (needed for Haiku answers)
        if apiKey == nil {
            showAlert(title: "API Key Required", message: "Please configure your Anthropic API key in Settings (⌘,)")
            return
        }

        // Initialize AR overlay to show Vision detection indicators
        if arOverlay == nil {
            arOverlay = ARAnnotationOverlay()
        }
        arOverlay?.showWithAutoTest()
        debugLog("🎯 AR overlay started with Vision detection indicators")

        // STT provider selection based on language:
        // - English: Deepgram streaming (fast, ~100ms latency)
        // - Non-English: Groq Whisper batch (better multilingual accuracy)
        let isEnglish = AppSettings.shared.speakingLanguage == .english
        let useStreamingMode = isEnglish && deepgramApiKey != nil
        let useGroqMode = !isEnglish && groqApiKey != nil

        if isEnglish && deepgramApiKey == nil {
            showAlert(title: "Deepgram API Key Required", message: "English mode uses Deepgram streaming. Please configure your Deepgram API key in Settings (⌘,)")
            return
        }
        if !isEnglish && groqApiKey == nil {
            showAlert(title: "Groq API Key Required", message: "Non-English languages use Groq Whisper for better accuracy. Please configure your Groq API key in Settings (⌘,)")
            return
        }

        // Initialize Anthropic client (always needed)
        anthropicClient = AnthropicClient(apiKey: apiKey!)

        // Get language and keyterms for STT
        // Use "multi" for non-English to enable code-switching (e.g., Bulgarian + English terms)
        let sttLanguage = AppSettings.shared.deepgramLanguageCode
        let sttKeyterms = AppSettings.shared.deepgramKeyterms

        if useStreamingMode {
            // STREAMING MODE: Deepgram Nova-3 + Silero VAD (~300-500ms faster)
            // Uses the same SystemAudioCapture with streaming mode enabled
            systemAudioCapture = SystemAudioCapture()

            // English: Use Deepgram Nova-3 streaming for fast, accurate transcription
            NSLog("🚀 Starting interview in STREAMING mode (Deepgram Nova-3, English, keyterms=%d)", sttKeyterms.count)
            systemAudioCapture?.enableStreamingMode(deepgramApiKey: deepgramApiKey!, language: sttLanguage, keyterms: sttKeyterms)

            // Configure voice interview processor (no Groq needed for streaming)
            voiceInterviewProcessor.configure(groqClient: nil, anthropicClient: anthropicClient)

            // Set up streaming callbacks
            systemAudioCapture?.onStatusChange = { [weak self] status in
                guard let self = self else { return }
                debugLog(.audio, "Streaming status: \(status)")
            }

            systemAudioCapture?.onLevelUpdate = { [weak self] db, isSpeaking in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.updateStatusIcon(listening: true, speaking: isSpeaking)
                }
            }

            systemAudioCapture?.onTranscript = { [weak self] text, isFinal in
                guard let self = self else { return }
                debugLog(.transcription, "Streaming transcript (final=\(isFinal)): \(text.prefix(50))...")
                self.voiceInterviewProcessor.processStreamingTranscript(text, isFinal: isFinal, source: .systemAudio)
            }

            systemAudioCapture?.onError = { [weak self] error in
                guard let self = self else { return }
                debugLog(.error, "Streaming error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.addVoiceMessage(type: .status, content: "⚠️ \(error.localizedDescription)", topic: nil)
                }
            }

            // Start capture (ScreenCaptureKit works, streaming enabled on top)
            Task {
                do {
                    debugLog(.audio, "Starting system audio capture with streaming mode...")
                    try await systemAudioCapture?.startCapturing()
                    debugLog(.audio, "System audio capture (streaming) started successfully")
                } catch {
                    debugLog(.error, "System audio capture failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.addVoiceMessage(type: .status, content: "⚠️ Failed to start: \(error.localizedDescription)", topic: nil)
                    }
                }
            }
        } else {
            // BATCH MODE: Groq Whisper for non-English (better multilingual accuracy)
            let langName = AppSettings.shared.speakingLanguage.displayName
            NSLog("🎤 Starting interview in BATCH mode (Groq Whisper, %@)", langName)

            vadRecorder = SileroVADRecorder()
            systemAudioCapture = SystemAudioCapture()
            groqClient = GroqInterviewClient(apiKey: groqApiKey!)

            // Configure voice interview processor with Groq
            voiceInterviewProcessor.configure(groqClient: groqClient, anthropicClient: anthropicClient)

            // Set up system audio capture (for interviewer's voice in Zoom/Teams)
            debugLog("Setting up system audio callbacks...")
            systemAudioCapture?.onStatusChange = { [weak self] status in
                guard let self = self else { return }
                debugLog(.audio, "System status: \(status)")
            }

            systemAudioCapture?.onLevelUpdate = { [weak self] db, isSpeaking in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.updateStatusIcon(listening: true, speaking: isSpeaking)
                }
            }

            systemAudioCapture?.onSpeechSegment = { [weak self] audioData in
                guard let self = self else { return }
                debugLog(.audio, "System audio segment received: \(audioData.count) bytes")
                self.voiceInterviewProcessor.processAudioSegment(audioData, source: .systemAudio)
            }

            // Start batch capture
            Task {
                do {
                    debugLog(.audio, "Starting system audio capture...")
                    try await systemAudioCapture?.startCapturing()
                    debugLog(.audio, "System audio capture started successfully")
                } catch {
                    debugLog(.error, "System audio capture failed: \(error.localizedDescription)")
                }
            }
        }

        // Common setup for both modes
        isInterviewActive = true

        // Clear screenshots array for new session
        screenshots.removeAll()
        // Rename old gallery so new screenshots create a fresh one (old gallery stays visible)
        if let oldGallery = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
            oldGallery.identifier = NSUserInterfaceItemIdentifier("screenshotGallery_archived")
        }

        // Update Nest button to recording state
        updateNestButtonState(recording: true)

        // Show recording indicator (Dynamic Island style)
        showRecordingIndicator()

        // Trigger AR overlay test to show line annotations
        showAROverlay()

        let modeLabel = useStreamingMode ? "streaming (Deepgram)" : "batch (Groq Whisper)"
        let langLabel = AppSettings.shared.speakingLanguage.displayName
        addVoiceMessage(type: .status, content: "Interview started - \(langLabel) (\(modeLabel)) - listening...", topic: nil)
    }

    func stopInterview() {
        vadRecorder?.stopListening()
        vadRecorder = nil

        // Stop system audio capture (batch mode)
        Task {
            await systemAudioCapture?.stopCapturing()
            await MainActor.run {
                systemAudioCapture = nil
            }
        }

        isInterviewActive = false

        // Clear conversation context but keep timeline visible
        conversationContext.clear()
        voiceInterviewProcessor.reset()

        // Hide loading indicator
        hideLoading()

        // Hide recording indicator
        hideRecordingIndicator()

        // Dismiss AR overlay
        arOverlay?.dismiss()

        // Update Nest button to idle state
        updateNestButtonState(recording: false)

        voiceStatusLabel.stringValue = ""
        // Reset waveform bars to dim state
        for bar in systemWaveformBars {
            bar.layer?.backgroundColor = NSColor.appleGold.withAlphaComponent(0.5).cgColor
        }

        // Add status to timeline (preserved)
        addVoiceMessage(type: .status, content: "Interview stopped", topic: nil)
    }

    // MARK: - Settings Dropdowns

    @objc func roleChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < InterviewRole.allCases.count else { return }
        AppSettings.shared.role = InterviewRole.allCases[index]
        NSLog("👤 Role changed to: \(AppSettings.shared.role.displayName)")
    }

    @objc func programmingLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < ProgrammingLanguage.allCases.count else { return }
        AppSettings.shared.programmingLanguage = ProgrammingLanguage.allCases[index]
        NSLog("💻 Programming language changed to: \(AppSettings.shared.programmingLanguage.displayName)")
    }

    @objc func speakingLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < SpeakingLanguage.allCases.count else { return }
        AppSettings.shared.speakingLanguage = SpeakingLanguage.allCases[index]
        NSLog("🌐 Speaking language changed to: \(AppSettings.shared.speakingLanguage.displayName)")
    }

    // MARK: - Export Interview

    @objc func exportInterview() {
        // Filter to only questions, answers, and followups (user responses disabled)
        let exportableMessages = voiceMessages.filter { msg in
            switch msg.type {
            case .question, .answer, .followUp, .codingTask:
                return true
            case .userResponse:  // DISABLED: User voice responses
                return false
            case .status, .screenshot:
                return false
            }
        }

        guard !exportableMessages.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nothing to Export"
            alert.informativeText = "Start an interview and have some Q&A before exporting."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Format the export
        var markdown = "# Interview Transcript\n\n"
        markdown += "**Date:** \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n"
        markdown += "**Tech Stack:** \(AppSettings.shared.techStack.displayName)\n\n"
        markdown += "**Legend:**\n"
        markdown += "- <span style=\"color: #E74C3C\">🎙️ **Interviewer**</span> - Questions from the interviewer\n"
        markdown += "- <span style=\"color: #27AE60\">💡 **Suggested Answer**</span> - AI-generated answer hints\n\n"
        markdown += "---\n\n"

        var currentTopic: String? = nil

        for msg in exportableMessages {
            // Add topic header if changed
            if let topic = msg.topic, topic != currentTopic, topic != "unknown" {
                markdown += "## \(topic.capitalized)\n\n"
                currentTopic = topic
            }

            let time = msg.displayTime
            switch msg.type {
            case .question:
                // Red/coral for interviewer
                markdown += "### <span style=\"color: #E74C3C\">🎙️ Interviewer</span> <small>(\(time))</small>\n\n"
                markdown += "> \(msg.content)\n\n"
            case .answer, .followUp:
                // Green for AI suggested answer
                markdown += "### <span style=\"color: #27AE60\">💡 Suggested Answer</span>\n\n"
                markdown += "\(msg.content)\n\n"
            // DISABLED: User voice responses
            // case .userResponse:
            //     let cleanedContent = cleanUserResponse(msg.content)
            //     guard !cleanedContent.isEmpty else { continue }
            //     markdown += "### <span style=\"color: #3498DB\">🗣️ Your Response</span> <small>(\(time))</small>\n\n"
            //     markdown += "\(cleanedContent)\n\n"
            default:
                break
            }
        }

        markdown += "---\n\n*Exported from Interview Master*\n"

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Interview"
        savePanel.nameFieldStringValue = "interview_\(formattedDateForFilename()).md"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    private func formattedDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    /// Clean up hallucinations from the start of user responses
    private func cleanUserResponse(_ text: String) -> String {
        var cleaned = text

        // Remove leading non-ASCII garbage (replacement chars, random unicode)
        while let first = cleaned.unicodeScalars.first, !first.isASCII || first.value < 32 {
            cleaned = String(cleaned.dropFirst())
        }

        // Common hallucination prefixes to remove
        let hallucationPrefixes = [
            "tabii,", "tabii", "tabibi", "merci beaucoup", "merci", "gracias",
            "thank you for watching", "thanks for watching", "subscribe",
            "reunited with", "accidental", "nexus,", "nexus"
        ]

        let lowerCleaned = cleaned.lowercased()
        for prefix in hallucationPrefixes {
            if lowerCleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // If starts with lowercase gibberish followed by actual content with capital letter,
        // try to find where real content starts (look for capital after space)
        if let firstChar = cleaned.first, firstChar.isLowercase {
            // Look for pattern: gibberish + space + Capital (start of real sentence)
            let words = cleaned.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            for (index, word) in words.enumerated() {
                if let first = word.first, first.isUppercase && index > 0 {
                    // Check if this looks like a real word (not just "You" alone)
                    let restOfSentence = words[index...].joined(separator: " ")
                    if restOfSentence.count > 10 {
                        cleaned = restOfSentence
                        break
                    }
                }
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Loading Indicator

    func showLoading(_ text: String = "", color: NSColor = .systemCyan) {
        DispatchQueue.main.async {
            self.startTypingDotsAnimation()
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.stopTypingDotsAnimation()
        }
    }

    /// Animate waveform bars based on speaking state and dB level
    func animateWaveform(bars: [NSView], color: NSColor, isSpeaking: Bool, db: Float) {
        let barMaxHeight: CGFloat = 14
        let barMinHeight: CGFloat = 3
        // Wave pattern for 5 bars: outer bars smaller, center bar tallest
        let waveMultipliers: [CGFloat] = [0.5, 0.8, 1.0, 0.8, 0.5]

        // When speaking, animate bars to varying heights based on volume
        // When silent, shrink all bars to minimum with wave pattern
        NSAnimationContext.runAnimationGroup { context in
            context.duration = isSpeaking ? 0.06 : 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            for (index, bar) in bars.enumerated() {
                var targetHeight: CGFloat
                var alpha: CGFloat
                let waveMultiplier = index < waveMultipliers.count ? waveMultipliers[index] : 0.7

                if isSpeaking {
                    // Map dB to height: -60dB = min, -20dB = max
                    let normalizedDb = max(0, min(1, (db + 60) / 40))
                    // Add variation per bar for organic waveform effect
                    let variation = CGFloat.random(in: 0.7...1.0)
                    let baseHeight = barMinHeight + (barMaxHeight - barMinHeight) * CGFloat(normalizedDb)
                    targetHeight = baseHeight * waveMultiplier * variation
                    targetHeight = max(barMinHeight, targetHeight) // Ensure minimum
                    alpha = 0.6 + CGFloat(normalizedDb) * 0.4
                } else {
                    // Resting state with gentle wave pattern
                    targetHeight = barMinHeight + (barMaxHeight - barMinHeight) * 0.2 * waveMultiplier
                    alpha = 0.35
                }

                // Update bar frame (animate height from center)
                var frame = bar.frame
                let centerY = frame.midY
                frame.size.height = targetHeight
                frame.origin.y = centerY - targetHeight / 2
                bar.animator().frame = frame

                // Update color with smooth transition
                bar.animator().layer?.backgroundColor = color.withAlphaComponent(alpha).cgColor
            }
        }
    }

    /// Start typing dots animation - iMessage style bounce
    func startTypingDotsAnimation() {
        typingDotsView.isHidden = false

        for (index, dot) in typingDots.enumerated() {
            dot.removeAllAnimations()

            // Bounce animation
            let bounce = CAKeyframeAnimation(keyPath: "transform.translateY")
            bounce.values = [0, -6, 0]
            bounce.keyTimes = [0, 0.4, 1.0]
            bounce.duration = 0.5
            bounce.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            bounce.repeatCount = .infinity
            bounce.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn)
            ]

            // Opacity pulse for extra polish
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.4, 1.0, 0.4]
            opacity.keyTimes = [0, 0.4, 1.0]
            opacity.duration = 0.5
            opacity.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            opacity.repeatCount = .infinity

            dot.add(bounce, forKey: "bounce")
            dot.add(opacity, forKey: "opacity")
        }
    }

    /// Stop typing dots animation
    func stopTypingDotsAnimation() {
        for dot in typingDots {
            dot.removeAllAnimations()
            dot.opacity = 1.0
        }
        typingDotsView.isHidden = true
    }

    /// Set loading indicator to inactive state (not used for spinning arc)
    func setWaveformInactiveState() {
        // No-op for spinning arc - just hide when not loading
    }

    // MARK: - Toolbar Button Updates

    /// Update play/stop button state
    func updateNestButtonState(recording: Bool) {
        let iconName = recording ? "stop.fill" : "play.fill"
        let accentColor = recording ? NSColor.appleRed : NSColor.appleGreen

        nestIconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: recording ? "Stop" : "Start")
        nestIconView.contentTintColor = accentColor

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        nestButtonInner.backgroundColor = accentColor.withAlphaComponent(0.15).cgColor
        CATransaction.commit()

        // Update status icon when recording state changes
        updateStatusIcon(listening: recording, speaking: false)
    }

    /// Update status icon based on current state
    func updateStatusIcon(listening: Bool, speaking: Bool) {
        let iconName: String
        let iconColor: NSColor
        let bgColor: NSColor

        if speaking {
            iconName = "waveform"
            iconColor = NSColor.appleGold
            bgColor = NSColor.appleGold.withAlphaComponent(0.15)
        } else if listening {
            iconName = "ear"
            iconColor = NSColor.appleGreen
            bgColor = NSColor.appleGreen.withAlphaComponent(0.15)
        } else {
            iconName = "mic.slash"
            iconColor = NSColor.white.withAlphaComponent(0.4)
            bgColor = NSColor.white.withAlphaComponent(0.08)
        }

        statusIconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        statusIconView.contentTintColor = iconColor
        statusIconContainer.layer?.backgroundColor = bgColor.cgColor
    }

    func clearTimeline() {
        voiceMessages.removeAll()
        for subview in voiceTimelineContainer.subviews {
            subview.removeFromSuperview()
        }
    }

    func promptForGroqApiKey() {
        let alert = NSAlert()
        alert.messageText = "Groq API Key Required"
        alert.informativeText = "Please configure your Groq API key in Settings to use voice transcription.\n\nYou can get a key at console.groq.com"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showSettings()
        }
    }

    func addVoiceMessage(type: InterviewMessage.MessageType, content: String, topic: String?, audioSource: AudioSource? = nil) {
        let message = InterviewMessage(type: type, content: content, topic: topic, audioSource: audioSource)
        voiceMessages.append(message)

        // Create message view
        let messageView = messageViewFactory.createMessageView(for: message)

        // Questions and new topics: push everything down, add at top
        // Answers and follow-ups: add below the most recent message (don't push it)
        let isNewTopic = (type == .question || type == .status || type == .codingTask || type == .screenshot)

        if isNewTopic {
            // Push all existing messages down to make room
            let newMessageHeight = messageView.frame.height + 15
            for subview in voiceTimelineContainer.subviews {
                subview.frame.origin.y += newMessageHeight
            }
            // Position at top
            messageView.frame.origin.y = 10
        } else {
            // Answer/follow-up: find the top-most message and add below it
            var topMessageMaxY: CGFloat = 10
            for subview in voiceTimelineContainer.subviews {
                if subview.frame.origin.y < 20 {  // Find message at top (Y~10)
                    topMessageMaxY = subview.frame.maxY + 15
                    break
                }
            }
            // Push messages below the answer position
            let newMessageHeight = messageView.frame.height + 15
            for subview in voiceTimelineContainer.subviews {
                if subview.frame.origin.y >= topMessageMaxY {
                    subview.frame.origin.y += newMessageHeight
                }
            }
            messageView.frame.origin.y = topMessageMaxY
        }

        voiceTimelineContainer.addSubview(messageView)

        // Update container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)

        // Scroll to top to show newest
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    /// Add a user response message (collapsed by default, expandable)
    func addUserResponseMessage(content: String, topic: String?) {
        var message = InterviewMessage(type: .userResponse, content: content, topic: topic, audioSource: .microphone)
        message.isCollapsed = true
        voiceMessages.append(message)

        // Create collapsed message view
        let messageView = createCollapsedUserResponseView(for: message)

        // Push all existing messages down to make room for new message at top
        let newMessageHeight = messageView.frame.height + 15
        for subview in voiceTimelineContainer.subviews {
            subview.frame.origin.y += newMessageHeight
        }

        // Position new message at top (Y=10 in flipped view = visually at top)
        messageView.frame.origin.y = 10
        voiceTimelineContainer.addSubview(messageView)

        // Update container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)

        // Scroll to top to show newest
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    /// Create a collapsed user response view (click to expand)
    func createCollapsedUserResponseView(for message: InterviewMessage) -> NSView {
        let width = voiceTimelineContainer.frame.width - 40
        let collapsedHeight: CGFloat = 36

        let container = NSView(frame: NSRect(x: 20, y: 0, width: width, height: collapsedHeight))
        container.wantsLayer = true
        container.identifier = NSUserInterfaceItemIdentifier("userResponse_\(message.id.uuidString)")

        // Blue separator line on left
        let lineView = NSView(frame: NSRect(x: 0, y: 0, width: 3, height: collapsedHeight))
        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        container.addSubview(lineView)

        // Time label
        let timeLabel = NSTextField(labelWithString: message.displayTime)
        timeLabel.frame = NSRect(x: 15, y: 10, width: 70, height: 16)
        timeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        container.addSubview(timeLabel)

        // "You said:" label with expand indicator
        let youSaidLabel = NSTextField(labelWithString: "🎤 You said:")
        youSaidLabel.frame = NSRect(x: 90, y: 10, width: 80, height: 16)
        youSaidLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        youSaidLabel.textColor = NSColor.systemBlue
        container.addSubview(youSaidLabel)

        // Preview of content (first ~40 chars)
        let preview = message.content.prefix(40) + (message.content.count > 40 ? "..." : "")
        let previewLabel = NSTextField(labelWithString: String(preview))
        previewLabel.frame = NSRect(x: 175, y: 10, width: width - 230, height: 16)
        previewLabel.font = .systemFont(ofSize: 12, weight: .regular)
        previewLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        previewLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(previewLabel)

        // Expand button
        let expandButton = NSButton(frame: NSRect(x: width - 50, y: 6, width: 40, height: 24))
        expandButton.title = "▶"
        expandButton.bezelStyle = .inline
        expandButton.isBordered = false
        expandButton.font = .systemFont(ofSize: 10)
        expandButton.contentTintColor = NSColor.systemBlue
        expandButton.target = self
        expandButton.action = #selector(toggleUserResponseExpand(_:))
        expandButton.identifier = NSUserInterfaceItemIdentifier(message.id.uuidString)
        container.addSubview(expandButton)

        // Store full content in container for expansion
        container.toolTip = message.content

        return container
    }

    @objc func toggleUserResponseExpand(_ sender: NSButton) {
        guard let messageId = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: messageId) else { return }

        // Find the container view
        guard let container = voiceTimelineContainer.subviews.first(where: {
            $0.identifier?.rawValue == "userResponse_\(messageId)"
        }) else { return }

        // Get stored content from tooltip
        let fullContent = container.toolTip ?? ""

        // Check if already expanded
        let isExpanded = container.frame.height > 50

        if isExpanded {
            // Collapse: animate to small height
            let collapsedHeight: CGFloat = 36
            let heightDiff = container.frame.height - collapsedHeight

            // Update button
            sender.title = "▶"

            // Hide content text view if exists
            for subview in container.subviews {
                if subview is NSScrollView {
                    subview.removeFromSuperview()
                }
            }

            // Resize container
            container.frame.size.height = collapsedHeight

            // Move messages below this one down
            for subview in voiceTimelineContainer.subviews where subview.frame.origin.y > container.frame.origin.y {
                subview.frame.origin.y -= heightDiff
            }

            // Update separator line height
            if let lineView = container.subviews.first {
                lineView.frame.size.height = collapsedHeight
            }

        } else {
            // Expand: show full content
            let textHeight = messageViewFactory.estimateTextHeight(fullContent, width: container.frame.width - 30)
            let expandedHeight = max(60, textHeight + 45)
            let heightDiff = expandedHeight - container.frame.height

            // Update button
            sender.title = "▼"

            // Move messages below this one up to make room
            for subview in voiceTimelineContainer.subviews where subview.frame.origin.y > container.frame.origin.y {
                subview.frame.origin.y += heightDiff
            }

            // Resize container
            container.frame.size.height = expandedHeight

            // Update separator line height
            if let lineView = container.subviews.first {
                lineView.frame.size.height = expandedHeight
            }

            // Add content text view
            let contentScrollView = NSScrollView(frame: NSRect(x: 15, y: 5, width: container.frame.width - 30, height: expandedHeight - 40))
            contentScrollView.hasVerticalScroller = false
            contentScrollView.drawsBackground = false

            let contentView = NSTextView(frame: contentScrollView.bounds)
            contentView.isEditable = false
            contentView.isSelectable = true
            contentView.drawsBackground = false
            contentView.backgroundColor = .clear
            contentView.textContainerInset = .zero
            contentView.string = fullContent
            contentView.font = .systemFont(ofSize: 12)
            contentView.textColor = NSColor.white.withAlphaComponent(0.8)

            contentScrollView.documentView = contentView
            container.addSubview(contentScrollView)
        }

        // Update container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
    }

    /// Add a screenshot thumbnail to the voice timeline (gallery style - one entry, multiple thumbnails)
    func addScreenshotToTimeline(thumbnail: NSImage, screenshotId: UUID) {
        let message = InterviewMessage(type: .screenshot, content: "Screenshot", topic: nil, screenshotId: screenshotId)
        voiceMessages.append(message)

        let thumbWidth: CGFloat = 80
        let thumbHeight: CGFloat = 50
        let thumbGap: CGFloat = 8

        // Check if screenshot gallery already exists - add to it
        if let existingGallery = voiceTimelineContainer.subviews.first(where: { $0.identifier?.rawValue == "screenshotGallery" }) {
            if let card = existingGallery.subviews.first(where: { $0.identifier?.rawValue == "screenshotCard" }),
               let scrollView = card.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
               let galleryContainer = scrollView.documentView {

                // Count existing thumbnails to position new one
                let existingCount = galleryContainer.subviews.count
                let newX = CGFloat(existingCount) * (thumbWidth + thumbGap)

                // Create new thumbnail button
                let thumbnailButton = NSButton(frame: NSRect(x: newX, y: 0, width: thumbWidth, height: thumbHeight))
                thumbnailButton.image = thumbnail
                thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
                thumbnailButton.isBordered = false
                thumbnailButton.bezelStyle = .rounded
                thumbnailButton.wantsLayer = true
                thumbnailButton.layer?.cornerRadius = 6
                thumbnailButton.layer?.borderWidth = 2
                thumbnailButton.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.4).cgColor
                thumbnailButton.layer?.masksToBounds = true
                thumbnailButton.target = self
                thumbnailButton.action = #selector(screenshotThumbnailClicked(_:))
                thumbnailButton.identifier = NSUserInterfaceItemIdentifier(screenshotId.uuidString)
                galleryContainer.addSubview(thumbnailButton)

                // Update gallery container width
                galleryContainer.frame.size.width = newX + thumbWidth + thumbGap

                // Update count label
                if let countLabel = card.subviews.first(where: { $0.identifier?.rawValue == "screenshotCount" }) as? NSTextField {
                    countLabel.stringValue = "\(screenshots.count) screenshots"
                }

                // Scroll to show newest thumbnail
                scrollView.contentView.scroll(to: NSPoint(x: max(0, galleryContainer.frame.width - scrollView.frame.width), y: 0))
            }
            return
        }

        // Create new screenshot gallery entry
        let badgeWidth: CGFloat = 22
        let badgeGap: CGFloat = 8
        let cardX: CGFloat = badgeWidth + badgeGap
        let cardWidth = voiceTimelineContainer.frame.width - 40 - cardX
        let containerHeight: CGFloat = 100

        // Outer container to hold badge + card
        let outerContainer = NSView(frame: NSRect(x: 20, y: 0, width: voiceTimelineContainer.frame.width - 40, height: containerHeight))
        outerContainer.identifier = NSUserInterfaceItemIdentifier("screenshotGallery")

        // S Badge - purple pill on the left
        let badge = NSView(frame: NSRect(x: 0, y: containerHeight - 26, width: badgeWidth, height: badgeWidth))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.15).cgColor
        badge.layer?.cornerRadius = badgeWidth / 2

        let badgeLabel = NSTextField(labelWithString: "S")
        badgeLabel.frame = NSRect(x: 0, y: 3, width: badgeWidth, height: 16)
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = NSColor.applePurple
        badgeLabel.alignment = .center
        badge.addSubview(badgeLabel)
        outerContainer.addSubview(badge)

        // Card container
        let card = NSView(frame: NSRect(x: cardX, y: 0, width: cardWidth, height: containerHeight))
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.backgroundColor = NSColor.applePurple.withAlphaComponent(0.06).cgColor
        card.identifier = NSUserInterfaceItemIdentifier("screenshotCard")
        outerContainer.addSubview(card)

        // Accent bar on left of card
        let accentBar = NSView(frame: NSRect(x: 0, y: 8, width: 3, height: containerHeight - 16))
        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = NSColor.applePurple.cgColor
        accentBar.layer?.cornerRadius = 1.5
        card.addSubview(accentBar)

        // Header with icon and count
        let headerIcon = NSImageView(frame: NSRect(x: 15, y: containerHeight - 26, width: 14, height: 14))
        headerIcon.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Screenshot")
        headerIcon.contentTintColor = NSColor.applePurple
        card.addSubview(headerIcon)

        let countLabel = NSTextField(labelWithString: "1 screenshot")
        countLabel.frame = NSRect(x: 34, y: containerHeight - 25, width: 100, height: 14)
        countLabel.font = .systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        countLabel.identifier = NSUserInterfaceItemIdentifier("screenshotCount")
        card.addSubview(countLabel)

        // Hint text on right
        let hintLabel = NSTextField(labelWithString: "⌘↩ analyze")
        hintLabel.frame = NSRect(x: cardWidth - 85, y: containerHeight - 25, width: 70, height: 14)
        hintLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        card.addSubview(hintLabel)

        // Horizontal scroll view for thumbnails
        let scrollView = NSScrollView(frame: NSRect(x: 15, y: 10, width: cardWidth - 30, height: thumbHeight + 10))
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Gallery container (expands horizontally)
        let galleryContainer = NSView(frame: NSRect(x: 0, y: 0, width: thumbWidth + thumbGap, height: thumbHeight))
        scrollView.documentView = galleryContainer

        // First thumbnail
        let thumbnailButton = NSButton(frame: NSRect(x: 0, y: 0, width: thumbWidth, height: thumbHeight))
        thumbnailButton.image = thumbnail
        thumbnailButton.imageScaling = .scaleProportionallyUpOrDown
        thumbnailButton.isBordered = false
        thumbnailButton.bezelStyle = .rounded
        thumbnailButton.wantsLayer = true
        thumbnailButton.layer?.cornerRadius = 6
        thumbnailButton.layer?.borderWidth = 2
        thumbnailButton.layer?.borderColor = NSColor.applePurple.withAlphaComponent(0.4).cgColor
        thumbnailButton.layer?.masksToBounds = true
        thumbnailButton.target = self
        thumbnailButton.action = #selector(screenshotThumbnailClicked(_:))
        thumbnailButton.identifier = NSUserInterfaceItemIdentifier(screenshotId.uuidString)
        galleryContainer.addSubview(thumbnailButton)

        card.addSubview(scrollView)

        // Push all existing messages down to make room for new message at top
        let newMessageHeight = outerContainer.frame.height + 15
        for subview in voiceTimelineContainer.subviews {
            subview.frame.origin.y += newMessageHeight
        }

        // Position new message at top (Y=10 in flipped view = visually at top)
        outerContainer.frame.origin.y = 10
        voiceTimelineContainer.addSubview(outerContainer)

        // Update container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)

        // Scroll to top to show newest
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
    }

    @objc func screenshotThumbnailClicked(_ sender: NSButton) {
        // Trigger analysis when screenshot is clicked
        analyzeScreenshots()
    }

    /// Pin a coding task solution in the timeline (replaces previous coding task if any)
    func setPinnedSolution(_ solution: String) {
        currentPinnedSolution = solution

        // Remove any existing coding task from timeline and shift messages up
        for subview in voiceTimelineContainer.subviews {
            if subview.identifier?.rawValue == "codingTask" {
                let removedHeight = subview.frame.height + 15
                subview.removeFromSuperview()
                // Shift all messages up to fill the gap
                for other in voiceTimelineContainer.subviews {
                    if other.frame.origin.y > 10 {
                        other.frame.origin.y -= removedHeight
                    }
                }
                break
            }
        }

        // Add coding task as a timeline message at the top
        let message = InterviewMessage(type: .codingTask, content: solution, topic: "solution")
        let messageView = messageViewFactory.createMessageView(for: message)

        // Push all existing messages down to make room for new message at top
        let newMessageHeight = messageView.frame.height + 15
        for subview in voiceTimelineContainer.subviews {
            subview.frame.origin.y += newMessageHeight
        }

        // Position new message at top (Y=10 in flipped view = visually at top)
        messageView.frame.origin.y = 10
        voiceTimelineContainer.addSubview(messageView)

        // Update container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)

        // Scroll to top to show newest
        voiceTimelineScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Hide the old overlay container (no longer needed)
        pinnedSolutionContainer.isHidden = true
    }

    /// Clear the pinned solution from timeline
    func clearPinnedSolution() {
        currentPinnedSolution = nil

        // Remove coding task from timeline
        for subview in voiceTimelineContainer.subviews {
            if subview.identifier?.rawValue == "codingTask" {
                let removedHeight = subview.frame.height + 15
                subview.removeFromSuperview()

                // Shift remaining messages down
                for otherView in voiceTimelineContainer.subviews {
                    if otherView.frame.origin.y > 10 {
                        otherView.frame.origin.y -= removedHeight
                    }
                }
                break
            }
        }

        // Recalculate container height
        var maxY: CGFloat = 0
        for subview in voiceTimelineContainer.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        voiceTimelineContainer.frame.size.height = max(voiceTimelineScrollView.frame.height, maxY + 20)
    }

}

@available(macOS 14.0, *)
@main
struct InterviewMasterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = InterviewMasterDelegate()
        app.delegate = delegate
        app.run()
    }
}
