import Foundation

public enum MarkdownCodeSpanScanner {
    public static func codeSpanRanges(in markdown: String) -> [NSRange] {
        scanCodeSpanRanges(in: markdown, intersecting: nil)
    }

    public static func codeSpanRanges(in markdown: String, intersecting targetRange: NSRange) -> [NSRange] {
        scanCodeSpanRanges(in: markdown, intersecting: targetRange)
    }

    private static func scanCodeSpanRanges(in markdown: String, intersecting targetRange: NSRange?) -> [NSRange] {
        let source = markdown as NSString
        guard source.length > 0 else { return [] }

        let fullRange = NSRange(location: 0, length: source.length)
        let targetRange = targetRange?.clamped(toLength: source.length)
        let searchRange = codeSpanSearchRange(in: source, targetRange: targetRange, fullRange: fullRange)

        guard let stringRange = Range(searchRange, in: markdown) else { return [] }

        var ranges: [NSRange] = []
        var cursor = stringRange.lowerBound

        while cursor < stringRange.upperBound {
            guard markdown[cursor] == "`" else {
                cursor = markdown.index(after: cursor)
                continue
            }

            if isCodeFenceDelimiterRun(at: cursor, in: markdown, source: source) {
                cursor = backtickRun(in: markdown, at: cursor, upperBound: stringRange.upperBound).end
                continue
            }

            let openingRun = backtickRun(in: markdown, at: cursor, upperBound: stringRange.upperBound)
            var closingCursor = openingRun.end
            var matchedRange: NSRange?

            while closingCursor < stringRange.upperBound {
                guard markdown[closingCursor] == "`" else {
                    closingCursor = markdown.index(after: closingCursor)
                    continue
                }

                if isCodeFenceDelimiterRun(at: closingCursor, in: markdown, source: source) {
                    closingCursor = backtickRun(in: markdown, at: closingCursor, upperBound: stringRange.upperBound).end
                    continue
                }

                let closingRun = backtickRun(in: markdown, at: closingCursor, upperBound: stringRange.upperBound)
                if closingRun.count == openingRun.count {
                    matchedRange = NSRange(cursor ..< closingRun.end, in: markdown)
                    cursor = closingRun.end
                    break
                }

                closingCursor = closingRun.end
            }

            if let matchedRange {
                appendCodeSpanRange(matchedRange, intersecting: targetRange, to: &ranges)
            } else {
                cursor = openingRun.end
            }
        }

        return ranges
    }

    private static func codeSpanSearchRange(
        in source: NSString,
        targetRange: NSRange?,
        fullRange: NSRange
    ) -> NSRange {
        guard let targetRange else { return fullRange }

        let clampedTarget = targetRange.clamped(toLength: source.length)
        var searchRange = source.lineRange(for: clampedTarget).clamped(toLength: source.length)

        while searchRange.location > 0 {
            let previousLineRange = source.lineRange(
                for: NSRange(location: max(0, searchRange.location - 1), length: 0)
            )
            let previousLine = source.substring(with: previousLineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !previousLine.isEmpty else { break }
            searchRange = NSUnionRange(searchRange, previousLineRange)
        }

        while searchRange.upperBound < source.length {
            let nextLineRange = source.lineRange(for: NSRange(location: searchRange.upperBound, length: 0))
            let nextLine = source.substring(with: nextLineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nextLine.isEmpty else { break }
            searchRange = NSUnionRange(searchRange, nextLineRange)
        }

        return searchRange.clamped(toLength: source.length)
    }

    private static func backtickRun(
        in markdown: String,
        at start: String.Index,
        upperBound: String.Index
    ) -> (count: Int, end: String.Index) {
        var cursor = start
        var count = 0

        while cursor < upperBound, markdown[cursor] == "`" {
            count += 1
            cursor = markdown.index(after: cursor)
        }

        return (count, cursor)
    }

    private static func isCodeFenceDelimiterRun(
        at index: String.Index,
        in markdown: String,
        source: NSString
    ) -> Bool {
        let location = NSRange(index ..< index, in: markdown).location
        let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
        let line = source.substring(with: lineRange)
        guard MarkdownCodeFenceScanner.delimiter(in: line) != nil else { return false }

        var markerOffset = 0
        while markerOffset < lineRange.length,
              markerOffset < 4,
              source.character(at: lineRange.location + markerOffset) == 32 {
            markerOffset += 1
        }

        return lineRange.location + markerOffset == location
    }

    private static func appendCodeSpanRange(
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
