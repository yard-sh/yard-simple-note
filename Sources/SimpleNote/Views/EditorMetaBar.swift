import SwiftUI

struct EditorMetaBar: View {
    let modifiedAt: Date
    let wordCount: Int
    let saveState: SaveState
    let isPreview: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(longDate)
                .foregroundStyle(Palette.textFaint)
            sep
            Text(timeOnly)
                .foregroundStyle(Palette.textFaint)
            sep
            Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                .foregroundStyle(Palette.textFaint)
                .monospacedDigit()
            sep
            saveLabel
            if isPreview {
                sep
                Text("Preview")
                    .foregroundStyle(Palette.accentSoft)
            }
            Spacer()
        }
        .font(Typography.mono(10.5))
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var sep: some View {
        Text("·").foregroundStyle(Palette.textFaint).opacity(0.55)
    }

    private var saveLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(saveText)
                .foregroundStyle(textColor)
        }
    }

    private var dotColor: Color {
        switch saveState {
        case .saved:   return Palette.success
        case .dirty:   return Palette.accentSoft.opacity(0.7)
        case .saving:  return Palette.accent
        case .error:   return Color.red.opacity(0.8)
        }
    }

    private var textColor: Color {
        switch saveState {
        case .saved:   return Palette.success
        case .dirty:   return Palette.textMuted
        case .saving:  return Palette.accentSoft
        case .error:   return Color(red: 0.99, green: 0.65, blue: 0.65)
        }
    }

    private var saveText: String {
        switch saveState {
        case .saved:        return "Saved"
        case .dirty:        return "Editing…"
        case .saving:       return "Saving…"
        case .error(let m): return "Save failed: \(m)"
        }
    }

    private var longDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: modifiedAt)
    }

    private var timeOnly: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: modifiedAt)
    }
}
