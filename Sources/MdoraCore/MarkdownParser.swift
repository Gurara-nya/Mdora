import Foundation

public enum MarkdownParser {
    public static func parse(_ markdown: String) -> ParsedMarkdownDocument {
        var parser = BlockParser(markdown: markdown)
        let parsedBlocks = parser.parseBlocks()
        let blocks = parsedBlocks.blocks
        let outline = MarkdownAnalyzer.outline(from: blocks)
        let metadata = MarkdownAnalyzer.metadata(from: blocks)
        let markers = MarkdownAnalyzer.markers(in: markdown, blocks: blocks)
        let referenceDefinitions = MarkdownAnalyzer.referenceDefinitions(from: blocks)
        let diagnostics = MarkdownAnalyzer.diagnostics(
            in: markdown,
            blocks: blocks,
            outline: outline
        )
        let stats = MarkdownAnalyzer.stats(for: markdown, blocks: blocks)

        return ParsedMarkdownDocument(
            blocks: blocks,
            sourceMap: parsedBlocks.sourceMap,
            outline: outline,
            metadata: metadata,
            markers: markers,
            referenceDefinitions: referenceDefinitions,
            diagnostics: diagnostics,
            stats: stats
        )
    }
}

private struct ParsedBlocks {
    var blocks: [MarkdownBlock]
    var sourceMap: [MarkdownBlockSourceRange]
}

private struct BlockParser {
    private let lines: [String]
    private var index = 0

    init(markdown: String) {
        lines = markdown.components(separatedBy: .newlines)
    }

    mutating func parseBlocks() -> ParsedBlocks {
        var blocks: [MarkdownBlock] = []
        var sourceMap: [MarkdownBlockSourceRange] = []

        if let frontMatter = parseFrontMatter() {
            append(.frontMatter(frontMatter), startingAt: 0, to: &blocks, sourceMap: &sourceMap)
        }

        while index < lines.count {
            if currentLine.trimmed.isEmpty {
                index += 1
                continue
            }

            let startIndex = index

            if let block = parseCodeFence() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseMathBlock() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseIndentedCodeBlock() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseTable() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseHeading() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseThematicBreak() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseBlockquote() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseList() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseFootnoteDefinition() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseDefinitionList() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseLinkReferenceDefinition() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseImage() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseHTMLComment() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            if let block = parseHTMLBlock() {
                append(block, startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
                continue
            }

            append(parseParagraph(), startingAt: startIndex, to: &blocks, sourceMap: &sourceMap)
        }

        return ParsedBlocks(blocks: blocks, sourceMap: sourceMap)
    }

    private func append(
        _ block: MarkdownBlock,
        startingAt startIndex: Int,
        to blocks: inout [MarkdownBlock],
        sourceMap: inout [MarkdownBlockSourceRange]
    ) {
        let blockIndex = blocks.count
        let startLine = startIndex + 1
        let endLine = max(startLine, index)

        blocks.append(block)
        sourceMap.append(
            MarkdownBlockSourceRange(
                blockIndex: blockIndex,
                startLine: startLine,
                endLine: endLine
            )
        )
    }

    private var currentLine: String {
        lines[index]
    }

    private func line(at offset: Int) -> String? {
        let nextIndex = index + offset
        guard lines.indices.contains(nextIndex) else { return nil }
        return lines[nextIndex]
    }

    private mutating func parseFrontMatter() -> FrontMatterBlock? {
        guard index == 0 else { return nil }

        let trimmed = currentLine.trimmed

        switch trimmed {
        case "---":
            return parseDelimitedFrontMatter(kind: .yaml, marker: "---")
        case "+++":
            return parseDelimitedFrontMatter(kind: .toml, marker: "+++")
        case _ where trimmed.hasPrefix("{"):
            return parseJSONFrontMatter()
        default:
            return nil
        }
    }

    private mutating func parseDelimitedFrontMatter(kind: FrontMatterKind, marker: String) -> FrontMatterBlock? {
        var content: [String] = []
        var cursor = index + 1

        while cursor < lines.count {
            let line = lines[cursor]
            if line.trimmed == marker {
                index = cursor + 1
                return FrontMatterBlock(kind: kind, lines: content)
            }

            content.append(line)
            cursor += 1
        }

        return nil
    }

    private mutating func parseJSONFrontMatter() -> FrontMatterBlock? {
        var content: [String] = []
        var cursor = index
        var depth = 0

        while cursor < lines.count {
            let line = lines[cursor]
            content.append(line)

            for character in line {
                if character == "{" { depth += 1 }
                if character == "}" { depth -= 1 }
            }

            if depth == 0 {
                let source = content.joined(separator: "\n")
                guard let data = source.data(using: .utf8),
                      (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
                    return nil
                }

                index = cursor + 1
                return FrontMatterBlock(kind: .json, lines: content)
            }

            cursor += 1
        }

        return nil
    }

    private mutating func parseCodeFence() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else { return nil }

        let fence = String(trimmed.prefix(3))
        let language = String(trimmed.dropFirst(3)).trimmed.nilIfEmpty
        var codeLines: [String] = []

        index += 1

        while index < lines.count {
            let line = currentLine
            if line.trimmed.hasPrefix(fence) {
                index += 1
                break
            }

            codeLines.append(line)
            index += 1
        }

        let code = codeLines.joined(separator: "\n")

        if let language, let diagramKind = DiagramKind(language: language) {
            return .diagram(DiagramBlock(kind: diagramKind, source: code))
        }

        return .codeBlock(language: language, code: code)
    }

