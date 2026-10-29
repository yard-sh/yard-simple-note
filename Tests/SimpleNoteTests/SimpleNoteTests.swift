import Foundation
import Testing
@testable import SimpleNote

@Suite struct VersionComparisonTests {
    @Test(arguments: [
        ("v1.1.0", "1.0.1", true),
        ("v1.10.0", "1.9", true),
        ("1.0", "1.0.0", false),
        ("v1.0.0", "1.1.0", false),
        ("v2.0.0-beta", "1.9.9", true),
    ])
    func isNewer(candidate: String, current: String, expected: Bool) {
        #expect(UpdateChecker.isNewer(candidate, than: current) == expected)
    }
}

@Suite struct DateGroupingTests {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func buckets() {
        func ago(days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }
        #expect(DateGrouping.bucket(for: now, now: now, calendar: calendar) == .today)
        #expect(DateGrouping.bucket(for: ago(days: 3), now: now, calendar: calendar) == .thisWeek)
        #expect(DateGrouping.bucket(for: ago(days: 30), now: now, calendar: calendar) == .earlier)
    }

    @Test func sectionsKeepNewestFirstOrder() {
        let notes = [Note(modifiedAt: now), Note(modifiedAt: now.addingTimeInterval(-60))]
        let sections = DateGrouping.sectionedNotes(notes, now: now)
        #expect(sections.flatMap(\.notes).map(\.id) == notes.map(\.id))
    }
}

@Suite struct InlineMarkdownTests {
    @Test func keepsLineBreaksWithinAParagraph() {
        let paragraphs = InlineMarkdown.paragraphs(from: "Try it:\n— one\n— two\n\nNext")
        #expect(paragraphs.count == 2)
        #expect(String(paragraphs[0].characters).contains("\n— one"))
    }

    @Test func rendersEmphasisWithoutMarkers() {
        let text = String(InlineMarkdown.paragraphs(from: "a *b* **c**")[0].characters)
        #expect(text == "a b c")
    }
}

@Suite struct NoteTests {
    @Test func displayTitleFallsBackToFirstLine() {
        #expect(Note(title: "  ", body: "\n  First line \nsecond").displayTitle == "First line")
        #expect(Note().displayTitle == "Untitled")
    }

    @Test func matchingIgnoresCaseAndDiacritics() {
        #expect(Note(body: "Café notes").matches("cafe"))
    }
}

@Suite struct LicenseTests {
    @Test func normalizesKeys() {
        #expect(LicenseManager.normalize("  abcd-efgh-jkmn-pqrs \n") == "ABCD-EFGH-JKMN-PQRS")
    }
}
