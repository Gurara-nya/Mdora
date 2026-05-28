import Foundation

public enum MarkdownTaskSourceEditor {
    public static func updatingTaskState(
        in markdown: String,
        document: ParsedMarkdownDocument,
        blockIndex: Int,
        itemIndex: Int,
        to state: TaskState
    ) -> String? {
        guard document.blocks.indices.contains(blockIndex),
              case let .taskList(items) = document.blocks[blockIndex],
              items.indices.contains(itemIndex),
              let markerRange = taskMarkerRange(
                in: markdown,
                document: document,
                blockIndex: blockIndex,
                itemIndex: itemIndex
              ) else {
            return nil
        }

        let updated = NSMutableString(string: markdown)
        updated.replaceCharacters(in: markerRange, with: state.marker)
        return String(updated)
    }

    private static func taskMarkerRange(
        in markdown: String,
        document: ParsedMarkdownDocument,
        blockIndex: Int,
        itemIndex: Int
    ) -> NSRange? {
        guard let blockRange = document.sourceRange(forBlockIndex: blockIndex) else { return nil }

        let string = markdown as NSString
        var lineNumber = 1
        var location = 0
        var taskIndex = 0

        while location < string.length {
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))

            if lineNumber >= blockRange.startLine && lineNumber <= blockRange.endLine {
                let line = string.substring(with: lineRange)
                if let markerOffset = taskMarkerOffset(in: line) {
                    if taskIndex == itemIndex {
                        return NSRange(location: lineRange.location + markerOffset, length: 1)
                    }
                    taskIndex += 1
                }
            }

            if lineNumber > blockRange.endLine {
                break
            }

            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation > location else { break }
            location = nextLocation
            lineNumber += 1
        }

        return nil
    }

    private static func taskMarkerOffset(in line: String) -> Int? {
        let line = line as NSString
        var offset = 0

        while offset < line.length && line.character(at: offset) == CharacterCode.space {
            offset += 1
        }

        guard offset < line.length else { return nil }

        let contentOffset: Int
        if isUnorderedMarkerStart(line.character(at: offset)) {
            guard offset + 1 < line.length,
                  line.character(at: offset + 1) == CharacterCode.space else {
                return nil
            }
            contentOffset = offset + 2
        } else {
            var digitEnd = offset
            while digitEnd < line.length && isDigit(line.character(at: digitEnd)) {
                digitEnd += 1
            }

            guard digitEnd > offset,
                  digitEnd + 1 < line.length,
                  line.character(at: digitEnd) == CharacterCode.period,
                  line.character(at: digitEnd + 1) == CharacterCode.space else {
                return nil
            }
            contentOffset = digitEnd + 2
        }

        guard contentOffset + 3 < line.length,
              line.character(at: contentOffset) == CharacterCode.openBracket,
              line.character(at: contentOffset + 2) == CharacterCode.closeBracket,
              line.character(at: contentOffset + 3) == CharacterCode.space else {
            return nil
        }

        return contentOffset + 1
    }

    private static func isUnorderedMarkerStart(_ value: unichar) -> Bool {
        value == CharacterCode.hyphen || value == CharacterCode.asterisk || value == CharacterCode.plus
    }

    private static func isDigit(_ value: unichar) -> Bool {
        value >= CharacterCode.zero && value <= CharacterCode.nine
    }
}

private enum CharacterCode {
    static let space = " ".utf16.first!
    static let period = ".".utf16.first!
    static let hyphen = "-".utf16.first!
    static let asterisk = "*".utf16.first!
    static let plus = "+".utf16.first!
    static let openBracket = "[".utf16.first!
    static let closeBracket = "]".utf16.first!
    static let zero = "0".utf16.first!
    static let nine = "9".utf16.first!
}
