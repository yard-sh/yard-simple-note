import SwiftUI

struct FindAcrossNotesView: View {
    @Bindable var store: NoteStore
    @Binding var isPresented: Bool

    @State private var query: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                TextField("Find across notes…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.ui(14))
                    .foregroundStyle(Palette.text)
                    .focused($fieldFocused)
                Button { isPresented = false } label: {
                    Text("esc")
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.textFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .bottom)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hits) { hit in
                        Button {
                            store.selectedID = hit.noteID
                            isPresented = false
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hit.title)
                                    .font(Typography.ui(13.5, weight: .medium))
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1)
                                snippet(for: hit)
                                    .font(Typography.ui(12))
                                    .foregroundStyle(Palette.textMuted)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().background(Palette.line)
                    }
                    if hits.isEmpty {
                        Text(query.isEmpty ? "Type to search across all notes." : "No matches.")
                            .font(Typography.ui(13))
                            .foregroundStyle(Palette.textMuted)
                            .padding(20)
                    }
                }
            }
            .frame(minHeight: 280, maxHeight: 480)
        }
        .frame(width: 580)
        .background(Palette.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 14)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { DispatchQueue.main.async { fieldFocused = true } }
    }

    private var hits: [NoteStore.CrossHit] {
        store.findAcross(query: query)
    }

    private func snippet(for hit: NoteStore.CrossHit) -> Text {
        guard let range = hit.matchRange else {
            return Text(hit.context)
        }
        // Build a Text where the matched substring is bolded.
        // hit.context was extracted from the body using surrounding indices, so just bold the query text wherever it appears in context.
        var t = Text("")
        var remaining = hit.context
        while let r = remaining.range(of: query, options: .caseInsensitive) {
            let head = String(remaining[..<r.lowerBound])
            let match = String(remaining[r])
            t = t + Text(head) + Text(match).foregroundStyle(Palette.accentSoft).bold()
            remaining = String(remaining[r.upperBound...])
            _ = range
        }
        if !remaining.isEmpty {
            t = t + Text(remaining)
        }
        return t
    }
}
