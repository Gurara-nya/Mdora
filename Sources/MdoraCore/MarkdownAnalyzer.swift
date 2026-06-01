import Foundation

public enum MarkdownAnalyzer {
    public static func outline(from blocks: [MarkdownBlock]) -> [DocumentSymbol] {
        blocks.compactMap { block in
            if case let .heading(level, text, anchor, _) = block {
                return DocumentSymbol(level: level, title: text, anchor: anchor)
            }

            return nil
        }
    }

    public static func metadata(from blocks: [MarkdownBlock]) -> [MetadataItem] {
        guard let frontMatter = blocks.compactMap({ block -> FrontMatterBlock? in
            if case let .frontMatter(frontMatter) = block {
                return frontMatter
            }

            return nil
        }).first else {
            return []
        }

        switch frontMatter.kind {
        case .yaml:
            return yamlMetadata(from: frontMatter.lines)
        case .toml:
            return tomlMetadata(from: frontMatter.lines)
        case .json:
            return jsonMetadata(from: frontMatter.lines)
        }
    }

    public static func referenceDefinitions(from blocks: [MarkdownBlock]) -> [String: LinkReferenceDefinition] {
        var definitions: [String: LinkReferenceDefinition] = [:]

        for block in blocks {
            guard case let .linkReferenceDefinition(definition) = block else { continue }
            if definitions[definition.normalizedLabel] == nil {
                definitions[definition.normalizedLabel] = definition
            }
        }

        return definitions
    }

    public static func abbreviationDefinitions(from blocks: [MarkdownBlock]) -> [String: AbbreviationDefinition] {
        var definitions: [String: AbbreviationDefinition] = [:]

        for block in blocks {
            guard case let .abbreviationDefinition(definition) = block else { continue }
            definitions[definition.normalizedTerm] = definition
        }

        return definitions
    }

