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
        let abbreviationDefinitions = MarkdownAnalyzer.abbreviationDefinitions(from: blocks)
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
            abbreviationDefinitions: abbreviationDefinitions,
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
    private struct ParagraphLine {
        var text: String
        var endsWithHardBreak: Bool
    }

    private let lines: [String]
    private var index = 0
    private var assignedHeadingAnchors: Set<String> = []

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

            if let block = parseAbbreviationDefinition() {
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
        guard let openingDelimiter = MarkdownCodeFenceScanner.delimiter(in: currentLine) else { return nil }

        let language = openingDelimiter.language
        var codeLines: [String] = []

        index += 1

        while index < lines.count {
            let line = currentLine
            if let closingDelimiter = MarkdownCodeFenceScanner.delimiter(in: line),
               MarkdownCodeFenceScanner.isClosingDelimiter(closingDelimiter, for: openingDelimiter) {
                index += 1
                break
            }

            codeLines.append(Self.removingFenceContentIndent(
                openingDelimiter.leadingSpaces,
                from: line
            ))
            index += 1
        }

        let code = codeLines.joined(separator: "\n")

        if let language, let diagramKind = DiagramKind(language: language) {
            return .diagram(DiagramBlock(kind: diagramKind, source: code))
        }

        return .codeBlock(language: language, code: code)
    }

    private static func removingFenceContentIndent(_ leadingSpaces: Int, from line: String) -> String {
        guard leadingSpaces > 0 else { return line }

        var cursor = line.startIndex
        var removedSpaces = 0
        while cursor < line.endIndex,
              removedSpaces < leadingSpaces,
              line[cursor] == " " {
            removedSpaces += 1
            cursor = line.index(after: cursor)
        }

        return String(line[cursor...])
    }

    private mutating func parseMathBlock() -> MarkdownBlock? {
        let trimmed = currentLine.trimmed
        let isDoubleDollar = trimmed.hasPrefix("$$")
        let isLaTeXBlock = trimmed.hasPrefix("\\[")

        guard isDoubleDollar || isLaTeXBlock else { return nil }

        if isDoubleDollar {
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
        } else {
            if trimmed.count > 2, trimmed.hasSuffix("\\]") {
                let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
                let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
                let expression = String(trimmed[start ..< end]).trimmed
                index += 1
                return .mathBlock(expression)
            }

            var mathLines: [String] = []
            index += 1

            while index < lines.count {
                if currentLine.trimmed == "\\]" {
                    index += 1
                    break
                }

                mathLines.append(currentLine)
                index += 1
            }

            return .mathBlock(mathLines.joined(separator: "\n"))
        }
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
        let trimmed = currentLine.trimmed
        let hashes = trimmed.prefix { character in
            character == "#"
        }.count

        if (1 ... 6).contains(hashes) {
            let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
            if markerEnd == trimmed.endIndex || trimmed[markerEnd].isWhitespace {
                let rawText: String
                if markerEnd == trimmed.endIndex {
                    rawText = ""
                } else {
                    let textStart = trimmed.index(after: markerEnd)
                    rawText = String(trimmed[textStart...])
                }

                let parsed = MarkdownHeadingAttributes.parse(rawText)
                index += 1

                return .heading(
                    level: hashes,
                    text: parsed.text,
                    anchor: anchor(for: parsed)
                )
            }
        }

        if let setextHeading = parseSetextHeading() {
            return setextHeading
        }

        return nil
    }

    private mutating func parseSetextHeading() -> MarkdownBlock? {
        guard let underline = line(at: 1)?.trimmed else { return nil }
        guard !currentLine.trimmed.isEmpty else { return nil }
        guard !underline.isEmpty else { return nil }
        guard underline.allSatisfy({ $0 == "=" }) || underline.allSatisfy({ $0 == "-" }) else { return nil }

        let level = underline.first == "=" ? 1 : 2
        let parsed = MarkdownHeadingAttributes.parse(currentLine.trimmed)
        index += 2
        return .heading(
            level: level,
            text: parsed.text,
            anchor: anchor(for: parsed)
        )
    }

    private mutating func parseThematicBreak() -> MarkdownBlock? {
        guard Self.isThematicBreakLine(currentLine) else { return nil }

        index += 1
        return .thematicBreak
    }

    private mutating func parseBlockquote() -> MarkdownBlock? {
        guard currentLine.trimmed.hasPrefix(">") else { return nil }

        var quoteLines: [String] = []

        while index < lines.count, currentLine.trimmed.hasPrefix(">") {
            let trimmed = currentLine.trimmed
            var content = String(trimmed.dropFirst())
            if content.hasPrefix(" ") {
                content.removeFirst()
            }
            quoteLines.append(content)
            index += 1
        }

        let callout = Self.parseCallout(from: quoteLines.first?.trimmed)
        if callout != nil, !quoteLines.isEmpty {
            quoteLines.removeFirst()
        }

        let blockquoteMarkdown = quoteLines.joined(separator: "\n")
        var subParser = BlockParser(markdown: blockquoteMarkdown)
        let subBlocks = subParser.parseBlocks().blocks

        return .blockquote(blocks: subBlocks, callout: callout)
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
                    TaskItem(text: item.text, state: item.taskState ?? .todo, depth: item.depth)
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

    private mutating func parseAbbreviationDefinition() -> MarkdownBlock? {
        guard let definition = Self.parseAbbreviationDefinitionLine(currentLine.trimmed) else {
            return nil
        }

        index += 1
        return .abbreviationDefinition(definition)
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
        let line = currentLine
        let trimmed = line.trimmed
        guard Self.isHTMLBlockStart(trimmed) else { return nil }
        guard !trimmed.hasPrefix("<!--") else { return nil }

        var htmlLines = [line]
        index += 1

        if let tagName = Self.htmlBlockTagName(from: trimmed),
           Self.shouldContinueHTMLBlock(startingWith: trimmed, tagName: tagName) {
            while index < lines.count {
                let candidate = currentLine
                guard !candidate.trimmed.isEmpty else { break }

                htmlLines.append(candidate)
                index += 1

                if Self.containsHTMLClosingTag(candidate, tagName: tagName) {
                    break
                }
            }
        }

        return .html(htmlLines.joined(separator: "\n"))
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
        var paragraphLines: [ParagraphLine] = []

        while index < lines.count {
            let line = currentLine
            if line.trimmed.isEmpty { break }
            if MarkdownCodeFenceScanner.delimiter(in: line) != nil { break }
            if line.trimmed == "$$" || line.trimmed.hasPrefix("$$ ") { break }
            if Self.isThematicBreakLine(line) { break }
            if Self.isTableSeparator(line) { break }
            if Self.parseListLine(line) != nil { break }
            if Self.isFootnoteDefinition(line) { break }
            if Self.isDefinitionLine(self.line(at: 1)) { break }
            if Self.parseLinkReferenceDefinitionLine(line.trimmed) != nil { break }
            if Self.parseAbbreviationDefinitionLine(line.trimmed) != nil { break }
            if line.trimmed.hasPrefix("<!--") { break }
            if line.trimmed.hasPrefix(">") { break }
            if Self.headingLevel(line) != nil { break }

            paragraphLines.append(Self.paragraphLine(from: line))
            index += 1
        }

        if paragraphLines.isEmpty, index < lines.count {
            paragraphLines.append(Self.paragraphLine(from: currentLine))
            index += 1
        }

        return .paragraph(Self.joinedParagraphLines(paragraphLines))
    }

    private static func isThematicBreakLine(_ line: String) -> Bool {
        let source = line.trimmingCharacters(in: .newlines)
        var cursor = source.startIndex
        var leadingSpaces = 0

        while cursor < source.endIndex {
            if source[cursor] == " " {
                leadingSpaces += 1
                guard leadingSpaces <= 3 else { return false }
                cursor = source.index(after: cursor)
                continue
            }

            if source[cursor] == "\t" {
                return false
            }

            break
        }

        let normalized = source[cursor...].filter { character in
            character != " " && character != "\t"
        }

        guard normalized.count >= 3, let marker = normalized.first else { return false }
        guard marker == "-" || marker == "*" || marker == "_" else { return false }
        return normalized.allSatisfy { $0 == marker }
    }

    private static func paragraphLine(from line: String) -> ParagraphLine {
        let textWithoutTrailingSpaces = line.trimmingCharacters(in: .whitespaces)
        if textWithoutTrailingSpaces.hasSuffix("\\") {
            let text = String(textWithoutTrailingSpaces.dropLast()).trimmingCharacters(in: .whitespaces)
            return ParagraphLine(text: text, endsWithHardBreak: true)
        }

        let trailingSpaces = line.reversed().prefix { $0 == " " }.count
        return ParagraphLine(
            text: textWithoutTrailingSpaces,
            endsWithHardBreak: trailingSpaces >= 2
        )
    }

    private static func joinedParagraphLines(_ lines: [ParagraphLine]) -> String {
        var result = ""

        for line in lines {
            if !result.isEmpty, !result.hasSuffix("\n") {
                result += " "
            }

            result += line.text

            if line.endsWithHardBreak {
                result += "\n"
            }
        }

        return result
    }

    private static func headingLevel(_ line: String) -> Int? {
        let trimmed = line.trimmed
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard (1 ... 6).contains(hashes) else { return nil }
        let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard markerEnd == trimmed.endIndex || trimmed[markerEnd].isWhitespace else { return nil }
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
                taskState: taskState(from: text)
            )
        }

        guard let delimiterIndex = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }
        let numberPart = trimmed[..<delimiterIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else { return nil }

        let spaceIndex = trimmed.index(after: delimiterIndex)
        guard spaceIndex < trimmed.endIndex, trimmed[spaceIndex] == " " else { return nil }

        let textStart = trimmed.index(after: spaceIndex)
        let text = String(trimmed[textStart...])

        return ParsedListLine(
            text: taskText(from: text) ?? text,
            depth: depth,
            isOrdered: true,
            taskState: taskState(from: text)
        )
    }

    private static func taskState(from text: String) -> TaskState? {
        guard text.count >= 4,
              text.first == "[",
              text[text.index(text.startIndex, offsetBy: 2)] == "]",
              text[text.index(text.startIndex, offsetBy: 3)] == " " else {
            return nil
        }

        let marker = text[text.index(after: text.startIndex)]
        return TaskState(marker: marker)
    }

    private static func taskText(from text: String) -> String? {
        guard taskState(from: text) != nil else { return nil }
        return String(text.dropFirst(4))
    }

    private static func isHTMLBlockStart(_ trimmed: String) -> Bool {
        guard trimmed.hasPrefix("<"), trimmed.hasSuffix(">") else { return false }
        if trimmed.hasPrefix("<!--") { return false }
        if trimmed.hasPrefix("<!") || trimmed.hasPrefix("<?") { return true }
        return htmlBlockTagName(from: trimmed) != nil
    }

    private static func htmlBlockTagName(from trimmed: String) -> String? {
        guard trimmed.hasPrefix("<") else { return nil }

        var cursor = trimmed.index(after: trimmed.startIndex)
        guard cursor < trimmed.endIndex, trimmed[cursor] != "/" else { return nil }

        let nameStart = cursor
        while cursor < trimmed.endIndex {
            let character = trimmed[cursor]
            guard character.isLetter || character.isNumber || character == "-" else { break }
            cursor = trimmed.index(after: cursor)
        }

        guard cursor > nameStart else { return nil }
        if cursor < trimmed.endIndex {
            let next = trimmed[cursor]
            guard next.isWhitespace || next == "/" || next == ">" else { return nil }
        }

        return String(trimmed[nameStart ..< cursor]).lowercased()
    }

    private static func shouldContinueHTMLBlock(startingWith trimmed: String, tagName: String) -> Bool {
        guard !htmlVoidTagNames.contains(tagName) else { return false }
        guard !trimmed.hasSuffix("/>") else { return false }
        return !containsHTMLClosingTag(trimmed, tagName: tagName)
    }

    private static func containsHTMLClosingTag(_ line: String, tagName: String) -> Bool {
        line.range(of: "</\(tagName)", options: [.caseInsensitive]) != nil
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
        if hasUnescapedTrailingPipe(trimmed) {
            trimmed.removeLast()
        }

        var cells: [String] = []
        var currentCell = ""
        var cursor = trimmed.startIndex
        var activeCodeFenceLength = 0

        while cursor < trimmed.endIndex {
            let character = trimmed[cursor]

            if character == "\\" {
                let next = trimmed.index(after: cursor)
                if next < trimmed.endIndex, trimmed[next] == "|" {
                    currentCell.append("|")
                    cursor = trimmed.index(after: next)
                    continue
                }

                currentCell.append(character)
                cursor = next
                continue
            }

            if character == "`" {
                let fenceLength = backtickRunLength(in: trimmed, from: cursor)
                if activeCodeFenceLength == 0 {
                    activeCodeFenceLength = fenceLength
                } else if activeCodeFenceLength == fenceLength {
                    activeCodeFenceLength = 0
                }

                currentCell.append(String(repeating: "`", count: fenceLength))
                cursor = trimmed.index(cursor, offsetBy: fenceLength)
                continue
            }

            if character == "|", activeCodeFenceLength == 0 {
                cells.append(currentCell.trimmed)
                currentCell.removeAll(keepingCapacity: true)
                cursor = trimmed.index(after: cursor)
                continue
            }

            currentCell.append(character)
            cursor = trimmed.index(after: cursor)
        }

        cells.append(currentCell.trimmed)
        return cells
    }

    private static let htmlVoidTagNames: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    private static func hasUnescapedTrailingPipe(_ text: String) -> Bool {
        guard text.last == "|" else { return false }

        var backslashCount = 0
        var cursor = text.index(before: text.endIndex)

        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous] == "\\" else { break }
            backslashCount += 1
            cursor = previous
        }

        return backslashCount % 2 == 0
    }

    private static func backtickRunLength(in text: String, from index: String.Index) -> Int {
        var cursor = index
        var count = 0

        while cursor < text.endIndex, text[cursor] == "`" {
            count += 1
            cursor = text.index(after: cursor)
        }

        return count
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

    private static func parseAbbreviationDefinitionLine(_ line: String) -> AbbreviationDefinition? {
        guard line.hasPrefix("*[") else { return nil }
        guard let closeTerm = line.firstIndex(of: "]") else { return nil }

        let colonIndex = line.index(after: closeTerm)
        guard colonIndex < line.endIndex, line[colonIndex] == ":" else { return nil }

        let termStart = line.index(line.startIndex, offsetBy: 2)
        let term = AbbreviationDefinition.normalizedTerm(String(line[termStart ..< closeTerm]))
        guard !term.isEmpty else { return nil }

        let expansionStart = line.index(after: colonIndex)
        let expansion = String(line[expansionStart...]).trimmed
        guard !expansion.isEmpty else { return nil }

        return AbbreviationDefinition(term: term, expansion: expansion)
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

    private static func parseCallout(from line: String?) -> Callout? {
        guard let line, line.hasPrefix("[!") else { return nil }
        guard let close = line.firstIndex(of: "]") else { return nil }

        let markerStart = line.index(line.startIndex, offsetBy: 2)
        guard let kind = CalloutKind(marker: String(line[markerStart ..< close])) else { return nil }

        let afterClose = line.index(after: close)
        let foldMarker = afterClose < line.endIndex ? CalloutFold(marker: line[afterClose]) : nil
        let titleStart = foldMarker == nil ? afterClose : line.index(after: afterClose)
        let title = titleStart < line.endIndex ? String(line[titleStart...]).trimmed : ""

        return Callout(kind: kind, title: title.isEmpty ? nil : title, fold: foldMarker)
    }

    private mutating func anchor(for parsed: (text: String, anchor: String?)) -> String {
        if let anchor = parsed.anchor {
            assignedHeadingAnchors.insert(anchor)
            return anchor
        }

        return uniqueGeneratedAnchor(for: parsed.text)
    }

    private mutating func uniqueGeneratedAnchor(for text: String) -> String {
        let base = Self.baseAnchor(for: text)
        var candidate = base
        var suffix = 1

        while assignedHeadingAnchors.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }

        assignedHeadingAnchors.insert(candidate)
        return candidate
    }

    private static func baseAnchor(for text: String) -> String {
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
    var taskState: TaskState?

    var taskDone: Bool? {
        taskState.map { $0 == .done }
    }
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
