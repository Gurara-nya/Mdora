import Foundation

public struct MarkdownAutoLinkMatch: Equatable {
    public var url: String
    public var range: NSRange

    public init(url: String, range: NSRange) {
        self.url = url
        self.range = range
    }
}

public enum MarkdownAutoLinkScanner {
    public static func autoLinks(in markdown: String) -> [MarkdownAutoLinkMatch] {
        scanAutoLinks(in: markdown, intersecting: nil)
    }

    public static func autoLinks(in markdown: String, intersecting targetRange: NSRange) -> [MarkdownAutoLinkMatch] {
        scanAutoLinks(in: markdown, intersecting: targetRange)
    }

    static func rawAutoLink(
        in text: String,
        at index: String.Index
    ) -> (url: String, end: String.Index)? {
        guard text[index...].hasPrefix("http://") || text[index...].hasPrefix("https://") else {
            return nil
        }
        guard isBoundaryBefore(index, in: text) else { return nil }

        var cursor = index
        var parenthesisDepth = 0

        while cursor < text.endIndex {
            let character = text[cursor]

            if character.isWhitespace || character == "<" {
                break
            }

            if character == ")" {
                guard parenthesisDepth > 0 else { break }
                parenthesisDepth -= 1
                cursor = text.index(after: cursor)
                continue
            }

            if character == "(" {
                parenthesisDepth += 1
            }

            cursor = text.index(after: cursor)
        }

        var urlEnd = cursor
        while urlEnd > index {
            let previous = text.index(before: urlEnd)
            let character = text[previous]

            if trailingPunctuation.contains(character) {
                urlEnd = previous
                continue
            }

            if character == "(", parenthesisDepth > 0 {
                parenthesisDepth -= 1
                urlEnd = previous
                continue
            }

            break
        }

        guard urlEnd > index else { return nil }
        let url = String(text[index ..< urlEnd])
        let minimumLength = text[index...].hasPrefix("https://") ? "https://".count : "http://".count
        guard url.count > minimumLength else { return nil }
        return (url, urlEnd)
    }

    private static func scanAutoLinks(
        in markdown: String,
        intersecting targetRange: NSRange?
    ) -> [MarkdownAutoLinkMatch] {
        let source = markdown as NSString
        let targetRange = targetRange?.clamped(toLength: source.length)
        var matches: [MarkdownAutoLinkMatch] = []
        var cursor = searchStartIndex(in: markdown, source: source, targetRange: targetRange)

        while cursor < markdown.endIndex {
            if let targetRange {
                let location = NSRange(cursor ..< cursor, in: markdown).location
                if location >= targetRange.upperBound {
                    break
                }
            }

            guard let match = rawAutoLink(in: markdown, at: cursor) else {
                cursor = markdown.index(after: cursor)
                continue
            }

            let range = NSRange(cursor ..< match.end, in: markdown)
            if let targetRange {
                if NSIntersectionRange(range, targetRange).length > 0 {
                    matches.append(MarkdownAutoLinkMatch(url: match.url, range: range))
                }
            } else {
                matches.append(MarkdownAutoLinkMatch(url: match.url, range: range))
            }

            cursor = match.end
        }

        return matches
    }

    private static func searchStartIndex(
        in markdown: String,
        source: NSString,
        targetRange: NSRange?
    ) -> String.Index {
        guard let targetRange, targetRange.location > 0 else {
            return markdown.startIndex
        }

        let lowerBound = max(0, targetRange.location - 4096)
        var location = targetRange.location

        while location > lowerBound {
            let character = source.character(at: location - 1)
            if character == 9 || character == 10 || character == 13 || character == 32 || character == 60 {
                break
            }

            location -= 1
        }

        return Range(NSRange(location: location, length: 0), in: markdown)?.lowerBound ?? markdown.startIndex
    }

    private static func isBoundaryBefore(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return !previous.isAutoLinkBoundaryCharacter
    }

    private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?"]
}

private extension Character {
    var isAutoLinkBoundaryCharacter: Bool {
        if isLetter || isNumber {
            return true
        }

        return self == "_" || self == "-" || self == "/" || self == "."
    }
}

private extension NSRange {
    var upperBound: Int {
        location + length
    }

    func clamped(toLength length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let safeLocation = min(max(0, location), length)
        let safeUpperBound = min(max(safeLocation, upperBound), length)
        return NSRange(location: safeLocation, length: safeUpperBound - safeLocation)
    }
}
