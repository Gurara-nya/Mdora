import Foundation

public struct MarkdownLineEdit {
    public var replacementRange: NSRange
    public var replacement: String
    public var selectedRange: NSRange
    public var updatedText: String

    public init(replacementRange: NSRange, replacement: String, selectedRange: NSRange, updatedText: String) {
        self.replacementRange = replacementRange
        self.replacement = replacement
        self.selectedRange = selectedRange
        self.updatedText = updatedText
    }
}

public enum MarkdownLineEditor {
    public static let defaultIndent = "  "

    public static func indentingLines(
        in text: String,
        selectedRange: NSRange,
        indent: String = defaultIndent
    ) -> MarkdownLineEdit {
        let source = text as NSString
        let selection = selectedRange.clamped(toLength: source.length)
        let lineRange = source.lineRange(for: selection)
        let selectedLines = source.substring(with: lineRange)
        let replacement = splitLines(selectedLines)
            .map { line in indent + line.body + line.ending }
            .joined()

        let selectedRange: NSRange
        if selection.length == 0 {
            selectedRange = NSRange(location: selection.location + indent.utf16.count, length: 0)
        } else {
            selectedRange = NSRange(location: lineRange.location, length: replacement.utf16.count)
        }

        return edit(
            source: source,
            replacementRange: lineRange,
            replacement: replacement,
            selectedRange: selectedRange
        )
    }

    public static func outdentingLines(
        in text: String,
        selectedRange: NSRange,
        indent: String = defaultIndent
    ) -> MarkdownLineEdit {
        let source = text as NSString
        let selection = selectedRange.clamped(toLength: source.length)
        let lineRange = source.lineRange(for: selection)
        let selectedLines = source.substring(with: lineRange)
        var removedFromFirstLine = 0

        let replacement = splitLines(selectedLines)
            .enumerated()
            .map { index, line in
                let outdented = outdentedBody(line.body, indent: indent)
                if index == 0 {
                    removedFromFirstLine = outdented.removedCount
                }
                return outdented.body + line.ending
            }
            .joined()

        let selectedRange: NSRange
        if selection.length == 0 {
            let cursorOffset = max(0, selection.location - lineRange.location)
            let removedBeforeCursor = min(cursorOffset, removedFromFirstLine)
            selectedRange = NSRange(location: selection.location - removedBeforeCursor, length: 0)
        } else {
            selectedRange = NSRange(location: lineRange.location, length: replacement.utf16.count)
        }

        return edit(
            source: source,
            replacementRange: lineRange,
            replacement: replacement,
            selectedRange: selectedRange
        )
    }

    private static func edit(
        source: NSString,
        replacementRange: NSRange,
        replacement: String,
        selectedRange: NSRange
    ) -> MarkdownLineEdit {
        let updated = NSMutableString(string: source as String)
        updated.replaceCharacters(in: replacementRange, with: replacement)
        return MarkdownLineEdit(
            replacementRange: replacementRange,
            replacement: replacement,
            selectedRange: selectedRange,
            updatedText: String(updated)
        )
    }

    private static func splitLines(_ text: String) -> [Line] {
        let source = text as NSString
        guard source.length > 0 else {
            return [Line(body: "", ending: "")]
        }

        var lines: [Line] = []
        var location = 0

        while location < source.length {
            let range = source.lineRange(for: NSRange(location: location, length: 0))
            guard range.length > 0 else { break }

            lines.append(Line(rawValue: source.substring(with: range)))
            location = NSMaxRange(range)
        }

        return lines.isEmpty ? [Line(body: "", ending: "")] : lines
    }

    private static func outdentedBody(_ body: String, indent: String) -> (body: String, removedCount: Int) {
        if body.hasPrefix(indent) {
            return (String(body.dropFirst(indent.count)), indent.utf16.count)
        }

        if body.hasPrefix("\t") {
            return (String(body.dropFirst()), 1)
        }

        let spacesToRemove = min(indent.count, body.prefix { $0 == " " }.count)
        guard spacesToRemove > 0 else {
            return (body, 0)
        }

        return (String(body.dropFirst(spacesToRemove)), spacesToRemove)
    }
}

private struct Line {
    var body: String
    var ending: String

    init(body: String, ending: String) {
        self.body = body
        self.ending = ending
    }

    init(rawValue: String) {
        if rawValue.hasSuffix("\r\n") {
            body = String(rawValue.dropLast(2))
            ending = "\r\n"
        } else if rawValue.hasSuffix("\n") || rawValue.hasSuffix("\r") {
            body = String(rawValue.dropLast())
            ending = String(rawValue.suffix(1))
        } else {
            body = rawValue
            ending = ""
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
