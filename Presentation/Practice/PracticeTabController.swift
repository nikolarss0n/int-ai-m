import Cocoa
import AVFoundation

/// Isolated Practice tab. Does not use live voice processor, VAD, or interview-focus burst.
@available(macOS 14.0, *)
final class PracticeTabController: NSObject, NSTextViewDelegate {
    private enum LearnPhase {
        case answering
        case reviewing(PracticeRecallReview)
    }

    let view: PracticeRootView

    private let store = PracticeStore.shared
    private var recorder: AVAudioRecorder?
    private var recordFileURL: URL?
    private var recordingPermissionGeneration = 0
    private var transcriptionGeneration = 0
    private var isTranscribing = false
    private var isScoringInterview = false

    private let bank = PracticeBankLoader.load()
    private var selectedRoleID = PracticeRole.aiEngineer.id
    private var selectedGroupIDs: Set<String> = Set(PracticeRole.aiEngineer.groupIds)
    private var selectedCount = 10
    private var selectedMode = PracticeRunMode.learn
    private var learnPhase = LearnPhase.answering
    private var recallDrafts: [String] = []
    private var recallUsedHelp: [Bool] = []
    private var recallResponses: [PracticeRecallResponse?] = []
    private var recallConfidences: [PracticeRecallConfidence?] = []
    private var recallCoverageOverrides: [[PracticeCoverageOverride]] = []
    private var recallRevealed: [Bool] = []
    private var recallRepairDrafts: [String] = []
    private var recallRepairing: [Bool] = []
    private var recallRepairIdeaIndices: [Int?] = []
    private var recallRequeuedQuestionIDs = Set<String>()
    private var baseQuestionCount = 0
    private var sessionSnapshotID = UUID().uuidString
    private var sessionTargetDate: Date?
    private var lastRatingUndo: PracticeRatingUndoMetadata?
    private var autosaveWorkItem: DispatchWorkItem?
    private var awaitingCompletion = false

    private var isRecallMode: Bool {
        selectedMode != .interview
    }

    private var sessionModeTitle: String {
        switch selectedMode {
        case .learn: return "ACTIVE RECALL"
        case .rehearse: return "VOICE REHEARSAL"
        case .interview: return "INTERVIEW"
        }
    }
    private var sessionPack: PracticeTopicPack?
    private var sessionQuestions: [PracticeQuestion] = []
    private var sessionAnswers: [PracticeScoredAnswer] = []
    private var sessionStartedAt = Date()
    private var questionIndex = 0
    private var viewingIndex = 0
    private var burstIDs: [UUID] = []
    private var usedHelp = false
    private var helpText = ""
    private var isRecording = false
    private var inSession = false
    private var historyVisible = false

    var onLeaveToTimeline: (() -> Void)?
    var onRequestInputFocus: ((NSResponder?) -> Void)?
    var canPresentPracticeUI: (() -> Bool)?
    var hasActiveSession: Bool { inSession }

    private var rolePopup: NSPopUpButton!
    private var modePopup: NSPopUpButton!
    private var countPopup: NSPopUpButton!
    private var roleCaption: NSTextField!
    private var modeCaption: NSTextField!
    private var countCaption: NSTextField!
    private var targetDateToggle: NSButton!
    private var targetDatePicker: NSDatePicker!
    private var topicRow: FlippedView!
    private var topicButtons: [NSButton] = []
    private var startButton: HoverButton!
    private var statusLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var sessionModePill: NSTextField!
    private var progressView: PracticeProgressSegmentsView!
    private var burstTitle: NSTextField!
    private var burstView: QuestionBurstStripView!
    private var questionCard: PracticeQuestionCard!
    private var recallCard: PracticeRecallCard!
    private var recordButton: HoverButton!
    private var helpButton: HoverButton!
    private var submitButton: HoverButton!
    private var endButton: HoverButton!
    private var endHeaderButton: HoverButton!
    private var recallRevealButton: HoverButton!
    private var recallAgainButton: HoverButton!
    private var recallHardButton: HoverButton!
    private var recallGotItButton: HoverButton!
    private var recallEditButton: HoverButton!
    private var recallDontKnowButton: HoverButton!
    private var recallRecordButton: HoverButton!
    private var resumeButton: HoverButton!
    private var undoRatingButton: HoverButton!
    private var practiceWeakButton: HoverButton!
    private var contrastButton: HoverButton!
    private var historyLabel: NSTextField!
    private var chartView: PracticeProgressChartView!
    private var historyCard: NSView!
    private var historyButton: HoverButton!
    private var headerLabel: NSTextField!
    private var appIconView: NSImageView!
    private var appTitleLabel: NSTextField!
    private var leaveButton: HoverButton!

    override init() {
        view = PracticeRootView(frame: .zero)
        super.init()
        buildUI()
        view.onLayout = { [weak self] in self?.relayout() }
        reloadHistory()
        refreshSelectionStatus()
    }

    func activate() {
        reloadHistory()
        if !inSession { updateIdlePlan() }
        view.needsLayout = true
        DispatchQueue.main.async { [weak self] in
            self?.focusResponseIfAppropriate()
        }
    }

    func deactivate() {
        recordingPermissionGeneration += 1
        if isRecording {
            stopRecording()
            transcribeRecording()
        }
        if inSession { saveSessionSnapshot() }
    }

