import Foundation

public enum MarkdownMathBlockScanner {
    public static func mathBlockLineRanges(in markdown: String) -> [NSRange] {
        scanMathBlockLineRanges(in: markdown, intersecting: nil)
    }

    public static func mathBlockLineRanges(in markdown: String, intersecting targetRange: NSRange) -> [NSRange] {
        scanMathBlockLineRanges(in: markdown, intersecting: targetRange)
    }

    public static func delimiter(in line: String) -> MarkdownMathBlockDelimiter? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == "$$" {
            return MarkdownMathBlockDelimiter(kind: .dollar, canOpen: true, canClose: true, isSingleLine: false)
        }

        if trimmed.hasPrefix("$$") {
            let isSingleLine = trimmed.count > 2 && trimmed.hasSuffix("$$")
            return MarkdownMathBlockDelimiter(kind: .dollar, canOpen: !isSingleLine, canClose: false, isSingleLine: isSingleLine)
        }

        if trimmed == "\\]" {
            return MarkdownMathBlockDelimiter(kind: .bracket, canOpen: false, canClose: true, isSingleLine: false)
        }

        if trimmed.hasPrefix("\\[") {
            let isSingleLine = trimmed.count > 2 && trimmed.hasSuffix("\\]")
            return MarkdownMathBlockDelimiter(kind: .bracket, canOpen: !isSingleLine, canClose: false, isSingleLine: isSingleLine)
        }

        return nil
    }

    private static func scanMathBlockLineRanges(in markdown: String, intersecting targetRange: NSRange?) -> [NSRange] {
        let source = markdown as NSString
        guard source.length > 0 else { return [] }

        let targetRange = targetRange?.clamped(toLength: source.length)
        let targetUpperBound = targetRange?.upperBound ?? source.length
        var ranges: [NSRange] = []
        var cursor = 0
        var openBlock: MathBlock?

        while cursor < source.length {
            if targetRange != nil,
               cursor >= targetUpperBound,
               openBlock == nil {
                break
            }

            let lineRange = source.lineRange(for: NSRange(location: cursor, length: 0))
            let line = source.substring(with: lineRange)

            if let delimiter = delimiter(in: line) {
                if delimiter.isSingleLine {
                    appendMathBlockRange(lineRange, intersecting: targetRange, to: &ranges)
                } else if let open = openBlock,
                          delimiter.canClose,
                          delimiter.kind == open.delimiter.kind {
                    appendMathBlockRange(
                        NSRange(location: open.location, length: lineRange.upperBound - open.location),
                        intersecting: targetRange,
                        to: &ranges
                    )
                    openBlock = nil
                } else if openBlock == nil, delimiter.canOpen {
                    openBlock = MathBlock(delimiter: delimiter, location: lineRange.location)
                }
            }

            let nextCursor = lineRange.upperBound
            guard nextCursor > cursor else { break }
            cursor = nextCursor
        }

        if let openBlock {
            appendMathBlockRange(
                NSRange(location: openBlock.location, length: source.length - openBlock.location),
                intersecting: targetRange,
                to: &ranges
            )
        }

        return ranges
    }

    private static func appendMathBlockRange(
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

public struct MarkdownMathBlockDelimiter: Equatable {
    public enum Kind: Equatable {
        case dollar
        case bracket
    }

    public var kind: Kind
    public var canOpen: Bool
    public var canClose: Bool
    public var isSingleLine: Bool

    public init(kind: Kind, canOpen: Bool, canClose: Bool, isSingleLine: Bool) {
        self.kind = kind
        self.canOpen = canOpen
        self.canClose = canClose
        self.isSingleLine = isSingleLine
    }
}

private struct MathBlock {
    var delimiter: MarkdownMathBlockDelimiter
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
