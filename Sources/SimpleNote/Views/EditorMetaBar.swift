import SwiftUI

struct EditorMetaBar: View {
    let modifiedAt: Date
    let wordCount: Int
    let saveState: SaveState
    let isPreview: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(modifiedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            sep
            Text(modifiedAt.formatted(date: .omitted, time: .shortened))
            sep
            Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                .monospacedDigit()
            sep
            saveLabel
            if isPreview {
                sep
                Text("Preview").foregroundStyle(Palette.accent)
            }
            Spacer()
        }
        .font(Typography.mono(10.5))
        .foregroundStyle(Palette.textMuted)
        .lineLimit(1)
    }

    private var sep: some View {
        Text("·")
    }

    private var saveLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(saveText)
                .foregroundStyle(textColor)
                .help(saveHelp)
        }
    }

    private var dotColor: Color {
        switch saveState {
        case .saved:  return Palette.success
        case .dirty:  return Palette.textMuted
        case .saving: return Palette.accent
        case .error:  return Palette.danger
        }
    }

    private var textColor: Color {
        switch saveState {
        case .saved:  return Palette.success
        case .dirty, .saving: return Palette.textMuted
        case .error:  return Palette.danger
        }
    }

    private var saveText: String {
        switch saveState {
        case .saved:  return "Saved"
        case .dirty:  return "Editing…"
        case .saving: return "Saving…"
        case .error:  return "Save failed"
        }
    }

    private var saveHelp: String {
        if case .error(let message) = saveState { return message }
        return ""
    }
}
