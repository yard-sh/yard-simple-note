import SwiftUI

struct SidebarRow: View {
    let note: Note
    let bucket: NoteBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(note.displayTitle)
                    .font(Typography.ui(13, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(DateGrouping.rowTimeLabel(for: note.modifiedAt, bucket: bucket))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(note.preview)
                .font(Typography.ui(12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }
}
