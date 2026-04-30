import SwiftUI

struct CommandPaletteView: View {
    @Bindable var store: NoteStore
    @Binding var isPresented: Bool

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var fieldFocused: Bool

    private struct Action: Identifiable {
        let id = UUID()
        let title: String
        let shortcut: String?
        let perform: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                TextField("Type a command or search notes…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.ui(14))
                    .foregroundStyle(Palette.text)
                    .focused($fieldFocused)
                    .onSubmit { activateSelection() }
                Button {
                    isPresented = false
                } label: {
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
            .background(Palette.surface)
            .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .bottom)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !filteredActions.isEmpty {
                        sectionHeader("Actions")
                        ForEach(Array(filteredActions.enumerated()), id: \.element.id) { idx, action in
                            paletteRow(
                                title: action.title,
                                trailing: action.shortcut,
                                isSelected: selectedIndex == idx,
                                onSelect: action.perform
                            )
                        }
                    }
                    if !filteredNotes.isEmpty {
                        sectionHeader("Notes")
                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { idx, note in
                            let absoluteIdx = filteredActions.count + idx
                            paletteRow(
                                title: note.displayTitle,
                                subtitle: note.preview,
                                isSelected: selectedIndex == absoluteIdx,
                                onSelect: { jumpTo(noteID: note.id) }
                            )
                        }
                    }
                    if filteredActions.isEmpty && filteredNotes.isEmpty {
                        Text("No matches")
                            .font(Typography.ui(13))
                            .foregroundStyle(Palette.textMuted)
                            .padding(20)
                    }
                }
            }
            .frame(minHeight: 240, maxHeight: 360)
            .background(Palette.bg1)

            // Hidden buttons for arrow-key navigation.
            VStack {
                Button("Next") { moveSelection(1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Prev") { moveSelection(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .frame(width: 540)
        .background(Palette.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 14)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.001))
        .onAppear {
            DispatchQueue.main.async { fieldFocused = true }
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Typography.mono(9.5, weight: .medium))
            .tracking(1.5)
            .foregroundStyle(Palette.textFaint)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func paletteRow(title: String, subtitle: String? = nil, trailing: String? = nil, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.ui(13.5, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.ui(11.5))
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Palette.accent.opacity(0.10) : Color.clear
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle().fill(Palette.accent).frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private var allActions: [Action] {
        [
            Action(title: "New note", shortcut: "⌘N") {
                store.newNote()
                isPresented = false
            },
            Action(title: "Duplicate current note", shortcut: "⌘D") {
                if let id = store.selectedID { store.duplicate(id: id) }
                isPresented = false
            },
            Action(title: "Delete current note", shortcut: "⌘⌫") {
                if let id = store.selectedID { store.delete(id: id) }
                isPresented = false
            },
            Action(title: "Find across notes", shortcut: "⌘⇧F") {
                isPresented = false
            }
        ]
    }

    private var filteredActions: [Action] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allActions }
        return allActions.filter { $0.title.lowercased().contains(q) }
    }

    private var filteredNotes: [Note] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Array(store.notes.prefix(20)) }
        return store.notes.filter {
            $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q)
        }.prefix(40).map { $0 }
    }

    private var totalRows: Int { filteredActions.count + filteredNotes.count }

    private func moveSelection(_ delta: Int) {
        guard totalRows > 0 else { return }
        let next = (selectedIndex + delta + totalRows) % totalRows
        selectedIndex = next
    }

    private func activateSelection() {
        guard totalRows > 0 else { return }
        if selectedIndex < filteredActions.count {
            filteredActions[selectedIndex].perform()
        } else {
            let noteIdx = selectedIndex - filteredActions.count
            if noteIdx < filteredNotes.count {
                jumpTo(noteID: filteredNotes[noteIdx].id)
            }
        }
    }

    private func jumpTo(noteID: Note.ID) {
        store.selectedID = noteID
        isPresented = false
    }
}
