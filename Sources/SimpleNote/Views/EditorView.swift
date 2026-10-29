import SwiftUI
import AppKit

struct EditorView: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppState.self) private var appState
    let noteID: Note.ID

    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var wordCount = 0
    @State private var wordCountTask: Task<Void, Never>?
    @State private var bodyFocusRequest = 0

    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let note = store.note(id: noteID) {
                EditorMetaBar(
                    modifiedAt: note.modifiedAt,
                    wordCount: wordCount,
                    saveState: store.saveState,
                    isPreview: appState.isPreview
                )
                .padding(.horizontal, 36)
                .padding(.top, 18)
                .padding(.bottom, 12)

                TextField("Untitled", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(Typography.serifItalic(34))
                    .foregroundStyle(Palette.text)
                    .focused($titleFocused)
                    .onSubmit { bodyFocusRequest += 1 }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 12)

                if appState.isPreview {
                    preview
                } else {
                    EditorTextView(text: $bodyText, focusRequest: bodyFocusRequest)
                        .padding(.horizontal, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
        .navigationTitle(titleText.isEmpty ? "Untitled" : titleText)
        .onAppear(perform: loadFromStore)
        .onChange(of: titleText) { _, newValue in store.update(id: noteID, title: newValue) }
        .onChange(of: bodyText) { _, newValue in
            store.update(id: noteID, body: newValue)
            scheduleWordCount()
        }
    }

    private var preview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(InlineMarkdown.paragraphs(from: bodyText).enumerated()), id: \.offset) { _, attr in
                    Text(attr)
                        .font(Typography.ui(16))
                        .foregroundStyle(Palette.text)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.bottom, 36)
        }
    }

    private func loadFromStore() {
        guard let note = store.note(id: noteID) else { return }
        titleText = note.title
        bodyText = note.body
        wordCount = WordCount.count(note.body)
        // A brand-new note starts with the cursor in the title.
        if note.title.isEmpty && note.body.isEmpty {
            titleFocused = true
        }
    }

    private func scheduleWordCount() {
        wordCountTask?.cancel()
        let snapshot = bodyText
        wordCountTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
            wordCount = WordCount.count(snapshot)
        }
    }
}

// MARK: - NSTextView wrapper for the editor body

/// Plain-text editor with the standard Mac find bar (⌘F, ⌘G, ⌘E) and undo.
private struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    /// Incremented by the parent to move keyboard focus into the editor.
    var focusRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

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
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 8, height: 4)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        tv.defaultParagraphStyle = paragraph
        tv.font = Typography.editorNSFont()
        tv.textColor = Palette.NS.text
        tv.insertionPointColor = Palette.NS.accent
        tv.selectedTextAttributes = [.backgroundColor: Palette.NS.selection]
        tv.typingAttributes = [
            .font: Typography.editorNSFont(),
            .foregroundColor: Palette.NS.text,
            .paragraphStyle: paragraph,
        ]
        tv.string = text
        context.coordinator.lastFocusRequest = focusRequest
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text {
            let selected = tv.selectedRange()
            tv.string = text
            let len = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: min(selected.location, len), length: 0))
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            tv.window?.makeFirstResponder(tv)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var lastFocusRequest = 0

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if text.wrappedValue != tv.string {
                text.wrappedValue = tv.string
            }
        }
    }
}
