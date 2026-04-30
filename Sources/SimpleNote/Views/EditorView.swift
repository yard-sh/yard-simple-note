import SwiftUI
import AppKit

struct EditorView: View {
    @Bindable var store: NoteStore
    let noteID: Note.ID

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @State private var isPreview: Bool = false
    @State private var debouncedWordCount: Int = 0
    @State private var wordCountTask: Task<Void, Never>?

    @State private var findActive: Bool = false
    @State private var findQuery: String = ""
    @State private var findCurrent: Int = 0

    @FocusState private var titleFocused: Bool
    @FocusState private var bodyFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if let note = store.note(id: noteID) {
                    EditorMetaBar(
                        modifiedAt: note.modifiedAt,
                        wordCount: debouncedWordCount,
                        saveState: store.saveState,
                        isPreview: isPreview
                    )

                    titleField
                        .padding(.horizontal, 36)
                        .padding(.bottom, 16)

                    contentArea
                        .padding(.horizontal, 30)
                        .padding(.bottom, 36)
                } else {
                    emptyState
                }
            }

            if findActive {
                FindInNoteBar(
                    query: $findQuery,
                    currentMatch: $findCurrent,
                    totalMatches: matchRanges.count,
                    onNext: jumpNext,
                    onPrev: jumpPrev,
                    onClose: dismissFind
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }

            // Hidden buttons that own the view-level keyboard shortcuts.
            VStack {
                Button("Toggle preview") { isPreview.toggle() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Find") { startFind() }
                    .keyboardShortcut("f", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .focusedSceneValue(\.focusedNoteID, noteID)
        .onAppear { syncFromStore(force: true) }
        .onChange(of: noteID) { _, _ in syncFromStore(force: true); dismissFind() }
        .onChange(of: titleText) { _, newValue in store.update(id: noteID, title: newValue) }
        .onChange(of: bodyText) { _, newValue in
            store.update(id: noteID, body: newValue)
            scheduleWordCount()
        }
        .onChange(of: findQuery) { _, _ in findCurrent = 0 }
    }

    // MARK: - Title field

    private var titleField: some View {
        TextField("Untitled", text: $titleText, axis: .horizontal)
            .textFieldStyle(.plain)
            .font(Typography.serifItalic(34))
            .foregroundStyle(Palette.text)
            .focused($titleFocused)
            .onSubmit {
                bodyFocused = true
            }
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if findActive {
            findHighlightedScroll
        } else if isPreview {
            previewScroll
        } else {
            editor
        }
    }

    private var editor: some View {
        EditorTextView(text: $bodyText, isFocused: $bodyFocused)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var previewScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(InlineMarkdown.paragraphs(from: bodyText).enumerated()), id: \.offset) { _, attr in
                    Text(attr)
                        .font(Typography.ui(16.5))
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(6)
                        .frame(maxWidth: 720, alignment: .leading)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var findHighlightedScroll: some View {
        ScrollView {
            Text(highlightedAttributedBody)
                .font(Typography.ui(16))
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(6)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .textSelection(.enabled)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No note selected")
                .font(Typography.serifItalic(28))
                .foregroundStyle(Palette.textMuted)
            Text("Press ⌘N to start writing.")
                .font(Typography.mono(12))
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sync

    private func syncFromStore(force: Bool) {
        guard let note = store.note(id: noteID) else { return }
        if force || titleText != note.title { titleText = note.title }
        if force || bodyText != note.body  { bodyText  = note.body }
        debouncedWordCount = WordCount.count(note.body)
    }

    private func scheduleWordCount() {
        wordCountTask?.cancel()
        let snapshot = bodyText
        wordCountTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
            debouncedWordCount = WordCount.count(snapshot)
        }
    }

    // MARK: - Find

    private var matchRanges: [Range<String.Index>] {
        let q = findQuery
        guard !q.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStart = bodyText.startIndex
        while let r = bodyText.range(of: q, options: .caseInsensitive, range: searchStart..<bodyText.endIndex) {
            ranges.append(r)
            searchStart = r.upperBound
            if searchStart == bodyText.endIndex { break }
        }
        return ranges
    }

    private var highlightedAttributedBody: AttributedString {
        var attr = AttributedString(bodyText)
        let ranges = matchRanges
        for (i, r) in ranges.enumerated() {
            if let nsRange = attr.range(of: bodyText[r]) {
                attr[nsRange].backgroundColor = (i == findCurrent) ? Palette.accent.opacity(0.55) : Palette.accent.opacity(0.18)
                attr[nsRange].foregroundColor = (i == findCurrent) ? Palette.text : Palette.text
            }
        }
        return attr
    }

    private func startFind() {
        findQuery = ""
        findCurrent = 0
        withAnimation(.easeOut(duration: 0.18)) { findActive = true }
    }

    private func jumpNext() {
        let total = matchRanges.count
        guard total > 0 else { return }
        findCurrent = (findCurrent + 1) % total
    }

    private func jumpPrev() {
        let total = matchRanges.count
        guard total > 0 else { return }
        findCurrent = (findCurrent - 1 + total) % total
    }

    private func dismissFind() {
        withAnimation(.easeOut(duration: 0.15)) {
            findActive = false
            findQuery = ""
        }
    }
}

// MARK: - NSTextView wrapper for the editor body

private struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.allowsUndo = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFontPanel = false
        tv.usesRuler = false
        tv.usesInspectorBar = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 8, height: 4)
        tv.font = NSFont(name: Typography.onestFamily, size: 16) ?? .systemFont(ofSize: 16)
        tv.textColor = NSColor(Palette.textSecondary)
        tv.insertionPointColor = NSColor(Palette.accent)
        tv.selectedTextAttributes = [
            .backgroundColor: NSColor(Palette.accent).withAlphaComponent(0.30)
        ]
        tv.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text {
            let selected = tv.selectedRange()
            tv.string = text
            let len = (tv.string as NSString).length
            let safe = NSRange(location: min(selected.location, len), length: 0)
            tv.setSelectedRange(safe)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        init(_ parent: EditorTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if parent.text != tv.string {
                parent.text = tv.string
            }
        }
    }
}