    private mutating func parseMathBlock() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        guard trimmed == "$$" || trimmed.hasPrefix("$$ ") else { return nil }

        if trimmed.count > 2, trimmed.hasSuffix("$$") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            let expression = String(trimmed[start ..< end]).trimmed
            index += 1
            return .mathBlock(expression)
        }

        var mathLines: [String] = []
        index += 1

        while index < lines.count {
            if currentLine.trimmed == "$$" {
                index += 1
                break
            }

            mathLines.append(currentLine)
            index += 1
        }

        return .mathBlock(mathLines.joined(separator: "\n"))
    }

    private mutating func parseIndentedCodeBlock() -> MarkdownBlock? {
        guard currentLine.hasPrefix("    ") || currentLine.hasPrefix("\t") else { return nil }

        var codeLines: [String] = []

        while index < lines.count {
            let line = currentLine

            if line.hasPrefix("    ") {
                codeLines.append(String(line.dropFirst(4)))
                index += 1
                continue
            }

            if line.hasPrefix("\t") {
                codeLines.append(String(line.dropFirst()))
                index += 1
                continue
            }

            if line.trimmed.isEmpty {
                codeLines.append("")
                index += 1
                continue
            }

            break
        }

        return .codeBlock(language: nil, code: codeLines.joined(separator: "\n"))
    }

    private mutating func parseTable() -> MarkdownBlock? {
        guard let separator = line(at: 1) else { return nil }
        guard currentLine.contains("|"), Self.isTableSeparator(separator) else { return nil }

        let headers = Self.splitTableRow(currentLine)
        let alignments = Self.parseTableAlignments(separator)
        guard !headers.isEmpty, !alignments.isEmpty else { return nil }

        index += 2
        var rows: [[String]] = []

        while index < lines.count, currentLine.contains("|"), !currentLine.trimmed.isEmpty {
            rows.append(Self.splitTableRow(currentLine))
            index += 1
        }

        return .table(TableBlock(headers: headers, alignments: alignments, rows: rows))
    }

    private mutating func parseHeading() -> MarkdownBlock? {
        if let setextHeading = parseSetextHeading() {
            return setextHeading
        }

        let trimmed = currentLine.trimmed
        let hashes = trimmed.prefix { character in
            character == "#"
        }.count

        guard (1 ... 6).contains(hashes) else { return nil }

        let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard markerEnd < trimmed.endIndex, trimmed[markerEnd] == " " else { return nil }

        let textStart = trimmed.index(after: markerEnd)
        let parsed = MarkdownHeadingAttributes.parse(String(trimmed[textStart...]))
        index += 1

        return .heading(
            level: hashes,
            text: parsed.text,
            anchor: parsed.anchor ?? Self.anchor(for: parsed.text)
        )
    }

    private mutating func parseSetextHeading() -> MarkdownBlock? {
        guard let underline = line(at: 1)?.trimmed else { return nil }
        guard !currentLine.trimmed.isEmpty else { return nil }
        guard underline.allSatisfy({ $0 == "=" }) || underline.allSatisfy({ $0 == "-" }) else { return nil }
        guard underline.count >= 2 else { return nil }

        let level = underline.first == "=" ? 1 : 2
        let parsed = MarkdownHeadingAttributes.parse(currentLine.trimmed)
        index += 2
        return .heading(
            level: level,
            text: parsed.text,
            anchor: parsed.anchor ?? Self.anchor(for: parsed.text)
        )
    }

    private mutating func parseThematicBreak() -> MarkdownBlock? {
        let normalized = currentLine.trimmed.replacingOccurrences(of: " ", with: "")
        guard normalized.count >= 3 else { return nil }
        guard normalized.allSatisfy({ $0 == "-" }) ||
            normalized.allSatisfy({ $0 == "*" }) ||
            normalized.allSatisfy({ $0 == "_" }) else {
            return nil
        }

        index += 1
        return .thematicBreak
    }

    private mutating func parseBlockquote() -> MarkdownBlock? {
        guard currentLine.trimmed.hasPrefix(">") else { return nil }

        var quoteLines: [String] = []

        while index < lines.count, currentLine.trimmed.hasPrefix(">") {
            let trimmed = currentLine.trimmed
            let content = String(trimmed.dropFirst()).trimmed
            quoteLines.append(content)
            index += 1
        }

        let callout = Self.parseCallout(from: quoteLines.first)
        if callout != nil, !quoteLines.isEmpty {
            quoteLines[0] = Self.removingCalloutMarker(from: quoteLines[0])
        }

        return .blockquote(lines: quoteLines.filter { !$0.isEmpty }, callout: callout)
    }

    private mutating func parseList() -> MarkdownBlock? {
        guard let first = Self.parseListLine(currentLine) else { return nil }

        var listLines: [ParsedListLine] = [first]
        index += 1

        while index < lines.count {
            guard let parsed = Self.parseListLine(currentLine) else { break }
            listLines.append(parsed)
            index += 1
        }

        if listLines.allSatisfy({ $0.taskDone != nil }) {
            return .taskList(
                listLines.map { item in
                    TaskItem(text: item.text, isDone: item.taskDone ?? false, depth: item.depth)
                }
            )
        }

        let items = listLines.map { ListItem(text: $0.text, depth: $0.depth) }
        return first.isOrdered ? .orderedList(items) : .unorderedList(items)
    }

    private mutating func parseImage() -> MarkdownBlock? {
        guard let image = Self.parseImageSyntax(currentLine.trimmed) else { return nil }
        index += 1
        return .image(alt: image.alt, source: image.source, title: image.title)
    }

    private mutating func parseLinkReferenceDefinition() -> MarkdownBlock? {
        guard let definition = Self.parseLinkReferenceDefinitionLine(currentLine.trimmed) else {
            return nil
        }

        index += 1
        return .linkReferenceDefinition(definition)
    }

    private mutating func parseFootnoteDefinition() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        guard trimmed.hasPrefix("[^") else { return nil }
        guard let close = trimmed.firstIndex(of: "]") else { return nil }

        let colonIndex = trimmed.index(after: close)
        guard colonIndex < trimmed.endIndex, trimmed[colonIndex] == ":" else { return nil }

        let idStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let identifier = String(trimmed[idStart ..< close])
        let textStart = trimmed.index(after: colonIndex)
        var textLines = [String(trimmed[textStart...]).trimmed]
        index += 1

        while index < lines.count {
            let line = currentLine
            guard line.hasPrefix("    ") || line.hasPrefix("\t") else { break }
            textLines.append(line.trimmed)
            index += 1
        }

        return .footnoteDefinition(identifier: identifier, text: textLines.joined(separator: " "))
    }

    private mutating func parseDefinitionList() -> MarkdownBlock? {
        guard let definitionLine = line(at: 1)?.trimmed else { return nil }
        guard definitionLine.hasPrefix(": ") || definitionLine.hasPrefix("~ ") else { return nil }
        guard !currentLine.trimmed.isEmpty else { return nil }

        var items: [DefinitionItem] = []

        while index < lines.count {
            let term = currentLine.trimmed
            guard !term.isEmpty else { break }
            guard let next = line(at: 1)?.trimmed, next.hasPrefix(": ") || next.hasPrefix("~ ") else { break }

            index += 1
            var definitions: [String] = []

            while index < lines.count {
                let candidate = currentLine.trimmed
                if candidate.hasPrefix(": ") || candidate.hasPrefix("~ ") {
                    definitions.append(String(candidate.dropFirst(2)).trimmed)
                    index += 1
                    continue
                }

                if currentLine.hasPrefix("    ") || currentLine.hasPrefix("\t") {
                    if definitions.isEmpty {
                        definitions.append(currentLine.trimmed)
                    } else {
                        definitions[definitions.count - 1] += " " + currentLine.trimmed
                    }
                    index += 1
                    continue
                }

                break
            }

            items.append(DefinitionItem(term: term, definitions: definitions))

            guard index + 1 < lines.count else { break }
            let upcomingDefinition = line(at: 1)?.trimmed ?? ""
            guard upcomingDefinition.hasPrefix(": ") || upcomingDefinition.hasPrefix("~ ") else { break }
        }

        guard !items.isEmpty else { return nil }
        return .definitionList(items)
    }

    private mutating func parseHTMLBlock() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        guard trimmed.hasPrefix("<"), trimmed.hasSuffix(">") else { return nil }
        guard !trimmed.hasPrefix("<!--") else { return nil }

        index += 1
        return .html(currentLine)
    }

    private mutating func parseHTMLComment() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        guard trimmed.hasPrefix("<!--") else { return nil }

        var commentLines = [currentLine]
        let isSingleLine = trimmed.contains("-->")
        index += 1

        if !isSingleLine {
            while index < lines.count {
                commentLines.append(currentLine)
                let line = currentLine.trimmed
                index += 1

                if line.contains("-->") {
                    break
                }
            }
        }

        return .htmlComment(commentLines.joined(separator: "\n"))
    }

    private mutating func parseParagraph() -> MarkdownBlock {
        var paragraphLines: [String] = []

        while index < lines.count {
            let line = currentLine
            if line.trimmed.isEmpty { break }
            if line.trimmed.hasPrefix("```") || line.trimmed.hasPrefix("~~~") { break }
            if line.trimmed == "$$" || line.trimmed.hasPrefix("$$ ") { break }
            if Self.isTableSeparator(line) { break }
            if Self.parseListLine(line) != nil { break }
            if Self.isFootnoteDefinition(line) { break }
            if Self.isDefinitionLine(self.line(at: 1)) { break }
            if Self.parseLinkReferenceDefinitionLine(line.trimmed) != nil { break }
            if line.trimmed.hasPrefix("<!--") { break }
            if line.trimmed.hasPrefix(">") { break }
            if Self.headingLevel(line) != nil { break }

            paragraphLines.append(line.trimmed)
            index += 1
        }

        if paragraphLines.isEmpty, index < lines.count {
            paragraphLines.append(currentLine.trimmed)
            index += 1
        }

        return .paragraph(paragraphLines.joined(separator: " "))
    }

    private static func headingLevel(_ line: String) -> Int? {
        let trimmed = line.trimmed
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard (1 ... 6).contains(hashes) else { return nil }
        let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard markerEnd < trimmed.endIndex, trimmed[markerEnd] == " " else { return nil }
        return hashes
    }

    private static func isFootnoteDefinition(_ line: String) -> Bool {
        let trimmed = line.trimmed
        guard trimmed.hasPrefix("[^") else { return false }
        guard let close = trimmed.firstIndex(of: "]") else { return false }
        let colonIndex = trimmed.index(after: close)
        return colonIndex < trimmed.endIndex && trimmed[colonIndex] == ":"
    }

    private static func isDefinitionLine(_ line: String?) -> Bool {
        guard let line else { return false }
        let trimmed = line.trimmed
        return trimmed.hasPrefix(": ") || trimmed.hasPrefix("~ ")
    }

    private static func parseListLine(_ line: String) -> ParsedListLine? {
        let leadingSpaces = line.prefix { character in
            character == " "
        }.count
        let depth = leadingSpaces / 2
        let trimmed = line.trimmed

        if let unorderedMarker = ["- ", "* ", "+ "].first(where: { trimmed.hasPrefix($0) }) {
            let text = String(trimmed.dropFirst(unorderedMarker.count))
            return ParsedListLine(
                text: taskText(from: text) ?? text,
                depth: depth,
                isOrdered: false,
                taskDone: taskState(from: text)
            )
        }

        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let numberPart = trimmed[..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else { return nil }

        let spaceIndex = trimmed.index(after: dotIndex)
        guard spaceIndex < trimmed.endIndex, trimmed[spaceIndex] == " " else { return nil }

        let textStart = trimmed.index(after: spaceIndex)
        let text = String(trimmed[textStart...])

        return ParsedListLine(
            text: taskText(from: text) ?? text,
            depth: depth,
            isOrdered: true,
            taskDone: taskState(from: text)
        )
    }

    private static func taskState(from text: String) -> Bool? {
        let lowercased = text.lowercased()
        if lowercased.hasPrefix("[x] ") { return true }
        if lowercased.hasPrefix("[ ] ") { return false }
        return nil
    }

    private static func taskText(from text: String) -> String? {
        guard taskState(from: text) != nil else { return nil }
        return String(text.dropFirst(4))
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = splitTableRow(line)
        guard !cells.isEmpty else { return false }

        return cells.allSatisfy { cell in
            let stripped = cell.trimmed
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
            return stripped.isEmpty && cell.contains("-")
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmed
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmed }
    }

    private static func parseTableAlignments(_ line: String) -> [TableAlignment] {
        splitTableRow(line).map { cell in
            let trimmed = cell.trimmed
            let leading = trimmed.hasPrefix(":")
            let trailing = trimmed.hasSuffix(":")

            if leading && trailing { return .center }
            if trailing { return .trailing }
            return .leading
        }
    }

    private static func parseImageSyntax(_ line: String) -> (alt: String, source: String, title: String?)? {
        guard line.hasPrefix("![") else { return nil }
        guard let closeAlt = line.firstIndex(of: "]") else { return nil }

        let openURL = line.index(after: closeAlt)
        guard openURL < line.endIndex, line[openURL] == "(" else { return nil }
        guard line.hasSuffix(")") else { return nil }

        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart ..< closeAlt])
        let contentStart = line.index(after: openURL)
        let contentEnd = line.index(before: line.endIndex)
        let content = String(line[contentStart ..< contentEnd]).trimmed

        guard !content.isEmpty else { return nil }

        if let quoteStart = content.firstIndex(of: "\""), content.hasSuffix("\"") {
            let source = String(content[..<quoteStart]).trimmed
            let titleStart = content.index(after: quoteStart)
            let titleEnd = content.index(before: content.endIndex)
            return (alt, source, String(content[titleStart ..< titleEnd]))
        }

        return (alt, content, nil)
    }

    private static func parseLinkReferenceDefinitionLine(_ line: String) -> LinkReferenceDefinition? {
        guard line.hasPrefix("[") else { return nil }
        guard let closeLabel = line.firstIndex(of: "]") else { return nil }

        let colonIndex = line.index(after: closeLabel)
        guard colonIndex < line.endIndex, line[colonIndex] == ":" else { return nil }

        let labelStart = line.index(after: line.startIndex)
        let label = String(line[labelStart ..< closeLabel]).trimmed
        guard !label.isEmpty else { return nil }

        let remainderStart = line.index(after: colonIndex)
        var remainder = String(line[remainderStart...]).trimmed
        guard !remainder.isEmpty else { return nil }

        let destination: String

        if remainder.hasPrefix("<"), let closeDestination = remainder.firstIndex(of: ">") {
            let destinationStart = remainder.index(after: remainder.startIndex)
            destination = String(remainder[destinationStart ..< closeDestination])
            remainder = String(remainder[remainder.index(after: closeDestination)...]).trimmed
        } else {
            let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let first = parts.first else { return nil }
            destination = String(first)
            remainder = parts.count > 1 ? String(parts[1]).trimmed : ""
        }

        let title = parseReferenceTitle(remainder)
        return LinkReferenceDefinition(label: label, destination: destination, title: title)
    }

    private static func parseReferenceTitle(_ text: String) -> String? {
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

    private static func parseCallout(from line: String?) -> CalloutKind? {
        guard let line, line.hasPrefix("[!") else { return nil }
        guard let close = line.firstIndex(of: "]") else { return nil }

        let markerStart = line.index(line.startIndex, offsetBy: 2)
        return CalloutKind(marker: String(line[markerStart ..< close]))
    }

    private static func removingCalloutMarker(from line: String) -> String {
        guard line.hasPrefix("[!"), let close = line.firstIndex(of: "]") else { return line }
        return String(line[line.index(after: close)...]).trimmed
    }

    private static func anchor(for text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = text.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(filtered)
            .lowercased()
            .split(separator: " ")
            .joined(separator: "-")
            .replacingOccurrences(of: "--", with: "-")

        return slug.isEmpty ? "section" : slug
    }
}