    @discardableResult
    func prepareForApplicationTermination() -> Bool {
        autosaveWorkItem?.cancel()
        recordingPermissionGeneration += 1
        transcriptionGeneration += 1
        isTranscribing = false
        isScoringInterview = false
        if isRecording { stopRecording() }
        if isRecallMode,
           recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = recallCard.responseView.string
        } else if selectedMode == .interview,
                  recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = questionCard.answerView.string
        }
        return !inSession || saveSessionSnapshot()
    }

    func shouldAllowWindowClose() -> Bool {
        guard inSession else { return true }
        if isTranscribing || isScoringInterview {
            let pendingAlert = NSAlert()
            pendingAlert.alertStyle = .informational
            pendingAlert.messageText = isTranscribing ? "Finishing transcription" : "Finishing answer scoring"
            pendingAlert.informativeText = "Wait for this Practice result to finish so it can be saved safely."
            pendingAlert.addButton(withTitle: "Keep Practice Open")
            pendingAlert.runModal()
            return false
        }
        if isRecording {
            let recordingAlert = NSAlert()
            recordingAlert.alertStyle = .informational
            recordingAlert.messageText = "Finish the spoken answer first"
            recordingAlert.informativeText = "Stop recording so Practice can transcribe and save the answer before closing."
            recordingAlert.addButton(withTitle: "Continue Recording")
            recordingAlert.runModal()
            focusResponseIfAppropriate()
            return false
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close Interview Master?"
        alert.informativeText = "Your unfinished Practice session can be saved for later or discarded."
        alert.addButton(withTitle: "Save & Close")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard prepareForApplicationTermination() else {
                statusLabel.stringValue = "Could not save this Practice session. The app will stay open."
                focusResponseIfAppropriate()
                return false
            }
            return true
        case .alertThirdButtonReturn:
            resetIdle(status: "Practice session discarded.")
            return true
        default:
            focusResponseIfAppropriate()
            return false
        }
    }

    func focusResponseIfAppropriate() {
        let responder: NSResponder?
        if !inSession {
            responder = resumeButton.isHidden ? startButton : resumeButton
        } else if awaitingCompletion {
            responder = lastRatingUndo == nil ? endHeaderButton : undoRatingButton
        } else if isRecallMode {
            switch learnPhase {
            case .answering:
                if selectedMode == .rehearse,
                   recallDrafts.indices.contains(questionIndex),
                   recallDrafts[questionIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    responder = recallRecordButton
                } else {
                    responder = recallCard.responseView
                }
            case .reviewing:
                if recallRepairing.indices.contains(questionIndex), recallRepairing[questionIndex] {
                    responder = recallCard.gapRepairResponder
                } else {
                    responder = recallAgainButton
                }
            }
        } else {
            responder = questionCard.answerView
        }
        onRequestInputFocus?(responder)
        NSAccessibility.post(element: view as Any, notification: .focusedUIElementChanged)
    }

    func performPrimaryAction() {
        guard inSession else {
            startRun()
            return
        }
        guard !isTranscribing else {
            statusLabel.stringValue = "Finishing the current transcription…"
            return
        }
        if awaitingCompletion {
            finishRun()
            return
        }
        if selectedMode == .interview {
            submitAnswer()
            return
        }
        if recallRepairing.indices.contains(questionIndex), recallRepairing[questionIndex] {
            completeGapRepair(recallCard.repairDraft)
            return
        }
        switch learnPhase {
        case .answering:
            revealRecallAnswer()
        case .reviewing:
            rateRecall(.gotIt)
        }
    }

    // MARK: - UI

    private func buildUI() {
        view.wantsLayer = true
        view.autoresizingMask = [.width, .height]

        appIconView = NSImageView(frame: .zero)
        let developmentIconPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("icon_1024.png").path
        appIconView.image = NSImage(named: "AppIcon")
            ?? NSImage(contentsOfFile: developmentIconPath)
            ?? NSApp.applicationIconImage
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.wantsLayer = true
        appIconView.layer?.cornerRadius = 7
        appIconView.layer?.masksToBounds = true
        appIconView.isHidden = true
        view.addSubview(appIconView)

        appTitleLabel = makeLabel(
            "Interview Master",
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .white
        )
        appTitleLabel.maximumNumberOfLines = 1
        appTitleLabel.isHidden = true
        view.addSubview(appTitleLabel)

        headerLabel = makeLabel("Practice", font: .systemFont(ofSize: 20, weight: .semibold), color: .white)
        view.addSubview(headerLabel)

        historyButton = makeHoverButton(title: "History", accent: .appleGold, action: #selector(toggleHistory))
        view.addSubview(historyButton)

        leaveButton = makeHoverButton(title: "Timeline", accent: .white, action: #selector(leaveToTimeline))
        view.addSubview(leaveButton)

        endHeaderButton = makeHoverButton(title: "Exit", accent: .appleRed, action: #selector(endRunTapped))
        endHeaderButton.isHidden = true
        view.addSubview(endHeaderButton)

        subtitleLabel = makeLabel(
            "Active Recall lets you answer first, compare key ideas, and choose when to review again.",
            font: .systemFont(ofSize: 12, weight: .regular),
            color: NSColor.white.withAlphaComponent(0.86)
        )
        subtitleLabel.identifier = NSUserInterfaceItemIdentifier("subtitle")
        view.addSubview(subtitleLabel)

        sessionModePill = makeLabel(
            "ACTIVE RECALL",
            font: .systemFont(ofSize: 10, weight: .bold),
            color: .systemBlue
        )
        sessionModePill.alignment = .center
        sessionModePill.maximumNumberOfLines = 1
        sessionModePill.wantsLayer = true
        sessionModePill.layer?.cornerRadius = 6
        sessionModePill.layer?.cornerCurve = .continuous
        sessionModePill.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
        sessionModePill.layer?.borderWidth = 1
        sessionModePill.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        sessionModePill.isHidden = true
        view.addSubview(sessionModePill)

        progressView = PracticeProgressSegmentsView(frame: .zero)
        progressView.isHidden = true
        view.addSubview(progressView)

        roleCaption = makeSetupCaption("ROLE")
        modeCaption = makeSetupCaption("MODE")
        countCaption = makeSetupCaption("QUESTIONS")
        view.addSubview(roleCaption)
        view.addSubview(modeCaption)
        view.addSubview(countCaption)

        rolePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for role in PracticeRole.all {
            rolePopup.addItem(withTitle: role.title)
            rolePopup.lastItem?.representedObject = role.id
        }
        rolePopup.selectItem(at: 0)
        rolePopup.target = self
        rolePopup.action = #selector(roleChanged)
        rolePopup.font = .systemFont(ofSize: 13, weight: .medium)
        rolePopup.setAccessibilityLabel("Interview role")
        rolePopup.setAccessibilityHelp("Chooses the role used to select relevant practice topics.")
        rolePopup.toolTip = "Interview role"
        view.addSubview(rolePopup)

        modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for mode in PracticeRunMode.allCases {
            modePopup.addItem(withTitle: mode.title)
            modePopup.lastItem?.representedObject = mode.rawValue
        }
        modePopup.selectItem(at: 0)
        modePopup.target = self
        modePopup.action = #selector(modeChanged)
        modePopup.font = .systemFont(ofSize: 13, weight: .medium)
        modePopup.setAccessibilityLabel("Practice mode")
        modePopup.setAccessibilityHelp("Active Recall teaches with key ideas. Voice Rehearsal practices delivery aloud. Interview simulates a scored answer.")
        modePopup.toolTip = "Practice mode"
        view.addSubview(modePopup)

        topicRow = FlippedView(frame: .zero)
        view.addSubview(topicRow)
        applyRoleSelection()
        rebuildTopicChips()

        countPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for count in [5, 10, 20, 50, 100] {
            countPopup.addItem(withTitle: "\(count)")
            countPopup.lastItem?.tag = count
        }
        countPopup.selectItem(withTag: selectedCount)
        countPopup.target = self
        countPopup.action = #selector(countChanged)
        countPopup.font = .systemFont(ofSize: 13, weight: .medium)
        countPopup.setAccessibilityLabel("Question count")
        countPopup.setAccessibilityHelp("Chooses how many questions to include in this practice session.")
        countPopup.toolTip = "Question count"
        view.addSubview(countPopup)

        targetDateToggle = NSButton(
            checkboxWithTitle: "Interview on",
            target: self,
            action: #selector(targetDateToggled)
        )
        targetDateToggle.font = .systemFont(ofSize: 10.5, weight: .medium)
        targetDateToggle.contentTintColor = NSColor.white.withAlphaComponent(0.86)
        targetDateToggle.setAccessibilityHelp("Uses the interview date to adapt review spacing.")
        view.addSubview(targetDateToggle)

        targetDatePicker = NSDatePicker(frame: .zero)
        targetDatePicker.datePickerStyle = .textFieldAndStepper
        targetDatePicker.datePickerElements = [.yearMonthDay]
        targetDatePicker.minDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        targetDatePicker.dateValue = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        targetDatePicker.isEnabled = false
        targetDatePicker.target = self
        targetDatePicker.action = #selector(targetDateChanged)
        targetDatePicker.setAccessibilityLabel("Target interview date")
        view.addSubview(targetDatePicker)

        startButton = makeHoverButton(title: "Start practice", accent: .appleGreen, action: #selector(startRun))
        view.addSubview(startButton)

        statusLabel = makeLabel("Pick topics and a count. Live listen stays on Timeline.", font: .systemFont(ofSize: 11), color: NSColor.white.withAlphaComponent(0.78))
        view.addSubview(statusLabel)

        burstTitle = makeLabel("QUESTION BURST", font: .systemFont(ofSize: 9.5, weight: .bold), color: NSColor.white.withAlphaComponent(0.72))
        view.addSubview(burstTitle)

        burstView = QuestionBurstStripView(frame: .zero)
        burstView.onSelect = { [weak self] id in
            self?.selectBurstQuestion(id)
        }
        burstView.update(entries: [], selectedID: nil)
        view.addSubview(burstView)

        questionCard = PracticeQuestionCard(frame: .zero)
        view.addSubview(questionCard)

        recallCard = PracticeRecallCard(frame: .zero)
        recallCard.isHidden = true
        recallCard.responseView.delegate = self
        recallCard.onConfidenceSelection = { [weak self] confidence in
            self?.setCurrentRecallConfidence(confidence)
        }
        recallCard.onCoverageChange = { [weak self] index, covered in
            self?.setCoverageOverride(index: index, covered: covered)
        }
        recallCard.onGapRepairSubmit = { [weak self] revision in
            self?.completeGapRepair(revision)
        }
        recallCard.onGapRepairDraftChange = { [weak self] draft in
            self?.updateGapRepairDraft(draft)
        }
        view.addSubview(recallCard)

        recordButton = makeHoverButton(title: "Record", accent: .appleGold, action: #selector(toggleRecord))
        helpButton = makeHoverButton(title: "Help", accent: .systemYellow, action: #selector(requestHelp))
        submitButton = makeHoverButton(title: "Submit", accent: .appleGreen, action: #selector(submitAnswer))
        endButton = makeHoverButton(title: "Exit run", accent: .appleRed, action: #selector(endRunTapped))
        questionCard.addSubview(recordButton)
        questionCard.addSubview(helpButton)
        helpButton.isHidden = true
        questionCard.addSubview(submitButton)
        questionCard.addSubview(endButton)
        questionCard.answerView.delegate = self

        recallRevealButton = makeHoverButton(title: "Reveal key ideas", accent: .appleGreen, action: #selector(revealRecallAnswer))
        recallAgainButton = makeHoverButton(title: "Again · now", accent: .appleRed, action: #selector(rateRecallAgain))
        recallHardButton = makeHoverButton(title: "Hard · tomorrow", accent: .appleGold, action: #selector(rateRecallHard))
        recallGotItButton = makeHoverButton(title: "Got it · 3 days", accent: .appleGreen, action: #selector(rateRecallGotIt))
        recallEditButton = makeHoverButton(title: "Repair one gap", accent: .white, action: #selector(beginGapRepair))
        recallDontKnowButton = makeHoverButton(title: "I don’t know yet", accent: .appleGold, action: #selector(revealRecallWithoutAnswer))
        recallRecordButton = makeHoverButton(title: "Answer aloud", accent: .appleGold, action: #selector(toggleRecord))
        setButtonSymbol(recallRevealButton, name: "lightbulb.fill")
        setButtonSymbol(recallAgainButton, name: "arrow.clockwise")
        setButtonSymbol(recallHardButton, name: "chart.line.uptrend.xyaxis")
        setButtonSymbol(recallGotItButton, name: "calendar")
        setButtonSymbol(recallEditButton, name: "pencil")
        setButtonSymbol(recallDontKnowButton, name: "questionmark.circle")
        setButtonSymbol(recallRecordButton, name: "mic.fill")
        for button in [recallRevealButton!, recallAgainButton!, recallHardButton!, recallGotItButton!, recallEditButton!, recallDontKnowButton!, recallRecordButton!] {
            recallCard.addSubview(button)
        }

        resumeButton = makeHoverButton(title: "Resume session", accent: .systemBlue, action: #selector(resumeSavedSession))
        setButtonSymbol(resumeButton, name: "play.circle.fill")
        resumeButton.isHidden = true
        questionCard.addSubview(resumeButton)

        contrastButton = makeHoverButton(title: "Compare concepts", accent: .systemPurple, action: #selector(startContrastPractice))
        setButtonSymbol(contrastButton, name: "arrow.left.arrow.right")
        questionCard.addSubview(contrastButton)

        undoRatingButton = makeHoverButton(title: "Undo last", accent: .appleGold, action: #selector(undoLastRating))
        setButtonSymbol(undoRatingButton, name: "arrow.uturn.backward")
        undoRatingButton.isHidden = true
        view.addSubview(undoRatingButton)

        historyCard = card()
        historyCard.isHidden = true
        view.addSubview(historyCard)

        historyLabel = makeLabel("History", font: .systemFont(ofSize: 12), color: NSColor.white.withAlphaComponent(0.85))
        historyLabel.maximumNumberOfLines = 12
        historyCard.addSubview(historyLabel)

        chartView = PracticeProgressChartView(frame: .zero)
        chartView.isHidden = true
        historyCard.addSubview(chartView)

        practiceWeakButton = makeHoverButton(title: "Practice 5 misses", accent: .systemBlue, action: #selector(startWeakPractice))
        setButtonSymbol(practiceWeakButton, name: "arrow.triangle.2.circlepath")
        historyCard.addSubview(practiceWeakButton)

        updateModeDescription()
        updateSessionControls()
    }

    private func relayout() {
        let w = view.bounds.width
        let h = view.bounds.height
        headerLabel.frame = NSRect(x: 18, y: 12, width: 120, height: 26)
        leaveButton.frame = NSRect(x: max(300, w - 118), y: 12, width: 100, height: 28)

        if inSession {
            appIconView.isHidden = false
            appTitleLabel.isHidden = false
            appIconView.frame = NSRect(x: 18, y: 8, width: 28, height: 28)
            appTitleLabel.frame = NSRect(x: 56, y: 12, width: 190, height: 22)
            headerLabel.frame = NSRect(x: 18, y: 46, width: 120, height: 26)
            leaveButton.frame = NSRect(x: max(300, w - 118), y: 8, width: 100, height: 28)
            subtitleLabel.isHidden = true
            rolePopup.isHidden = true
            modePopup.isHidden = true
            countPopup.isHidden = true
            roleCaption.isHidden = true
            modeCaption.isHidden = true
            countCaption.isHidden = true
            targetDateToggle.isHidden = true
            targetDatePicker.isHidden = true
            topicRow.isHidden = true
            startButton.isHidden = true
            historyButton.isHidden = true
            burstTitle.isHidden = true
            burstView.isHidden = true
            historyCard.isHidden = true

            sessionModePill.isHidden = false
            sessionModePill.frame = NSRect(x: headerLabel.frame.maxX + 2, y: 48, width: 112, height: 22)
            endHeaderButton.isHidden = false
            endHeaderButton.frame = NSRect(x: leaveButton.frame.minX - 96, y: 8, width: 88, height: 28)
            undoRatingButton.isHidden = lastRatingUndo == nil
            undoRatingButton.frame = NSRect(x: endHeaderButton.frame.minX - 96, y: 8, width: 88, height: 28)
            statusLabel.isHidden = false
            statusLabel.frame = NSRect(x: 18, y: 78, width: max(170, w - 310), height: 18)
            statusLabel.textColor = NSColor.white.withAlphaComponent(0.84)
            progressView.isHidden = false
            progressView.frame = NSRect(x: max(300, w - 248), y: 83, width: 230, height: 8)

            let cardTop: CGFloat = 104
            let cardFrame = NSRect(x: 16, y: cardTop, width: w - 32, height: max(280, h - cardTop - 16))
            recallCard.frame = cardFrame
            questionCard.frame = cardFrame
        } else {
            appIconView.isHidden = true
            appTitleLabel.isHidden = true
            subtitleLabel.isHidden = false
            subtitleLabel.frame = NSRect(x: 18, y: 38, width: w - 36, height: 18)
            rolePopup.isHidden = false
            modePopup.isHidden = false
            countPopup.isHidden = false
            roleCaption.isHidden = false
            modeCaption.isHidden = false
            countCaption.isHidden = false
            targetDateToggle.isHidden = false
            targetDatePicker.isHidden = false
            topicRow.isHidden = false
            startButton.isHidden = false
            historyButton.isHidden = false
            sessionModePill.isHidden = true
            endHeaderButton.isHidden = true
            undoRatingButton.isHidden = true
            progressView.isHidden = true
            burstTitle.isHidden = true
            burstView.isHidden = true

            historyButton.frame = NSRect(x: leaveButton.frame.minX - 108, y: 12, width: 100, height: 28)
            let controlsY: CGFloat = 72
            rolePopup.frame = NSRect(x: 18, y: controlsY, width: min(180, max(140, w * 0.22)), height: 26)
            modePopup.frame = NSRect(x: rolePopup.frame.maxX + 8, y: controlsY, width: 130, height: 26)
            countPopup.frame = NSRect(x: modePopup.frame.maxX + 8, y: controlsY, width: 72, height: 26)
            startButton.frame = NSRect(x: countPopup.frame.maxX + 8, y: controlsY - 2, width: 120, height: 30)
            roleCaption.frame = NSRect(x: rolePopup.frame.minX, y: 58, width: rolePopup.frame.width, height: 12)
            modeCaption.frame = NSRect(x: modePopup.frame.minX, y: 58, width: modePopup.frame.width, height: 12)
            countCaption.frame = NSRect(x: countPopup.frame.minX, y: 58, width: countPopup.frame.width, height: 12)

            let chipHeight = layoutTopicChips(width: w - 36)
            topicRow.frame = NSRect(x: 18, y: 106, width: w - 36, height: chipHeight)
            statusLabel.isHidden = false
            statusLabel.textColor = NSColor.white.withAlphaComponent(0.78)
            targetDateToggle.frame = NSRect(x: 18, y: topicRow.frame.maxY + 3, width: 92, height: 22)
            targetDatePicker.frame = NSRect(x: targetDateToggle.frame.maxX + 4, y: topicRow.frame.maxY + 2, width: 118, height: 24)
            statusLabel.frame = NSRect(x: targetDatePicker.frame.maxX + 10, y: topicRow.frame.maxY + 4, width: max(100, w - targetDatePicker.frame.maxX - 28), height: 20)
            let cardTop = statusLabel.frame.maxY + 8
            questionCard.frame = NSRect(x: 16, y: cardTop, width: w - 32, height: max(140, h - cardTop - 16))
            recallCard.frame = questionCard.frame
        }

        let historyHeight: CGFloat = min(220, max(160, h * 0.38))
        historyCard.frame = NSRect(x: 16, y: h - historyHeight - 12, width: w - 32, height: historyHeight)
        historyCard.isHidden = inSession || !historyVisible

        let btnW: CGFloat = 86
        let gap: CGFloat = 8
        let buttonsY: CGFloat = 10
        var buttonX: CGFloat = 18
        if !recordButton.isHidden {
            recordButton.frame = NSRect(x: buttonX, y: buttonsY, width: btnW, height: 28)
            buttonX += btnW + gap
        }
        helpButton.frame = NSRect(x: 18 + (btnW + gap), y: buttonsY, width: btnW, height: 28)
        if !submitButton.isHidden {
            submitButton.frame = NSRect(x: buttonX, y: buttonsY, width: btnW, height: 28)
            buttonX += btnW + gap
        }
        endButton.frame = NSRect(x: buttonX, y: buttonsY, width: btnW, height: 28)

        let recallW = recallCard.bounds.width
        let recallPad: CGFloat = 18
        let recallGap: CGFloat = 7
        if !recallRevealButton.isHidden {
            let revealWidth: CGFloat = 148
            recallRevealButton.frame = NSRect(
                x: max(recallPad, recallW - recallPad - revealWidth),
                y: 10,
                width: revealWidth,
                height: 30
            )
            recallDontKnowButton.frame = NSRect(
                x: recallPad,
                y: 10,
                width: 142,
                height: 30
            )
            recallRecordButton.frame = NSRect(
                x: recallDontKnowButton.frame.maxX + recallGap,
                y: 10,
                width: 136,
                height: 30
            )
        }
        if !recallAgainButton.isHidden {
            let available = max(360, recallW - recallPad * 2 - recallGap * 3)
            let againWidth = floor(available * 0.21)
            let hardWidth = floor(available * 0.25)
            let gotWidth = floor(available * 0.28)
            let editWidth = available - againWidth - hardWidth - gotWidth
            var x = recallPad
            recallAgainButton.frame = NSRect(x: x, y: 10, width: againWidth, height: 30)
            x += againWidth + recallGap
            recallHardButton.frame = NSRect(x: x, y: 10, width: hardWidth, height: 30)
            x += hardWidth + recallGap
            recallGotItButton.frame = NSRect(x: x, y: 10, width: gotWidth, height: 30)
            x += gotWidth + recallGap
            recallEditButton.frame = NSRect(x: x, y: 10, width: editWidth, height: 30)
        }
        resumeButton.frame = NSRect(x: max(18, questionCard.bounds.width - 168), y: 10, width: 150, height: 30)
        contrastButton.frame = NSRect(x: 18, y: 10, width: 150, height: 30)
        questionCard.needsLayout = true
        recallCard.needsLayout = true

        let hw = historyCard.bounds.width
        let hh = historyCard.bounds.height
        historyLabel.frame = NSRect(x: 14, y: 46, width: hw - 28, height: hh - 56)
        practiceWeakButton.frame = NSRect(x: max(14, hw - 164), y: 10, width: 150, height: 28)
        chartView.frame = .zero
    }

    private func card() -> NSView {
        let card = NSView(frame: .zero)
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        return card
    }

    private func makeLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        return label
    }

    private func makeSetupCaption(_ text: String) -> NSTextField {
        let label = makeLabel(
            text,
            font: .systemFont(ofSize: 9.5, weight: .bold),
            color: NSColor.white.withAlphaComponent(0.78)
        )
        label.maximumNumberOfLines = 1
        return label
    }

    private func makeHoverButton(title: String, accent: NSColor, action: Selector) -> HoverButton {
        let button = HoverButton(frame: .zero)
        button.title = title
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1.4
        button.contentTintColor = .white
        button.configureHoverColors(accent: accent)
        button.target = self
        button.action = action
        return button
    }

    private func setButtonSymbol(_ button: NSButton, name: String) {
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: button.title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
    }

    // MARK: - Session

    @objc private func leaveToTimeline() {
        if inSession {
            endRunTapped()
            return
        }
        deactivate()
        onLeaveToTimeline?()
    }

    @objc private func toggleHistory() {
        historyVisible.toggle()
        historyCard.isHidden = !historyVisible
        historyButton.title = historyVisible ? "Close history" : historyButtonTitle()
        if historyVisible {
            reloadHistory()
            view.addSubview(historyCard, positioned: .above, relativeTo: questionCard)
        }
        relayout()
    }

    private func historyButtonTitle() -> String {
        let count = store.allRuns().count
        return count == 0 ? "History" : "History (\(count))"
    }

    @objc private func roleChanged() {
        selectedRoleID = (rolePopup.selectedItem?.representedObject as? String) ?? PracticeRole.aiEngineer.id
        applyRoleSelection()
        rebuildTopicChips()
        view.needsLayout = true
        reloadHistory()
        refreshSelectionStatus()
    }

    @objc private func topicToggled(_ sender: NSButton) {
        let id = sender.identifier?.rawValue ?? ""
        if sender.state == .on {
            selectedGroupIDs.insert(id)
        } else {
            selectedGroupIDs.remove(id)
            if selectedGroupIDs.isEmpty {
                selectedGroupIDs.insert(id)
                sender.state = .on
            }
        }
        refreshSelectionStatus()
    }

    private func applyRoleSelection() {
        let available = allAvailableTopicIDs()
        let role = practiceRole(id: selectedRoleID) ?? .aiEngineer
        selectedGroupIDs = Set(practiceGroupIDs(forRole: role, available: available))
        if selectedGroupIDs.isEmpty, let first = available.first {
            selectedGroupIDs = [first]
        }
    }

    private func allAvailableTopicIDs() -> [String] {
        practiceBankGroups(from: bank).map(\.id)
    }

    @objc private func countChanged() {
        selectedCount = countPopup.selectedItem?.tag ?? selectedCount
        refreshSelectionStatus()
    }

    private struct SelectableTopic {
        let id: String
        let title: String
    }

    private func selectableTopics() -> [SelectableTopic] {
        let role = practiceRole(id: selectedRoleID) ?? .aiEngineer
        let allowed = Set(practiceGroupIDs(forRole: role, available: allAvailableTopicIDs()))
        let titles = Dictionary(uniqueKeysWithValues: practiceBankGroups(from: bank).map { ($0.id, $0.title) })
        var topics: [SelectableTopic] = []
        var seen = Set<String>()
        let ordered = practiceInterviewTopicOrder + allowed.filter { !practiceInterviewTopicOrder.contains($0) }
        for id in ordered where allowed.contains(id) && seen.insert(id).inserted {
            topics.append(SelectableTopic(id: id, title: titles[id] ?? id))
        }
        return topics
    }

    private func rebuildTopicChips() {
        topicButtons.forEach { $0.removeFromSuperview() }
        topicButtons = []
        for topic in selectableTopics() {
            let button = NSButton(checkboxWithTitle: topic.title, target: self, action: #selector(topicToggled(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(topic.id)
            button.font = .systemFont(ofSize: 11.5, weight: .medium)
            button.contentTintColor = .white
            button.state = selectedGroupIDs.contains(topic.id) ? .on : .off
            topicRow.addSubview(button)
            topicButtons.append(button)
        }
    }

    private func syncTopicChips() {
        for button in topicButtons {
            let id = button.identifier?.rawValue ?? ""
            button.state = selectedGroupIDs.contains(id) ? .on : .off
        }
    }

    @discardableResult
    private func layoutTopicChips(width: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        var y: CGFloat = 0
        let height: CGFloat = 28
        let gap: CGFloat = 8
        for button in topicButtons {
            let size = button.intrinsicContentSize
            let chipWidth = min(width, max(70, size.width + 8))
            if x + chipWidth > width, x > 0 {
                x = 0
                y += height + 6
            }
            button.frame = NSRect(x: x, y: y, width: chipWidth, height: height)
            x += chipWidth + gap
        }
        return y + height
    }

    private func groupTitle(for question: PracticeQuestion) -> String {
        let fallback = bank.packs
            .compactMap { $0.groups.first(where: { $0.id == question.groupId })?.title }
            .first ?? question.groupId
        return practiceGroupDisplayTitle(id: question.groupId, fallback: fallback)
    }

    private func currentPool() -> [PracticeQuestion] {
        practiceQuestionPool(from: bank, groupIDs: selectedGroupIDs)
    }

    private func makeSessionQuestionState(at index: Int) -> PracticeSessionQuestionState? {
        guard sessionQuestions.indices.contains(index) else { return nil }
        let question = sessionQuestions[index]
        let draft: String
        if isRecallMode {
            draft = recallDrafts.indices.contains(index) ? recallDrafts[index] : ""
        } else if index == questionIndex {
            draft = questionCard.answerView.string
        } else {
            draft = sessionAnswers.indices.contains(index) ? sessionAnswers[index].answer : ""
        }
        return PracticeSessionQuestionState(
            reference: PracticeQuestionReference(packId: question.packId, questionId: question.id),
            draftResponse: draft,
            recallResponse: recallResponses.indices.contains(index) ? recallResponses[index] : nil,
            confidence: recallConfidences.indices.contains(index) ? recallConfidences[index] : nil,
            hasRevealedKeyIdeas: recallRevealed.indices.contains(index) && recallRevealed[index],
            coverageOverrides: recallCoverageOverrides.indices.contains(index) ? recallCoverageOverrides[index] : [],
            usedHelp: recallUsedHelp.indices.contains(index) && recallUsedHelp[index],
            repairDraft: recallRepairDrafts.indices.contains(index) ? recallRepairDrafts[index] : "",
            isRepairingGap: recallRepairing.indices.contains(index) && recallRepairing[index],
            repairIdeaIndex: recallRepairIdeaIndices.indices.contains(index) ? recallRepairIdeaIndices[index] : nil
        )
    }

    private func makeSessionSnapshot(now: Date = Date()) -> PracticeSessionSnapshot? {
        guard inSession, let pack = sessionPack else { return nil }
        let states = sessionQuestions.indices.compactMap(makeSessionQuestionState(at:))
        guard states.count == sessionQuestions.count else { return nil }
        return PracticeSessionSnapshot(
            id: sessionSnapshotID,
            packId: pack.id,
            packTitle: pack.title,
            roleId: selectedRoleID,
            groupIds: Array(selectedGroupIDs).sorted(),
            mode: selectedMode,
            questionStates: states,
            baseQuestionCount: baseQuestionCount,
            currentQuestionIndex: questionIndex,
            startedAt: sessionStartedAt,
            updatedAt: now,
            answers: sessionAnswers,
            requeuedQuestionKeys: Array(recallRequeuedQuestionIDs).sorted(),
            lastRatingUndo: lastRatingUndo,
            targetDate: sessionTargetDate
        )
    }

    @discardableResult
    private func saveSessionSnapshot() -> Bool {
        guard let snapshot = makeSessionSnapshot() else { return false }
        guard store.saveInProgressSession(snapshot) else {
            statusLabel.stringValue = "Could not autosave this Practice session."
            return false
        }
        resumeButton.isHidden = true
        return true
    }

    private func scheduleSessionAutosave() {
        autosaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveSessionSnapshot() }
        autosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func textDidChange(_ notification: Notification) {
        guard inSession, let textView = notification.object as? NSTextView else { return }
        if isRecallMode,
           textView === recallCard.responseView,
           recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = textView.string
        } else if selectedMode == .interview,
                  textView === questionCard.answerView,
                  recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = textView.string
        }
        scheduleSessionAutosave()
    }

    private func updateIdlePlan() {
        guard !inSession, questionCard != nil else { return }
        let runs = store.allRuns()
        let latest = practiceLatestRecallAnswers(from: runs)
        let attempts = practiceRecallAttempts(from: runs)
        let plan = practiceTodaysPlan(
            questions: currentPool(),
            latestAnswers: latest,
            attemptsByQuestion: attempts,
            maximumQuestions: selectedCount,
            estimatedSecondsPerQuestion: selectedMode == .rehearse ? 120 : 60
        )
        let resumable = store.inProgressSession().flatMap { snapshot -> String? in
            guard snapshot.canResume else { return nil }
            return "\(snapshot.mode.title) · question \(snapshot.currentQuestionIndex + 1) of \(snapshot.baseQuestionCount)"
        }
        if selectedMode == .interview {
            questionCard.showIdle()
            questionCard.titleLabel.stringValue = "Mock interview"
            questionCard.sourceLabel.stringValue = "Scored free response · no learning help"
            questionCard.questionView.string = "Practice answering under interview conditions by typing or speaking, then review the saved report."
            resumeButton.isHidden = resumable == nil
            contrastButton.isHidden = true
            startButton.title = "Start interview"
            view.needsLayout = true
            return
        }
        questionCard.showTodayPlan(plan, resumeSummary: resumable)
        resumeButton.isHidden = resumable == nil
        contrastButton.isHidden = false
        contrastButton.isEnabled = !practiceContrastPairs(
            from: currentPool(),
            latestAnswers: latest,
            attemptsByQuestion: attempts,
            limit: 1
        ).isEmpty
        startButton.title = plan.recommendedCount > 0 ? "Start today’s plan" : "Start practice"
        view.needsLayout = true
    }

    @objc private func resumeSavedSession() {
        guard let snapshot = store.inProgressSession(), snapshot.canResume else {
            statusLabel.stringValue = "No resumable Practice session was found."
            updateIdlePlan()
            return
        }
        restoreSession(from: snapshot, persist: false)
    }

    private func restoreSession(from snapshot: PracticeSessionSnapshot, persist: Bool) {
        var questionsByKey: [String: PracticeQuestion] = [:]
        for question in bank.packs.flatMap(\.questions) {
            questionsByKey[practiceRecallReviewKey(packId: question.packId, questionId: question.id)] = question
        }
        let restoredQuestions = snapshot.questionStates.compactMap { state in
            questionsByKey[practiceRecallReviewKey(
                packId: state.reference.packId,
                questionId: state.reference.questionId
            )]
        }
        guard restoredQuestions.count == snapshot.questionStates.count else {
            statusLabel.stringValue = "This saved session references questions that are no longer available."
            return
        }

        sessionSnapshotID = snapshot.id
        selectedRoleID = snapshot.roleId ?? selectedRoleID
        if !snapshot.groupIds.isEmpty {
            selectedGroupIDs = Set(snapshot.groupIds)
        }
        selectedMode = snapshot.mode
        sessionQuestions = restoredQuestions
        sessionAnswers = snapshot.answers
        sessionStartedAt = snapshot.startedAt
        baseQuestionCount = snapshot.baseQuestionCount
        questionIndex = min(max(0, snapshot.currentQuestionIndex), max(0, restoredQuestions.count - 1))
        viewingIndex = questionIndex
        recallRequeuedQuestionIDs = Set(snapshot.requeuedQuestionKeys)
        lastRatingUndo = snapshot.lastRatingUndo
        awaitingCompletion = snapshot.currentQuestionIndex == snapshot.questionStates.count - 1
            && snapshot.answers.count >= snapshot.questionStates.count
        sessionTargetDate = snapshot.targetDate
        targetDateToggle.state = snapshot.targetDate == nil ? .off : .on
        targetDatePicker.isEnabled = snapshot.targetDate != nil
        if let targetDate = snapshot.targetDate { targetDatePicker.dateValue = targetDate }
        burstIDs = restoredQuestions.map { _ in UUID() }

        recallDrafts = snapshot.questionStates.map(\.draftResponse)
        recallUsedHelp = snapshot.questionStates.map(\.usedHelp)
        recallResponses = snapshot.questionStates.map(\.recallResponse)
        recallConfidences = snapshot.questionStates.map(\.confidence)
        recallCoverageOverrides = snapshot.questionStates.map(\.coverageOverrides)
        recallRevealed = snapshot.questionStates.map(\.hasRevealedKeyIdeas)
        recallRepairDrafts = snapshot.questionStates.map(\.repairDraft)
        recallRepairing = snapshot.questionStates.map(\.isRepairingGap)
        recallRepairIdeaIndices = snapshot.questionStates.map(\.repairIdeaIndex)

        sessionPack = PracticeTopicPack(
            id: snapshot.packId,
            title: snapshot.packTitle,
            blurb: "",
            groups: bank.packs.first(where: { $0.id == snapshot.packId })?.groups ?? [],
            questions: restoredQuestions
        )
        inSession = true
        isScoringInterview = false
        submitButton.isEnabled = true
        rolePopup.selectItem(withTitle: practiceRole(id: selectedRoleID)?.title ?? "AI Engineer")
        modePopup.selectItem(withTitle: selectedMode.title)
        updateModeDescription()
        rebuildTopicChips()
        syncTopicChips()
        rolePopup.isEnabled = false
        modePopup.isEnabled = false
        countPopup.isEnabled = false
        topicButtons.forEach { $0.isEnabled = false }

        restoreLearnPhase(for: questionIndex)
        displayQuestion(at: questionIndex)
        let question = sessionQuestions[questionIndex]
        statusLabel.stringValue = sessionPositionText(for: question)
        sessionModePill.stringValue = sessionModeTitle
        progressView.total = max(1, baseQuestionCount)
        progressView.completed = min(baseQuestionCount, questionIndex)
        progressView.currentIndex = questionIndex
        progressView.queuedReviews = max(0, sessionQuestions.count - baseQuestionCount)
        updateSessionControls()
        relayout()
        NSAccessibility.post(element: view as Any, notification: .layoutChanged)
        DispatchQueue.main.async { [weak self] in self?.focusResponseIfAppropriate() }
        if persist { saveSessionSnapshot() }
    }

    @objc private func undoLastRating() {
        guard let snapshot = makeSessionSnapshot(),
              let undo = snapshot.lastRatingUndo,
              snapshot.answers.indices.contains(undo.answerCountBeforeRating),
              var restored = practiceSnapshotAfterUndoingLastRating(snapshot, updatedAt: Date()) else {
            statusLabel.stringValue = "There is no rating to undo."
            return
        }
        let ratedAnswer = snapshot.answers[undo.answerCountBeforeRating]
        if ratedAnswer.recallRating == .again,
           undo.requeuedQuestionKeysBeforeRating == nil {
            let key = practiceRecallReviewKey(
                packId: undo.question.packId,
                questionId: undo.question.questionId
            )
            restored.requeuedQuestionKeys.removeAll { $0 == key }
        }
        restoreSession(from: restored, persist: true)
        statusLabel.stringValue = "Last rating undone. Review and choose again."
    }

    private func refreshSelectionStatus() {
        let pool = currentPool()
        let runCount = min(selectedCount, pool.count)
        let topics = Set(pool.map(\.groupId))
        let perTopic = topics.isEmpty ? 0 : (runCount + topics.count - 1) / topics.count
        let names = selectableTopics().filter { selectedGroupIDs.contains($0.id) }.map(\.title)
        let roleTitle = practiceRole(id: selectedRoleID)?.title ?? "Practice"
        let minutesPerQuestion = selectedMode == .learn ? 1.0 : 2.0
        let estimatedMinutes = max(1, Int(ceil(Double(runCount) * minutesPerQuestion)))
        if runCount < topics.count {
            statusLabel.stringValue = "\(roleTitle) · \(selectedMode.title) · \(runCount) of \(topics.count) topics · ~\(estimatedMinutes) min"
            statusLabel.toolTip = "Increase Questions to at least \(topics.count) to cover every selected topic. Selected: \(names.joined(separator: ", "))"
        } else {
            statusLabel.stringValue = "\(roleTitle) · \(selectedMode.title) · \(topics.count) topics · \(runCount) questions (~\(perTopic) per topic) · ~\(estimatedMinutes) min"
            statusLabel.toolTip = names.joined(separator: ", ")
        }
        if !inSession { updateIdlePlan() }
    }

    @objc private func modeChanged() {
        selectedMode = practiceRunMode(id: (modePopup.selectedItem?.representedObject as? String) ?? PracticeRunMode.learn.rawValue)
        updateModeDescription()
        refreshSelectionStatus()
    }

    private func updateModeDescription() {
        switch selectedMode {
        case .learn:
            subtitleLabel.stringValue = "Active Recall lets you answer first, compare key ideas, repair gaps, and schedule the next review."
        case .rehearse:
            subtitleLabel.stringValue = "Voice Rehearsal practices a spoken answer, then uses Key Ideas and one-gap repair before retrying."
        case .interview:
            subtitleLabel.stringValue = "Interview mode uses typed or spoken answers and scores them without showing learning help."
        }
    }

    @objc private func targetDateToggled() {
        let enabled = targetDateToggle.state == .on
        targetDatePicker.isEnabled = enabled
        sessionTargetDate = enabled ? targetDatePicker.dateValue : nil
        refreshSelectionStatus()
        updateIdlePlan()
    }

    @objc private func targetDateChanged() {
        if targetDateToggle.state == .on {
            sessionTargetDate = targetDatePicker.dateValue
        }
        updateIdlePlan()
    }

    @objc private func startRun() {
        let pool = currentPool()
        guard !pool.isEmpty else {
            statusLabel.stringValue = "Tick at least one topic."
            return
        }
        guard confirmReplacingSavedSessionIfNeeded() else { return }
        let latestRecall = isRecallMode
            ? practiceLatestRecallAnswers(from: store.allRuns())
            : [:]
        let recallAttempts = isRecallMode
            ? practiceRecallAttempts(from: store.allRuns())
            : [:]
        let selectionDate = Date()
        var selectionPool = pool
        var desiredCount = selectedCount
        if isRecallMode {
            let actionable = pool.filter { question in
                let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
                return practiceMasteryState(
                    latestAnswer: latestRecall[key],
                    attempts: recallAttempts[key, default: []],
                    now: selectionDate
                ) != .solid
            }
            if !actionable.isEmpty {
                selectionPool = actionable
                desiredCount = min(
                    selectedCount,
                    practiceTodaysPlan(
                        questions: actionable,
                        latestAnswers: latestRecall,
                        attemptsByQuestion: recallAttempts,
                        now: selectionDate,
                        maximumQuestions: selectedCount
                    ).recommendedCount
                )
            }
        }
        let groupIds = Array(selectedGroupIDs)
        let selectedQuestions = interviewOrderedPracticeSelection(
            questions: selectionPool,
            count: desiredCount,
            topicOf: { practiceTopicKey(for: $0, groupIds: groupIds) },
            shuffle: { questions in
                if self.isRecallMode {
                    return practicePrioritizedRecallQuestions(
                        questions,
                        latestAnswers: latestRecall,
                        now: selectionDate
                    )
                }
                return questions.shuffled()
            }
        )
        beginSession(questions: selectedQuestions, sessionTitle: "Study book")
    }

    private func confirmReplacingSavedSessionIfNeeded() -> Bool {
        guard !inSession, let snapshot = store.inProgressSession(), snapshot.canResume else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Start a new Practice session?"
        alert.informativeText = "A saved \(snapshot.mode.title) session is waiting at question \(snapshot.currentQuestionIndex + 1) of \(snapshot.baseQuestionCount)."
        alert.addButton(withTitle: "Start New")
        alert.addButton(withTitle: "Resume Saved")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if store.clearInProgressSession() { return true }
            statusLabel.stringValue = "Could not replace the saved session. Try again."
            return false
        case .alertSecondButtonReturn:
            resumeSavedSession()
            return false
        default:
            return false
        }
    }

    private func beginSession(
        questions: [PracticeQuestion],
        sessionTitle: String
    ) {
        guard !questions.isEmpty else {
            statusLabel.stringValue = "No matching questions are available for this session."
            return
        }
        sessionQuestions = questions
        let study = bank.packs.first(where: { $0.id == "study-book" })
        sessionPack = PracticeTopicPack(
            id: "study-book",
            title: "\(sessionTitle) · \(sessionQuestions.count)",
            blurb: study?.blurb ?? "",
            groups: study?.groups ?? [],
            questions: sessionQuestions
        )
        sessionAnswers = []
        sessionStartedAt = Date()
        sessionSnapshotID = UUID().uuidString
        sessionTargetDate = targetDateToggle.state == .on ? targetDatePicker.dateValue : nil
        lastRatingUndo = nil
        awaitingCompletion = false
        questionIndex = 0
        viewingIndex = 0
        baseQuestionCount = sessionQuestions.count
        burstIDs = (0..<sessionQuestions.count).map { _ in UUID() }
        inSession = true
        isScoringInterview = false
        submitButton.isEnabled = true
        if isRecallMode {
            learnPhase = .answering
            recallDrafts = sessionQuestions.map { _ in "" }
            recallUsedHelp = sessionQuestions.map { _ in false }
            recallResponses = sessionQuestions.map { _ in nil }
            recallConfidences = sessionQuestions.map { _ in nil }
            recallCoverageOverrides = sessionQuestions.map { _ in [] }
            recallRevealed = sessionQuestions.map { _ in false }
            recallRepairDrafts = sessionQuestions.map { _ in "" }
            recallRepairing = sessionQuestions.map { _ in false }
            recallRepairIdeaIndices = sessionQuestions.map { _ in nil }
            recallRequeuedQuestionIDs = []
        } else {
            recallDrafts = sessionQuestions.map { _ in "" }
            recallUsedHelp = []
            recallResponses = []
            recallConfidences = []
            recallCoverageOverrides = []
            recallRevealed = []
            recallRepairDrafts = []
            recallRepairing = []
            recallRepairIdeaIndices = []
            recallRequeuedQuestionIDs = []
        }
        startButton.isEnabled = false
        rolePopup.isEnabled = false
        modePopup.isEnabled = false
        countPopup.isEnabled = false
        topicButtons.forEach { $0.isEnabled = false }
        updateSessionControls()
        presentCurrentQuestion()
        saveSessionSnapshot()
    }

    private func updateSessionControls() {
        let active = inSession
        resumeButton.isHidden = active || store.inProgressSession() == nil
        contrastButton.isHidden = active
        helpButton.isHidden = true
        recordButton.isHidden = !active || isRecallMode
        submitButton.isHidden = !active || isRecallMode
        endButton.isHidden = !active || isRecallMode
        recordButton.isEnabled = active && !isTranscribing && !isScoringInterview
        submitButton.isEnabled = active && !isTranscribing && !isScoringInterview

        recallRevealButton.isHidden = true
        recallAgainButton.isHidden = true
        recallHardButton.isHidden = true
        recallGotItButton.isHidden = true
        recallEditButton.isHidden = true
        recallDontKnowButton.isHidden = true
        recallRecordButton.isHidden = true
        recallRevealButton.isEnabled = !isTranscribing
        recallDontKnowButton.isEnabled = !isTranscribing
        recallRecordButton.isEnabled = !isTranscribing
        if awaitingCompletion {
            recordButton.isHidden = true
            submitButton.isHidden = true
            endButton.isHidden = true
            endHeaderButton.title = "Finish"
            return
        }
        endHeaderButton.title = "Exit"
        if active && isRecallMode {
            switch learnPhase {
            case .answering:
                recallRevealButton.isHidden = false
                recallDontKnowButton.isHidden = false
                recallRecordButton.isHidden = false
                if !isRecording {
                    recallRecordButton.title = selectedMode == .rehearse ? "Start speaking" : "Answer aloud"
                }
            case .reviewing:
                recallAgainButton.isHidden = false
                recallHardButton.isHidden = false
                recallGotItButton.isHidden = false
                recallEditButton.isHidden = false
                let isRepairing = recallRepairing.indices.contains(questionIndex)
                    && recallRepairing[questionIndex]
                recallAgainButton.isEnabled = !isRepairing
                recallHardButton.isEnabled = !isRepairing
                recallGotItButton.isEnabled = !isRepairing
            }
        }
    }

    private func presentCurrentQuestion() {
        usedHelp = false
        helpText = ""
        helpButton.isEnabled = true
        questionCard.answerView.string = ""
        guard questionIndex < sessionQuestions.count else {
            finishRun()
            return
        }
        restoreLearnPhase(for: questionIndex)
        viewingIndex = questionIndex
        displayQuestion(at: viewingIndex)
        let question = sessionQuestions[questionIndex]
        statusLabel.stringValue = sessionPositionText(for: question)
        sessionModePill.stringValue = sessionModeTitle
        progressView.total = max(1, baseQuestionCount)
        progressView.completed = min(baseQuestionCount, questionIndex)
        progressView.currentIndex = questionIndex
        progressView.queuedReviews = max(0, sessionQuestions.count - baseQuestionCount)
        progressView.setAccessibilityLabel(sessionPositionText(for: question))
        updateSessionControls()
        refreshBurst()
        relayout()
        NSAccessibility.post(element: isRecallMode ? recallCard as Any : questionCard as Any, notification: .layoutChanged)
        DispatchQueue.main.async { [weak self] in self?.focusResponseIfAppropriate() }
    }

    private func restoreLearnPhase(for index: Int) {
        guard isRecallMode,
              sessionQuestions.indices.contains(index),
              recallDrafts.indices.contains(index),
              recallRevealed.indices.contains(index),
              recallRevealed[index] else {
            learnPhase = .answering
            return
        }
        let response = recallResponses.indices.contains(index)
            ? (recallResponses[index]?.current ?? recallDrafts[index])
            : recallDrafts[index]
        let overrides = recallCoverageOverrides.indices.contains(index)
            ? recallCoverageOverrides[index]
            : []
        learnPhase = .reviewing(practiceRecallReview(
            for: sessionQuestions[index],
            answer: response,
            coverageOverrides: overrides
        ))
    }

    private func sessionPositionText(for question: PracticeQuestion) -> String {
        let position: String
        if questionIndex < baseQuestionCount {
            position = "Question \(questionIndex + 1) of \(baseQuestionCount)"
        } else {
            let retryTotal = max(1, sessionQuestions.count - baseQuestionCount)
            position = "Review \(questionIndex - baseQuestionCount + 1) of \(retryTotal)"
        }
        let group = groupTitle(for: question)
        let topic = question.topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !topic.isEmpty, topic.localizedCaseInsensitiveCompare(group) != .orderedSame {
            return "\(position) · \(group) · \(topic)"
        }
        return "\(position) · \(group)"
    }

    private func displayQuestion(at index: Int) {
        guard sessionQuestions.indices.contains(index) else { return }
        let question = sessionQuestions[index]
        let topic = question.topicTitle.isEmpty ? (sessionPack?.title ?? "Practice") : question.topicTitle
        let editable = inSession && index == questionIndex && !awaitingCompletion

        if isRecallMode {
            questionCard.isHidden = true
            recallCard.isHidden = false
            let response = recallDrafts.indices.contains(index) ? recallDrafts[index] : ""
            switch learnPhase {
            case .answering:
                let confidence = recallConfidences.indices.contains(index) ? recallConfidences[index] : nil
                recallCard.showPrompt(
                    question: question.text,
                    response: response,
                    confidence: confidence,
                    showsConfidencePicker: true
                )
            case .reviewing(let review):
                updateRecallRatingButtonTitles(for: question)
                recallCard.showReview(
                    question: question.text,
                    response: recallResponses.indices.contains(index) ? (recallResponses[index]?.current ?? response) : response,
                    review: review,
                    coverageIsEstimated: true,
                    allowsManualCoverage: true
                )
                if recallRepairing.indices.contains(index), recallRepairing[index] {
                    let savedIndex = recallRepairIdeaIndices.indices.contains(index)
                        ? recallRepairIdeaIndices[index]
                        : nil
                    let repairIndex: Int?
                    if let savedIndex {
                        repairIndex = review.keyIdeas.indices.contains(savedIndex)
                            && review.covered.indices.contains(savedIndex)
                            && !review.covered[savedIndex]
                            ? savedIndex
                            : nil
                    } else {
                        // Older snapshots did not record a target; recover them once.
                        repairIndex = review.covered.firstIndex(of: false)
                    }
                    if let repairIndex, review.keyIdeas.indices.contains(repairIndex) {
                        if recallRepairIdeaIndices.indices.contains(index) {
                            recallRepairIdeaIndices[index] = repairIndex
                        }
                        recallCard.beginGapRepair(
                            missedIdea: review.keyIdeas[repairIndex],
                            draft: recallRepairDrafts.indices.contains(index) ? recallRepairDrafts[index] : ""
                        )
                    } else {
                        recallRepairing[index] = false
                        if recallRepairIdeaIndices.indices.contains(index) { recallRepairIdeaIndices[index] = nil }
                        if recallRepairDrafts.indices.contains(index) { recallRepairDrafts[index] = "" }
                        recallCard.endGapRepair()
                    }
                }
                let isRepairing = recallRepairing.indices.contains(index) && recallRepairing[index]
                recallEditButton.title = isRepairing
                    ? "Cancel repair"
                    : (review.covered.contains(false) ? "Repair one gap" : "Edit response")
            }
            updateSessionControls()
            return
        }

        recallCard.isHidden = true
        questionCard.isHidden = false
        let answered = sessionAnswers.indices.contains(index)
        let interviewEditable = editable && !answered && !isScoringInterview
        let existingAnswer = answered
            ? sessionAnswers[index].answer
            : (recallDrafts.indices.contains(index) ? recallDrafts[index] : (editable ? questionCard.answerView.string : ""))
        questionCard.showQuestion(
            topic: topic,
            index: index + 1,
            total: sessionQuestions.count,
            question: question.text,
            source: practiceQuestionSourceLine(question, groupTitle: groupTitle(for: question)),
            help: nil,
            answer: existingAnswer,
            editable: interviewEditable,
            helpCaption: "ANSWER · 0.4×"
        )
        helpButton.isEnabled = false
        recordButton.isEnabled = interviewEditable && selectedMode == .interview
        submitButton.isEnabled = interviewEditable && practiceShowsSubmitButton(in: selectedMode) && !isTranscribing
    }

    private func updateRecallRatingButtonTitles(for question: PracticeQuestion, now: Date = Date()) {
        let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        let priorAttempts = practiceRecallAttempts(from: store.allRuns())[key, default: []]
            + sessionAnswers.filter { practiceRecallReviewKey(packId: $0.packId, questionId: $0.questionId) == key }
        let confidence = recallConfidences.indices.contains(questionIndex) ? recallConfidences[questionIndex] : nil
        func intervalTitle(_ rating: PracticeRecallRating) -> String {
            let due = practiceAdaptiveNextReviewDate(
                for: rating,
                priorAttempts: priorAttempts,
                confidence: confidence,
                from: now,
                targetDate: sessionTargetDate
            )
            let seconds = max(0, due.timeIntervalSince(now))
            if seconds < 60 * 60 {
                return "\(max(1, Int(ceil(seconds / 60)))) min"
            }
            if seconds < 36 * 60 * 60 { return "tomorrow" }
            return "\(max(2, Int(ceil(seconds / (24 * 60 * 60))))) days"
        }
        recallAgainButton.title = "Again · \(intervalTitle(.again))"
        recallHardButton.title = "Hard · \(intervalTitle(.hard))"
        recallGotItButton.title = "Got it · \(intervalTitle(.gotIt))"
    }

    private func refreshBurst() {
        guard !sessionQuestions.isEmpty else {
            burstView.update(entries: [], selectedID: nil)
            return
        }
        var entries: [QuestionBurstEntry] = []
        for (index, question) in sessionQuestions.enumerated() {
            let phase: QuestionBurstPhase
            if index < questionIndex {
                phase = .ready
            } else if index == questionIndex {
                phase = inSession ? .answering : .ready
            } else {
                phase = .queued
            }
            entries.append(QuestionBurstEntry(
                id: burstIDs[index],
                sequence: index + 1,
                question: question.text,
                topic: question.topicTitle,
                detectedAt: Date(),
                phase: phase,
                answer: "",
                latencyMs: nil
            ))
        }
        let windowStart = max(0, min(viewingIndex, max(0, entries.count - 3)))
        let visible = Array(entries.dropFirst(windowStart).prefix(3))
        burstView.update(entries: visible, selectedID: burstIDs.indices.contains(viewingIndex) ? burstIDs[viewingIndex] : nil)
    }

    private func selectBurstQuestion(_ id: UUID) {
        guard let index = burstIDs.firstIndex(of: id) else { return }
        viewingIndex = index
        displayQuestion(at: index)
        refreshBurst()
    }

    @objc private func toggleRecord() {
        guard !isTranscribing, !isScoringInterview else {
            statusLabel.stringValue = isTranscribing ? "Finishing the current transcription…" : "Finishing the current score…"
            return
        }
        if isRecording {
            stopRecording()
            transcribeRecording()
        } else {
            startRecording()
        }
    }

    @objc private func requestHelp() {
        statusLabel.stringValue = "Help is shown as Key Ideas after you answer in Active Recall."
    }

    private func setCurrentRecallConfidence(_ confidence: PracticeRecallConfidence) {
        guard inSession, isRecallMode, recallConfidences.indices.contains(questionIndex) else { return }
        recallConfidences[questionIndex] = confidence
        scheduleSessionAutosave()
    }

    private func setCoverageOverride(index: Int, covered: Bool) {
        guard inSession,
              isRecallMode,
              recallCoverageOverrides.indices.contains(questionIndex),
              case .reviewing = learnPhase else { return }
        var overrides = recallCoverageOverrides[questionIndex]
        overrides.removeAll { $0.ideaIndex == index }
        overrides.append(PracticeCoverageOverride(ideaIndex: index, isCovered: covered))
        recallCoverageOverrides[questionIndex] = overrides

        let clearedActiveRepair = covered
            && recallRepairing.indices.contains(questionIndex)
            && recallRepairing[questionIndex]
            && recallRepairIdeaIndices.indices.contains(questionIndex)
            && recallRepairIdeaIndices[questionIndex] == index
        if clearedActiveRepair {
            recallRepairing[questionIndex] = false
            recallRepairIdeaIndices[questionIndex] = nil
            if recallRepairDrafts.indices.contains(questionIndex) {
                recallRepairDrafts[questionIndex] = ""
            }
            recallCard.endGapRepair()
        }

        let question = sessionQuestions[questionIndex]
        let response = recallDrafts.indices.contains(questionIndex) ? recallDrafts[questionIndex] : ""
        let review = practiceRecallReview(for: question, answer: response, coverageOverrides: overrides)
        learnPhase = .reviewing(review)
        displayQuestion(at: questionIndex)
        if clearedActiveRepair {
            statusLabel.stringValue = "Repair cleared because that idea is now covered."
        }
        scheduleSessionAutosave()
    }

    @objc private func beginGapRepair() {
        guard inSession, isRecallMode, case .reviewing(let review) = learnPhase else { return }
        if recallRepairing.indices.contains(questionIndex), recallRepairing[questionIndex] {
            cancelGapRepair()
            return
        }
        guard let missedIndex = review.covered.firstIndex(of: false), review.keyIdeas.indices.contains(missedIndex) else {
            editRecallResponse()
            return
        }
        if recallRepairing.indices.contains(questionIndex) {
            recallRepairing[questionIndex] = true
        }
        if recallRepairIdeaIndices.indices.contains(questionIndex) {
            recallRepairIdeaIndices[questionIndex] = missedIndex
        }
        let savedDraft = recallRepairDrafts.indices.contains(questionIndex) ? recallRepairDrafts[questionIndex] : ""
        recallCard.beginGapRepair(missedIdea: review.keyIdeas[missedIndex], draft: savedDraft)
        statusLabel.stringValue = "Repair one missed idea in your own words."
        recallEditButton.title = "Cancel repair"
        updateSessionControls()
        NSAccessibility.post(element: recallCard as Any, notification: .layoutChanged)
        saveSessionSnapshot()
    }

    private func cancelGapRepair() {
        guard recallRepairing.indices.contains(questionIndex) else { return }
        recallRepairing[questionIndex] = false
        if recallRepairIdeaIndices.indices.contains(questionIndex) {
            recallRepairIdeaIndices[questionIndex] = nil
        }
        if recallRepairDrafts.indices.contains(questionIndex) {
            recallRepairDrafts[questionIndex] = ""
        }
        recallCard.endGapRepair()
        if case .reviewing(let review) = learnPhase {
            recallEditButton.title = review.covered.contains(false) ? "Repair one gap" : "Edit response"
        }
        statusLabel.stringValue = "Repair cancelled. Your original response is unchanged."
        updateSessionControls()
        focusResponseIfAppropriate()
        saveSessionSnapshot()
    }

    private func updateGapRepairDraft(_ draft: String) {
        guard inSession, isRecallMode, recallRepairDrafts.indices.contains(questionIndex) else { return }
        recallRepairDrafts[questionIndex] = draft
        if recallRepairing.indices.contains(questionIndex) {
            recallRepairing[questionIndex] = true
        }
        scheduleSessionAutosave()
    }

    private func completeGapRepair(_ revision: String) {
        let cleaned = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              inSession,
              isRecallMode,
              questionIndex < sessionQuestions.count else {
            recallCard.setGapRepairValidationMessage("Add one sentence in your own words.")
            return
        }
        let existingResponse = recallResponses.indices.contains(questionIndex)
            ? recallResponses[questionIndex]
            : nil
        let initial = existingResponse?.initial ?? recallDrafts[questionIndex]
        let current = existingResponse?.current ?? initial
        let revised = current.isEmpty ? cleaned : "\(current)\n\(cleaned)"
        if recallResponses.indices.contains(questionIndex) {
            recallResponses[questionIndex] = PracticeRecallResponse(initial: initial, revised: revised)
        }
        if recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = revised
        }
        if recallCoverageOverrides.indices.contains(questionIndex) {
            recallCoverageOverrides[questionIndex] = []
        }
        if recallUsedHelp.indices.contains(questionIndex) {
            recallUsedHelp[questionIndex] = true
        }
        if recallRevealed.indices.contains(questionIndex) {
            recallRevealed[questionIndex] = false
        }
        if recallRepairing.indices.contains(questionIndex) {
            recallRepairing[questionIndex] = false
        }
        if recallRepairIdeaIndices.indices.contains(questionIndex) {
            recallRepairIdeaIndices[questionIndex] = nil
        }
        if recallRepairDrafts.indices.contains(questionIndex) {
            recallRepairDrafts[questionIndex] = ""
        }
        recallCard.endGapRepair()
        presentRecallReview(response: revised)
    }

    @objc private func revealRecallAnswer() {
        guard inSession, questionIndex < sessionQuestions.count, isRecallMode else { return }
        if isRecording {
            stopRecording()
            transcribeRecording()
            return
        }
        let response = recallCard.responseView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else {
            statusLabel.stringValue = "Write what you remember before revealing the key ideas."
            return
        }
        presentRecallReview(response: response)
    }

    @objc private func revealRecallWithoutAnswer() {
        guard inSession, questionIndex < sessionQuestions.count, isRecallMode else { return }
        if isRecording {
            stopRecording()
            transcribeRecording()
            return
        }
        guard !isTranscribing else { return }
        if recallConfidences.indices.contains(questionIndex) {
            recallConfidences[questionIndex] = .unsure
        }
        if recallCoverageOverrides.indices.contains(questionIndex) {
            recallCoverageOverrides[questionIndex] = []
        }
        presentRecallReview(response: "I don’t know yet.")
    }

    private func presentRecallReview(response: String) {
        if recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = response
        }
        if recallResponses.indices.contains(questionIndex) {
            if let existing = recallResponses[questionIndex] {
                recallResponses[questionIndex] = PracticeRecallResponse(
                    initial: existing.initial,
                    revised: response == existing.initial ? nil : response
                )
            } else {
                recallResponses[questionIndex] = PracticeRecallResponse(initial: response)
            }
        }
        if recallRevealed.indices.contains(questionIndex) {
            recallRevealed[questionIndex] = true
        }
        let overrides = recallCoverageOverrides.indices.contains(questionIndex)
            ? recallCoverageOverrides[questionIndex]
            : []
        let review = practiceRecallReview(
            for: sessionQuestions[questionIndex],
            answer: response,
            coverageOverrides: overrides
        )
        learnPhase = .reviewing(review)
        displayQuestion(at: questionIndex)
        let confidence = recallConfidences.indices.contains(questionIndex) ? recallConfidences[questionIndex] : nil
        if confidence == .very, review.coveredCount < review.keyIdeas.count {
            statusLabel.stringValue = "Confident gap · repair the first missed idea before rating."
        } else if confidence == .unsure, review.score >= 0.8 {
            statusLabel.stringValue = "Stronger than expected · you covered most key ideas."
        } else {
            statusLabel.stringValue = sessionPositionText(for: sessionQuestions[questionIndex])
        }
        updateSessionControls()
        relayout()
        NSAccessibility.post(element: recallCard as Any, notification: .layoutChanged)
        DispatchQueue.main.async { [weak self] in self?.focusResponseIfAppropriate() }
        saveSessionSnapshot()
    }

    @objc private func submitAnswer() {
        guard inSession, questionIndex < sessionQuestions.count else { return }
        if isRecallMode {
            revealRecallAnswer()
            return
        }
        guard practiceShowsSubmitButton(in: selectedMode) else { return }
        guard submitButton.isEnabled else { return }
        if isRecording {
            stopRecording()
            transcribeRecording { [weak self] in
                guard let self else { return }
                if self.canPresentPracticeUI?() == true {
                    self.submitAnswer()
                } else {
                    self.saveSessionSnapshot()
                }
            }
            return
        }
        let answer = questionCard.answerView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            statusLabel.stringValue = "Record or type an answer first."
            return
        }
        statusLabel.stringValue = "Scoring…"
        isScoringInterview = true
        submitButton.isEnabled = false
        recordButton.isEnabled = false
        questionCard.answerView.isEditable = false
        let question = sessionQuestions[questionIndex]
        let helped = usedHelp
        let expectedSnapshotID = sessionSnapshotID
        let expectedQuestionIndex = questionIndex
        let expectedQuestionKey = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        Task { [weak self] in
            let judged = await self?.judge(question: question.text, answer: answer, rubric: question.rubric) ?? (
                score: heuristicPracticeRawScore(question: question.text, answer: answer),
                feedback: "Local score",
                strengths: [] as [String],
                gaps: [] as [String]
            )
            let penalty = applyHelpPenalty(rawScore: judged.score, usedHelp: helped)
            let scored = PracticeScoredAnswer(
                questionId: question.id,
                packId: question.packId,
                question: question.text,
                answer: answer,
                usedHelp: penalty.usedHelp,
                mark: penalty.mark,
                rawScore: penalty.rawScore,
                finalScore: penalty.finalScore,
                feedback: judged.feedback,
                strengths: judged.strengths,
                gaps: judged.gaps
            )
            DispatchQueue.main.async {
                guard let self,
                      self.inSession,
                      self.sessionSnapshotID == expectedSnapshotID,
                      self.questionIndex == expectedQuestionIndex,
                      self.sessionQuestions.indices.contains(expectedQuestionIndex),
                      practiceRecallReviewKey(
                        packId: self.sessionQuestions[expectedQuestionIndex].packId,
                        questionId: self.sessionQuestions[expectedQuestionIndex].id
                      ) == expectedQuestionKey else { return }
                self.sessionAnswers.append(scored)
                self.isScoringInterview = false
                self.submitButton.isEnabled = true
                if self.questionIndex + 1 >= self.sessionQuestions.count {
                    self.awaitingCompletion = true
                    self.updateSessionControls()
                    self.statusLabel.stringValue = "Answer scored · finish the run when ready."
                    self.saveSessionSnapshot()
                    self.relayout()
                    self.focusResponseIfAppropriate()
                } else {
                    self.questionIndex += 1
                    self.presentCurrentQuestion()
                    self.saveSessionSnapshot()
                }
            }
        }
    }

    @objc private func rateRecallAgain() {
        rateRecall(.again)
    }

    @objc private func rateRecallHard() {
        rateRecall(.hard)
    }

    @objc private func rateRecallGotIt() {
        rateRecall(.gotIt)
    }

    @objc private func editRecallResponse() {
        guard inSession, isRecallMode, questionIndex < sessionQuestions.count else { return }
        guard case .reviewing = learnPhase else { return }
        if recallUsedHelp.indices.contains(questionIndex) {
            recallUsedHelp[questionIndex] = true
        }
        if recallRevealed.indices.contains(questionIndex) {
            recallRevealed[questionIndex] = false
        }
        if recallRepairing.indices.contains(questionIndex) {
            recallRepairing[questionIndex] = false
        }
        if recallRepairDrafts.indices.contains(questionIndex) {
            recallRepairDrafts[questionIndex] = ""
        }
        if recallRepairIdeaIndices.indices.contains(questionIndex) {
            recallRepairIdeaIndices[questionIndex] = nil
        }
        if recallCoverageOverrides.indices.contains(questionIndex) {
            recallCoverageOverrides[questionIndex] = []
        }
        learnPhase = .answering
        displayQuestion(at: questionIndex)
        statusLabel.stringValue = "Editing after reveal · your original answer is preserved."
        updateSessionControls()
        relayout()
        NSAccessibility.post(element: recallCard as Any, notification: .layoutChanged)
        DispatchQueue.main.async { [weak self] in self?.focusResponseIfAppropriate() }
        saveSessionSnapshot()
    }

    private func rateRecall(_ rating: PracticeRecallRating) {
        guard inSession, isRecallMode, questionIndex < sessionQuestions.count else { return }
        guard case .reviewing(let review) = learnPhase else { return }
        let question = sessionQuestions[questionIndex]
        let response = recallDrafts.indices.contains(questionIndex) ? recallDrafts[questionIndex] : ""
        let helped = recallUsedHelp.indices.contains(questionIndex) && recallUsedHelp[questionIndex]
        let rawScore = review.keyIdeas.isEmpty ? rating.fallbackScore : review.score
        let reviewedAt = Date()
        let responseRecord = recallResponses.indices.contains(questionIndex)
            ? (recallResponses[questionIndex] ?? PracticeRecallResponse(initial: response))
            : PracticeRecallResponse(initial: response)
        let confidence = recallConfidences.indices.contains(questionIndex) ? recallConfidences[questionIndex] : nil
        let overrides = recallCoverageOverrides.indices.contains(questionIndex)
            ? recallCoverageOverrides[questionIndex]
            : []
        let strengths = review.keyIdeas.enumerated().compactMap { index, idea in
            review.covered.indices.contains(index) && review.covered[index] ? idea : nil
        }
        let gaps = review.keyIdeas.enumerated().compactMap { index, idea in
            review.covered.indices.contains(index) && !review.covered[index] ? idea : nil
        }
        let feedback: String
        if review.keyIdeas.isEmpty {
            feedback = "Self-rated \(rating.title)"
        } else {
            feedback = "Covered \(review.coveredCount) of \(review.keyIdeas.count) key ideas · \(rating.title)"
        }
        let questionKey = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        let priorAttempts = practiceRecallAttempts(from: store.allRuns())[questionKey, default: []]
            + sessionAnswers.filter { practiceRecallReviewKey(packId: $0.packId, questionId: $0.questionId) == questionKey }
        let nextReviewAt = practiceAdaptiveNextReviewDate(
            for: rating,
            priorAttempts: priorAttempts,
            confidence: confidence,
            from: reviewedAt,
            targetDate: sessionTargetDate
        )

        let previousState = makeSessionQuestionState(at: questionIndex)
        lastRatingUndo = previousState.map {
            PracticeRatingUndoMetadata(
                question: $0.reference,
                questionIndex: questionIndex,
                answerCountBeforeRating: sessionAnswers.count,
                questionCountBeforeRating: sessionQuestions.count,
                previousQuestionState: $0,
                ratedAt: reviewedAt,
                requeuedQuestionKeysBeforeRating: Array(recallRequeuedQuestionIDs).sorted()
            )
        }

        sessionAnswers.append(PracticeScoredAnswer(
            questionId: question.id,
            packId: question.packId,
            question: question.text,
            answer: response,
            usedHelp: helped,
            mark: helped ? .yellow : .none,
            rawScore: rawScore,
            finalScore: rawScore,
            feedback: feedback,
            strengths: strengths,
            gaps: gaps,
            recallRating: rating,
            nextReviewAt: nextReviewAt,
            recallResponse: responseRecord,
            recallConfidence: confidence,
            coverageOverrides: overrides,
            reviewedAt: reviewedAt
        ))

        let retryKey = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
        if rating == .again, recallRequeuedQuestionIDs.insert(retryKey).inserted {
            sessionQuestions.append(question)
            recallDrafts.append("")
            recallUsedHelp.append(false)
            recallResponses.append(nil)
            recallConfidences.append(nil)
            recallCoverageOverrides.append([])
            recallRevealed.append(false)
            recallRepairDrafts.append("")
            recallRepairing.append(false)
            recallRepairIdeaIndices.append(nil)
            burstIDs.append(UUID())
        }

        if questionIndex + 1 >= sessionQuestions.count {
            awaitingCompletion = true
            updateSessionControls()
            statusLabel.stringValue = "Rating saved · Undo it or finish the run."
            saveSessionSnapshot()
            relayout()
            DispatchQueue.main.async { [weak self] in self?.focusResponseIfAppropriate() }
        } else {
            questionIndex += 1
            presentCurrentQuestion()
            saveSessionSnapshot()
        }
    }

    @objc private func endRunTapped() {
        guard inSession else { return }
        guard !isTranscribing, !isScoringInterview else {
            statusLabel.stringValue = "Wait for the current Practice result to finish."
            return
        }
        if isRecording {
            stopRecording()
            transcribeRecording { [weak self] in
                guard let self else { return }
                if self.canPresentPracticeUI?() == true {
                    self.endRunTapped()
                } else {
                    self.saveSessionSnapshot()
                }
            }
            return
        }
        if awaitingCompletion {
            finishRun()
            return
        }
        if isRecallMode,
           recallDrafts.indices.contains(questionIndex) {
            recallDrafts[questionIndex] = recallCard.responseView.string
        }
        let snapshotSavedBeforePrompt = saveSessionSnapshot()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Leave this Practice session?"
        alert.informativeText = "Save it to resume later, keep practicing, or discard the unfinished session."
        alert.addButton(withTitle: "Save & Exit")
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Discard")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if snapshotSavedBeforePrompt || saveSessionSnapshot() {
                onLeaveToTimeline?()
            } else {
                statusLabel.stringValue = "Could not save this Practice session. Keep practicing or choose Discard."
                focusResponseIfAppropriate()
            }
        case .alertThirdButtonReturn:
            resetIdle(status: "Practice session discarded.")
        default:
            focusResponseIfAppropriate()
        }
    }

    private func finishRun() {
        autosaveWorkItem?.cancel()
        recordingPermissionGeneration += 1
        transcriptionGeneration += 1
        isTranscribing = false
        isScoringInterview = false
        stopRecording()
        guard let pack = sessionPack else {
            resetIdle(status: "No pack.")
            return
        }
        let run = makePracticeRunRecord(
            id: sessionSnapshotID,
            pack: pack,
            startedAt: sessionStartedAt,
            finishedAt: Date(),
            answers: sessionAnswers,
            mode: selectedMode,
            targetDate: sessionTargetDate
        )
        guard store.append(run) else {
            statusLabel.stringValue = "Could not save the run. Your resumable session is still available."
            saveSessionSnapshot()
            return
        }
        let clearedSnapshot = store.clearInProgressSession()
        lastRatingUndo = nil
        awaitingCompletion = false
        inSession = false
        startButton.isEnabled = true
        rolePopup.isEnabled = true
        modePopup.isEnabled = true
        countPopup.isEnabled = true
        topicButtons.forEach { $0.isEnabled = true }
        recallCard.isHidden = true
        questionCard.isHidden = false
        updateSessionControls()
        questionCard.showReport(formatReport(run))
        statusLabel.stringValue = clearedSnapshot
            ? String(format: "Run saved · %.0f%% overall", run.overallScore * 100)
            : String(format: "Run saved · %.0f%% overall · old resume data could not be cleared", run.overallScore * 100)
        refreshBurst()
        reloadHistory()
        relayout()
        NSAccessibility.post(element: questionCard as Any, notification: .layoutChanged)
        onRequestInputFocus?(questionCard.reportView)
    }

    private func resetIdle(status: String) {
        autosaveWorkItem?.cancel()
        recordingPermissionGeneration += 1
        transcriptionGeneration += 1
        isTranscribing = false
        stopRecording()
        let clearedSnapshot = store.clearInProgressSession()
        inSession = false
        sessionQuestions = []
        sessionAnswers = []
        recallDrafts = []
        recallUsedHelp = []
        recallResponses = []
        recallConfidences = []
        recallCoverageOverrides = []
        recallRevealed = []
        recallRepairDrafts = []
        recallRepairing = []
        recallRepairIdeaIndices = []
        recallRequeuedQuestionIDs = []
        baseQuestionCount = 0
        lastRatingUndo = nil
        awaitingCompletion = false
        usedHelp = false
        startButton.isEnabled = true
        rolePopup.isEnabled = true
        modePopup.isEnabled = true
        countPopup.isEnabled = true
        topicButtons.forEach { $0.isEnabled = true }
        recallCard.isHidden = true
        questionCard.isHidden = false
        updateSessionControls()
        burstIDs = []
        viewingIndex = 0
        questionCard.showIdle()
        burstView.update(entries: [], selectedID: nil)
        statusLabel.stringValue = clearedSnapshot ? status : "\(status) Saved resume data could not be cleared."
        updateIdlePlan()
        relayout()
        NSAccessibility.post(element: questionCard as Any, notification: .layoutChanged)
        onRequestInputFocus?(startButton)
    }

    private func formatReport(_ run: PracticeRunRecord) -> String {
        let mode = run.mode?.title ?? "Practice"
        var lines = [
            String(format: "Report · %@ · %@ · %.0f%% · %d assisted", mode, run.packTitle, run.overallScore * 100, run.helpedCount)
        ]
        for (index, answer) in run.answers.enumerated() {
            let mark = answer.usedHelp ? "  ASSISTED" : ""
            lines.append(String(
                format: "%d. %.0f%% (raw %.0f%%)%@ — %@",
                index + 1,
                answer.finalScore * 100,
                answer.rawScore * 100,
                mark,
                answer.feedback
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func reloadHistory() {
        let runs = store.allRuns().sorted { $0.finishedAt > $1.finishedAt }
        let latest = practiceLatestRecallAnswers(from: runs)
        let attempts = practiceRecallAttempts(from: runs)
        let summaries = practiceTopicMasterySummaries(
            questions: currentPool(),
            latestAnswers: latest,
            attemptsByQuestion: attempts
        ).sorted {
            if $0.dueCount != $1.dueCount { return $0.dueCount > $1.dueCount }
            if $0.learningCount != $1.learningCount { return $0.learningCount > $1.learningCount }
            return $0.topic.title < $1.topic.title
        }
        var lines = ["Topic mastery"]
        if summaries.isEmpty {
            lines.append("No practice data yet.")
        } else {
            for summary in summaries.prefix(8) {
                let percent = Int((summary.masteredFraction * 100).rounded())
                lines.append("\(summary.topic.title)  \(percent)% solid · \(summary.dueCount) due · \(summary.learningCount) learning")
            }
        }
        if let latestRun = runs.first {
            lines.append("")
            lines.append(String(format: "Latest · %@ · %.0f%%", shortDate(latestRun.finishedAt), latestRun.overallScore * 100))
        }
        historyLabel.stringValue = lines.joined(separator: "\n")
        practiceWeakButton.isEnabled = summaries.contains { $0.dueCount > 0 || $0.learningCount > 0 }
        chartView.points = []
        chartView.packPoints = []
        if !historyVisible {
            historyButton.title = historyButtonTitle()
        }
    }

    @objc private func startWeakPractice() {
        let latest = practiceLatestRecallAnswers(from: store.allRuns())
        let attempts = practiceRecallAttempts(from: store.allRuns())
        let now = Date()
        let weak = currentPool().filter { question in
            let key = practiceRecallReviewKey(packId: question.packId, questionId: question.id)
            let state = practiceMasteryState(
                latestAnswer: latest[key],
                attempts: attempts[key, default: []],
                now: now
            )
            return state == .due || state == .learning
        }
        let selection = Array(
            practicePrioritizedRecallQuestions(weak, latestAnswers: latest, now: now).prefix(5)
        )
        guard !selection.isEmpty else {
            statusLabel.stringValue = "No due or learning questions are available in the selected topics."
            return
        }
        guard confirmReplacingSavedSessionIfNeeded() else { return }
        selectedMode = .learn
        modePopup.selectItem(withTitle: selectedMode.title)
        updateModeDescription()
        selectedCount = 5
        countPopup.selectItem(withTag: selectedCount)
        historyVisible = false
        historyCard.isHidden = true
        beginSession(questions: selection, sessionTitle: "Weak concepts")
    }

    @objc private func startContrastPractice() {
        let pool = currentPool()
        let runs = store.allRuns()
        let latest = practiceLatestRecallAnswers(from: runs)
        let attempts = practiceRecallAttempts(from: runs)
        let selection = practiceContrastQuestionSelection(
            from: pool,
            latestAnswers: latest,
            attemptsByQuestion: attempts,
            pairLimit: max(1, min(3, selectedCount / 2))
        )
        guard !selection.isEmpty else {
            statusLabel.stringValue = "No strong comparison pair is available in the selected topics."
            return
        }
        guard confirmReplacingSavedSessionIfNeeded() else { return }
        selectedMode = .learn
        modePopup.selectItem(withTitle: selectedMode.title)
        updateModeDescription()
        beginSession(questions: selection, sessionTitle: "Contrast round")
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func makeClient() -> PracticeGroqClient? {
        guard let key = ApiKeyManager.shared.getKey(.groq), !key.isEmpty else { return nil }
        return PracticeGroqClient(apiKey: key)
    }

    private func judge(question: String, answer: String, rubric: String) async -> (score: Double, feedback: String, strengths: [String], gaps: [String]) {
        if let client = makeClient() {
            do {
                return try await client.judgeAnswer(question: question, answer: answer, rubric: rubric)
            } catch {
                let score = heuristicPracticeRawScore(question: question, answer: answer)
                return (score, "Local score (judge unavailable).", [], [])
            }
        }
        let score = heuristicPracticeRawScore(question: question, answer: answer)
        return (score, "Local score (no Groq key).", [], [])
    }

    // MARK: - Mic

    private func startRecording() {
        guard inSession, !isTranscribing, !isScoringInterview else { return }
        recordingPermissionGeneration += 1
        transcriptionGeneration += 1
        let expectedPermissionGeneration = recordingPermissionGeneration
        let expectedSnapshotID = sessionSnapshotID
        let expectedQuestionIndex = questionIndex
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self,
                      self.inSession,
                      self.recordingPermissionGeneration == expectedPermissionGeneration,
                      self.sessionSnapshotID == expectedSnapshotID,
                      self.questionIndex == expectedQuestionIndex else { return }
                guard granted else {
                    self.statusLabel.stringValue = "Microphone permission needed, or type your answer."
                    self.onRequestInputFocus?(self.isRecallMode ? self.recallCard.responseView : self.questionCard.answerView)
                    return
                }
                self.beginRecorder()
            }
        }
    }

    private func beginRecorder() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-\(UUID().uuidString).m4a")
        recordFileURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
            recordButton.title = "Stop"
            recallRecordButton.title = "Stop recording"
            statusLabel.stringValue = "Recording answer…"
        } catch {
            statusLabel.stringValue = "Could not record. Type your answer instead."
            onRequestInputFocus?(isRecallMode ? recallCard.responseView : questionCard.answerView)
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        recordButton.title = "Record"
        recallRecordButton.title = selectedMode == .rehearse ? "Start speaking" : "Answer aloud"
    }

    private func transcribeRecording(completion: (() -> Void)? = nil) {
        guard let url = recordFileURL, let data = try? Data(contentsOf: url), !data.isEmpty else {
            isTranscribing = false
            statusLabel.stringValue = "No audio captured. Type your answer."
            onRequestInputFocus?(isRecallMode ? recallCard.responseView : questionCard.answerView)
            completion?()
            return
        }
        transcriptionGeneration += 1
        let expectedTranscriptionGeneration = transcriptionGeneration
        isTranscribing = true
        updateSessionControls()
        statusLabel.stringValue = "Transcribing…"
        let expectedSnapshotID = sessionSnapshotID
        let expectedQuestionIndex = questionIndex
        let editorTextAtStart = isRecallMode ? recallCard.responseView.string : questionCard.answerView.string
        Task { [weak self] in
            var text = ""
            if let client = self?.makeClient() {
                do {
                    text = try await client.transcribe(audioData: data)
                } catch {
                    text = ""
                }
            }
            let captured = text
            DispatchQueue.main.async {
                guard let self,
                      self.inSession,
                      self.transcriptionGeneration == expectedTranscriptionGeneration,
                      self.sessionSnapshotID == expectedSnapshotID,
                      self.questionIndex == expectedQuestionIndex,
                      self.sessionQuestions.indices.contains(expectedQuestionIndex) else { return }
                self.isTranscribing = false
                self.updateSessionControls()
                let currentEditorText = self.isRecallMode
                    ? self.recallCard.responseView.string
                    : self.questionCard.answerView.string
                if currentEditorText != editorTextAtStart,
                   !currentEditorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.statusLabel.stringValue = "Transcript finished; your newer typed edits were kept."
                    self.scheduleSessionAutosave()
                    completion?()
                    return
                }
                if captured.isEmpty {
                    self.statusLabel.stringValue = "Transcription unavailable. Type your answer."
                    self.onRequestInputFocus?(self.isRecallMode ? self.recallCard.responseView : self.questionCard.answerView)
                } else {
                    if self.isRecallMode {
                        self.recallCard.responseView.string = captured
                        if self.recallDrafts.indices.contains(self.questionIndex) {
                            self.recallDrafts[self.questionIndex] = captured
                        }
                        self.statusLabel.stringValue = "Answer captured. Reveal the key ideas when ready."
                    } else {
                        self.questionCard.answerView.string = captured
                        self.statusLabel.stringValue = "Answer captured. Submit when ready."
                    }
                    self.scheduleSessionAutosave()
                    self.focusResponseIfAppropriate()
                }
                completion?()
            }
        }
    }
}

@available(macOS 14.0, *)
final class PracticeRootView: FlippedView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}

@available(macOS 14.0, *)
final class PracticeProgressChartView: NSView {
    var points: [CGFloat] = [] {
        didSet { needsDisplay = true }
    }
    var packPoints: [CGFloat] = [] {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.withAlphaComponent(0.06).setFill()
        bounds.fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        border.lineWidth = 1
        border.stroke()

        drawSeries(points, color: NSColor.appleGold, width: 2)
        drawSeries(packPoints, color: NSColor.systemTeal.withAlphaComponent(0.9), width: 1.5)

        let caption = "gold = all  ·  teal = pack"
        caption.draw(
            at: NSPoint(x: 10, y: 6),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55)
            ]
        )
    }

    private func drawSeries(_ values: [CGFloat], color: NSColor, width: CGFloat) {
        guard !values.isEmpty else { return }
        let inset: CGFloat = 14
        let w = bounds.width - inset * 2
        let h = bounds.height - inset * 2 - 12
        let path = NSBezierPath()
        for (index, value) in values.enumerated() {
            let x = inset + (values.count == 1 ? w / 2 : w * CGFloat(index) / CGFloat(values.count - 1))
            let y = inset + 12 + h * min(1, max(0, value))
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        color.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.stroke()
    }
}
