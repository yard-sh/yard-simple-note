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
    /// Set when notes.json couldn't be read at launch; holds where the bad file was moved.
    var corruptFileURL: URL?

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Bumped on every edit. A save only reports `.saved` if nothing changed while it ran.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var savedGeneration = 0
    @ObservationIgnored private let saveDelay: Duration = .milliseconds(400)

    init() {
        switch NotesFile.load() {
        case .loaded(let loaded) where !loaded.isEmpty:
            notes = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
        case .corrupt(let quarantinedAt):
            notes = [NoteStore.makeWelcomeNote()]
            corruptFileURL = quarantinedAt ?? NotesFile.fileURL
        case .loaded, .missing:
            notes = [NoteStore.makeWelcomeNote()]
            markDirty()
        }
        selectedID = notes.first?.id
    }

    // MARK: - CRUD

    @discardableResult
    func newNote() -> Note.ID {
        let n = Note()
        notes.insert(n, at: 0)
        selectedID = n.id
        searchQuery = ""
        markDirty()
        return n.id
    }

    func delete(id: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes.remove(at: idx)
        if notes.isEmpty {
            // Always keep one note around so the editor has something to show.
            notes.append(Note())
        }
        if selectedID == id {
            selectedID = notes[min(idx, notes.count - 1)].id
        }
        markDirty()
    }

    @discardableResult
    func duplicate(id: Note.ID) -> Note.ID? {
        guard let original = note(id: id) else { return nil }
        let copy = Note(
            title: original.title.isEmpty ? "" : "\(original.title) Copy",
            body: original.body
        )
        notes.insert(copy, at: 0)
        selectedID = copy.id
        markDirty()
        return copy.id
    }

    func update(id: Note.ID, title: String? = nil, body: String? = nil) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[idx]
        if let title { note.title = title }
        if let body { note.body = body }
        guard note != notes[idx] else { return }
        note.modifiedAt = .now
        // Most-recently edited floats to the top.
        notes.remove(at: idx)
        notes.insert(note, at: 0)
        markDirty()
    }

    // MARK: - Queries

    func note(id: Note.ID?) -> Note? {
        guard let id else { return nil }
        return notes.first(where: { $0.id == id })
    }

    func filtered() -> [Note] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return notes }
        return notes.filter { $0.matches(q) }
    }

    struct CrossHit: Identifiable {
        var id: Note.ID { noteID }
        let noteID: Note.ID
        let title: String
        let context: String
    }

    func findAcross(query: String) -> [CrossHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return notes.compactMap { note in
            let body = note.body
            if let range = body.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
                let lower = body.index(range.lowerBound, offsetBy: -30, limitedBy: body.startIndex) ?? body.startIndex
                let upper = body.index(range.upperBound, offsetBy: 60, limitedBy: body.endIndex) ?? body.endIndex
                let snippet = (lower > body.startIndex ? "…" : "")
                    + body[lower..<upper].replacingOccurrences(of: "\n", with: " ")
                return CrossHit(noteID: note.id, title: note.displayTitle, context: snippet)
            }
            if note.title.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return CrossHit(noteID: note.id, title: note.displayTitle, context: note.preview)
            }
            return nil
        }
    }

    // MARK: - Save lifecycle

    var hasUnsavedChanges: Bool { generation != savedGeneration }

    private func markDirty() {
        generation += 1
        saveState = .dirty
        scheduleSave()
    }

    /// Debounced save. Saves run one at a time; edits made during a save trigger another.
    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            await self?.saveLoop()
        }
    }

    private func saveLoop() async {
        while hasUnsavedChanges {
            let snapshot = notes
            let target = generation
            saveState = .saving
            do {
                try await Task.detached(priority: .utility) {
                    try NotesFile.save(snapshot, generation: target)
                }.value
                savedGeneration = max(savedGeneration, target)
                saveState = hasUnsavedChanges ? .dirty : .saved
            } catch {
                saveState = .error(error.localizedDescription)
                break
            }
        }
        saveTask = nil
    }

    /// Synchronously writes pending changes. Called when the app is about to quit,
    /// where an async save could be cut short.
    func flushSync() {
        guard hasUnsavedChanges else { return }
        do {
            try NotesFile.save(notes, generation: generation)
            savedGeneration = generation
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
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
        return Note(title: "Welcome", body: body)
    }
}
