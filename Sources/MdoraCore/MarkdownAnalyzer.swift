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
        let inlineSegments = inlineSegments(from: blocks)

        markers.links = unique(inlineSegments.compactMap { segment in
            if case let .link(_, destination, _) = segment {
                return destination
            }

            return nil
        })
        markers.autoLinks = unique(inlineSegments.compactMap { segment in
            if case let .autoLink(url) = segment {
                return url
            }

            return nil
        })
        markers.emailLinks = unique(inlineSegments.compactMap { segment in
            if case let .email(email) = segment {
                return email
            }

            return nil
        })
        markers.images = unique(inlineSegments.compactMap { segment in
            if case let .image(_, source, _) = segment {
                return source
            }

            return nil
        })
        markers.imageReferences = unique(inlineSegments.compactMap { segment in
            if case let .imageReference(_, label) = segment {
                return label
            }

            return nil
        })
        markers.tags = unique(inlineSegments.compactMap { segment in
            if case let .tag(tag) = segment {
                return tag
            }

            return nil
        })
        markers.mentions = unique(inlineSegments.compactMap { segment in
            if case let .mention(mention) = segment {
                return mention
            }

            return nil
        })
        markers.wikiLinks = unique(inlineSegments.compactMap { segment in
            if case let .wikiLink(value) = segment {
                return value
            }

            return nil
        })
        markers.footnotes = unique(footnoteLabels(in: blocks, segments: inlineSegments))
        markers.linkReferences = unique(referenceLabels(in: blocks, segments: inlineSegments))
        markers.htmlComments = unique(htmlComments(in: blocks))
        markers.taskTokens = taskTokens(in: markdown)
        markers.mathExpressions = unique(mathExpressions(in: blocks, segments: inlineSegments))

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
        diagnostics.append(contentsOf: referenceDiagnostics(in: markdown, blocks: blocks))
        diagnostics.append(contentsOf: footnoteDiagnostics(in: markdown, blocks: blocks))
        diagnostics.append(contentsOf: headingDiagnostics(outline: outline))

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
        let pattern = #"(?im)^\s*(?:[-*]\s+)?(?:<!--\s*)?\b(TODO|FIXME|BUG|HACK|NOTE|IMPORTANT|QUESTION)\b[:：]?\s*(.*)"#
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

    private static func mathExpressions(in blocks: [MarkdownBlock], segments: [InlineMarkdownSegment]) -> [String] {
        var expressions = blocks.compactMap { block -> String? in
            if case let .mathBlock(expression) = block {
                return expression
            }

            return nil
        }

        expressions.append(contentsOf: segments.compactMap { segment in
            if case let .inlineMath(expression) = segment {
                return expression
            }

            return nil
        })

        return expressions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func referenceLabels(in blocks: [MarkdownBlock], segments: [InlineMarkdownSegment]) -> [String] {
        var labels = blocks.compactMap { block -> String? in
            if case let .linkReferenceDefinition(definition) = block {
                return definition.label
            }

            return nil
        }

        labels.append(contentsOf: segments.compactMap { segment in
            if case let .referenceLink(_, label) = segment {
                return label
            }

            return nil
        })

        return labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func footnoteLabels(in blocks: [MarkdownBlock], segments: [InlineMarkdownSegment]) -> [String] {
        var labels = blocks.compactMap { block -> String? in
            if case let .footnoteDefinition(identifier, _) = block {
                return identifier
            }

            return nil
        }

        labels.append(contentsOf: segments.compactMap { segment in
            if case let .footnote(identifier) = segment {
                return identifier
            }

            return nil
        })

        return labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func inlineSegments(from blocks: [MarkdownBlock]) -> [InlineMarkdownSegment] {
        blocks.flatMap(inlineTexts(from:)).flatMap(InlineMarkdownParser.parse)
    }

    private static func inlineTexts(from block: MarkdownBlock) -> [String] {
        switch block {
        case let .heading(_, text, _):
            return [text]
        case let .paragraph(text):
            return [text]
        case let .blockquote(lines, _):
            return lines
        case let .unorderedList(items), let .orderedList(items):
            return items.map(\.text)
        case let .taskList(items):
            return items.map(\.text)
        case let .table(table):
            return table.headers + table.rows.flatMap { $0 }
        case let .definitionList(items):
            return items.flatMap { [$0.term] + $0.definitions }
        case let .footnoteDefinition(identifier, text):
            return ["[^\(identifier)]", text]
        case let .linkReferenceDefinition(definition):
            return [definition.title].compactMap { $0 }
        case let .image(alt, source, title):
            return ["![\(alt)](\(source)\(title.map { " \"\($0)\"" } ?? ""))"]
        case .frontMatter, .codeBlock, .diagram, .mathBlock, .thematicBreak, .htmlComment, .html:
            return []
        }
    }

    private static func htmlComments(in blocks: [MarkdownBlock]) -> [String] {
        blocks.compactMap { block in
            if case let .htmlComment(comment) = block {
                return comment
            }

            return nil
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

        var openFence: (marker: String, line: Int)?
        var openMathLine: Int?

        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))

                if let fence = openFence, fence.marker == marker {
                    openFence = nil
                } else if openFence == nil {
                    openFence = (marker, lineNumber)
                }
            }

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
                    message: "A \(fence.marker) fence was opened but not closed.",
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

    private static func referenceDiagnostics(in markdown: String, blocks: [MarkdownBlock]) -> [MarkdownDiagnostic] {
        let definitions = Set(
            blocks.compactMap { block -> String? in
                if case let .linkReferenceDefinition(definition) = block {
                    return definition.label.lowercased()
                }

                return nil
            }
        )

        let referencedLabels = Set(
            matches(in: markdown, pattern: #"(?<!\!)\[[^\]]+\]\[([^\]]+)\]"#, group: 1)
                .map { $0.lowercased() }
        )

        let imageLabels = Set(
            matches(in: markdown, pattern: #"\!\[[^\]]*\]\[([^\]]+)\]"#, group: 1)
                .map { $0.lowercased() }
        )

        let missing = referencedLabels.union(imageLabels).subtracting(definitions).sorted()

        return missing.map { label in
            MarkdownDiagnostic(
                id: "missing-reference-\(label)",
                severity: .warning,
                title: "Missing reference",
                message: "No reference definition found for [\(label)]."
            )
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
}
