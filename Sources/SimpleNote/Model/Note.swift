import Foundation

struct Note: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(),
         title: String = "",
         body: String = "",
         createdAt: Date = .now,
         modifiedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }

    var preview: String {
        let raw = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "Empty note" }
        let oneLine = raw.replacingOccurrences(of: "\n", with: " ")
        return String(oneLine.prefix(140))
    }
}
