import Foundation

enum NoteBucket: String, CaseIterable, Hashable {
    case today, yesterday, thisWeek, earlier

    var label: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek:  return "This week"
        case .earlier:   return "Earlier"
        }
    }

    var order: Int {
        switch self {
        case .today:     return 0
        case .yesterday: return 1
        case .thisWeek:  return 2
        case .earlier:   return 3
        }
    }
}

enum DateGrouping {
    static func bucket(for date: Date, now: Date = .now, calendar: Calendar = .current) -> NoteBucket {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }

        let dateYear = calendar.component(.yearForWeekOfYear, from: date)
        let nowYear  = calendar.component(.yearForWeekOfYear, from: now)
        let dateWeek = calendar.component(.weekOfYear, from: date)
        let nowWeek  = calendar.component(.weekOfYear, from: now)
        if dateYear == nowYear, dateWeek == nowWeek { return .thisWeek }

        // Friendly fallback: anything in the last 7 days still groups as "This week".
        if let diff = calendar.dateComponents([.day], from: date, to: now).day,
           diff >= 0, diff < 7 {
            return .thisWeek
        }
        return .earlier
    }

    static func sectionedNotes(_ notes: [Note], now: Date = .now) -> [(bucket: NoteBucket, notes: [Note])] {
        let grouped = Dictionary(grouping: notes) { bucket(for: $0.modifiedAt, now: now) }
        return NoteBucket.allCases
            .compactMap { b -> (NoteBucket, [Note])? in
                guard let arr = grouped[b], !arr.isEmpty else { return nil }
                return (b, arr.sorted { $0.modifiedAt > $1.modifiedAt })
            }
            .map { (bucket: $0.0, notes: $0.1) }
    }

    static func rowTimeLabel(for date: Date, bucket: NoteBucket, now: Date = .now, calendar: Calendar = .current) -> String {
        switch bucket {
        case .today:
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        case .yesterday:
            return "Yest"
        case .thisWeek:
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        case .earlier:
            let f = DateFormatter()
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            f.dateFormat = sameYear ? "MMM d" : "MMM yyyy"
            return f.string(from: date)
        }
    }
}
