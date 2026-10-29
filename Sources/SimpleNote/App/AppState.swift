import SwiftUI
import Observation

/// Window-level UI state shared between the main window and the menu bar commands.
@MainActor
@Observable
final class AppState {
    enum Sheet: Identifiable {
        case palette, findAcross
        var id: Self { self }
    }

    var activeSheet: Sheet?
    /// Runs once the current sheet has finished dismissing, for actions that present
    /// something else (another sheet, an alert) and must not overlap the dismissal.
    var afterSheetDismiss: (() -> Void)?
    var pendingDelete: Note.ID?
    var isPreview = false
    var columnVisibility: NavigationSplitViewVisibility = .all

    func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.18)) {
            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }
}
