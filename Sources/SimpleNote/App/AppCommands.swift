import SwiftUI

struct AppCommands: Commands {
    let store: NoteStore
    let appState: AppState
    let license: LicenseManager
    let updates: UpdateChecker

    @Environment(\.openSettings) private var openSettings

    /// Note commands are unavailable while the activation screen is showing.
    private var locked: Bool { license.requiresActivation }

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                openSettings()
                Task { await updates.check(licenseKey: license.licenseKey) }
            }
            Button(license.isLicensed ? "License…" : "Enter License…") {
                openSettings()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("New Note") { store.newNote() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(locked)
        }

        CommandMenu("Note") {
            Button("Duplicate") {
                if let id = store.selectedID { store.duplicate(id: id) }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(locked || store.selectedID == nil)

            // ⌘⌫ is left to the text editor (delete to start of line).
            Button("Delete…") {
                appState.pendingDelete = store.selectedID
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(locked || store.selectedID == nil)

            Divider()

            Button("Command Palette") { appState.activeSheet = .palette }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(locked)

            Button("Find Across Notes") { appState.activeSheet = .findAcross }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(locked)
        }

        CommandGroup(replacing: .sidebar) {
            Button(appState.columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("/", modifiers: .command)
            .disabled(locked)

            Button(appState.isPreview ? "Edit Note" : "Show Preview") {
                appState.isPreview.toggle()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(locked)
        }
    }
}
