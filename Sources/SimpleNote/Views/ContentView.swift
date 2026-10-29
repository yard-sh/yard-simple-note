import SwiftUI

struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(LicenseManager.self) private var license

    var body: some View {
        Group {
            if license.requiresActivation {
                ActivationView()
            } else {
                notes
            }
        }
        .animation(.easeInOut(duration: 0.25), value: license.requiresActivation)
        .alert(
            "Your notes file couldn’t be read",
            isPresented: Binding(
                get: { store.corruptFileURL != nil },
                set: { if !$0 { store.corruptFileURL = nil } }
            ),
            presenting: store.corruptFileURL
        ) { url in
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("OK", role: .cancel) {}
        } message: { url in
            Text("It was moved aside to “\(url.lastPathComponent)” so nothing is lost. Simple Note has started a fresh notes file.")
        }
    }

    private var notes: some View {
        @Bindable var store = store
        @Bindable var appState = appState

        return NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let id = store.selectedID, store.note(id: id) != nil {
                EditorView(noteID: id)
                    .id(id)
            } else {
                ContentUnavailableView {
                    Label("No Note Selected", systemImage: "note.text")
                } description: {
                    Text("Press ⌘N to start writing.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.bg)
            }
        }
        .sheet(item: $appState.activeSheet, onDismiss: {
            let action = appState.afterSheetDismiss
            appState.afterSheetDismiss = nil
            action?()
        }) { sheet in
            switch sheet {
            case .palette: CommandPaletteView()
            case .findAcross: FindAcrossNotesView()
            }
        }
        .alert(
            "Delete “\(store.note(id: appState.pendingDelete)?.displayTitle ?? "Note")”?",
            isPresented: Binding(
                get: { appState.pendingDelete != nil },
                set: { if !$0 { appState.pendingDelete = nil } }
            ),
            presenting: appState.pendingDelete
        ) { id in
            Button("Delete", role: .destructive) {
                store.delete(id: id)
                appState.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This can’t be undone.")
        }
    }
}