    private static func yamlMetadata(from lines: [String]) -> [MetadataItem] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            guard let separator = trimmed.firstIndex(of: ":") else { return nil }

            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            guard !key.isEmpty else { return nil }
            return MetadataItem(key: key, value: value)
        }
    }

    private static func tomlMetadata(from lines: [String]) -> [MetadataItem] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("[") else { return nil }
            guard let separator = trimmed.firstIndex(of: "=") else { return nil }

            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            guard !key.isEmpty else { return nil }
            return MetadataItem(key: key, value: value)
        }
    }

    private static func jsonMetadata(from lines: [String]) -> [MetadataItem] {
        let source = lines.joined(separator: "\n")
        guard let data = source.data(using: .utf8) else { return [] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        return object.keys.sorted().compactMap { key in
            guard let value = object[key] else { return nil }
            return MetadataItem(key: key, value: metadataValueDescription(value))
        }
    }

    private static func metadataValueDescription(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return array.map(metadataValueDescription).joined(separator: ", ")
        case let dictionary as [String: Any]:
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else {
                return "\(dictionary)"
            }
            return json
        default:
            return "\(value)"
        }
    }

    public static func markers(
        in markdown: String,
        blocks: [MarkdownBlock],
        sourceMap: [MarkdownBlockSourceRange] = [],
        referenceDefinitions precomputedReferences: [String: LinkReferenceDefinition]? = nil,
        abbreviationDefinitions precomputedAbbreviations: [String: AbbreviationDefinition]? = nil
    ) -> MarkdownMarkers {
        var markers = MarkdownMarkers()
        let references = precomputedReferences ?? referenceDefinitions(from: blocks)
        let abbreviations = precomputedAbbreviations ?? abbreviationDefinitions(from: blocks)
        let blockMarkers = collectBlockMarkers(in: blocks)
        let inlineMarkers = inlineMarkers(in: blocks, references: references)

        markers.links = unique(inlineMarkers.links)
        markers.autoLinks = unique(inlineMarkers.autoLinks)
        markers.emailLinks = unique(inlineMarkers.emailLinks)
        markers.images = unique(inlineMarkers.images)
        markers.imageReferences = unique(inlineMarkers.imageReferences)
        markers.tags = unique(inlineMarkers.tags)
        markers.mentions = unique(inlineMarkers.mentions)
        markers.wikiLinks = unique(inlineMarkers.wikiLinks)
        markers.wikiEmbeds = unique(inlineMarkers.wikiEmbeds)
        markers.blockIDs = unique(blockMarkers.blockIDs)
        markers.customAnchors = unique(blockMarkers.customAnchors)
        markers.abbreviations = unique(abbreviations.values.sorted { lhs, rhs in
            lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
        })
        markers.footnotes = unique(blockMarkers.footnotes + inlineMarkers.footnotes)
        markers.linkReferences = unique(blockMarkers.linkReferences + inlineMarkers.linkReferences)
        markers.htmlComments = unique(blockMarkers.htmlComments)
        markers.inlineHTML = unique(inlineMarkers.inlineHTML)
        markers.htmlEntities = unique(inlineMarkers.htmlEntities)
        markers.taskTokens = taskTokens(in: markdown, blocks: blocks, sourceMap: sourceMap)
        markers.taskStates = blockMarkers.taskStates
        markers.mathExpressions = unique(blockMarkers.mathExpressions + inlineMarkers.mathExpressions)
        markers.highlights = unique(inlineMarkers.highlights)
        markers.superscripts = unique(inlineMarkers.superscripts)
        markers.subscripts = unique(inlineMarkers.subscripts)
        markers.criticAdditions = unique(inlineMarkers.criticAdditions)
        markers.criticDeletions = unique(inlineMarkers.criticDeletions)
        markers.criticSubstitutions = unique(inlineMarkers.criticSubstitutions)
        markers.criticComments = unique(inlineMarkers.criticComments)
        markers.criticHighlights = unique(inlineMarkers.criticHighlights)
        markers.citations = unique(inlineMarkers.citations)
        markers.emojiShortcodes = unique(inlineMarkers.emojiShortcodes)
        markers.keyboardShortcuts = unique(inlineMarkers.keyboardShortcuts)
        markers.codeLanguages = unique(blockMarkers.codeLanguages)
        markers.diagrams = unique(blockMarkers.diagrams)
        markers.callouts = blockMarkers.callouts

        return markers
    }

    public static func stats(for markdown: String, blocks: [MarkdownBlock]) -> MarkdownStats {
        let textCounts = textCounts(in: markdown)

        return MarkdownStats(
            words: textCounts.words,
            characters: textCounts.characters,
            lines: textCounts.lines,
            blocks: blocks.count,
            blockKinds: blockKinds(from: blocks),
            readingMinutes: max(1, Int(ceil(Double(textCounts.words) / 220.0)))
        )
    }

    private static func textCounts(in markdown: String) -> DocumentTextCounts {
        var words = 0
        var characters = 0
        var lineBreaks = 0
        var isInsideWord = false

        for character in markdown {
            characters += 1

            for scalar in character.unicodeScalars where CharacterSet.newlines.contains(scalar) {
                lineBreaks += 1
            }

            if character.isWhitespace || character.isNewline {
                isInsideWord = false
            } else if !isInsideWord {
                words += 1
                isInsideWord = true
            }
        }

        return DocumentTextCounts(
            words: words,
            characters: characters,
            lines: max(1, lineBreaks + 1)
        )
    }

    public static func diagnostics(
        in markdown: String,
        blocks: [MarkdownBlock],
        outline: [DocumentSymbol],
        referenceDefinitions precomputedReferences: [String: LinkReferenceDefinition]? = nil,
        markers precomputedMarkers: MarkdownMarkers? = nil
    ) -> [MarkdownDiagnostic] {
        var diagnostics: [MarkdownDiagnostic] = []
        let references = precomputedReferences ?? referenceDefinitions(from: blocks)
        diagnostics.append(contentsOf: structuralDiagnostics(in: markdown))
        diagnostics.append(contentsOf: inlineReferenceDiagnostics(
            in: blocks,
            referenceDefinitionKeys: Set(references.keys),
            markers: precomputedMarkers
        ))
        diagnostics.append(contentsOf: headingDiagnostics(outline: outline))
        diagnostics.append(contentsOf: blockIDDiagnostics(in: blocks))
        diagnostics.append(contentsOf: duplicateReferenceDiagnostics(in: blocks))

        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(
                MarkdownDiagnostic(
                    id: "empty-document",
                    severity: .info,
                    title: "Empty document",
                    message: "Start typing Markdown to build a preview."
                )
            )
        }

        return diagnostics
    }

    private static func matches(in text: String, pattern: String, group: Int) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        let results = expression.matches(in: text, range: range)

        return results.compactMap { result in
            guard result.numberOfRanges > group else { return nil }
            guard let matchRange = Range(result.range(at: group), in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }

    private static func blockKinds(from blocks: [MarkdownBlock]) -> [BlockKindCount] {
        var counts: [String: Int] = [:]

        for block in blocks {
            counts[kindName(for: block), default: 0] += 1
        }

        return counts
            .map { BlockKindCount(kind: $0.key, count: $0.value) }
            .sorted { first, second in
                if first.count == second.count {
                    return first.kind < second.kind
                }

                return first.count > second.count
            }
    }

    private static func kindName(for block: MarkdownBlock) -> String {
        switch block {
        case let .frontMatter(frontMatter):
            "\(frontMatter.kind.title) Front Matter"
        case .heading:
            "Heading"
        case .paragraph:
            "Paragraph"
        case .blockquote:
            "Blockquote"
        case .unorderedList:
            "Bulleted List"
        case .orderedList:
            "Numbered List"
        case .taskList:
            "Task List"
        case .codeBlock:
            "Code"
        case .diagram:
            "Diagram"
        case .mathBlock:
            "Math"
        case .table:
            "Table"
        case .definitionList:
            "Definition List"
        case .footnoteDefinition:
            "Footnote"
        case .linkReferenceDefinition:
            "Reference"
        case .abbreviationDefinition:
            "Abbreviation"
        case .image:
            "Image"
        case .thematicBreak:
            "Divider"
        case .htmlComment:
            "Comment"
        case .html:
            "HTML"
        }
    }

    private static func taskTokens(
        in markdown: String,
        blocks: [MarkdownBlock],
        sourceMap: [MarkdownBlockSourceRange]
    ) -> [TaskToken] {
        guard !sourceMap.isEmpty else {
            return taskTokens(in: blocks)
        }

        var tokens: [TaskToken] = []
        var lineNumber = 1
        var sourceMapIndex = 0

        for rawLine in markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            while sourceMapIndex < sourceMap.count,
                  lineNumber > sourceMap[sourceMapIndex].endLine {
                sourceMapIndex += 1
            }

            if sourceMapIndex < sourceMap.count {
                let sourceRange = sourceMap[sourceMapIndex]
                if sourceRange.contains(line: lineNumber),
                   blocks.indices.contains(sourceRange.blockIndex),
                   shouldScanRawTaskTokenLine(in: blocks[sourceRange.blockIndex]),
                   let token = taskToken(in: rawLine) {
                    tokens.append(token)
                }
            }

            lineNumber += 1
        }

        for block in blocks {
            if case .blockquote = block {
                collectTaskTokens(in: block, into: &tokens)
            }
        }

        return unique(tokens)
    }

    private static func taskTokens(in blocks: [MarkdownBlock]) -> [TaskToken] {
        var tokens: [TaskToken] = []

        for block in blocks {
            collectTaskTokens(in: block, into: &tokens)
        }

        return unique(tokens)
    }

    private static func shouldScanRawTaskTokenLine(in block: MarkdownBlock) -> Bool {
        switch block {
        case .heading, .paragraph, .unorderedList, .orderedList, .taskList, .definitionList, .footnoteDefinition, .htmlComment:
            return true
        case .blockquote, .frontMatter, .codeBlock, .diagram, .mathBlock, .table, .linkReferenceDefinition, .abbreviationDefinition, .image, .thematicBreak, .html:
            return false
        }
    }

    private static func collectTaskTokens(in block: MarkdownBlock, into tokens: inout [TaskToken]) {
        switch block {
        case let .heading(_, text, _, _), let .paragraph(text):
            collectTaskTokens(inText: text, into: &tokens)
        case let .blockquote(blocks, _):
            for block in blocks {
                collectTaskTokens(in: block, into: &tokens)
            }
        case let .unorderedList(items), let .orderedList(items):
            for item in items {
                collectTaskTokens(inText: item.text, into: &tokens)
            }
        case let .taskList(items):
            for item in items {
                collectTaskTokens(inText: item.text, into: &tokens)
            }
        case let .definitionList(items):
            for item in items {
                for term in item.terms {
                    collectTaskTokens(inText: term, into: &tokens)
                }
                for definition in item.definitions {
                    collectTaskTokens(inText: definition, into: &tokens)
                }
            }
        case let .footnoteDefinition(_, text):
            collectTaskTokens(inText: text, into: &tokens)
        case let .htmlComment(comment):
            collectTaskTokens(inText: comment, into: &tokens)
        case .frontMatter, .codeBlock, .diagram, .mathBlock, .table, .linkReferenceDefinition, .abbreviationDefinition, .image, .thematicBreak, .html:
            break
        }
    }

    private static func collectTaskTokens(inText text: String, into tokens: inout [TaskToken]) {
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if let token = taskToken(in: line) {
                tokens.append(token)
            }
        }
    }

    private static func taskToken<S: StringProtocol>(in line: S) -> TaskToken? {
        var cursor = line.startIndex
        skipWhitespace(in: line, from: &cursor)
        stripHeadingPrefix(in: line, from: &cursor)
        stripListPrefix(in: line, from: &cursor)
        stripHTMLCommentPrefix(in: line, from: &cursor)
        skipWhitespace(in: line, from: &cursor)

        guard cursor < line.endIndex else { return nil }
        let markerStart = cursor
        while cursor < line.endIndex, line[cursor].isLetter {
            cursor = line.index(after: cursor)
        }

        guard markerStart < cursor else { return nil }
        let marker = String(line[markerStart ..< cursor])
        guard let kind = TaskTokenKind(marker: marker) else { return nil }

        if cursor < line.endIndex {
            if line[cursor] == ":" || line[cursor] == "：" {
                cursor = line.index(after: cursor)
            } else if !line[cursor].isWhitespace {
                return nil
            }
        }

        skipWhitespace(in: line, from: &cursor)
        let rawText = String(line[cursor...]).trimmingCharacters(in: .whitespaces)
        let text = rawText.hasSuffix("-->")
            ? String(rawText.dropLast(3)).trimmingCharacters(in: .whitespaces)
            : rawText

        return TaskToken(kind: kind, text: text)
    }

    private static func stripHeadingPrefix<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        guard cursor < line.endIndex, line[cursor] == "#" else { return }

        var scan = cursor
        var count = 0
        while scan < line.endIndex, line[scan] == "#", count < 6 {
            count += 1
            scan = line.index(after: scan)
        }

        guard count > 0,
              scan < line.endIndex,
              line[scan].isWhitespace else {
            return
        }

        cursor = scan
        skipWhitespace(in: line, from: &cursor)
    }

    private static func stripListPrefix<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        stripMarkdownListMarker(in: line, from: &cursor)
        stripTaskStatePrefix(in: line, from: &cursor)
    }

    private static func stripMarkdownListMarker<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        guard cursor < line.endIndex else { return }

        let marker = line[cursor]
        if marker == "-" || marker == "*" || marker == "+" {
            let afterMarker = line.index(after: cursor)
            guard afterMarker < line.endIndex, line[afterMarker].isWhitespace else { return }
            cursor = afterMarker
            skipWhitespace(in: line, from: &cursor)
            return
        }

        guard marker.isNumber else { return }
        var scan = cursor
        while scan < line.endIndex, line[scan].isNumber {
            scan = line.index(after: scan)
        }

        guard scan < line.endIndex,
              line[scan] == "." || line[scan] == ")" else {
            return
        }

        let afterDelimiter = line.index(after: scan)
        guard afterDelimiter < line.endIndex, line[afterDelimiter].isWhitespace else { return }
        cursor = afterDelimiter
        skipWhitespace(in: line, from: &cursor)
    }

    private static func stripTaskStatePrefix<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        guard cursor < line.endIndex, line[cursor] == "[" else { return }
        guard let markerIndex = line.index(cursor, offsetBy: 1, limitedBy: line.endIndex),
              markerIndex < line.endIndex,
              let closeIndex = line.index(cursor, offsetBy: 2, limitedBy: line.endIndex),
              closeIndex < line.endIndex,
              line[closeIndex] == "]",
              TaskState(marker: line[markerIndex]) != nil else {
            return
        }

        let afterClose = line.index(after: closeIndex)
        guard afterClose < line.endIndex, line[afterClose].isWhitespace else { return }
        cursor = afterClose
        skipWhitespace(in: line, from: &cursor)
    }

    private static func stripHTMLCommentPrefix<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        guard line[cursor...].hasPrefix("<!--") else { return }
        cursor = line.index(cursor, offsetBy: 4)
        skipWhitespace(in: line, from: &cursor)
    }

    private static func skipWhitespace<S: StringProtocol>(in line: S, from cursor: inout S.Index) {
        while cursor < line.endIndex, line[cursor].isWhitespace {
            cursor = line.index(after: cursor)
        }
    }

    private static func collectBlockMarkers(in blocks: [MarkdownBlock]) -> BlockMarkerCollections {
        var markers = BlockMarkerCollections()

        for block in blocks {
            collectBlockMarkers(from: block, isNested: false, into: &markers)
        }

        return markers
    }

    private static func collectBlockMarkers(
        from block: MarkdownBlock,
        isNested: Bool,
        into markers: inout BlockMarkerCollections
    ) {
        switch block {
        case let .heading(_, text, _, customAnchor):
            appendBlockID(from: text, to: &markers.blockIDs)
            if let customAnchor {
                markers.customAnchors.append(customAnchor)
            }
        case let .paragraph(text):
            appendBlockID(from: text, to: &markers.blockIDs)
        case let .blockquote(blocks, callout):
            if !isNested, let callout {
                markers.callouts.append(callout)
            }
            for block in blocks {
                collectBlockMarkers(from: block, isNested: true, into: &markers)
            }
        case let .unorderedList(items), let .orderedList(items):
            for item in items {
                appendBlockID(from: item.text, to: &markers.blockIDs)
            }
        case let .taskList(items):
            for item in items {
                appendBlockID(from: item.text, to: &markers.blockIDs)
                if !isNested {
                    markers.taskStateCounts[item.state, default: 0] += 1
                }
            }
        case let .codeBlock(language, _):
            if !isNested, let language {
                markers.codeLanguages.append(language.lowercased())
            }
        case let .diagram(diagram):
            if !isNested {
                markers.diagrams.append(diagram.kind)
            }
        case let .mathBlock(expression):
            guard !isNested else { break }
            appendTrimmed(expression, to: &markers.mathExpressions)
        case let .definitionList(items):
            for item in items {
                for term in item.terms {
                    appendBlockID(from: term, to: &markers.blockIDs)
                }
                for definition in item.definitions {
                    appendBlockID(from: definition, to: &markers.blockIDs)
                }
            }
        case let .footnoteDefinition(identifier, text):
            appendBlockID(from: text, to: &markers.blockIDs)
            if !isNested {
                appendTrimmed(identifier, to: &markers.footnotes)
            }
        case let .linkReferenceDefinition(definition):
            if !isNested {
                appendTrimmed(definition.label, to: &markers.linkReferences)
            }
        case let .htmlComment(comment):
            if !isNested {
                markers.htmlComments.append(comment)
            }
        case .frontMatter, .table, .abbreviationDefinition, .image, .thematicBreak, .html:
            break
        }
    }

    private static func appendBlockID(from text: String, to identifiers: inout [String]) {
        guard let identifier = MarkdownBlockIDParser.trailingIdentifier(in: text) else { return }
        identifiers.append(identifier)
    }

    private static func blockFootnoteLabels(in blocks: [MarkdownBlock]) -> [String] {
        blocks.compactMap { block -> String? in
            if case let .footnoteDefinition(identifier, _) = block {
                let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            return nil
        }
    }

    private static func blockIdentifiers(in blocks: [MarkdownBlock]) -> [String] {
        blocks.flatMap(blockIdentifierTexts(from:)).compactMap(MarkdownBlockIDParser.trailingIdentifier)
    }

    private static func blockIdentifierTexts(from block: MarkdownBlock) -> [String] {
        switch block {
        case let .heading(_, text, _, _), let .paragraph(text):
            return [text]
        case let .blockquote(blocks, _):
            return blocks.flatMap(blockIdentifierTexts(from:))
        case let .unorderedList(items), let .orderedList(items):
            return items.map(\.text)
        case let .taskList(items):
            return items.map(\.text)
        case let .definitionList(items):
            return items.flatMap { $0.terms + $0.definitions }
        case let .footnoteDefinition(_, text):
            return [text]
        case .frontMatter, .codeBlock, .diagram, .mathBlock, .table, .linkReferenceDefinition, .abbreviationDefinition, .image, .thematicBreak, .htmlComment, .html:
            return []
        }
    }

    private static func inlineMarkers(
        in blocks: [MarkdownBlock],
        references: [String: LinkReferenceDefinition]
    ) -> InlineMarkerCollections {
        var markers = InlineMarkerCollections()

        forEachInlineText(in: blocks) { text in
            collectInlineMarkers(from: text, references: references, into: &markers)
        }

        return markers
    }

    private static func forEachInlineText(in blocks: [MarkdownBlock], _ visit: (String) -> Void) {
        for block in blocks {
            forEachInlineText(in: block, visit)
        }
    }

    private static func forEachInlineText(in block: MarkdownBlock, _ visit: (String) -> Void) {
        switch block {
        case let .heading(_, text, _, _):
            visit(text)
        case let .paragraph(text):
            visit(text)
        case let .blockquote(blocks, _):
            for block in blocks {
                forEachInlineText(in: block, visit)
            }
        case let .unorderedList(items), let .orderedList(items):
            for item in items {
                visit(item.text)
            }
        case let .taskList(items):
            for item in items {
                visit(item.text)
            }
        case let .table(table):
            for header in table.headers {
                visit(header)
            }
            for row in table.rows {
                for cell in row {
                    visit(cell)
                }
            }
        case let .definitionList(items):
            for item in items {
                for term in item.terms {
                    visit(term)
                }
                for definition in item.definitions {
                    visit(definition)
                }
            }
        case let .footnoteDefinition(identifier, text):
            visit("[^\(identifier)]")
            visit(text)
        case let .linkReferenceDefinition(definition):
            if let title = definition.title {
                visit(title)
            }
        case .abbreviationDefinition:
            break
        case let .image(alt, source, title):
            visit("![\(alt)](\(source)\(title.map { " \"\($0)\"" } ?? ""))")
        case .frontMatter, .codeBlock, .diagram, .mathBlock, .thematicBreak, .htmlComment, .html:
            break
        }
    }

    private static func collectInlineMarkers(
        from text: String,
        references: [String: LinkReferenceDefinition],
        into markers: inout InlineMarkerCollections
    ) {
        guard !text.isEmpty else { return }

        for segment in InlineMarkdownParser.parse(text) {
            switch segment {
            case let .link(_, destination, _):
                markers.links.append(destination)
            case let .autoLink(url):
                markers.autoLinks.append(url)
            case let .email(email):
                markers.emailLinks.append(email)
            case let .image(_, source, _):
                markers.images.append(source)
            case let .imageReference(_, label):
                markers.imageReferences.append(label)
            case let .shortcutImageReference(alt):
                if references[LinkReferenceDefinition.normalizedLabel(alt)] != nil {
                    markers.imageReferences.append(alt)
                }
            case let .tag(tag):
                markers.tags.append(tag)
            case let .mention(mention):
                markers.mentions.append(mention)
            case let .wikiLink(value):
                markers.wikiLinks.append(value)
            case let .wikiEmbed(value):
                markers.wikiEmbeds.append(value)
            case let .htmlInline(value):
                markers.inlineHTML.append(value)
            case let .htmlEntity(source, _):
                markers.htmlEntities.append(source)
            case let .highlight(value):
                markers.highlights.append(value)
            case let .superscript(value):
                markers.superscripts.append(value)
            case let .subscriptText(value):
                markers.subscripts.append(value)
            case let .criticAddition(value):
                markers.criticAdditions.append(value)
            case let .criticDeletion(value):
                markers.criticDeletions.append(value)
            case let .criticSubstitution(original, replacement):
                markers.criticSubstitutions.append(CriticSubstitution(original: original, replacement: replacement))
            case let .criticComment(value):
                markers.criticComments.append(value)
            case let .criticHighlight(value):
                markers.criticHighlights.append(value)
            case let .citation(identifier):
                markers.citations.append(identifier)
            case let .emojiShortcode(name):
                markers.emojiShortcodes.append(name)
            case let .keyboard(value):
                markers.keyboardShortcuts.append(value)
            case let .referenceLink(_, label):
                appendTrimmed(label, to: &markers.linkReferences)
            case let .shortcutReferenceLink(label):
                if references[LinkReferenceDefinition.normalizedLabel(label)] != nil {
                    appendTrimmed(label, to: &markers.linkReferences)
                }
            case let .footnote(identifier):
                appendTrimmed(identifier, to: &markers.footnotes)
            case let .inlineMath(expression):
                appendTrimmed(expression, to: &markers.mathExpressions)
            case .text, .hardBreak, .strong, .emphasis, .strikethrough, .code:
                break
            }
        }
    }

    private static func appendTrimmed(_ value: String, to values: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        values.append(trimmed)
    }

    private static func structuralDiagnostics(in markdown: String) -> [MarkdownDiagnostic] {
        let lines = markdown.components(separatedBy: .newlines)
        var diagnostics: [MarkdownDiagnostic] = []

        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           firstLine == "---" || firstLine == "+++" {
            let hasClosingFrontMatter = lines.dropFirst().contains { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines) == firstLine
            }

            if !hasClosingFrontMatter {
                let kind = firstLine == "+++" ? "TOML" : "YAML"
                diagnostics.append(
                    MarkdownDiagnostic(
                        id: "unclosed-front-matter",
                        severity: .warning,
                        title: "Unclosed front matter",
                        message: "\(kind) front matter starts with \(firstLine) but has no closing \(firstLine).",
                        line: 1
                    )
                )
            }
        }

        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "{" {
            var depth = 0
            for line in lines {
                for character in line {
                    if character == "{" { depth += 1 }
                    if character == "}" { depth -= 1 }
                }
            }

            if depth > 0 {
                diagnostics.append(
                    MarkdownDiagnostic(
                        id: "unclosed-json-front-matter",
                        severity: .warning,
                        title: "Unclosed JSON front matter",
                        message: "JSON front matter starts with { but has no closing }.",
                        line: 1
                    )
                )
            }
        }

        var openFence: (delimiter: MarkdownCodeFenceDelimiter, line: Int)?
        var openMathLine: Int?

        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1

            if let delimiter = MarkdownCodeFenceScanner.delimiter(in: line) {
                if let fence = openFence,
                   MarkdownCodeFenceScanner.isClosingDelimiter(delimiter, for: fence.delimiter) {
                    openFence = nil
                } else if openFence == nil {
                    openFence = (delimiter, lineNumber)
                }
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "$$" {
                if openMathLine == nil {
                    openMathLine = lineNumber
                } else {
                    openMathLine = nil
                }
            }
        }

        if let fence = openFence {
            diagnostics.append(
                MarkdownDiagnostic(
                    id: "unclosed-code-fence-\(fence.line)",
                    severity: .error,
                    title: "Unclosed code fence",
                    message: "A \(String(repeating: String(fence.delimiter.marker), count: fence.delimiter.length)) fence was opened but not closed.",
                    line: fence.line
                )
            )
        }

        if let openMathLine {
            diagnostics.append(
                MarkdownDiagnostic(
                    id: "unclosed-math-\(openMathLine)",
                    severity: .warning,
                    title: "Unclosed math block",
                    message: "A $$ math block was opened but not closed.",
                    line: openMathLine
                )
            )
        }

        return diagnostics
    }

    private static func inlineReferenceDiagnostics(
        in blocks: [MarkdownBlock],
        referenceDefinitionKeys definitions: Set<String>,
        markers: MarkdownMarkers?
    ) -> [MarkdownDiagnostic] {
        let footnoteDefinitions = Set(
            blockFootnoteLabels(in: blocks).map(normalizedFootnoteLabel)
        )
        let references = markers.map(inlineDiagnosticReferences(from:)) ?? inlineDiagnosticReferences(in: blocks)

        let missingReferences = references.referenceLabels.subtracting(definitions).sorted().map { label in
            MarkdownDiagnostic(
                id: "missing-reference-\(label)",
                severity: .warning,
                title: "Missing reference",
                message: "No reference definition found for [\(label)]."
            )
        }

        let missingFootnotes = references.footnoteLabels.subtracting(footnoteDefinitions).sorted().map { identifier in
            MarkdownDiagnostic(
                id: "missing-footnote-\(identifier)",
                severity: .warning,
                title: "Missing footnote",
                message: "No footnote definition found for [^\(identifier)]."
            )
        }

        return missingReferences + missingFootnotes
    }

    private static func inlineDiagnosticReferences(from markers: MarkdownMarkers) -> InlineDiagnosticReferences {
        InlineDiagnosticReferences(
            referenceLabels: Set((markers.linkReferences + markers.imageReferences).compactMap { label in
                let normalized = LinkReferenceDefinition.normalizedLabel(label)
                return normalized.isEmpty ? nil : normalized
            }),
            footnoteLabels: Set(markers.footnotes.compactMap { label in
                let normalized = normalizedFootnoteLabel(label)
                return normalized.isEmpty ? nil : normalized
            })
        )
    }

    private static func inlineDiagnosticReferences(in blocks: [MarkdownBlock]) -> InlineDiagnosticReferences {
        var references = InlineDiagnosticReferences()

        forEachInlineText(in: blocks) { text in
            collectInlineDiagnosticReferences(from: text, into: &references)
        }

        return references
    }

    private static func collectInlineDiagnosticReferences(
        from text: String,
        into references: inout InlineDiagnosticReferences
    ) {
        guard !text.isEmpty else { return }

        for segment in InlineMarkdownParser.parse(text) {
            switch segment {
            case let .referenceLink(_, label), let .imageReference(_, label):
                let normalized = LinkReferenceDefinition.normalizedLabel(label)
                if !normalized.isEmpty {
                    references.referenceLabels.insert(normalized)
                }
            case let .footnote(identifier):
                let normalized = normalizedFootnoteLabel(identifier)
                if !normalized.isEmpty {
                    references.footnoteLabels.insert(normalized)
                }
            default:
                break
            }
        }
    }

    private static func normalizedFootnoteLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func headingDiagnostics(outline: [DocumentSymbol]) -> [MarkdownDiagnostic] {
        let grouped = Dictionary(grouping: outline, by: \.anchor)

        return grouped.compactMap { anchor, symbols in
            guard symbols.count > 1 else { return nil }

            return MarkdownDiagnostic(
                id: "duplicate-heading-\(anchor)",
                severity: .info,
                title: "Duplicate heading anchor",
                message: "\(symbols.count) headings produce the same #\(anchor) anchor."
            )
        }
        .sorted { $0.id < $1.id }
    }

    private static func blockIDDiagnostics(in blocks: [MarkdownBlock]) -> [MarkdownDiagnostic] {
        let grouped = Dictionary(grouping: blockIdentifiers(in: blocks), by: { $0 })

        return grouped.compactMap { identifier, identifiers in
            guard identifiers.count > 1 else { return nil }

            return MarkdownDiagnostic(
                id: "duplicate-block-id-\(identifier)",
                severity: .warning,
                title: "Duplicate block id",
                message: "\(identifiers.count) blocks use the same ^\(identifier) id."
            )
        }
        .sorted { $0.id < $1.id }
    }

    private static func duplicateReferenceDiagnostics(in blocks: [MarkdownBlock]) -> [MarkdownDiagnostic] {
        let definitions = blocks.compactMap { block -> LinkReferenceDefinition? in
            guard case let .linkReferenceDefinition(definition) = block else { return nil }
            return definition
        }
        let grouped = Dictionary(grouping: definitions, by: \.normalizedLabel)

        return grouped.compactMap { normalizedLabel, definitions in
            guard definitions.count > 1 else { return nil }
            return MarkdownDiagnostic(
                id: "duplicate-reference-\(normalizedLabel)",
                severity: .info,
                title: "Duplicate reference definition",
                message: "\(definitions.count) reference definitions use [\(definitions[0].label)]; the first definition is used."
            )
        }
        .sorted { $0.id < $1.id }
    }
}

