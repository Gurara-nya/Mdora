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
        let searchRange: NSRange
        if let targetRange {
            searchRange = source.lineRange(for: targetRange).clamped(toLength: source.length)
        } else {
            searchRange = fullRange
        }

        guard let stringRange = Range(searchRange, in: markdown) else { return [] }

        var ranges: [NSRange] = []
        var cursor = stringRange.lowerBound

        while cursor < stringRange.upperBound {
            guard markdown[cursor] == "`" else {
                cursor = markdown.index(after: cursor)
                continue
            }

            let openingRun = backtickRun(in: markdown, at: cursor, upperBound: stringRange.upperBound)
            var closingCursor = openingRun.end
            var matchedRange: NSRange?

            while closingCursor < stringRange.upperBound {
                let character = markdown[closingCursor]
                if isLineBreak(character) {
                    break
                }

                guard character == "`" else {
                    closingCursor = markdown.index(after: closingCursor)
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

    private static func isLineBreak(_ character: Character) -> Bool {
        character == "\n" || character == "\r"
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
