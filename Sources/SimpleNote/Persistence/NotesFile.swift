import Foundation
import Synchronization

enum NotesFile {
    static let appFolderName = "SimpleNote"
    static let fileName = "notes.json"

    enum LoadResult {
        case missing
        case loaded([Note])
        /// The file couldn't be decoded. It was moved aside (never deleted) to `quarantinedAt`.
        case corrupt(quarantinedAt: URL?)
    }

    static var directoryURL: URL {
        URL.applicationSupportDirectory.appending(path: appFolderName, directoryHint: .isDirectory)
    }

    static var fileURL: URL {
        directoryURL.appending(path: fileName, directoryHint: .notDirectory)
    }

    static func load() -> LoadResult {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return .missing }
            return .loaded(try decoder.decode([Note].self, from: data))
        } catch {
            return .corrupt(quarantinedAt: quarantineCorrupt(url: url))
        }
    }

    /// Highest generation written so far. Guards against a slower, older save landing
    /// after a newer one (e.g. a background save finishing after the quit-time flush).
    private static let lastWritten = Mutex<Int>(0)

    /// Writes atomically: the data goes to a temporary file that then replaces the target,
    /// so a crash mid-write never leaves a truncated notes.json behind. A snapshot older
    /// than one already written is skipped.
    static func save(_ notes: [Note], generation: Int) throws {
        try lastWritten.withLock { last in
            guard generation > last else { return }
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: .atomic)
            last = generation
        }
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func quarantineCorrupt(url: URL) -> URL? {
        let stamp = Date.now.ISO8601Format().replacingOccurrences(of: ":", with: "-")
        let dest = url.deletingLastPathComponent().appending(path: "notes.json.corrupt-\(stamp)")
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
