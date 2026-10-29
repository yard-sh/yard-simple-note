import SwiftUI

struct CommandPaletteView: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var body: some View {
        QuickSearchPanel(
            prompt: "Type a command or search notes…",
            systemImage: "command",
            query: $query,
            rows: actionRows + noteRows,
            emptyText: "No matches"
        )
    }

    private var actionRows: [QuickSearchRow] {
        let hasSelection = store.selectedID != nil
        let all: [QuickSearchRow?] = [
            QuickSearchRow(id: "new", section: "Actions", title: "New Note", shortcut: "⌘N") {
                store.newNote()
                dismiss()
            },
            hasSelection ? QuickSearchRow(id: "duplicate", section: "Actions", title: "Duplicate Note", shortcut: "⌘D") {
                if let id = store.selectedID { store.duplicate(id: id) }
                dismiss()
            } : nil,
            hasSelection ? QuickSearchRow(id: "delete", section: "Actions", title: "Delete Note…", shortcut: "⇧⌘⌫") {
                let id = store.selectedID
                appState.afterSheetDismiss = { appState.pendingDelete = id }
                dismiss()
            } : nil,
            QuickSearchRow(id: "find", section: "Actions", title: "Find Across Notes", shortcut: "⇧⌘F") {
                appState.afterSheetDismiss = { appState.activeSheet = .findAcross }
                dismiss()
            },
            QuickSearchRow(id: "preview", section: "Actions", title: appState.isPreview ? "Edit Note" : "Show Preview", shortcut: "⌘↩") {
                appState.isPreview.toggle()
                dismiss()
            },
        ]
        let q = query.trimmingCharacters(in: .whitespaces)
        return all.compactMap { $0 }.filter { q.isEmpty || $0.title.localizedStandardContains(q) }
    }

    private var noteRows: [QuickSearchRow] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let notes = q.isEmpty ? Array(store.notes.prefix(20)) : Array(store.notes.filter { $0.matches(q) }.prefix(40))
        return notes.map { note in
            QuickSearchRow(id: note.id.uuidString, section: "Notes", title: note.displayTitle, subtitle: AttributedString(note.preview)) {
                store.selectedID = note.id
                dismiss()
            }
        }
    }
}
