import SwiftUI

struct FocusedNoteIDKey: FocusedValueKey {
    typealias Value = Note.ID
}

extension FocusedValues {
    var focusedNoteID: Note.ID? {
        get { self[FocusedNoteIDKey.self] }
        set { self[FocusedNoteIDKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    var store: NoteStore
    @Binding var showPalette: Bool
    @Binding var showFindAcross: Bool
    @Binding var pendingDelete: Note.ID?

    @FocusedValue(\.focusedNoteID) private var focusedNoteID: Note.ID?

    var body: some Commands {
        // ⌘N — New note (replaces default New)
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                store.newNote()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Pasteboard / undo: keep defaults.
        CommandMenu("Note") {
            Button("Duplicate") {
                if let id = store.selectedID ?? focusedNoteID {
                    store.duplicate(id: id)
                }
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("Delete…") {
                if let id = store.selectedID ?? focusedNoteID {
                    pendingDelete = id
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)

            Divider()

            Button("Command Palette") {
                showPalette = true
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Find Across Notes") {
                showFindAcross = true
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        // Replace the View menu's sidebar toggle with our own.
        CommandGroup(replacing: .sidebar) {
            // Empty: ContentView's toolbar button owns ⌘/.
        }
    }
}
