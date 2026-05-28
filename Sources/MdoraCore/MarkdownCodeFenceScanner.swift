import Foundation

public enum MarkdownCodeFenceScanner {
    public static func fencedLineRanges(in markdown: String) -> [NSRange] {
        let source = markdown as NSString
        guard source.length > 0 else { return [] }

        var ranges: [NSRange] = []
        var cursor = 0
        var openFence: Fence?

        while cursor < source.length {
            let lineRange = source.lineRange(for: NSRange(location: cursor, length: 0))
            let line = source.substring(with: lineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let candidate = fenceCandidate(in: line) {
                if let open = openFence,
                   candidate.marker == open.marker,
                   candidate.length >= open.length,
                   candidate.canClose {
                    ranges.append(NSRange(location: open.location, length: lineRange.upperBound - open.location))
                    openFence = nil
                } else if openFence == nil {
                    openFence = Fence(
                        marker: candidate.marker,
                        length: candidate.length,
                        location: lineRange.location
                    )
                }
            }

            let nextCursor = lineRange.upperBound
            guard nextCursor > cursor else { break }
            cursor = nextCursor
        }

        if let openFence {
            ranges.append(NSRange(location: openFence.location, length: source.length - openFence.location))
        }

        return ranges
    }

    private static func fenceCandidate(in trimmedLine: String) -> FenceCandidate? {
        guard let marker = trimmedLine.first, marker == "`" || marker == "~" else { return nil }

        var cursor = trimmedLine.startIndex
        var length = 0
        while cursor < trimmedLine.endIndex, trimmedLine[cursor] == marker {
            length += 1
            cursor = trimmedLine.index(after: cursor)
        }

        guard length >= 3 else { return nil }
        let rest = String(trimmedLine[cursor...])
        return FenceCandidate(
            marker: marker,
            length: length,
            canClose: rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

private struct Fence {
    var marker: Character
    var length: Int
    var location: Int
}

private struct FenceCandidate {
    var marker: Character
    var length: Int
    var canClose: Bool
}
