import Foundation

public enum MarkdownCodeFenceScanner {
    public static func delimiter(in line: String) -> MarkdownCodeFenceDelimiter? {
        let line = line.trimmingCharacters(in: .newlines)
        var cursor = line.startIndex
        var leadingSpaces = 0

        while cursor < line.endIndex, line[cursor] == " " {
            leadingSpaces += 1
            guard leadingSpaces <= 3 else { return nil }
            cursor = line.index(after: cursor)
        }

        guard cursor < line.endIndex else { return nil }
        let marker = line[cursor]
        guard marker == "`" || marker == "~" else { return nil }

        var length = 0
        while cursor < line.endIndex, line[cursor] == marker {
            length += 1
            cursor = line.index(after: cursor)
        }

        guard length >= 3 else { return nil }
        let info = String(line[cursor...])
        let trimmedInfo = info.trimmingCharacters(in: .whitespacesAndNewlines)
        if marker == "`", trimmedInfo.contains("`") {
            return nil
        }

        return MarkdownCodeFenceDelimiter(
            marker: marker,
            length: length,
            info: trimmedInfo,
            canClose: trimmedInfo.isEmpty,
            leadingSpaces: leadingSpaces
        )
    }

    public static func isClosingDelimiter(
        _ delimiter: MarkdownCodeFenceDelimiter,
        for openingDelimiter: MarkdownCodeFenceDelimiter
    ) -> Bool {
        delimiter.marker == openingDelimiter.marker &&
            delimiter.length >= openingDelimiter.length &&
            delimiter.canClose
    }

    public static func fencedLineRanges(in markdown: String) -> [NSRange] {
        scanFencedLineRanges(in: markdown, intersecting: nil)
    }

    public static func fencedLineRanges(in markdown: String, intersecting targetRange: NSRange) -> [NSRange] {
        scanFencedLineRanges(in: markdown, intersecting: targetRange)
    }

    private static func scanFencedLineRanges(in markdown: String, intersecting targetRange: NSRange?) -> [NSRange] {
        let source = markdown as NSString
        guard source.length > 0 else { return [] }

        let targetRange = targetRange?.clamped(toLength: source.length)
        let targetUpperBound = targetRange?.upperBound ?? source.length
        var ranges: [NSRange] = []
        var cursor = 0
        var openFence: Fence?

        while cursor < source.length {
            if targetRange != nil,
               cursor >= targetUpperBound,
               openFence == nil {
                break
            }

            let lineRange = source.lineRange(for: NSRange(location: cursor, length: 0))
            let line = source.substring(with: lineRange)

            if let candidate = delimiter(in: line) {
                if let open = openFence,
                   isClosingDelimiter(candidate, for: open.delimiter) {
                    appendFenceRange(
                        NSRange(location: open.location, length: lineRange.upperBound - open.location),
                        intersecting: targetRange,
                        to: &ranges
                    )
                    openFence = nil
                } else if openFence == nil {
                    openFence = Fence(
                        delimiter: candidate,
                        location: lineRange.location
                    )
                }
            }

            let nextCursor = lineRange.upperBound
            guard nextCursor > cursor else { break }
            cursor = nextCursor
        }

        if let openFence {
            appendFenceRange(
                NSRange(location: openFence.location, length: source.length - openFence.location),
                intersecting: targetRange,
                to: &ranges
            )
        }

        return ranges
    }

    private static func appendFenceRange(
        _ range: NSRange,
        intersecting targetRange: NSRange?,
        to ranges: inout [NSRange]
    ) {
        guard let targetRange else {
            ranges.append(range)
            return
        }

        if NSIntersectionRange(range, targetRange).length > 0 {
            ranges.append(range)
        }
    }
}

public struct MarkdownCodeFenceDelimiter: Equatable {
    public var marker: Character
    public var length: Int
    public var info: String
    public var canClose: Bool
    public var leadingSpaces: Int
    public var language: String? {
        info.split { $0.isWhitespace || $0.isNewline }.first.map(String.init)
    }

    public init(
        marker: Character,
        length: Int,
        info: String,
        canClose: Bool,
        leadingSpaces: Int = 0
    ) {
        self.marker = marker
        self.length = length
        self.info = info
        self.canClose = canClose
        self.leadingSpaces = leadingSpaces
    }
}

private struct Fence {
    var delimiter: MarkdownCodeFenceDelimiter
    var location: Int
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
