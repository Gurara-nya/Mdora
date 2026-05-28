import Foundation

public enum InlineMarkdownParser {
    public static func parse(_ text: String) -> [InlineMarkdownSegment] {
        var parser = InlineParser(text: text)
        return parser.parse()
    }
}

private struct InlineParser {
    let text: String
    var index: String.Index
    var textBuffer = ""

    init(text: String) {
        self.text = text
        index = text.startIndex
    }

    mutating func parse() -> [InlineMarkdownSegment] {
        var segments: [InlineMarkdownSegment] = []

        while index < text.endIndex {
            if consumeEscape() {
                continue
            }

            if let segment = consumeNextSegment() {
                flushText(into: &segments)
                segments.append(segment)
                continue
            }

            textBuffer.append(text[index])
            index = text.index(after: index)
        }

        flushText(into: &segments)
        return coalescedTextSegments(segments)
    }

    private mutating func consumeNextSegment() -> InlineMarkdownSegment? {
        if let segment = consumeCode() { return segment }
        if let segment = consumeCriticMarkup() { return segment }
        if let segment = consumeStrong() { return segment }
        if let segment = consumeStrikethrough() { return segment }
        if let segment = consumeEmphasis() { return segment }
        if let segment = consumeHighlight() { return segment }
        if let segment = consumeSuperscript() { return segment }
        if let segment = consumeSubscript() { return segment }
        if let segment = consumeInlineMath() { return segment }
        if let segment = consumeKeyboard() { return segment }
        if let segment = consumeAngleAutoLink() { return segment }
        if let segment = consumeImage() { return segment }
        if let segment = consumeCitation() { return segment }
        if let segment = consumeLinkOrFootnote() { return segment }
        if let segment = consumeWikiLink() { return segment }
        if let segment = consumeAutoLink() { return segment }
        if let segment = consumeEmail() { return segment }
        if let segment = consumeEmojiShortcode() { return segment }
        return consumeSymbolToken()
    }

    private mutating func flushText(into segments: inout [InlineMarkdownSegment]) {
        guard !textBuffer.isEmpty else { return }
        segments.append(.text(textBuffer))
        textBuffer.removeAll(keepingCapacity: true)
    }

    private func coalescedTextSegments(_ segments: [InlineMarkdownSegment]) -> [InlineMarkdownSegment] {
        var coalesced: [InlineMarkdownSegment] = []

        for segment in segments {
            if case let .text(value) = segment,
               case let .text(previous) = coalesced.last {
                coalesced[coalesced.count - 1] = .text(previous + value)
            } else {
                coalesced.append(segment)
            }
        }

        return coalesced
    }

    private mutating func consumeEscape() -> Bool {
        guard text[index] == "\\" else { return false }
        let next = text.index(after: index)
        guard next < text.endIndex else { return false }

        textBuffer.append(text[next])
        index = text.index(after: next)
        return true
    }

    private mutating func consumeCode() -> InlineMarkdownSegment? {
        guard hasPrefix("`") else { return nil }
        let contentStart = text.index(after: index)
        guard let close = closingIndex(for: "`", after: contentStart) else { return nil }
        let value = String(text[contentStart ..< close])
        guard !value.isEmpty else { return nil }

        index = text.index(after: close)
        return .code(value)
    }

    private mutating func consumeCriticMarkup() -> InlineMarkdownSegment? {
        if let segment = consumeCriticDelimited(
            open: "{++",
            close: "++}",
            as: InlineMarkdownSegment.criticAddition
        ) {
            return segment
        }

        if let segment = consumeCriticDelimited(
            open: "{--",
            close: "--}",
            as: InlineMarkdownSegment.criticDeletion
        ) {
            return segment
        }

        if let segment = consumeCriticSubstitution() {
            return segment
        }

        if let segment = consumeCriticDelimited(
            open: "{>>",
            close: "<<}",
            as: InlineMarkdownSegment.criticComment
        ) {
            return segment
        }

        return consumeCriticDelimited(
            open: "{==",
            close: "==}",
            as: InlineMarkdownSegment.criticHighlight
        )
    }

