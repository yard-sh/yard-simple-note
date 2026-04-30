import SwiftUI
import AppKit

@main
struct SimpleNoteApp: App {
    @State private var store: NoteStore
    @State private var showPalette: Bool = false
    @State private var showFindAcross: Bool = false
    @State private var pendingDelete: Note.ID? = nil

    init() {
        FontRegistration.registerBundledFonts()
        // Ensure SwiftPM-built apps appear as a regular app from Finder.
        NSApplication.shared.setActivationPolicy(.regular)
        _store = State(initialValue: NoteStore())
    }

    var body: some Scene {
        WindowGroup("Simple Note") {
            ContentView(
                store: store,
                showPalette: $showPalette,
                showFindAcross: $showFindAcross,
                pendingDelete: $pendingDelete
            )
            .frame(minWidth: 760, minHeight: 480)
            .preferredColorScheme(.dark)
            .background(Palette.bg.ignoresSafeArea())
            .task {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands(
                store: store,
                showPalette: $showPalette,
                showFindAcross: $showFindAcross,
                pendingDelete: $pendingDelete
            )
        }
    }
}
