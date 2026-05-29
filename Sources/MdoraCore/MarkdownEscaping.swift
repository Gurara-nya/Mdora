import Foundation

public enum MarkdownEscaping {
    public static func unescaped(_ text: String) -> String {
        var result = ""
        var cursor = text.startIndex

        while cursor < text.endIndex {
            if text[cursor] == "\\" {
                let next = text.index(after: cursor)
                if next < text.endIndex, isEscapable(text[next]) {
                    result.append(text[next])
                    cursor = text.index(after: next)
                    continue
                }
            }

            result.append(text[cursor])
            cursor = text.index(after: cursor)
        }

        return result
    }

    public static func isEscapable(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return markdownEscapeCharacters.contains(scalar)
    }

    public static func isEscaped(_ index: String.Index, in text: String) -> Bool {
        var cursor = index
        var slashCount = 0

        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous] == "\\" else { break }
            slashCount += 1
            cursor = previous
        }

        return slashCount % 2 == 1
    }

    private static let markdownEscapeCharacters = CharacterSet(charactersIn: "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
}
