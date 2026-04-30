import Foundation
import SwiftUI

enum InlineMarkdown {
    /// Render the body as an AttributedString. Each paragraph is its own AttributedString
    /// so the caller can lay them out as separate Text views (preserving paragraph spacing).
    static func paragraphs(from body: String) -> [AttributedString] {
        // Split on blank-line boundaries so single newlines stay inside a paragraph.
        let normalized = body.replacingOccurrences(of: "\r\n", with: "\n")
        let chunks = normalized.components(separatedBy: "\n\n")
        return chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph(from: $0) }
    }

    private static func paragraph(from text: String) -> AttributedString {
        // Convert single newlines inside a paragraph into a soft-break (line break, same paragraph).
        let unwrapped = text.replacingOccurrences(of: "\n", with: " ")
        let opts = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attr = try? AttributedString(markdown: unwrapped, options: opts) {
            return styleEmphasis(attr)
        }
        return AttributedString(unwrapped)
    }

    /// Re-style the emphasis runs to use the serif italic the design demands.
    private static func styleEmphasis(_ attr: AttributedString) -> AttributedString {
        var out = attr
        for run in out.runs {
            guard let traits = run.inlinePresentationIntent else { continue }
            let range = run.range
            if traits.contains(.emphasized) {
                out[range].font = .custom(Typography.serifItalicPostScript, size: 18, relativeTo: .body)
                out[range].foregroundColor = Palette.accentSoft
            }
            if traits.contains(.stronglyEmphasized) {
                out[range].font = Font.custom(Typography.onestFamily, size: 17, relativeTo: .body).weight(.semibold)
                out[range].foregroundColor = Palette.text
            }
        }
        return out
    }
}
