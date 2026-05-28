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

    public static func markers(in markdown: String, blocks: [MarkdownBlock]) -> MarkdownMarkers {
        var markers = MarkdownMarkers()

        markers.links = unique(matches(in: markdown, pattern: #"(?<!\!)\[([^\]]+)\]\(([^\)]+)\)"#, group: 2))
        markers.autoLinks = unique(matches(in: markdown, pattern: ##"(?<![\]\)">])(https?://[^\s<\)]+)"##, group: 1))
        markers.images = unique(matches(in: markdown, pattern: #"\!\[([^\]]*)\]\(([^\)]+)\)"#, group: 2))
        markers.tags = unique(matches(in: markdown, pattern: #"(?<!\w)#([A-Za-z0-9_\-/\p{Han}]+)"#, group: 1))
        markers.mentions = unique(matches(in: markdown, pattern: #"(?<!\w)@([A-Za-z0-9_\-\.]+)"#, group: 1))
        markers.wikiLinks = unique(matches(in: markdown, pattern: #"\[\[([^\]]+)\]\]"#, group: 1))
        markers.footnotes = unique(matches(in: markdown, pattern: #"\[\^([^\]]+)\]"#, group: 1))
        markers.taskTokens = taskTokens(in: markdown)
        markers.mathExpressions = unique(mathExpressions(in: markdown, blocks: blocks))

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
            readingMinutes: max(1, Int(ceil(Double(words) / 220.0)))
        )
    }

    private static func matches(in text: String, pattern: String, group: Int) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
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

    private static func mathExpressions(in markdown: String, blocks: [MarkdownBlock]) -> [String] {
        var expressions = blocks.compactMap { block -> String? in
            if case let .mathBlock(expression) = block {
                return expression
            }

            return nil
        }

        expressions.append(contentsOf: matches(in: markdown, pattern: #"(?<!\\)\$([^$\n]+)(?<!\\)\$"#, group: 1))

        return expressions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