private struct BlockMarkerCollections {
    var blockIDs: [String] = []
    var customAnchors: [String] = []
    var footnotes: [String] = []
    var linkReferences: [String] = []
    var htmlComments: [String] = []
    var mathExpressions: [String] = []
    var codeLanguages: [String] = []
    var diagrams: [DiagramKind] = []
    var callouts: [Callout] = []
    var taskStateCounts: [TaskState: Int] = [:]

    var taskStates: [TaskStateCount] {
        TaskState.allCases.compactMap { state in
            guard let count = taskStateCounts[state], count > 0 else { return nil }
            return TaskStateCount(state: state, count: count)
        }
    }
}

private struct InlineMarkerCollections {
    var links: [String] = []
    var autoLinks: [String] = []
    var emailLinks: [String] = []
    var images: [String] = []
    var imageReferences: [String] = []
    var tags: [String] = []
    var mentions: [String] = []
    var wikiLinks: [String] = []
    var wikiEmbeds: [String] = []
    var footnotes: [String] = []
    var linkReferences: [String] = []
    var inlineHTML: [String] = []
    var htmlEntities: [String] = []
    var mathExpressions: [String] = []
    var highlights: [String] = []
    var superscripts: [String] = []
    var subscripts: [String] = []
    var criticAdditions: [String] = []
    var criticDeletions: [String] = []
    var criticSubstitutions: [CriticSubstitution] = []
    var criticComments: [String] = []
    var criticHighlights: [String] = []
    var citations: [String] = []
    var emojiShortcodes: [String] = []
    var keyboardShortcuts: [String] = []
}

private struct DocumentTextCounts {
    var words: Int
    var characters: Int
    var lines: Int
}

private struct InlineDiagnosticReferences {
    var referenceLabels: Set<String> = []
    var footnoteLabels: Set<String> = []
}
