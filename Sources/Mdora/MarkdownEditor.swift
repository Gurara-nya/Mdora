import AppKit
import MdoraCore
import SwiftUI

struct EditorSelection: Equatable {
    var line: Int
    var column: Int
    var selectedLength: Int

    static let start = EditorSelection(line: 1, column: 1, selectedLength: 0)
}

struct MarkdownEditor: View {
    @Binding var text: String
    @ObservedObject var commandCenter: EditorCommandCenter
    let theme: MdoraTheme
    let fontSize: CGFloat
    let focusMode: Bool
    let onSelectionChange: (EditorSelection) -> Void

    var body: some View {
        NativeMarkdownTextView(
            text: $text,
            commandCenter: commandCenter,
            theme: theme,
            fontSize: fontSize,
            focusMode: focusMode,
            onSelectionChange: onSelectionChange
        )
        .background(theme.palette.editorColor)
    }
}

private struct NativeMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var commandCenter: EditorCommandCenter
    let theme: MdoraTheme
    let fontSize: CGFloat
    let focusMode: Bool
    let onSelectionChange: (EditorSelection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownNSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        textView.onSmartNewline = { [weak textView] in
            guard let textView else { return }
            context.coordinator.parent.text = textView.string
            context.coordinator.highlight(textView)
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let themeChanged = context.coordinator.lastHighlightedTheme != theme
        let sizeChanged = context.coordinator.lastHighlightedFontSize != fontSize
        let focusModeChanged = context.coordinator.lastHighlightedFocusMode != focusMode
        let externalTextChanged = textView.string != text

        if themeChanged || sizeChanged {
            applyTheme(to: textView, scrollView: scrollView)
            context.coordinator.lastHighlightedTheme = theme
            context.coordinator.lastHighlightedFontSize = fontSize
        }

        if focusModeChanged {
            context.coordinator.lastHighlightedFocusMode = focusMode
        }

        if externalTextChanged {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange.clamped(toLength: (textView.string as NSString).length))
            context.coordinator.lastHighlightedText = text
            context.coordinator.invalidateSelectionCache()
            context.coordinator.scheduleHighlight(in: textView)
        }

        if let command = commandCenter.command, command.id != context.coordinator.lastCommandID {
            context.coordinator.lastCommandID = command.id
            context.coordinator.apply(command.action)
            DispatchQueue.main.async {
                text = textView.string
            }
            context.coordinator.invalidateSelectionCache()
            context.coordinator.scheduleHighlight(in: textView)
        }

        // Highlight immediately on theme/fontSize change to avoid styling flicker
        if themeChanged || sizeChanged || focusModeChanged {
            context.coordinator.highlight(textView)
        }
    }

    private func applyTheme(to textView: NSTextView, scrollView: NSScrollView) {
        let palette = theme.palette
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = palette.editor
        textView.textColor = palette.text
        textView.insertionPointColor = palette.accent
        textView.selectedTextAttributes = [
            .backgroundColor: palette.accent.withAlphaComponent(0.30),
            .foregroundColor: palette.text
        ]
        scrollView.backgroundColor = palette.editor
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeMarkdownTextView
        weak var textView: NSTextView?
        var lastCommandID: UUID?
        var isHighlighting = false
        private var pendingHighlightTask: Task<Void, Never>?

        var lastHighlightedTheme: MdoraTheme?
        var lastHighlightedFontSize: CGFloat?
        var lastHighlightedFocusMode: Bool?
        var lastHighlightedText: String?
        private var lastReportedSelection = EditorSelection.start
        private var lastSelectionComputation: SelectionComputation?
        private var currentHighlightRange: NSRange?
        private var lastHighlightedRange: NSRange?
        @MainActor private static var expressionCache: [ExpressionCacheKey: NSRegularExpression] = [:]

        init(_ parent: NativeMarkdownTextView) {
            self.parent = parent
        }

        func invalidateSelectionCache() {
            lastSelectionComputation = nil
        }

        @MainActor
        func scheduleHighlight(in textView: NSTextView) {
            pendingHighlightTask?.cancel()
            pendingHighlightTask = Task { @MainActor [weak self, weak textView] in
                do {
                    try await Task.sleep(nanoseconds: 120_000_000) // 0.12s
                } catch {
                    return // cancelled
                }
                guard let self, let textView else { return }
                self.highlight(textView)
            }
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scheduleHighlight(in: textView)
            _ = reportSelection(in: textView)
        }

        @MainActor
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let previousLine = lastReportedSelection.line
            let selection = reportSelection(in: textView)

            if parent.focusMode || selection.line != previousLine {
                scheduleHighlight(in: textView)
            }
        }

        @MainActor
        func apply(_ action: EditorAction) {
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)

            switch action {
            case .bold:
                wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
            case .italic:
                wrapSelection(prefix: "*", suffix: "*", placeholder: "italic text")
            case .strikethrough:
                wrapSelection(prefix: "~~", suffix: "~~", placeholder: "struck text")
            case .highlight:
                wrapSelection(prefix: "==", suffix: "==", placeholder: "highlighted text")
            case .superscript:
                wrapSelection(prefix: "^", suffix: "^", placeholder: "2")
            case .subscriptText:
                wrapSelection(prefix: "~", suffix: "~", placeholder: "2")
            case .inlineCode:
                wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
            case .keyboard:
                wrapSelection(prefix: "<kbd>", suffix: "</kbd>", placeholder: "⌘K")
            case .citation:
                wrapSelection(prefix: "[@", suffix: "]", placeholder: "citation-key")
            case .link:
                wrapSelection(prefix: "[", suffix: "](https://example.com)", placeholder: "link text")
            case .wikiLink:
                wrapSelection(prefix: "[[", suffix: "]]", placeholder: "Page Name")
            case .image:
                replaceSelection(with: "![alt text](image.png)")
            case let .heading(level):
                prefixSelectedLines(with: String(repeating: "#", count: level) + " ")
            case .quote:
                prefixSelectedLines(with: "> ")
            case .unorderedList:
                prefixSelectedLines(with: "- ")
            case .orderedList:
                prefixSelectedLines(with: "1. ")
            case .task:
                prefixSelectedLines(with: "- [ ] ")
            case .codeBlock:
                wrapSelection(prefix: "```text\n", suffix: "\n```", placeholder: "code")
            case .mathBlock:
                wrapSelection(prefix: "$$\n", suffix: "\n$$", placeholder: "E = mc^2")
            case let .diagram(kind):
                wrapSelection(prefix: "```\(kind.rawValue)\n", suffix: "\n```", placeholder: diagramPlaceholder(for: kind))
            case .footnote:
                replaceSelection(with: "[^1]\n\n[^1]: Footnote text")
            case .linkReference:
                replaceSelection(with: "[reference]: https://example.com \"Optional title\"")
            case .definitionList:
                replaceSelection(with: "Term\n: Definition")
            case let .tableOfContents(symbols):
                replaceSelection(with: tableOfContents(for: symbols))
            case .table:
                replaceSelection(with: "| Name | Value |\n| --- | --- |\n| Mdora | Native Markdown |")
            case let .callout(kind):
                replaceSelection(with: "> [!\(kind.rawValue.uppercased())]\n> \(kind.title)")
            }
        }

        private func tableOfContents(for symbols: [DocumentSymbol]) -> String {
            guard !symbols.isEmpty else {
                return "- [Untitled](#untitled)"
            }

            return symbols.map { symbol in
                let indent = String(repeating: "  ", count: max(0, symbol.level - 1))
                return "\(indent)- [\(symbol.title)](#\(symbol.anchor))"
            }.joined(separator: "\n")
        }

        private func diagramPlaceholder(for kind: DiagramKind) -> String {
            switch kind {
            case .mermaid:
                "flowchart LR\n    A[Start] --> B[Mdora]"
            case .graphviz:
                "digraph G {\n    A -> B\n}"
            case .plantuml:
                "@startuml\nAlice -> Bob: Hello\n@enduml"
            case .sequence:
                "Alice->Bob: Hello"
            case .flowchart:
                "start=>start: Start\nend=>end: End\nstart->end"
            }
        }

        @MainActor
        private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
            guard let textView else { return }
            let range = textView.selectedRange()
            let source = textView.string as NSString
            let selected = range.length > 0 ? source.substring(with: range) : placeholder
            let replacement = prefix + selected + suffix

            textView.insertText(replacement, replacementRange: range)

            if range.length == 0 {
                let start = range.location + prefix.utf16.count
                textView.setSelectedRange(NSRange(location: start, length: placeholder.utf16.count))
            }
        }

        @MainActor
        private func replaceSelection(with replacement: String) {
            guard let textView else { return }
            textView.insertText(replacement, replacementRange: textView.selectedRange())
        }

        @MainActor
        private func reportSelection(in textView: NSTextView) -> EditorSelection {
            let selection = selection(in: textView)
            lastReportedSelection = selection
            parent.onSelectionChange(selection)
            return selection
        }

        @MainActor
        private func selection(in textView: NSTextView) -> EditorSelection {
            let source = textView.string as NSString
            let selectedRange = textView.selectedRange().clamped(toLength: source.length)
            let position = selectedRange.location
            let cached = lastSelectionComputation
            var line = cached?.line ?? 1
            var lineStart = cached?.lineStart ?? 0
            var cursor = cached?.location ?? 0

            if cursor > position || cursor > source.length || lineStart > position {
                line = 1
                lineStart = 0
                cursor = 0
            }

            while cursor < position {
                let character = source.character(at: cursor)
                if character == 10 || character == 13 {
                    line += 1

                    if character == 13,
                       cursor + 1 < position,
                       source.character(at: cursor + 1) == 10 {
                        cursor += 1
                    }

                    lineStart = cursor + 1
                }

                cursor += 1
            }

            lastSelectionComputation = SelectionComputation(
                location: position,
                line: line,
                lineStart: lineStart
            )

            return EditorSelection(
                line: line,
                column: position - lineStart + 1,
                selectedLength: selectedRange.length
            )
        }

        @MainActor
        private func prefixSelectedLines(with prefix: String) {
            guard let textView else { return }

            let source = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let lineRange = source.lineRange(for: selectedRange)

            if selectedRange.length == 0 {
                textView.insertText(prefix, replacementRange: NSRange(location: lineRange.location, length: 0))
                return
            }

            let selectedLines = source.substring(with: lineRange)
            let endsWithNewline = selectedLines.hasSuffix("\n")
            var lines = selectedLines.components(separatedBy: "\n")

            if endsWithNewline {
                lines.removeLast()
            }

            let replacement = lines.map { line in
                line.isEmpty ? line : prefix + line
            }.joined(separator: "\n") + (endsWithNewline ? "\n" : "")

            textView.insertText(replacement, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
        }

        @MainActor
        func highlight(_ textView: NSTextView) {
            guard !isHighlighting else { return }
            guard let textStorage = textView.textStorage else { return }

            isHighlighting = true
            defer { isHighlighting = false }

            let selectedRange = textView.selectedRange()
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            let targetRange = Self.highlightRange(in: textView, selectedRange: selectedRange)
            let resetRange = Self.union(targetRange, lastHighlightedRange).clamped(toLength: fullRange.length)
            let palette = parent.theme.palette
            let baseSize = parent.fontSize
            let baseFont = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: palette.text
            ]

            textStorage.beginEditing()
            currentHighlightRange = targetRange
            textStorage.setAttributes(baseAttributes, range: resetRange)
            highlightLines(in: textView, storage: textStorage, baseFont: baseFont)
            highlightInline(pattern: #"\|"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted
            ])
            highlightInline(pattern: #"!\[[^\]]*\]\([^\)]+\)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.10)
            ])
            highlightInline(pattern: #"!\[[^\]]*\]\[[^\]]*\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.10)
            ])
            highlightInline(pattern: #"`[^`]+`"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .backgroundColor: palette.code
            ])
            highlightInline(pattern: #"\*\*[^*\n]+\*\*|__[^_\n]+__"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .bold)
            ])
            highlightInline(pattern: #"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .font: italicFont(size: baseSize)
            ])
            highlightInline(pattern: #"~~[^~]+~~"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"==[^=\n]+=="#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .backgroundColor: palette.accent.withAlphaComponent(0.16)
            ])
            highlightInline(pattern: #"\{#[A-Za-z0-9_\-:\.]+(?:\s+[^}\n]+)?\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.12),
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 2), weight: .medium)
            ])
            highlightInline(pattern: #"\{\+\+[^\n]*?\+\+\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"\{--[^\n]*?--\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"\{~~[^\n]*?~>[^\n]*?~~\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.code
            ])
            highlightInline(pattern: #"\{>>[^\n]*?<<\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted,
                .backgroundColor: palette.surface
            ])
            highlightInline(pattern: #"\{==[^\n]*?==\}"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .backgroundColor: palette.accent.withAlphaComponent(0.20)
            ])
            highlightInline(pattern: #"(?<!\^)\^[^^\n]+\^(?!\^)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .baselineOffset: 4,
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 3), weight: .medium)
            ])
            highlightInline(pattern: #"(?m)(?<=\s)\^[A-Za-z0-9_\-:\.]+$"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.12),
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 2), weight: .medium)
            ])
            highlightInline(pattern: #"(?<!~)~[^~\n]+~(?!~)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .baselineOffset: -2,
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 3), weight: .medium)
            ])
            highlightInline(pattern: #"(?<!\!)\[([^\]]+)\]\(([^\)]+)\)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"(?<!\!)\[[^\]]+\]\[[^\]]*\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"!\[\[[^\]]+\]\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.18)
            ])
            highlightInline(pattern: #"(?<!\!)\[\[[^\]]+\]\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.12)
            ])
            highlightInline(pattern: #"(?<!\\)\$([^$\n]+)(?<!\\)\$"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.code
            ])
            highlightInline(pattern: #"\[\^[^\]]+\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .baselineOffset: 3,
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 3), weight: .medium)
            ])
            highlightInline(pattern: #"\[@[^\]]+\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted,
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 2), weight: .medium)
            ])
            highlightInline(pattern: #"<kbd>[^<]+</kbd>"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.text,
                .backgroundColor: palette.surface,
                .font: NSFont.monospacedSystemFont(ofSize: max(10, baseSize - 2), weight: .semibold)
            ])
            highlightInline(pattern: #"<[A-Z][A-Z0-9+\-.]{1,31}:[^\s<>]+>|<[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}>"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], options: [.caseInsensitive])
            highlightInline(pattern: #"(?<!\w):[A-Za-z0-9_\-\+]{2,}:"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
            ])
            highlightInline(pattern: ##"(?<![\]\)">])(https?://[^\s<\)]+)"##, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"(?<![\w@])([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})(?![\w@])"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], options: [.caseInsensitive])
            highlightInline(pattern: #"(?<!\w)#([A-Za-z0-9_\-/\p{Han}]+)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent
            ])
            highlightInline(pattern: #"(?<!\w)@([A-Za-z0-9_\-\.]+)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent
            ])
            highlightInline(pattern: #"(?im)^\s*(?:[-*]\s+)?(?:<!--\s*)?\b(TODO|FIXME|BUG|HACK|NOTE|IMPORTANT|QUESTION)\b.*"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .semibold)
            ])
            highlightCurrentLine(in: textView, storage: textStorage)
            textStorage.endEditing()

            currentHighlightRange = nil
            lastHighlightedRange = targetRange
            textView.typingAttributes = baseAttributes
            textView.setSelectedRange(selectedRange.clamped(toLength: fullRange.length))
        }

        @MainActor
        private static func highlightRange(in textView: NSTextView, selectedRange: NSRange) -> NSRange {
            let nsString = textView.string as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            guard nsString.length > 0 else { return fullRange }

            if nsString.length <= 50_000 {
                return fullRange
            }

            let selectedLineRange = nsString.lineRange(for: selectedRange.clamped(toLength: nsString.length))
            let visibleRange = visibleCharacterRange(in: textView)
            let anchorRange = visibleRange?.length ?? 0 > 0
                ? NSUnionRange(visibleRange!, selectedLineRange)
                : selectedLineRange
            let margin = 10_000
            let lowerBound = max(0, anchorRange.location - margin)
            let upperBound = min(nsString.length, anchorRange.upperBound + margin)
            return nsString.lineRange(for: NSRange(location: lowerBound, length: upperBound - lowerBound))
        }

        @MainActor
        private static func visibleCharacterRange(in textView: NSTextView) -> NSRange? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return nil
            }

            var visibleRect = textView.visibleRect
            visibleRect.origin.x -= textView.textContainerInset.width
            visibleRect.origin.y -= textView.textContainerInset.height
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        }

        private static func union(_ lhs: NSRange, _ rhs: NSRange?) -> NSRange {
            guard let rhs, rhs.location != NSNotFound else { return lhs }
            return NSUnionRange(lhs, rhs)
        }

        @MainActor
        private func highlightLines(in textView: NSTextView, storage: NSTextStorage, baseFont: NSFont) {
            let nsString = textView.string as NSString
            let fullRange = currentHighlightRange ?? NSRange(location: 0, length: nsString.length)
            let palette = parent.theme.palette
            let baseSize = parent.fontSize
            var isInFence = isInsideCodeFence(at: fullRange.location, in: nsString)

            let selectedRange = textView.selectedRange()
            let clampedLocation = min(selectedRange.location, max(0, nsString.length - 1))
            let activeLineRange = nsString.lineRange(for: NSRange(location: clampedLocation, length: 0))

            nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = nsString.substring(with: lineRange)
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                let isActiveLine = (lineRange.location >= activeLineRange.location && lineRange.location < activeLineRange.upperBound) ||
                                   (activeLineRange.location >= lineRange.location && activeLineRange.location < lineRange.upperBound)

                if self.parent.focusMode && !isActiveLine {
                    let fadedColor = isInFence ? palette.muted.withAlphaComponent(0.20) : palette.text.withAlphaComponent(0.30)
                    let bgAttr: [NSAttributedString.Key: Any] = isInFence ? [.backgroundColor: palette.code.withAlphaComponent(0.04)] : [:]
                    storage.addAttributes([
                        .foregroundColor: fadedColor,
                        .font: isInFence ? baseFont : NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
                    ].merging(bgAttr) { $1 }, range: lineRange)

                    if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                        isInFence.toggle()
                    }
                    return
                }

                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .semibold)
                    ], range: lineRange)
                    isInFence.toggle()
                    return
                }

                if trimmed == "$$" || trimmed.hasPrefix("$$ ") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .semibold)
                    ], range: lineRange)
                    return
                }

                if self.isFrontMatterFence(lineRange: lineRange, in: nsString) {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if isInFence {
                    storage.addAttributes([
                        .foregroundColor: palette.muted,
                        .backgroundColor: palette.code,
                        .font: baseFont
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("#") {
                    let level = trimmed.prefix { character in
                        character == "#"
                    }.count
                    let size = max(baseSize, baseSize + 7 - CGFloat(level * 2))
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
                    ], range: lineRange)
                    return
                }

                if self.isReferenceDefinition(trimmed) {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if self.isAbbreviationDefinition(trimmed) {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .backgroundColor: palette.accent.withAlphaComponent(0.10),
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if self.isMetadataLine(trimmed, lineRange: lineRange, in: nsString) {
                    storage.addAttributes([
                        .foregroundColor: palette.muted,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("<!--") {
                    storage.addAttributes([
                        .foregroundColor: palette.muted,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("|") {
                    if trimmed.range(of: "^\\|[:\\-\\s|]+$", options: .regularExpression) != nil {
                        storage.addAttributes([
                            .foregroundColor: palette.muted,
                            .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                        ], range: lineRange)
                    }
                    return
                }

                if trimmed.hasPrefix("> [!") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .semibold)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix(">") {
                    storage.addAttributes([
                        .foregroundColor: palette.muted
                    ], range: lineRange)
                    return
                }

                if let taskState = self.taskStateMarker(in: trimmed) {
                    var attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: taskState == " " ? palette.accent : palette.muted,
                        .font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .medium)
                    ]

                    if taskState == "x" || taskState == "X" || taskState == "-" {
                        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    }

                    storage.addAttributes(attributes, range: lineRange)
                }
            }
        }

        private func taskStateMarker(in trimmedLine: String) -> Character? {
            guard trimmedLine.count >= 6,
                  ["- ", "* ", "+ "].contains(where: { trimmedLine.hasPrefix($0) }) else {
                return nil
            }

            let markerOpen = trimmedLine.index(trimmedLine.startIndex, offsetBy: 2)
            let markerValue = trimmedLine.index(after: markerOpen)
            let markerClose = trimmedLine.index(markerOpen, offsetBy: 2)
            guard trimmedLine[markerOpen] == "[",
                  trimmedLine[markerClose] == "]",
                  trimmedLine.index(after: markerClose) < trimmedLine.endIndex,
                  trimmedLine[trimmedLine.index(after: markerClose)] == " " else {
                return nil
            }

            let marker = trimmedLine[markerValue]
            return " xX/->!?".contains(marker) ? marker : nil
        }

        private func isReferenceDefinition(_ line: String) -> Bool {
            guard line.hasPrefix("[") else { return false }
            guard let close = line.firstIndex(of: "]") else { return false }
            let colon = line.index(after: close)
            return colon < line.endIndex && line[colon] == ":"
        }

        private func isAbbreviationDefinition(_ line: String) -> Bool {
            guard line.hasPrefix("*[") else { return false }
            guard let close = line.firstIndex(of: "]") else { return false }
            let colon = line.index(after: close)
            return colon < line.endIndex && line[colon] == ":"
        }

        private func isMetadataLine(_ line: String, lineRange: NSRange, in string: NSString) -> Bool {
            guard lineRange.location > 0 else { return false }
            guard line.contains(":") || line.contains("=") else { return false }
            return isInsideFrontMatter(lineRange: lineRange, in: string)
        }

        private func isFrontMatterFence(lineRange: NSRange, in string: NSString) -> Bool {
            let line = string.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line == "---" || line == "+++" else { return false }
            return lineRange.location == 0 || isInsideFrontMatter(lineRange: lineRange, in: string)
        }

        private func isInsideFrontMatter(lineRange: NSRange, in string: NSString) -> Bool {
            guard string.length > 0 else { return false }
            let firstLineRange = string.lineRange(for: NSRange(location: 0, length: 0))
            let firstLine = string.substring(with: firstLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard firstLine == "---" || firstLine == "+++" else { return false }
            guard lineRange.location >= firstLineRange.upperBound else { return true }

            var cursor = firstLineRange.upperBound

            while cursor < string.length {
                let candidateRange = string.lineRange(for: NSRange(location: cursor, length: 0))
                let candidate = string.substring(with: candidateRange).trimmingCharacters(in: .whitespacesAndNewlines)

                if candidate == firstLine {
                    return lineRange.location <= candidateRange.location
                }

                cursor = candidateRange.upperBound
            }

            return false
        }

        private func isInsideCodeFence(at location: Int, in string: NSString) -> Bool {
            guard location > 0, string.length > 0 else { return false }
            var cursor = 0
            var openFence: String?

            while cursor < min(location, string.length) {
                let lineRange = string.lineRange(for: NSRange(location: cursor, length: 0))
                let line = string.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

                if line.hasPrefix("```") || line.hasPrefix("~~~") {
                    let fence = String(line.prefix(3))
                    if openFence == fence {
                        openFence = nil
                    } else if openFence == nil {
                        openFence = fence
                    }
                }

                let nextCursor = lineRange.upperBound
                guard nextCursor > cursor else { break }
                cursor = nextCursor
            }

            return openFence != nil
        }

        @MainActor
        private func highlightCurrentLine(in textView: NSTextView, storage: NSTextStorage) {
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            guard nsString.length > 0 else { return }

            let clampedLocation = min(selectedRange.location, max(0, nsString.length - 1))
            let lineRange = nsString.lineRange(for: NSRange(location: clampedLocation, length: 0))
            let palette = parent.theme.palette

            storage.addAttributes([
                .backgroundColor: palette.accent.withAlphaComponent(0.07)
            ], range: lineRange)
        }

        @MainActor
        private func highlightInline(
            pattern: String,
            in textView: NSTextView,
            storage: NSTextStorage,
            attributes: [NSAttributedString.Key: Any],
            options: NSRegularExpression.Options = []
        ) {
            guard let expression = Self.cachedExpression(pattern: pattern, options: options) else { return }

            let text = textView.string
            let fullRange = NSRange(text.startIndex ..< text.endIndex, in: text)
            let range = (currentHighlightRange ?? fullRange).clamped(toLength: fullRange.length)

            for match in expression.matches(in: text, range: range) {
                storage.addAttributes(attributes, range: match.range)
            }
        }

        @MainActor
        private static func cachedExpression(
            pattern: String,
            options: NSRegularExpression.Options
        ) -> NSRegularExpression? {
            let key = ExpressionCacheKey(pattern: pattern, optionsRawValue: options.rawValue)
            if let cached = expressionCache[key] {
                return cached
            }

            guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
                return nil
            }

            expressionCache[key] = expression
            return expression
        }

        private func italicFont(size: CGFloat) -> NSFont {
            let base = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        }
    }

    private struct ExpressionCacheKey: Hashable {
        var pattern: String
        var optionsRawValue: UInt
    }

    private struct SelectionComputation {
        var location: Int
        var line: Int
        var lineStart: Int
    }
}

private final class MarkdownNSTextView: NSTextView {
    var onSmartNewline: (() -> Void)?

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard let typedString = string as? String, typedString.count == 1 else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let char = typedString.first!
        let pairs: [Character: Character] = [
            "(": ")",
            "[": "]",
            "{": "}",
            "\"": "\"",
            "'": "'",
            "`": "`"
        ]

        if let closingChar = pairs[char] {
            let selectedRange = self.selectedRange()

            if selectedRange.length > 0 {
                let source = self.string as NSString
                let selectedText = source.substring(with: selectedRange)
                let wrapped = String(char) + selectedText + String(closingChar)
                super.insertText(wrapped, replacementRange: selectedRange)
                self.setSelectedRange(NSRange(location: selectedRange.location, length: wrapped.utf16.count))
            } else {
                super.insertText(String(char) + String(closingChar), replacementRange: replacementRange)
                self.setSelectedRange(NSRange(location: self.selectedRange().location - 1, length: 0))
            }
            onSmartNewline?()
            return
        }

        let closingBrackets: Set<Character> = [")", "]", "}", "\"", "'", "`"]
        if closingBrackets.contains(char) {
            let selectedRange = self.selectedRange()
            if selectedRange.length == 0 {
                let source = self.string as NSString
                if selectedRange.location < source.length {
                    let nextChar = Character(UnicodeScalar(source.character(at: selectedRange.location))!)
                    if nextChar == char {
                        self.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))
                        return
                    }
                }
            }
        }

        super.insertText(string, replacementRange: replacementRange)
    }

    override func deleteBackward(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        guard selectedRange.length == 0, selectedRange.location > 0 else {
            super.deleteBackward(sender)
            onSmartNewline?()
            return
        }

        let source = self.string as NSString
        guard selectedRange.location < source.length else {
            super.deleteBackward(sender)
            onSmartNewline?()
            return
        }

        let leftChar = Character(UnicodeScalar(source.character(at: selectedRange.location - 1))!)
        let rightChar = Character(UnicodeScalar(source.character(at: selectedRange.location))!)

        let pairs: [Character: Character] = [
            "(": ")",
            "[": "]",
            "{": "}",
            "\"": "\"",
            "'": "'",
            "`": "`"
        ]

        if let expectedRight = pairs[leftChar], rightChar == expectedRight {
            let deleteRange = NSRange(location: selectedRange.location - 1, length: 2)
            super.insertText("", replacementRange: deleteRange)
            onSmartNewline?()
            return
        }

        super.deleteBackward(sender)
        onSmartNewline?()
    }

    override func insertNewline(_ sender: Any?) {
        guard selectedRange().length == 0 else {
            super.insertNewline(sender)
            onSmartNewline?()
            return
        }

        if let continuation = smartContinuation() {
            insertText(continuation, replacementRange: selectedRange())
            onSmartNewline?()
        } else {
            super.insertNewline(sender)
            onSmartNewline?()
        }
    }

    override func insertTab(_ sender: Any?) {
        applyLineEdit(MarkdownLineEditor.indentingLines(in: string, selectedRange: selectedRange()))
    }

    override func insertBacktab(_ sender: Any?) {
        applyLineEdit(MarkdownLineEditor.outdentingLines(in: string, selectedRange: selectedRange()))
    }

    private func applyLineEdit(_ edit: MarkdownLineEdit) {
        super.insertText(edit.replacement, replacementRange: edit.replacementRange)
        setSelectedRange(edit.selectedRange)
        onSmartNewline?()
    }

    private func smartContinuation() -> String? {
        let source = string as NSString
        guard source.length > 0 else { return nil }

        let selectedLocation = selectedRange().location
        let lookupLocation = max(0, min(selectedLocation, source.length) - 1)
        let lineRange = source.lineRange(for: NSRange(location: lookupLocation, length: 0))
        let linePrefixLength = max(0, selectedLocation - lineRange.location)
        let linePrefix = source.substring(with: NSRange(location: lineRange.location, length: linePrefixLength))
        return MarkdownTypingContinuation.continuation(after: linePrefix)
    }
}

private extension NSRange {
    func clamped(toLength length: Int) -> NSRange {
        guard location <= length else {
            return NSRange(location: length, length: 0)
        }

        return NSRange(location: location, length: Swift.min(self.length, length - location))
    }
}
