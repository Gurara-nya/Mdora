import Foundation

public struct MarkdownBlockID: Equatable, Hashable {
    public var content: String
    public var identifier: String

    public init(content: String, identifier: String) {
        self.content = content
        self.identifier = identifier
    }
}

public enum MarkdownBlockIDParser {
    public static func splitTrailingIdentifier(in text: String) -> MarkdownBlockID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let caretIndex = trimmed.lastIndex(of: "^"),
              caretIndex != trimmed.startIndex else {
            return nil
        }

        let identifierStart = trimmed.index(after: caretIndex)
        guard identifierStart < trimmed.endIndex else { return nil }

        let contentPart = String(trimmed[..<caretIndex])
        guard contentPart.last?.isWhitespace == true else { return nil }

        let identifier = String(trimmed[identifierStart...])
        guard isValidIdentifier(identifier) else { return nil }

        let content = contentPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        return MarkdownBlockID(content: content, identifier: identifier)
    }

    public static func contentWithoutTrailingIdentifier(_ text: String) -> String {
        splitTrailingIdentifier(in: text)?.content ?? text
    }

    public static func trailingIdentifier(in text: String) -> String? {
        splitTrailingIdentifier(in: text)?.identifier
    }

    public static func stripTrailingIdentifierFromLastLine(_ lines: [String]) -> (lines: [String], identifier: String?) {
        guard let lastIndex = lines.indices.last,
              let blockID = splitTrailingIdentifier(in: lines[lastIndex]) else {
            return (lines, nil)
        }

        var stripped = lines
        stripped[lastIndex] = blockID.content
        return (stripped, blockID.identifier)
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy(allowedCharacters.contains)
    }

    private static let allowedCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_-:."))
}