    private mutating func consumeCriticDelimited(
        open: String,
        close: String,
        as factory: (String) -> InlineMarkdownSegment
    ) -> InlineMarkdownSegment? {
        guard hasPrefix(open) else { return nil }
        let contentStart = text.index(index, offsetBy: open.count)
        guard let closeIndex = closingIndex(for: close, after: contentStart) else { return nil }

        let value = String(text[contentStart ..< closeIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: \.isNewline) else { return nil }

        index = text.index(closeIndex, offsetBy: close.count)
        return factory(value)
    }

    private mutating func consumeCriticSubstitution() -> InlineMarkdownSegment? {
        let open = "{~~"
        let close = "~~}"

        guard hasPrefix(open) else { return nil }
        let contentStart = text.index(index, offsetBy: open.count)
        guard let closeIndex = closingIndex(for: close, after: contentStart) else { return nil }

        let rawValue = String(text[contentStart ..< closeIndex])
        guard !rawValue.contains(where: \.isNewline),
              let separator = rawValue.range(of: "~>") else {
            return nil
        }

        let original = String(rawValue[..<separator.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = String(rawValue[separator.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, !replacement.isEmpty else { return nil }

        index = text.index(closeIndex, offsetBy: close.count)
        return .criticSubstitution(original: original, replacement: replacement)
    }

    private mutating func consumeStrong() -> InlineMarkdownSegment? {
        if let segment = consumeDelimited(marker: "**", as: InlineMarkdownSegment.strong) {
            return segment
        }

        return consumeDelimited(marker: "__", as: InlineMarkdownSegment.strong)
    }

    private mutating func consumeStrikethrough() -> InlineMarkdownSegment? {
        consumeDelimited(marker: "~~", as: InlineMarkdownSegment.strikethrough)
    }

    private mutating func consumeHighlight() -> InlineMarkdownSegment? {
        consumeDelimited(marker: "==", as: InlineMarkdownSegment.highlight)
    }

    private mutating func consumeSuperscript() -> InlineMarkdownSegment? {
        consumeDelimited(marker: "^", as: InlineMarkdownSegment.superscript)
    }

    private mutating func consumeSubscript() -> InlineMarkdownSegment? {
        consumeDelimited(marker: "~", as: InlineMarkdownSegment.subscriptText)
    }

    private mutating func consumeEmphasis() -> InlineMarkdownSegment? {
        if let segment = consumeDelimited(marker: "*", as: InlineMarkdownSegment.emphasis) {
            return segment
        }

        return consumeDelimited(marker: "_", as: InlineMarkdownSegment.emphasis)
    }

    private mutating func consumeInlineMath() -> InlineMarkdownSegment? {
        guard hasPrefix("$") else { return nil }
        let contentStart = text.index(after: index)
        guard contentStart < text.endIndex, text[contentStart] != " " else { return nil }
        guard let close = closingIndex(for: "$", after: contentStart) else { return nil }

        let value = String(text[contentStart ..< close]).trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        index = text.index(after: close)
        return .inlineMath(value)
    }

    private mutating func consumeKeyboard() -> InlineMarkdownSegment? {
        guard hasPrefix("<kbd>") else { return nil }
        let contentStart = text.index(index, offsetBy: 5)
        guard let close = text[contentStart...].range(of: "</kbd>")?.lowerBound else { return nil }

        let value = String(text[contentStart ..< close]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        index = text.index(close, offsetBy: 6)
        return .keyboard(value)
    }

    private mutating func consumeAngleAutoLink() -> InlineMarkdownSegment? {
        guard hasPrefix("<") else { return nil }
        let valueStart = text.index(after: index)
        guard let close = closingIndex(for: ">", after: valueStart) else { return nil }

        let value = String(text[valueStart ..< close])
        guard !value.isEmpty else { return nil }
        guard !value.contains(where: { $0.isWhitespace || $0.isNewline || $0 == "<" || $0 == ">" }) else {
            return nil
        }

        if Self.isAbsoluteURI(value) {
            index = text.index(after: close)
            return .autoLink(value)
        }

        if Self.isEmailAddress(value) {
            index = text.index(after: close)
            return .email(value)
        }

        return nil
    }

    private mutating func consumeDelimited(
        marker: String,
        as factory: (String) -> InlineMarkdownSegment
    ) -> InlineMarkdownSegment? {
        guard hasPrefix(marker) else { return nil }
        guard marker.count > 1 || isInlineDelimiterStart(marker) else { return nil }

        let contentStart = text.index(index, offsetBy: marker.count)
        guard contentStart < text.endIndex else { return nil }
        guard let close = closingIndex(for: marker, after: contentStart) else { return nil }

        let value = String(text[contentStart ..< close])
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        index = text.index(close, offsetBy: marker.count)
        return factory(value)
    }

    private mutating func consumeImage() -> InlineMarkdownSegment? {
        guard hasPrefix("![") else { return nil }
        let altStart = text.index(index, offsetBy: 2)
        guard let closeAlt = closingIndex(for: "]", after: altStart) else { return nil }

        let alt = String(text[altStart ..< closeAlt])
        let afterAlt = text.index(after: closeAlt)
        guard afterAlt < text.endIndex else { return nil }

        if text[afterAlt] == "(",
           let destination = parseParenthesizedDestination(from: afterAlt) {
            index = destination.end
            return .image(alt: alt, source: destination.destination, title: destination.title)
        }

        if text[afterAlt] == "[",
           let label = parseBracketedText(from: afterAlt) {
            index = label.end
            return .imageReference(alt: alt, label: label.value.isEmpty ? alt : label.value)
        }

        return nil
    }

    private mutating func consumeCitation() -> InlineMarkdownSegment? {
        guard hasPrefix("[@") else { return nil }
        let idStart = text.index(index, offsetBy: 2)
        guard let close = closingIndex(for: "]", after: idStart) else { return nil }

        let identifier = String(text[idStart ..< close])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return nil }

        index = text.index(after: close)
        return .citation(identifier)
    }

    private mutating func consumeLinkOrFootnote() -> InlineMarkdownSegment? {
        guard hasPrefix("[") else { return nil }

        if hasPrefix("[^") {
            let idStart = text.index(index, offsetBy: 2)
            guard let close = closingIndex(for: "]", after: idStart) else { return nil }
            let identifier = String(text[idStart ..< close])
            guard !identifier.isEmpty else { return nil }
            index = text.index(after: close)
            return .footnote(identifier)
        }

        let textStart = text.index(after: index)
        guard let closeText = closingIndex(for: "]", after: textStart) else { return nil }

        let labelText = String(text[textStart ..< closeText])
        let afterText = text.index(after: closeText)
        guard afterText < text.endIndex else { return nil }

        if text[afterText] == "(",
           let destination = parseParenthesizedDestination(from: afterText) {
            index = destination.end
            return .link(text: labelText, destination: destination.destination, title: destination.title)
        }

        if text[afterText] == "[",
           let reference = parseBracketedText(from: afterText) {
            let label = reference.value.isEmpty ? labelText : reference.value
            guard !label.isEmpty else { return nil }
            index = reference.end
            return .referenceLink(text: labelText, label: label)
        }

        return nil
    }

    private mutating func consumeWikiLink() -> InlineMarkdownSegment? {
        guard hasPrefix("[[") else { return nil }
        let contentStart = text.index(index, offsetBy: 2)
        guard let close = closingIndex(for: "]]", after: contentStart) else { return nil }
        let value = String(text[contentStart ..< close]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        index = text.index(close, offsetBy: 2)
        return .wikiLink(value)
    }

    private mutating func consumeAutoLink() -> InlineMarkdownSegment? {
        guard hasPrefix("http://") || hasPrefix("https://") else { return nil }
        guard isBoundaryBeforeIndex else { return nil }

        var cursor = index
        while cursor < text.endIndex {
            let character = text[cursor]
            if character.isWhitespace || character == "<" || character == ")" {
                break
            }
            cursor = text.index(after: cursor)
        }

        let rawURL = String(text[index ..< cursor])
        let url = rawURL.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
        guard !url.isEmpty else { return nil }

        index = text.index(index, offsetBy: url.count)
        return .autoLink(url)
    }

    private mutating func consumeEmail() -> InlineMarkdownSegment? {
        guard isBoundaryBeforeIndex else { return nil }

        let remaining = String(text[index...])
        let range = NSRange(remaining.startIndex ..< remaining.endIndex, in: remaining)
        guard let match = Self.emailExpression.firstMatch(in: remaining, range: range),
              match.range.location == 0,
              let matchRange = Range(match.range, in: remaining) else {
            return nil
        }

        let email = String(remaining[matchRange])
        guard !email.isEmpty else { return nil }

        index = text.index(index, offsetBy: email.count)
        return .email(email)
    }

    private mutating func consumeEmojiShortcode() -> InlineMarkdownSegment? {
        guard hasPrefix(":") else { return nil }
        guard isBoundaryBeforeIndex else { return nil }

        let nameStart = text.index(after: index)
        guard nameStart < text.endIndex else { return nil }
        guard let close = closingIndex(for: ":", after: nameStart) else { return nil }

        let name = String(text[nameStart ..< close])
        guard name.count >= 2, name.allSatisfy(\.isEmojiShortcodeCharacter) else { return nil }
        guard name.contains(where: { $0.isLetter }) else { return nil }

        index = text.index(after: close)
        return .emojiShortcode(name)
    }

    private mutating func consumeSymbolToken() -> InlineMarkdownSegment? {
        guard text[index] == "#" || text[index] == "@" else { return nil }
        guard isBoundaryBeforeIndex else { return nil }

        let prefix = text[index]
        var cursor = text.index(after: index)
        let valueStart = cursor

        while cursor < text.endIndex, text[cursor].isSymbolTokenCharacter {
            cursor = text.index(after: cursor)
        }

        guard cursor > valueStart else { return nil }
        let value = String(text[valueStart ..< cursor])
        index = cursor

        return prefix == "#" ? .tag(value) : .mention(value)
    }

    private func parseParenthesizedDestination(
        from open: String.Index
    ) -> (destination: String, title: String?, end: String.Index)? {
        guard text[open] == "(" else { return nil }
        let contentStart = text.index(after: open)
        guard let close = closingIndex(for: ")", after: contentStart) else { return nil }

        let rawContent = String(text[contentStart ..< close]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawContent.isEmpty else { return nil }

        let parsed = Self.parseDestinationAndTitle(rawContent)
        guard !parsed.destination.isEmpty else { return nil }

        return (parsed.destination, parsed.title, text.index(after: close))
    }

    private func parseBracketedText(from open: String.Index) -> (value: String, end: String.Index)? {
        guard text[open] == "[" else { return nil }
        let contentStart = text.index(after: open)
        guard let close = closingIndex(for: "]", after: contentStart) else { return nil }
        return (String(text[contentStart ..< close]), text.index(after: close))
    }

    private func closingIndex(for marker: String, after start: String.Index) -> String.Index? {
        var cursor = start

        while cursor < text.endIndex {
            guard let range = text[cursor...].range(of: marker) else { return nil }
            if !isEscaped(range.lowerBound) {
                return range.lowerBound
            }

            cursor = text.index(after: range.lowerBound)
        }

        return nil
    }

    private func hasPrefix(_ prefix: String) -> Bool {
        text[index...].hasPrefix(prefix)
    }

    private func isInlineDelimiterStart(_ marker: String) -> Bool {
        let next = text.index(index, offsetBy: marker.count)
        guard next < text.endIndex else { return false }
        guard !text[next].isWhitespace else { return false }

        if marker == "_" {
            return isBoundaryBeforeIndex
        }

        return true
    }

    private var isBoundaryBeforeIndex: Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return !previous.isSymbolTokenCharacter
    }

    private func isEscaped(_ position: String.Index) -> Bool {
        var count = 0
        var cursor = position

        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous] == "\\" else { break }
            count += 1
            cursor = previous
        }

        return count % 2 == 1
    }

    private static func parseDestinationAndTitle(_ text: String) -> (destination: String, title: String?) {
        var remainder = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let destination: String
        if remainder.hasPrefix("<"), let close = remainder.firstIndex(of: ">") {
            let start = remainder.index(after: remainder.startIndex)
            destination = String(remainder[start ..< close])
            remainder = String(remainder[remainder.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        } else {
            let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            destination = parts.first.map(String.init) ?? ""
            remainder = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
        }

        return (destination, parseTitle(remainder))
    }

    private static func parseTitle(_ text: String) -> String? {
        guard text.count >= 2 else { return nil }

        let pairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("(", ")")
        ]

        for pair in pairs where text.first == pair.0 && text.last == pair.1 {
            let start = text.index(after: text.startIndex)
            let end = text.index(before: text.endIndex)
            return String(text[start ..< end])
        }

        return nil
    }

    private static func isAbsoluteURI(_ value: String) -> Bool {
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        guard let match = absoluteURIExpression.firstMatch(in: value, range: range) else {
            return false
        }

        return match.range == range
    }

    private static func isEmailAddress(_ value: String) -> Bool {
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        guard let match = emailExpression.firstMatch(in: value, range: range) else {
            return false
        }

        return match.range == range
    }

    private static let absoluteURIExpression = try! NSRegularExpression(
        pattern: #"^[A-Z][A-Z0-9+\-.]{1,31}:[^\s<>]+$"#,
        options: [.caseInsensitive]
    )

    private static let emailExpression = try! NSRegularExpression(
        pattern: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
}

private extension Character {
    var isSymbolTokenCharacter: Bool {
        if isLetter || isNumber {
            return true
        }

        return self == "_" || self == "-" || self == "/" || self == "."
    }

    var isEmojiShortcodeCharacter: Bool {
        isLetter || isNumber || self == "_" || self == "-" || self == "+"
    }
}
