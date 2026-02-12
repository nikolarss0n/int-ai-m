import Cocoa
import Carbon
import ScreenCaptureKit
import AVFoundation
import UniformTypeIdentifiers

@available(macOS 14.0, *)
class InterviewMasterDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, StreamingMessageHandlerDelegate, FloatingSolutionDataSource, PermissionsPanelDelegate, VoiceInterviewProcessorDelegate {
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

    // Floating solution window controller
    var floatingSolutionController: FloatingSolutionWindowController!

    // Interview mode - transparent click-through overlay
    var isInterviewModeActive = false
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var accessibilityPermissionTimer: Timer?

    var vadRecorder: SileroVADRecorder?
    var systemAudioCapture: SystemAudioCapture?
    var groqClient: GroqInterviewClient?
    var conversationContext = ConversationContext()
    var isInterviewActive = false
    var groqApiKey: String? {
        return ApiKeyManager.shared.getKey(.groq)
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
    var screenShareTimer: Timer?
    var focusMonitorTimer: Timer?
    var lastScreenshotCount = 0

    // Permissions panel
    var permissionsPanelController: PermissionsPanelController!

    // Persistence
    let notesStorageKey = "InterviewMaster.SavedNotes"
    let dataConsentKey = "InterviewMaster.DataConsentGiven"

    // NotificationCenter observer tokens
    var notificationObservers: [NSObjectProtocol] = []

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
        let apiKeysObserver = NotificationCenter.default.addObserver(
            forName: .apiKeysUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleApiKeysUpdated()
        }
        notificationObservers.append(apiKeysObserver)

        // Listen for interview settings updates from Settings
        let settingsObserver = NotificationCenter.default.addObserver(
            forName: .interviewSettingsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleInterviewSettingsUpdated()
        }
        notificationObservers.append(settingsObserver)
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
        contextBtn.setAccessibilityLabel("Context Tab")
        contextBtn.setAccessibilityRole(.button)
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
        timelineBtn.setAccessibilityLabel("Timeline Tab")
        timelineBtn.setAccessibilityRole(.button)
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
        voiceToggleButton.setAccessibilityLabel("Start Interview")
        voiceToggleButton.setAccessibilityRole(.button)
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
        exportButton.setAccessibilityLabel("Export Interview")
        exportButton.setAccessibilityRole(.button)
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
        settingsButton.setAccessibilityLabel("Settings")
        settingsButton.setAccessibilityRole(.button)
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

        // Initialize floating solution controller
        floatingSolutionController = FloatingSolutionWindowController(dataSource: self)

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
        searchField.focusRingType = .default
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
        guard currentTab != .notes else { return }
        let previousView = currentTab == .voice ? voiceContentView : codingContentView
        currentTab = .notes

        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            notesContentView.alphaValue = 0
            notesContentView.isHidden = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = LayoutConstants.Animation.normal
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                notesContentView.animator().alphaValue = 1.0
                previousView?.animator().alphaValue = 0.0
            }) {
                self.codingContentView.isHidden = true
                self.voiceContentView.isHidden = true
                self.codingContentView.alphaValue = 1.0
                self.voiceContentView.alphaValue = 1.0
            }
        } else {
            notesContentView.isHidden = false
            codingContentView.isHidden = true
            voiceContentView.isHidden = true
        }

        updateToolbarTabIcons(contextSelected: true)
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
        guard currentTab != .voice else { return }
        let previousView = currentTab == .notes ? notesContentView : codingContentView
        currentTab = .voice
        hideFormattingToolbar()

        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            voiceContentView.alphaValue = 0
            voiceContentView.isHidden = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = LayoutConstants.Animation.normal
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                voiceContentView.animator().alphaValue = 1.0
                previousView?.animator().alphaValue = 0.0
            }) {
                self.notesContentView.isHidden = true
                self.codingContentView.isHidden = true
                self.notesContentView.alphaValue = 1.0
                self.codingContentView.alphaValue = 1.0
            }
        } else {
            notesContentView.isHidden = true
            codingContentView.isHidden = true
            voiceContentView.isHidden = false
        }

        updateToolbarTabIcons(contextSelected: false)
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

        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        NSAnimationContext.runAnimationGroup { context in
            context.duration = shouldAnimate ? LayoutConstants.Animation.normal : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.tabSelectionPill.animator().frame = targetFrame
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = shouldAnimate ? LayoutConstants.Animation.fast : 0
            context.allowsImplicitAnimation = true

            if targetButton === notesTabButton {
                notesTabButton.contentTintColor = .white
                voiceTabButton.contentTintColor = NSColor.white.withAlphaComponent(LayoutConstants.Alpha.subtleText)
            } else {
                voiceTabButton.contentTintColor = .white
                notesTabButton.contentTintColor = NSColor.white.withAlphaComponent(LayoutConstants.Alpha.subtleText)
            }
        })
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


    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        accessibilityPermissionTimer?.invalidate()
        screenshotMonitorTimer?.invalidate()
        screenShareTimer?.invalidate()
        focusMonitorTimer?.invalidate()
        renderTimer?.invalidate()
        recordingTimer?.invalidate()

        // Remove NotificationCenter observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
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
