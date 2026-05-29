import Foundation

public struct MarkdownSyntaxHighlightRanges: Equatable {
    public var fencedLineRanges: [NSRange]
    public var mathBlockRanges: [NSRange]
    public var codeSpanRanges: [NSRange]
    public var inlineExcludedRanges: [NSRange]

    public init(
        fencedLineRanges: [NSRange],
        mathBlockRanges: [NSRange] = [],
        codeSpanRanges: [NSRange],
        inlineExcludedRanges: [NSRange]
    ) {
        self.fencedLineRanges = fencedLineRanges
        self.mathBlockRanges = mathBlockRanges
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
        let candidateFencedRanges: [NSRange]
        let candidateMathBlockRanges: [NSRange]
        let candidateCodeSpanRanges: [NSRange]

        if let targetRange {
            candidateFencedRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: markdown, intersecting: targetRange)
            candidateMathBlockRanges = MarkdownMathBlockScanner.mathBlockLineRanges(in: markdown, intersecting: targetRange)
            candidateCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: markdown, intersecting: targetRange)
        } else {
            candidateFencedRanges = MarkdownCodeFenceScanner.fencedLineRanges(in: markdown)
            candidateMathBlockRanges = MarkdownMathBlockScanner.mathBlockLineRanges(in: markdown)
            candidateCodeSpanRanges = MarkdownCodeSpanScanner.codeSpanRanges(in: markdown)
        }

        let blockRanges = nonOverlappingBlockRanges(
            fencedRanges: candidateFencedRanges,
            mathBlockRanges: candidateMathBlockRanges
        )
        let fencedRanges = blockRanges.fencedRanges
        let mathBlockRanges = blockRanges.mathBlockRanges

        let codeSpanRanges = candidateCodeSpanRanges.filter { codeSpanRange in
            !(fencedRanges + mathBlockRanges).contains { protectedRange in
                NSIntersectionRange(codeSpanRange, protectedRange).length > 0
            }
        }

        return MarkdownSyntaxHighlightRanges(
            fencedLineRanges: fencedRanges,
            mathBlockRanges: mathBlockRanges,
            codeSpanRanges: codeSpanRanges,
            inlineExcludedRanges: mergedRanges(fencedRanges + mathBlockRanges + codeSpanRanges)
        )
    }

    private static func nonOverlappingBlockRanges(
        fencedRanges: [NSRange],
        mathBlockRanges: [NSRange]
    ) -> (fencedRanges: [NSRange], mathBlockRanges: [NSRange]) {
        let candidates = fencedRanges.map { ProtectedBlockRange(kind: .fence, range: $0) } +
            mathBlockRanges.map { ProtectedBlockRange(kind: .math, range: $0) }
        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.range.location == rhs.range.location {
                if lhs.kind == rhs.kind {
                    return lhs.range.length > rhs.range.length
                }

                return lhs.kind.sortOrder < rhs.kind.sortOrder
            }

            return lhs.range.location < rhs.range.location
        }

        var accepted: [ProtectedBlockRange] = []

        for candidate in sortedCandidates {
            guard !accepted.contains(where: { NSIntersectionRange($0.range, candidate.range).length > 0 }) else {
                continue
            }

            accepted.append(candidate)
        }

        return (
            accepted.compactMap { $0.kind == .fence ? $0.range : nil },
            accepted.compactMap { $0.kind == .math ? $0.range : nil }
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

private struct ProtectedBlockRange {
    enum Kind {
        case fence
        case math

        var sortOrder: Int {
            switch self {
            case .fence:
                0
            case .math:
                1
            }
        }
    }

    var kind: Kind
    var range: NSRange
}

private extension NSRange {
    var upperBound: Int {
        location + length
    }
}
