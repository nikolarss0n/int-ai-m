import Foundation

/// One step's code inside a file, with where it starts so line numbers match the file once it is pasted.
struct CodeChunk: Equatable {
    var number: Int
    var why: String
    var code: String
    /// Zero-based line of the file this chunk starts on.
    var firstLine: Int
    /// The model repeated code from an earlier chunk, so appending it would duplicate lines.
    var repeatsEarlierCode: Bool
}

/// Consecutive steps that write the same file, read as that file.
struct CodeFileSection: Equatable {
    var fileName: String
    var language: String
    var chunks: [CodeChunk]

    /// The whole file. A blank line separates chunks, and `firstLine` counts it.
    var code: String {
        chunks.map(\.code).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

/// Steps are appended chunks, so neighbours in one file join into one block. A file that comes back
/// after another file starts a new section, because the steps are kept in typing order.
func groupCodeSteps(_ steps: [CodingInterviewStep]) -> [CodeFileSection] {
    var sections: [CodeFileSection] = []
    var nextLine = 0
    var seenLines: Set<String> = []

    for step in steps {
        if sections.last?.fileName != step.fileName {
            sections.append(CodeFileSection(fileName: step.fileName, language: step.language, chunks: []))
            nextLine = 0
            seenLines = []
        }
        let lines = step.code.isEmpty ? [] : step.code.components(separatedBy: "\n")
        let meaningful = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 2 }
        let repeated = meaningful.filter(seenLines.contains).count
        sections[sections.count - 1].chunks.append(CodeChunk(
            number: step.number, why: step.why, code: step.code, firstLine: nextLine,
            repeatsEarlierCode: meaningful.count >= 2 && repeated * 2 >= meaningful.count
        ))
        seenLines.formUnion(meaningful)
        if !lines.isEmpty { nextLine += lines.count + 1 }
    }
    return sections
}

/// What moved between two versions of a file, by zero-based line of the new version.
struct CodeLineChanges: Equatable {
    var changed: Set<Int> = []
    /// Lines were removed just before this line. It can be one past the last line.
    var removedBefore: Set<Int> = []
}

/// Compares two versions of a file line by line. Returns nil for a rewrite, where marking nearly every
/// line says nothing, and for files too long to compare while the interface waits.
func codeLineChanges(from old: String, to new: String) -> CodeLineChanges? {
    let oldLines = old.components(separatedBy: "\n")
    let newLines = new.components(separatedBy: "\n")
    guard oldLines.count * newLines.count <= 400_000 else { return nil }

    var lengths = Array(repeating: Array(repeating: 0, count: newLines.count + 1), count: oldLines.count + 1)
    for i in stride(from: oldLines.count - 1, through: 0, by: -1) {
        for j in stride(from: newLines.count - 1, through: 0, by: -1) {
            lengths[i][j] = oldLines[i] == newLines[j]
                ? lengths[i + 1][j + 1] + 1
                : max(lengths[i + 1][j], lengths[i][j + 1])
        }
    }

    func isBlank(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces).isEmpty }
    var changes = CodeLineChanges()
    var keptLines = 0
    var i = 0, j = 0
    var removedInGap = 0, addedInGap = 0

    func closeGap(at line: Int) {
        if removedInGap > addedInGap { changes.removedBefore.insert(line) }
        removedInGap = 0
        addedInGap = 0
    }

    while i < oldLines.count || j < newLines.count {
        if i < oldLines.count, j < newLines.count, oldLines[i] == newLines[j] {
            closeGap(at: j)
            if !isBlank(newLines[j]) { keptLines += 1 }
            i += 1
            j += 1
        } else if j < newLines.count, i == oldLines.count || lengths[i][j + 1] >= lengths[i + 1][j] {
            if !isBlank(newLines[j]) {
                changes.changed.insert(j)
                addedInGap += 1
            }
            j += 1
        } else {
            if !isBlank(oldLines[i]) { removedInGap += 1 }
            i += 1
        }
    }
    closeGap(at: newLines.count)

    let total = keptLines + changes.changed.count
    guard total > 0, keptLines * 10 >= total * 4 else { return nil }
    return changes
}
