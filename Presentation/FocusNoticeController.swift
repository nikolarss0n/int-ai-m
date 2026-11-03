import Cocoa

/// The window's own voice. Errors used to go to a timeline nobody was looking at and confirmations to
/// nowhere; now they are one line in the header, where the eye already goes for status.
@available(macOS 14.0, *)
extension InterviewMasterDelegate {

    /// Says something in the header. `action` is what the notice's button does ("Undo", "Show").
    /// A less important notice does not cover a more important one: a saved session does not hide an error.
    func postFocusNotice(_ notice: FeedbackNotice, action: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.postFocusNotice(notice, action: action) }
            return
        }
        guard focusNoticeView != nil, focusNotices.show(notice, at: Date()) else { return }
        focusNoticeActions[notice.key] = action
        renderFocusNotice()
        announceForAccessibility([notice.message, notice.detail].compactMap { $0 }.joined(separator: ". "), urgent: notice.kind == .error)
    }

    /// The thing a notice is about has gone right again, so the notice goes.
    func resolveFocusNotice(_ key: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.resolveFocusNotice(key) }
            return
        }
        guard focusNotices.current?.key == key else { return }
        focusNotices.resolve(key)
        focusNoticeActions[key] = nil
        renderFocusNotice()
    }

    func dismissFocusNotice() {
        if let key = focusNotices.current?.key { focusNoticeActions[key] = nil }
        focusNotices.dismiss()
        renderFocusNotice()
    }

    func runFocusNoticeAction() {
        guard let key = focusNotices.current?.key else { return }
        let action = focusNoticeActions[key]
        dismissFocusNotice()
        action?()
    }

    /// Puts the board on screen and arranges for a notice that lasts a while to go when it is time.
    private func renderFocusNotice() {
        focusNoticeExpiry?.cancel()
        focusNoticeExpiry = nil
        focusNotices.expire(at: Date())
        let notice = focusNotices.current
        focusNoticeView.show(notice)
        focusHeaderTitleLabel?.isHidden = notice != nil
        focusHeaderOverlineLabel?.isHidden = notice != nil
        (focusHeaderView as? FocusHeaderView)?.needsLayout = true
        guard let expiry = focusNotices.expiry else { return }
        let work = DispatchWorkItem { [weak self] in self?.renderFocusNotice() }
        focusNoticeExpiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, expiry.timeIntervalSinceNow), execute: work)
    }
}
