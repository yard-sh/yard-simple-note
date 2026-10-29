import SwiftUI

/// One selectable row in a `QuickSearchPanel`.
struct QuickSearchRow: Identifiable {
    let id: String
    let section: String
    let title: String
    var subtitle: AttributedString?
    var shortcut: String?
    let perform: () -> Void
}

/// A Spotlight-style sheet: a search field over a keyboard-navigable list.
/// ↑/↓ move the selection, ↩ activates it, Esc dismisses.
struct QuickSearchPanel: View {
    let prompt: String
    let systemImage: String
    @Binding var query: String
    let rows: [QuickSearchRow]
    let emptyText: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.accent)
                TextField(prompt, text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($fieldFocused)
                    .onSubmit(activateSelection)
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            if idx == 0 || rows[idx - 1].section != row.section {
                                Text(row.section)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.textMuted)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                            }
                            rowView(row, isSelected: idx == selectedIndex)
                                .id(row.id)
                        }
                        if rows.isEmpty {
                            Text(emptyText)
                                .foregroundStyle(Palette.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(24)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
                .onChange(of: selectedIndex) { _, idx in
                    guard rows.indices.contains(idx) else { return }
                    proxy.scrollTo(rows[idx].id)
                }
            }
            .frame(height: 340)
        }
        .frame(width: 560)
        .background(Palette.surface)
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    private func rowView(_ row: QuickSearchRow, isSelected: Bool) -> some View {
        Button {
            row.perform()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .lineLimit(1)
                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(isSelected ? Palette.textSecondary : Palette.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let shortcut = row.shortcut {
                    Text(shortcut)
                        .font(.callout)
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Palette.selection : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func moveSelection(_ delta: Int) {
        guard !rows.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + rows.count) % rows.count
    }

    private func activateSelection() {
        guard rows.indices.contains(selectedIndex) else { return }
        rows[selectedIndex].perform()
    }
}
