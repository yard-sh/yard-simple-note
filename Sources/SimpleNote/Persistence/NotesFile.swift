import Foundation

enum NotesFile {
    static let appFolderName = "SimpleNote"
    static let fileName = "notes.json"

    static func directoryURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: nil,
                                 create: true))
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = base.appendingPathComponent(appFolderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL() -> URL {
        directoryURL().appendingPathComponent(fileName, isDirectory: false)
    }

    /// Load notes from disk. Returns an empty array if the file is missing.
    /// On a corrupt file, the bad file is renamed (never deleted) and an empty array is returned.
    static func load() -> [Note] {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Note].self, from: data)
        } catch {
            quarantineCorrupt(url: url)
            return []
        }
    }

    static func save(_ notes: [Note]) throws {
        let dir = directoryURL()
        let target = fileURL()
        let temp = dir.appendingPathComponent("notes.json.tmp", isDirectory: false)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notes)

        if FileManager.default.fileExists(atPath: temp.path) {
            try? FileManager.default.removeItem(at: temp)
        }
        try data.write(to: temp, options: .atomic)

        if FileManager.default.fileExists(atPath: target.path) {
            do {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
                return
            } catch {
                // Fallback for non-APFS / iCloud-synced volumes.
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.moveItem(at: temp, to: target)
                return
            }
        } else {
            try FileManager.default.moveItem(at: temp, to: target)
        }
    }

    private static func quarantineCorrupt(url: URL) {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let dest = url.deletingLastPathComponent()
            .appendingPathComponent("notes.json.corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: dest)
    }
}
