import AppKit
import MdoraCore
import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @ObservedObject var commandCenter: EditorCommandCenter
    let theme: MdoraTheme

    var body: some View {
        NativeMarkdownTextView(
            text: $text,
            commandCenter: commandCenter,
            theme: theme
        )
        .background(theme.palette.editorColor)
    }
}

private struct NativeMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var commandCenter: EditorCommandCenter
    let theme: MdoraTheme

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
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

        applyTheme(to: textView, scrollView: scrollView)

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange.clamped(toLength: (textView.string as NSString).length))
        }

        if let command = commandCenter.command, command.id != context.coordinator.lastCommandID {
            context.coordinator.lastCommandID = command.id
            context.coordinator.apply(command.action)
            DispatchQueue.main.async {
                text = textView.string
            }
        }

        context.coordinator.highlight(textView)
    }

    private func applyTheme(to textView: NSTextView, scrollView: NSScrollView) {
        let palette = theme.palette
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

        init(_ parent: NativeMarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            highlight(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            highlight(textView)
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
            case .inlineCode:
                wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
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
            let palette = parent.theme.palette
            let baseFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: palette.text
            ]

            textStorage.beginEditing()
            textStorage.setAttributes(baseAttributes, range: fullRange)
            highlightLines(in: textView, storage: textStorage, baseFont: baseFont)
            highlightInline(pattern: #"`[^`]+`"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.code
            ])
            highlightInline(pattern: #"~~[^~]+~~"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.muted,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"(?<!\!)\[[^\]]+\]\[[^\]]*\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            highlightInline(pattern: #"\[\[[^\]]+\]\]"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.accent.withAlphaComponent(0.12)
            ])
            highlightInline(pattern: #"(?<!\\)\$([^$\n]+)(?<!\\)\$"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .backgroundColor: palette.code
            ])
            highlightInline(pattern: #"(?<!\w)#([A-Za-z0-9_\-/\p{Han}]+)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent
            ])
            highlightInline(pattern: #"(?<!\w)@([A-Za-z0-9_\-\.]+)"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent
            ])
            highlightInline(pattern: #"(?im)^\s*(?:[-*]\s+)?(?:<!--\s*)?\b(TODO|FIXME|BUG|HACK|NOTE|IMPORTANT|QUESTION)\b.*"#, in: textView, storage: textStorage, attributes: [
                .foregroundColor: palette.accent,
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
            ])
            highlightCurrentLine(in: textView, storage: textStorage)
            textStorage.endEditing()

            textView.typingAttributes = baseAttributes
            textView.setSelectedRange(selectedRange.clamped(toLength: fullRange.length))
        }

        @MainActor
        private func highlightLines(in textView: NSTextView, storage: NSTextStorage, baseFont: NSFont) {
            let nsString = textView.string as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            let palette = parent.theme.palette
            var isInFence = false

            nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = nsString.substring(with: lineRange)
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
                    ], range: lineRange)
                    isInFence.toggle()
                    return
                }

                if trimmed == "$$" || trimmed.hasPrefix("$$ ") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
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
                    let size = max(15, 22 - CGFloat(level * 2))
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
                    ], range: lineRange)
                    return
                }

                if self.isReferenceDefinition(trimmed) {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("<!--") {
                    storage.addAttributes([
                        .foregroundColor: palette.muted,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("|") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("> [!") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent,
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix(">") {
                    storage.addAttributes([
                        .foregroundColor: palette.muted
                    ], range: lineRange)
                    return
                }

                if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                    storage.addAttributes([
                        .foregroundColor: palette.muted,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue
                    ], range: lineRange)
                } else if trimmed.hasPrefix("- [ ]") {
                    storage.addAttributes([
                        .foregroundColor: palette.accent
                    ], range: lineRange)
                }
            }
        }

        private func isReferenceDefinition(_ line: String) -> Bool {
            guard line.hasPrefix("[") else { return false }
            guard let close = line.firstIndex(of: "]") else { return false }
            let colon = line.index(after: close)
            return colon < line.endIndex && line[colon] == ":"
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
            attributes: [NSAttributedString.Key: Any]
        ) {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return }

            let text = textView.string
            let range = NSRange(text.startIndex ..< text.endIndex, in: text)

            for match in expression.matches(in: text, range: range) {
                storage.addAttributes(attributes, range: match.range)
            }
        }
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
