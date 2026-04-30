import SwiftUI

struct FindInNoteBar: View {
    @Binding var query: String
    @Binding var currentMatch: Int
    let totalMatches: Int
    let onNext: () -> Void
    let onPrev: () -> Void
    let onClose: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textMuted)

            TextField("Find in note", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.ui(12.5))
                .foregroundStyle(Palette.text)
                .focused($focused)
                .onSubmit { onNext() }

            Text(matchLabel)
                .font(Typography.mono(10.5))
                .foregroundStyle(Palette.textFaint)
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)

            HStack(spacing: 2) {
                stepButton(systemName: "chevron.up", action: onPrev)
                stepButton(systemName: "chevron.down", action: onNext)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textMuted)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 36)
        .padding(.top, 14)
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }

    private var matchLabel: String {
        if totalMatches == 0 { return query.isEmpty ? "" : "No matches" }
        return "\(currentMatch + 1) / \(totalMatches)"
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .padding(6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(totalMatches == 0 ? Palette.textFaint : Palette.textSecondary)
        .disabled(totalMatches == 0)
    }
}
