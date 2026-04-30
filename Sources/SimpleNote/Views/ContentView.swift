import SwiftUI

struct ContentView: View {
    @Bindable var store: NoteStore
    @Binding var showPalette: Bool
    @Binding var showFindAcross: Bool
    @Binding var pendingDelete: Note.ID?

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ZStack {
                Palette.bg.ignoresSafeArea()
                if let id = store.selectedID, store.note(id: id) != nil {
                    EditorView(store: store, noteID: id)
                } else {
                    Text("Select or create a note.")
                        .font(Typography.serifItalic(28))
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                        .foregroundStyle(Palette.textSecondary)
                }
                .keyboardShortcut("/", modifiers: .command)
                .help("Toggle sidebar (⌘/)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPalette = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "command")
                        Text("Command")
                            .font(Typography.ui(12))
                    }
                    .foregroundStyle(Palette.textSecondary)
                }
                .help("Command palette (⌘K)")
            }
        }
        .background(Palette.bg)
        .sheet(isPresented: $showPalette) {
            CommandPaletteView(store: store, isPresented: $showPalette)
                .background(Palette.bg1)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showFindAcross) {
            FindAcrossNotesView(store: store, isPresented: $showFindAcross)
                .background(Palette.bg1)
                .preferredColorScheme(.dark)
        }
        .alert("Delete this note?",
               isPresented: Binding(
                   get: { pendingDelete != nil },
                   set: { if !$0 { pendingDelete = nil } }
               ),
               presenting: pendingDelete) { id in
            Button("Delete", role: .destructive) {
                store.delete(id: id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.18)) {
            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }
}
