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
        markers.images = unique(matches(in: markdown, pattern: #"\!\[([^\]]*)\]\(([^\)]+)\)"#, group: 2))
        markers.tags = unique(matches(in: markdown, pattern: #"(?<!\w)#([A-Za-z0-9_\-/\p{Han}]+)"#, group: 1))
        markers.mentions = unique(matches(in: markdown, pattern: #"(?<!\w)@([A-Za-z0-9_\-\.]+)"#, group: 1))
        markers.footnotes = unique(matches(in: markdown, pattern: #"\[\^([^\]]+)\]"#, group: 1))

        markers.codeLanguages = unique(
            blocks.compactMap { block in
                if case let .codeBlock(language, _) = block {
                    return language?.lowercased()
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
}
