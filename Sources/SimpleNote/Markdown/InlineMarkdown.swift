import Foundation
import SwiftUI

enum InlineMarkdown {
    /// Render the body as one AttributedString per paragraph (blank-line separated) so the
    /// caller can lay them out as separate Text views with paragraph spacing. Single newlines
    /// inside a paragraph are kept as line breaks.
    static func paragraphs(from body: String) -> [AttributedString] {
        body.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(paragraph(from:))
    }

    private static func paragraph(from text: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attr = try? AttributedString(markdown: text, options: opts) else {
            return AttributedString(text)
        }
        return styleEmphasis(attr)
    }

    /// Re-style emphasis runs: *italic* uses the serif italic, **bold** a heavier weight.
    private static func styleEmphasis(_ attr: AttributedString) -> AttributedString {
        var out = attr
        for run in out.runs {
            guard let traits = run.inlinePresentationIntent else { continue }
            if traits.contains(.emphasized) {
                out[run.range].font = Typography.serifItalic(18)
            }
            if traits.contains(.stronglyEmphasized) {
                out[run.range].font = Typography.ui(16, weight: .semibold)
            }
        }
        return out
    }
}
