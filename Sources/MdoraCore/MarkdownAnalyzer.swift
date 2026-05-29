import Foundation

public enum MarkdownAnalyzer {
    public static func outline(from blocks: [MarkdownBlock]) -> [DocumentSymbol] {
        blocks.compactMap { block in
            if case let .heading(level, text, anchor) = block {
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

    public static func markers(in markdown: String, blocks: [MarkdownBlock]) -> MarkdownMarkers {
        var markers = MarkdownMarkers()
        let references = referenceDefinitions(from: blocks)
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
        markers.blockIDs = unique(blockIdentifiers(in: blocks))
        markers.customAnchors = unique(customHeadingAnchors(in: markdown))
        markers.abbreviations = unique(abbreviationDefinitions(from: blocks).values.sorted { lhs, rhs in
            lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
        })
        markers.footnotes = unique(blockFootnoteLabels(in: blocks) + inlineMarkers.footnotes)
        markers.linkReferences = unique(blockReferenceLabels(in: blocks) + inlineMarkers.linkReferences)
        markers.htmlComments = unique(htmlComments(in: blocks))
        markers.inlineHTML = unique(inlineMarkers.inlineHTML)
        markers.htmlEntities = unique(inlineMarkers.htmlEntities)
        markers.taskTokens = taskTokens(in: markdown)
        markers.taskStates = taskStateCounts(in: blocks)
        markers.mathExpressions = unique(blockMathExpressions(in: blocks) + inlineMarkers.mathExpressions)
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

        markers.codeLanguages = unique(
            blocks.compactMap { block in
                if case let .codeBlock(language, _) = block {
                    return language?.lowercased()
                }

                return nil
            }
        )

        markers.diagrams = unique(
            blocks.compactMap { block in
                if case let .diagram(diagram) = block {
                    return diagram.kind
                }

                return nil
            }
        )

        markers.callouts = blocks.compactMap { block in
            if case let .blockquote(_, callout) = block {
                return callout
            }

            return nil
        }

        return markers
    }

    public static func stats(for markdown: String, blocks: [MarkdownBlock]) -> MarkdownStats {
        let words = markdown.split { character in
            character.isWhitespace || character.isNewline
        }.count

        return MarkdownStats(
            words: words,
            characters: markdown.count,
            lines: max(1, markdown.components(separatedBy: .newlines).count),
            blocks: blocks.count,
            blockKinds: blockKinds(from: blocks),
            readingMinutes: max(1, Int(ceil(Double(words) / 220.0)))
        )
    }

    public static func diagnostics(
        in markdown: String,
        blocks: [MarkdownBlock],
        outline: [DocumentSymbol]
    ) -> [MarkdownDiagnostic] {
        var diagnostics: [MarkdownDiagnostic] = []
        diagnostics.append(contentsOf: structuralDiagnostics(in: markdown))
        diagnostics.append(contentsOf: referenceDiagnostics(in: blocks))
        diagnostics.append(contentsOf: footnoteDiagnostics(in: markdown, blocks: blocks))
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

    private static func taskTokens(in markdown: String) -> [TaskToken] {
        let pattern = #"(?im)^\s*(?:(?:[-*+]\s+|\d+[.)]\s+)(?:\[(?: |x|X|/|-|>|!|\?)\]\s+)?)?(?:<!--\s*)?\b(TODO|FIXME|BUG|HACK|NOTE|IMPORTANT|QUESTION)\b[:：]?\s*(.*?)(?:\s*-->)?\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(markdown.startIndex ..< markdown.endIndex, in: markdown)
        let matches = expression.matches(in: markdown, range: range)

        let tokens = matches.compactMap { match -> TaskToken? in
            guard match.numberOfRanges >= 3 else { return nil }
            guard let markerRange = Range(match.range(at: 1), in: markdown) else { return nil }
            guard let kind = TaskTokenKind(marker: String(markdown[markerRange])) else { return nil }

            let text: String
            if let textRange = Range(match.range(at: 2), in: markdown) {
                text = String(markdown[textRange]).trimmingCharacters(in: .whitespaces)
            } else {
                text = ""
            }

            return TaskToken(kind: kind, text: text)
        }

        return unique(tokens)
    }

    private static func blockMathExpressions(in blocks: [MarkdownBlock]) -> [String] {
        blocks.compactMap { block -> String? in
            if case let .mathBlock(expression) = block {
                let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            return nil
        }
    }

    private static func blockReferenceLabels(in blocks: [MarkdownBlock]) -> [String] {
        blocks.compactMap { block -> String? in
            if case let .linkReferenceDefinition(definition) = block {
                let trimmed = definition.label.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            return nil
        }
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

    private static func taskStateCounts(in blocks: [MarkdownBlock]) -> [TaskStateCount] {
        var counts: [TaskState: Int] = [:]

        for block in blocks {
            guard case let .taskList(items) = block else { continue }
            for item in items {
                counts[item.state, default: 0] += 1
            }
        }

        return TaskState.allCases.compactMap { state in
            guard let count = counts[state], count > 0 else { return nil }
            return TaskStateCount(state: state, count: count)
        }
    }

    private static func blockIdentifierTexts(from block: MarkdownBlock) -> [String] {
        switch block {
        case let .heading(_, text, _), let .paragraph(text):
            return [text]
        case let .blockquote(blocks, _):
            return blocks.flatMap(blockIdentifierTexts(from:))
        case let .unorderedList(items), let .orderedList(items):
            return items.map(\.text)
        case let .taskList(items):
            return items.map(\.text)
        case let .definitionList(items):
            return items.flatMap { [$0.term] + $0.definitions }
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
        case let .heading(_, text, _):
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
                visit(item.term)
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

    private static func htmlComments(in blocks: [MarkdownBlock]) -> [String] {
        blocks.compactMap { block in
            if case let .htmlComment(comment) = block {
                return comment
            }

            return nil
        }
    }

    private static func customHeadingAnchors(in markdown: String) -> [String] {
        let lines = markdown.components(separatedBy: .newlines)

        return lines.enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                guard (1 ... 6).contains(hashes) else { return nil }

                let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
                guard markerEnd < trimmed.endIndex else { return nil }
                guard trimmed[markerEnd].isWhitespace else { return nil }

                let contentStart = trimmed.index(after: markerEnd)
                let content = MarkdownHeadingAttributes.strippedClosingHashes(from: String(trimmed[contentStart...]))
                return MarkdownHeadingAttributes.customAnchor(in: content)
            }

            guard lines.indices.contains(index + 1) else { return nil }
            let underline = lines[index + 1].trimmingCharacters(in: .whitespaces)
            guard !underline.isEmpty,
                  underline.allSatisfy({ $0 == "=" }) || underline.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            return MarkdownHeadingAttributes.customAnchor(in: trimmed)
        }
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

    private static func referenceDiagnostics(in blocks: [MarkdownBlock]) -> [MarkdownDiagnostic] {
        let definitions = Set(referenceDefinitions(from: blocks).keys)
        let referencedLabels = referencedDefinitionLabels(in: blocks)

        let missing = referencedLabels.subtracting(definitions).sorted()

        return missing.map { label in
            MarkdownDiagnostic(
                id: "missing-reference-\(label)",
                severity: .warning,
                title: "Missing reference",
                message: "No reference definition found for [\(label)]."
            )
        }
    }

    private static func referencedDefinitionLabels(in blocks: [MarkdownBlock]) -> Set<String> {
        var labels: Set<String> = []

        forEachInlineText(in: blocks) { text in
            collectReferencedDefinitionLabels(from: text, into: &labels)
        }

        return labels
    }

    private static func collectReferencedDefinitionLabels(
        from text: String,
        into labels: inout Set<String>
    ) {
        guard !text.isEmpty else { return }

        for segment in InlineMarkdownParser.parse(text) {
            switch segment {
            case let .referenceLink(_, label), let .imageReference(_, label):
                let normalized = LinkReferenceDefinition.normalizedLabel(label)
                if !normalized.isEmpty {
                    labels.insert(normalized)
                }
            default:
                break
            }
        }
    }

    private static func footnoteDiagnostics(in markdown: String, blocks: [MarkdownBlock]) -> [MarkdownDiagnostic] {
        let definitions = Set(
            blocks.compactMap { block -> String? in
                if case let .footnoteDefinition(identifier, _) = block {
                    return identifier.lowercased()
                }

                return nil
            }
        )

        let references = Set(
            matches(in: markdown, pattern: #"\[\^([^\]]+)\]"#, group: 1)
                .map { $0.lowercased() }
        )

        return references.subtracting(definitions).sorted().map { identifier in
            MarkdownDiagnostic(
                id: "missing-footnote-\(identifier)",
                severity: .warning,
                title: "Missing footnote",
                message: "No footnote definition found for [^\(identifier)]."
            )
        }
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
