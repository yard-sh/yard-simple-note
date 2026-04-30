import Foundation

enum WordCount {
    static func count(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        var n = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                                 options: [.byWords, .localized]) { substring, _, _, _ in
            if let s = substring, !s.isEmpty { n += 1 }
        }
        return n
    }
}