private struct ParsedListLine {
    var text: String
    var depth: Int
    var isOrdered: Bool
    var taskDone: Bool?
}

enum MarkdownHeadingAttributes {
    static func parse(_ rawText: String) -> (text: String, anchor: String?) {
        let text = strippedClosingHashes(from: rawText)
        guard let anchor = customAnchor(in: text),
              let attributesStart = attributesStart(in: text) else {
            return (text, nil)
        }

        let displayText = String(text[..<attributesStart]).trimmed
        return (displayText.isEmpty ? text : displayText, anchor)
    }

    static func customAnchor(in text: String) -> String? {
        guard let attributes = trailingAttributes(in: text) else { return nil }

        return attributes
            .split { $0.isWhitespace || $0.isNewline }
            .compactMap { token -> String? in
                guard token.hasPrefix("#") else { return nil }
                let anchor = String(token.dropFirst()).trimmed
                return anchor.isEmpty ? nil : anchor
            }
            .first
    }

    static func strippedClosingHashes(from rawText: String) -> String {
        let text = rawText.trimmed
        var end = text.endIndex

        while end > text.startIndex, text[text.index(before: end)].isWhitespace {
            end = text.index(before: end)
        }

        var hashStart = end
        while hashStart > text.startIndex, text[text.index(before: hashStart)] == "#" {
            hashStart = text.index(before: hashStart)
        }

        guard hashStart < end,
              hashStart > text.startIndex,
              text[text.index(before: hashStart)].isWhitespace else {
            return text
        }

        return String(text[..<hashStart]).trimmed
    }

    private static func trailingAttributes(in text: String) -> String? {
        guard let start = attributesStart(in: text) else { return nil }
        let afterOpen = text.index(after: start)
        let beforeClose = text.index(before: text.endIndex)
        let attributes = String(text[afterOpen ..< beforeClose]).trimmed
        return attributes.isEmpty ? nil : attributes
    }

    private static func attributesStart(in text: String) -> String.Index? {
        let text = text.trimmed
        guard text.hasSuffix("}") else { return nil }
        guard let start = text.lastIndex(of: "{") else { return nil }
        guard start > text.startIndex, text[text.index(before: start)].isWhitespace else { return nil }

        let afterOpen = text.index(after: start)
        guard afterOpen < text.endIndex else { return nil }
        return String(text[afterOpen...]).contains("#") ? start : nil
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
