import Foundation

enum NoteBucket: CaseIterable, Hashable {
    case today, yesterday, thisWeek, earlier

    var label: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek:  return "Previous 7 Days"
        case .earlier:   return "Earlier"
        }
    }
}

enum DateGrouping {
    static func bucket(for date: Date, now: Date = .now, calendar: Calendar = .current) -> NoteBucket {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday), date >= weekAgo {
            return .thisWeek
        }
        return .earlier
    }

    /// Notes are expected newest-first (as `NoteStore` keeps them); order is preserved.
    static func sectionedNotes(_ notes: [Note], now: Date = .now) -> [(bucket: NoteBucket, notes: [Note])] {
        let grouped = Dictionary(grouping: notes) { bucket(for: $0.modifiedAt, now: now) }
        return NoteBucket.allCases.compactMap { b in
            guard let arr = grouped[b], !arr.isEmpty else { return nil }
            return (bucket: b, notes: arr)
        }
    }

    /// Locale-aware (respects the user's 12/24-hour setting).
    static func rowTimeLabel(for date: Date, bucket: NoteBucket, now: Date = .now, calendar: Calendar = .current) -> String {
        switch bucket {
        case .today:
            return date.formatted(date: .omitted, time: .shortened)
        case .yesterday:
            return "Yesterday"
        case .thisWeek:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .earlier:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            return sameYear
                ? date.formatted(.dateTime.month(.abbreviated).day())
                : date.formatted(.dateTime.month(.abbreviated).year())
        }
    }
}
