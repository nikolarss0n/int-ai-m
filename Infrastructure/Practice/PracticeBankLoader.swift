import Foundation

enum PracticeBankLoader {
    static func decode(_ data: Data) throws -> PracticeBankFile {
        try JSONDecoder().decode(PracticeBankFile.self, from: data)
    }

    static func load(fromFile url: URL) throws -> PracticeBankFile {
        try decode(try Data(contentsOf: url))
    }

    static func load() -> PracticeBankFile {
        for dir in candidateDirectories() {
            let bank = loadDirectory(dir)
            if !bank.packs.isEmpty {
                NSLog("📚 Practice bank loaded: %d packs, %d positions from %@", bank.packs.count, bank.positions.count, dir.path)
                return bank
            }
        }
        NSLog("⚠️ Practice bank.json not found; using built-in AWS/Models/Angular packs")
        return PracticeBankFile(
            packs: PracticeTopicPack.all,
            positions: PracticeTopicPack.all.map {
                PracticePosition(id: $0.id, title: $0.title, packId: $0.id, groupIds: [])
            }
        )
    }

    static func loadDirectory(_ dir: URL) -> PracticeBankFile {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return PracticeBankFile(packs: [], positions: [])
        }
        var packs: [PracticeTopicPack] = []
        var positions: [PracticePosition] = []
        var seen = Set<String>()
        for url in files.filter({ $0.pathExtension.lowercased() == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let bank = try? load(fromFile: url) else { continue }
            for pack in bank.packs where seen.insert(pack.id).inserted {
                packs.append(pack)
            }
            positions.append(contentsOf: bank.positions)
        }
        return PracticeBankFile(packs: packs, positions: positions)
    }

    private static func candidateDirectories() -> [URL] {
        var dirs: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("practice") {
            dirs.append(bundled)
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        dirs.append(cwd.appendingPathComponent("Resources/practice"))
        dirs.append(cwd.appendingPathComponent("practice"))
        return dirs
    }

    private static func candidateURLs() -> [URL] {
        candidateDirectories().map { $0.appendingPathComponent("bank.json") }
    }
}
