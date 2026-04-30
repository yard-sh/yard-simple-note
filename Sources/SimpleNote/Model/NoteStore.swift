import Foundation
import Observation

enum SaveState: Equatable {
    case saved
    case dirty
    case saving
    case error(String)
}

@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [Note]
    var selectedID: Note.ID?
    var searchQuery: String = ""
    private(set) var saveState: SaveState = .saved
    var corruptionDetected: Bool = false

    @ObservationIgnored
    private var saver: DebouncedSaver?

    init() {
        let loaded = NotesFile.load()
        if loaded.isEmpty {
            let welcome = NoteStore.makeWelcomeNote()
            self.notes = [welcome]
            self.selectedID = welcome.id
        } else {
            self.notes = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
            self.selectedID = self.notes.first?.id
        }

        self.saver = DebouncedSaver { [weak self] in
            await self?.performSave()
        }

        if !FileManager.default.fileExists(atPath: NotesFile.fileURL().path) && !loaded.isEmpty {
            // Edge: load returned non-empty but file gone? Persist immediately.
            saver?.schedule()
        }
        if loaded.isEmpty {
            saver?.schedule()
        }
    }

    // MARK: - CRUD

    @discardableResult
    func newNote() -> Note.ID {
        let n = Note(title: "", body: "")
        notes.insert(n, at: 0)
        selectedID = n.id
        markDirty()
        return n.id
    }

    func delete(id: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes.remove(at: idx)
        if selectedID == id {
            selectedID = notes.first?.id
        }
        if notes.isEmpty {
            // Always keep one note around so the editor has something to show.
            let fresh = Note(title: "", body: "")
            notes.append(fresh)
            selectedID = fresh.id
        }
        markDirty()
    }

    @discardableResult
    func duplicate(id: Note.ID) -> Note.ID? {
        guard let original = notes.first(where: { $0.id == id }) else { return nil }
        var copy = Note(
            title: original.title.isEmpty ? "" : "\(original.title) Copy",
            body: original.body
        )
        copy.createdAt = .now
        copy.modifiedAt = .now
        notes.insert(copy, at: 0)
        selectedID = copy.id
        markDirty()
        return copy.id
    }

    func update(id: Note.ID, title: String? = nil, body: String? = nil) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var changed = false
        if let title, notes[idx].title != title {
            notes[idx].title = title
            changed = true
        }
        if let body, notes[idx].body != body {
            notes[idx].body = body
            changed = true
        }
        guard changed else { return }
        notes[idx].modifiedAt = .now
        // Re-sort so most-recently edited floats up. Stable enough for the sidebar.
        notes.sort { $0.modifiedAt > $1.modifiedAt }
        markDirty()
    }

    // MARK: - Queries

    func note(id: Note.ID?) -> Note? {
        guard let id else { return nil }
        return notes.first(where: { $0.id == id })
    }

    func indexOf(id: Note.ID) -> Int? {
        notes.firstIndex(where: { $0.id == id })
    }

    func filtered() -> [Note] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return notes }
        return notes.filter { n in
            n.title.lowercased().contains(q) || n.body.lowercased().contains(q)
        }
    }

    struct CrossHit: Identifiable {
        let id: UUID
        let noteID: Note.ID
        let title: String
        let context: String
        let matchRange: Range<String.Index>?
    }

    func findAcross(query: String) -> [CrossHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var hits: [CrossHit] = []
        for note in notes {
            let body = note.body
            if let range = body.range(of: q, options: .caseInsensitive) {
                let lower = body.index(range.lowerBound, offsetBy: -30, limitedBy: body.startIndex) ?? body.startIndex
                let upper = body.index(range.upperBound, offsetBy: 60, limitedBy: body.endIndex) ?? body.endIndex
                let snippet = String(body[lower..<upper]).replacingOccurrences(of: "\n", with: " ")
                hits.append(CrossHit(id: UUID(), noteID: note.id, title: note.displayTitle, context: snippet, matchRange: range))
            } else if note.title.range(of: q, options: .caseInsensitive) != nil {
                hits.append(CrossHit(id: UUID(), noteID: note.id, title: note.displayTitle, context: note.preview, matchRange: nil))
            }
        }
        return hits
    }

    // MARK: - Save lifecycle

    private func markDirty() {
        saveState = .dirty
        saver?.schedule()
    }

    private func performSave() async {
        saveState = .saving
        let snapshot = notes
        do {
            try await Task.detached(priority: .utility) {
                try NotesFile.save(snapshot)
            }.value
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }

    func flushSave() async {
        await saver?.flush()
    }

    // MARK: - Welcome note

    private static func makeWelcomeNote() -> Note {
        let body = """
        Welcome to Simple Note.

        Three things. *Nothing else.* No folders. No tags. No databases. Just notes, **ordered by when you wrote them.**

        Try it:
        — Press ⌘N for a new note.
        — Press ⌘K for the command palette.
        — Press ⌘↩ to toggle a rendered preview.
        — Press ⌘/ to toggle the sidebar.

        Use *single asterisks* for italic and **double** for bold. The preview will render them.

        That's the entire app. Now write something.
        """
        return Note(title: "Welcome", body: body, createdAt: .now, modifiedAt: .now)
    }
}
