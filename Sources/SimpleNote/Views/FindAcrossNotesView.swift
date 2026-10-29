import SwiftUI

struct FindAcrossNotesView: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var body: some View {
        QuickSearchPanel(
            prompt: "Find across notes…",
            systemImage: "text.magnifyingglass",
            query: $query,
            rows: rows,
            emptyText: query.isEmpty ? "Type to search across all notes." : "No matches."
        )
    }

    private var rows: [QuickSearchRow] {
        store.findAcross(query: query).map { hit in
            QuickSearchRow(id: hit.noteID.uuidString, section: "Results", title: hit.title, subtitle: highlighted(hit.context)) {
                store.selectedID = hit.noteID
                dismiss()
            }
        }
    }

    /// Bolds every occurrence of the query in the snippet.
    private func highlighted(_ context: String) -> AttributedString {
        var attr = AttributedString(context)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return attr }
        var searchStart = attr.startIndex
        while searchStart < attr.endIndex,
              let range = attr[searchStart...].range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return attr
    }
}
