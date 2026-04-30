import SwiftUI

struct SidebarRow: View {
    let note: Note
    let bucket: NoteBucket
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(isActive ? Palette.accent : Color.clear)
                .frame(width: 2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(note.displayTitle)
                        .font(Typography.ui(13.5, weight: .medium))
                        .foregroundStyle(isActive ? Palette.text : Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(DateGrouping.rowTimeLabel(for: note.modifiedAt, bucket: bucket))
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.textFaint)
                        .lineLimit(1)
                }
                Text(note.preview)
                    .font(Typography.ui(11.5))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 7)
            .padding(.leading, 9)
            .padding(.trailing, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isActive ? Palette.accent.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(isActive ? Palette.accent.opacity(0.22) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
