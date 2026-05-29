import Foundation

public struct MarkdownSyntaxHighlightRanges: Equatable {
    public var fencedLineRanges: [NSRange]
    public var codeSpanRanges: [NSRange]
    public var inlineExcludedRanges: [NSRange]

    public init(
        fencedLineRanges: [NSRange],
        codeSpanRanges: [NSRange],
        inlineExcludedRanges: [NSRange]
    ) {
        self.fencedLineRanges = fencedLineRanges
        self.codeSpanRanges = codeSpanRanges
        self.inlineExcludedRanges = inlineExcludedRanges
    }
}

public enum MarkdownSyntaxHighlightScanner {
    public static func ranges(in markdown: String) -> MarkdownSyntaxHighlightRanges {
        ranges(in: markdown, intersecting: nil)
    }

    public static func ranges(
        in markdown: String,
        intersecting targetRange: NSRange?
    ) -> MarkdownSyntaxHighlightRanges {
        let fencedRanges: [NSRange]
        let candidateCodeSpanRanges: [NSRange]

        if let targetRange {
            fencedRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: markdown, intersecting: targetRange)
            candidateCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: markdown, intersecting: targetRange)
        } else {
            fencedRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: markdown)
            candidateCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: markdown)
        }

        let codeSpanRanges = candidateCodeSpanRanges.filter { codeSpanRange in
            !fencedRanges.contains { fencedRange in
                NSIntersectionRange(codeSpanRange, fencedRange).length > 0
            }
        }

        return MarkdownSyntaxHighlightRanges(
            fencedLineRanges: fencedRanges,
            codeSpanRanges: codeSpanRanges,
            inlineExcludedRanges: mergedRanges(fencedRanges + codeSpanRanges)
        )
    }

    private static func mergedRanges(_ ranges: [NSRange]) -> [NSRange] {
        let sortedRanges = ranges
            .filter { $0.location != NSNotFound && $0.length > 0 }
            .sorted {
                if $0.location == $1.location {
                    return $0.length < $1.length
                }
                return $0.location < $1.location
            }

        var merged: [NSRange] = []

        for range in sortedRanges {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }

            if range.location <= last.upperBound {
                merged[merged.count - 1] = NSRange(
                    location: last.location,
                    length: max(last.upperBound, range.upperBound) - last.location
                )
            } else {
                merged.append(range)
            }
        }

        return merged
    }
}

private extension NSRange {
    var upperBound: Int {
        location + length
    }
}
