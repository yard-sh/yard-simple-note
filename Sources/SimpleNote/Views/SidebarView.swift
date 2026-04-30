import SwiftUI

struct SidebarView: View {
    @Bindable var store: NoteStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            list
        }
        .background(Palette.bg.opacity(0.6))
        .frame(minWidth: 240, idealWidth: 270, maxWidth: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                store.newNote()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                    Text("New note")
                        .font(Typography.ui(12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Palette.line2, lineWidth: 1)
                )
                .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textMuted)
            TextField("Search notes", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(Typography.ui(12))
                .foregroundStyle(Palette.text)
                .focused($searchFocused)
            if !store.searchQuery.isEmpty {
                Button {
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘K")
                    .font(Typography.mono(9.5))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Palette.line, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2, pinnedViews: []) {
                ForEach(sections, id: \.bucket) { section in
                    Text(section.bucket.label.uppercased())
                        .font(Typography.mono(9.5, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Palette.textFaint)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(section.notes) { note in
                        Button {
                            store.selectedID = note.id
                        } label: {
                            SidebarRow(
                                note: note,
                                bucket: section.bucket,
                                isActive: store.selectedID == note.id
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    }
                }
                Color.clear.frame(height: 12)
            }
            .padding(.bottom, 8)
        }
        .scrollContentBackground(.hidden)
    }

    private var sections: [(bucket: NoteBucket, notes: [Note])] {
        DateGrouping.sectionedNotes(store.filtered())
    }
}
