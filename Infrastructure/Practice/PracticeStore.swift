import Foundation

/// Isolated practice history. Lives under Documents/InterviewMaster/practice/, not live memory.json.
final class PracticeStore {
    static let shared = PracticeStore()

    private let queue = DispatchQueue(label: "com.interviewmaster.practicestore")
    private let runsFileURL: URL
    private let inProgressFileURL: URL
    private var runs: [PracticeRunRecord] = []
    private var inProgress: PracticeSessionSnapshot?
    /// A malformed history must never be replaced by a new, apparently empty history.
    /// Relaunch after repairing or removing the file is required before writes resume.
    private var runsLoadFailed = false
    /// Snapshot writes stay blocked only when malformed data could not be moved to safety.
    private var inProgressLoadFailed = false

    /// An injectable directory keeps persistence verifiable without touching the
    /// learner's real history. Production uses the same historical location.
    init(directoryURL: URL? = nil) {
        let dir = directoryURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/InterviewMaster/practice")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runsFileURL = dir.appendingPathComponent("runs.json")
        inProgressFileURL = dir.appendingPathComponent("in-progress.json")
        loadRuns()
        loadInProgress()
    }

    func allRuns() -> [PracticeRunRecord] {
        queue.sync { runs }
    }

    @discardableResult
    func append(_ run: PracticeRunRecord) -> Bool {
        queue.sync {
            guard !runsLoadFailed else {
                NSLog("⚠️ PracticeStore refused to save because runs.json did not load successfully.")
                return false
            }
            if let existingIndex = runs.firstIndex(where: { $0.id == run.id }) {
                guard runs[existingIndex] != run else { return true }
                let previous = runs[existingIndex]
                runs[existingIndex] = run
                if saveRuns() { return true }
                runs[existingIndex] = previous
                return false
            }
            runs.append(run)
            if saveRuns() {
                return true
            }
            runs.removeLast()
            return false
        }
    }

    func inProgressSession() -> PracticeSessionSnapshot? {
        queue.sync { inProgress }
    }

    /// Atomically replaces the single resumable session. Completed history remains
    /// in runs.json so older app versions can continue to read it.
    @discardableResult
    func saveInProgressSession(_ snapshot: PracticeSessionSnapshot) -> Bool {
        queue.sync {
            guard !inProgressLoadFailed else {
                NSLog("⚠️ PracticeStore refused to save because malformed in-progress data could not be preserved.")
                return false
            }
            guard saveInProgress(snapshot) else { return false }
            inProgress = snapshot
            return true
        }
    }

    @discardableResult
    func clearInProgressSession() -> Bool {
        queue.sync {
            guard FileManager.default.fileExists(atPath: inProgressFileURL.path) else {
                inProgress = nil
                inProgressLoadFailed = false
                return true
            }
            do {
                try FileManager.default.removeItem(at: inProgressFileURL)
                inProgress = nil
                inProgressLoadFailed = false
                return true
            } catch {
                NSLog("⚠️ PracticeStore failed to clear in-progress session: %@", error.localizedDescription)
                return false
            }
        }
    }

    func progressInputs(packId: String? = nil) -> [PracticeProgressInput] {
        allRuns().map {
            PracticeProgressInput(finishedAt: $0.finishedAt, score: $0.overallScore, packId: $0.packId)
        }.filter { packId == nil || $0.packId == packId }
    }

    private func loadRuns() {
        guard FileManager.default.fileExists(atPath: runsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: runsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = try decoder.decode([PracticeRunRecord].self, from: data)
        } catch {
            runsLoadFailed = true
            NSLog("⚠️ PracticeStore failed to load: %@", error.localizedDescription)
        }
    }

    private func loadInProgress() {
        guard FileManager.default.fileExists(atPath: inProgressFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: inProgressFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            inProgress = try decoder.decode(PracticeSessionSnapshot.self, from: data)
        } catch {
            let recoveryURL = inProgressFileURL.deletingLastPathComponent()
                .appendingPathComponent("in-progress-recovery-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: inProgressFileURL, to: recoveryURL)
                NSLog(
                    "⚠️ PracticeStore preserved malformed in-progress session at %@: %@",
                    recoveryURL.path,
                    error.localizedDescription
                )
            } catch let recoveryError {
                inProgressLoadFailed = true
                NSLog(
                    "⚠️ PracticeStore failed to load or preserve in-progress session: %@; %@",
                    error.localizedDescription,
                    recoveryError.localizedDescription
                )
            }
        }
    }

    private func saveRuns() -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(runs)
            try data.write(to: runsFileURL, options: .atomic)
            return true
        } catch {
            NSLog("⚠️ PracticeStore failed to save: %@", error.localizedDescription)
            return false
        }
    }

    private func saveInProgress(_ snapshot: PracticeSessionSnapshot) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: inProgressFileURL, options: .atomic)
            return true
        } catch {
            NSLog("⚠️ PracticeStore failed to save in-progress session: %@", error.localizedDescription)
            return false
        }
    }
}
