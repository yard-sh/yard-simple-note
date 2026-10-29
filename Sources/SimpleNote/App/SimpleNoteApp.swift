import SwiftUI
import AppKit

@main
struct SimpleNoteApp: App {
    @State private var store = NoteStore()
    @State private var appState = AppState()
    @State private var license = LicenseManager()
    @State private var updates = UpdateChecker()

    init() {
        // Lets `swift run` builds (which have no Info.plist) show a Dock icon and menu bar.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Simple Note", id: "main") {
            ContentView()
                .frame(minWidth: 760, minHeight: 480)
                .tint(Palette.accentFill)
                .task {
                    await license.refresh()
                    await updates.checkInBackgroundIfDue(licenseKey: license.licenseKey)
                }
                .onChange(of: license.licenseKey) { _, newKey in
                    // A key activated after launch gets its first update check right away.
                    guard newKey != nil else { return }
                    Task { await updates.checkInBackgroundIfDue(licenseKey: newKey) }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.flushSync()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    store.flushSync()
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            AppCommands(store: store, appState: appState, license: license, updates: updates)
        }
        .environment(store)
        .environment(appState)
        .environment(license)
        .environment(updates)

        Settings {
            SettingsView()
                .tint(Palette.accentFill)
                .environment(license)
                .environment(updates)
        }
    }
}
