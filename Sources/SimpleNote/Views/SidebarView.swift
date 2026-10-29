import SwiftUI

struct SidebarView: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedID) {
            ForEach(DateGrouping.sectionedNotes(store.filtered()), id: \.bucket) { section in
                Section(section.bucket.label) {
                    ForEach(section.notes) { note in
                        SidebarRow(note: note, bucket: section.bucket)
                            .tag(note.id)
                    }
                }
            }
        }
        // One menu for the whole list: a note's actions on a row, New Note on empty space.
        .contextMenu(forSelectionType: Note.ID.self) { ids in
            if let id = ids.first {
                Button("Duplicate") { store.duplicate(id: id) }
                Divider()
                Button("Delete…", role: .destructive) { appState.pendingDelete = id }
            } else {
                Button("New Note") { store.newNote() }
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.horizontal, 10, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Palette.sidebarTint)
        .searchable(text: $store.searchQuery, placement: .sidebar, prompt: "Search notes")
        .overlay {
            if !store.searchQuery.isEmpty && store.filtered().isEmpty {
                ContentUnavailableView.search(text: store.searchQuery)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.newNote()
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New note (⌘N)")
            }
        }
    }
}
