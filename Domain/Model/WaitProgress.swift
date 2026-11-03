import Foundation

/// How long a wait has lasted decides what the interface says about it: at first only what is
/// happening, then the seconds, then that it is taking longer than usual.
enum WaitStage: Equatable {
    case brief, counting, stalled
}

enum WaitProgress {
    /// After this many seconds a wait shows how long it has been.
    static let showSecondsAfter: TimeInterval = 4
    /// After this many it says it is taking longer than usual.
    static let stalledAfter: TimeInterval = 10

    static func stage(elapsed: TimeInterval) -> WaitStage {
        if elapsed >= stalledAfter { return .stalled }
        if elapsed >= showSecondsAfter { return .counting }
        return .brief
    }

    /// "7s", and "1m 05s" once a minute has passed.
    static func format(_ elapsed: TimeInterval) -> String {
        let whole = max(0, Int(elapsed))
        return whole < 60 ? "\(whole)s" : String(format: "%dm %02ds", whole / 60, whole % 60)
    }

    /// What an answer card says about an answer that has not started to appear.
    static func answerStatus(queued: Bool, elapsed: TimeInterval, separator: String) -> String {
        if queued { return "Queued" }
        return status(brief: "Generating", stalled: "Still generating", elapsed: elapsed, separator: separator)
    }

    /// The same for a card too narrow for the whole line: once the wait has a length, the length is what
    /// is left, because the placeholder and the strip already say what is happening.
    static func answerStatusShort(queued: Bool, elapsed: TimeInterval) -> String {
        if queued { return "Queued" }
        return stage(elapsed: elapsed) == .brief ? "Generating" : format(elapsed)
    }

    /// What the code panel says about code that has not started to appear.
    static func codeStatus(elapsed: TimeInterval, separator: String) -> String {
        status(brief: "Writing", stalled: "Still writing", elapsed: elapsed, separator: separator)
    }

    private static func status(brief: String, stalled: String, elapsed: TimeInterval, separator: String) -> String {
        switch stage(elapsed: elapsed) {
        case .brief: return brief
        case .counting: return brief + separator + format(elapsed)
        case .stalled: return stalled + separator + format(elapsed)
        }
    }
}

/// Work that only earns an indicator once it has lasted a moment (a wait of a tenth of a second
/// flashes an indicator and is gone), and that stops earning one when nothing ever reports its end.
/// Time is passed in, so the rule can be tested without waiting.
struct DelayedActivity {
    let showAfter: TimeInterval
    let expireAfter: TimeInterval
    private var starts: [UUID: Date] = [:]

    init(showAfter: TimeInterval, expireAfter: TimeInterval) {
        self.showAfter = showAfter
        self.expireAfter = expireAfter
    }

    var isEmpty: Bool { starts.isEmpty }

    /// A second begin for the same work keeps the first start.
    mutating func begin(_ id: UUID, at now: Date) {
        if starts[id] == nil { starts[id] = now }
    }

    mutating func end(_ id: UUID) {
        starts[id] = nil
    }

    mutating func removeAll() {
        starts.removeAll()
    }

    func isShowing(at now: Date) -> Bool {
        starts.values.contains { age(of: $0, at: now) >= showAfter && age(of: $0, at: now) < expireAfter }
    }

    /// The next moment `isShowing` can change on its own, for scheduling a refresh.
    func nextChange(after now: Date) -> Date? {
        starts.values
            .flatMap { [$0.addingTimeInterval(showAfter), $0.addingTimeInterval(expireAfter)] }
            .filter { $0 > now }
            .min()
    }

    private func age(of start: Date, at now: Date) -> TimeInterval {
        now.timeIntervalSince(start)
    }
}
