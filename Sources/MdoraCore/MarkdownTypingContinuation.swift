import Foundation

public enum MarkdownTypingContinuation {
    public static func continuation(after linePrefix: String) -> String? {
        let leading = linePrefix.prefix { character in
            character == " " || character == "\t"
        }
        let trimmed = linePrefix.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return nil
        }

        if trimmed == ">" || trimmed == "> " {
            return "\n"
        }

        if trimmed.hasPrefix("> ") {
            return "\n\(leading)> "
        }

        if let taskContinuation = taskListContinuation(trimmed: trimmed, leading: String(leading)) {
            return taskContinuation
        }

        if let bulletContinuation = bulletListContinuation(trimmed: trimmed, leading: String(leading)) {
            return bulletContinuation
        }

        if let orderedContinuation = orderedListContinuation(trimmed: trimmed, leading: String(leading)) {
            return orderedContinuation
        }

        if !leading.isEmpty {
            return "\n\(leading)"
        }

        return nil
    }

    private static func taskListContinuation(trimmed: String, leading: String) -> String? {
        for bullet in ["-", "*", "+"] {
            for checkbox in taskCheckboxes {
                let marker = "\(bullet) \(checkbox)"

                if trimmed == marker {
                    return "\n"
                }

                if trimmed.hasPrefix(marker + " ") {
                    return "\n\(leading)\(bullet) [ ] "
                }
            }
        }

        return nil
    }

    private static func bulletListContinuation(trimmed: String, leading: String) -> String? {
        if ["-", "*", "+"].contains(trimmed) {
            return "\n"
        }

        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            guard trimmed.count > marker.count else {
                return "\n"
            }

            return "\n\(leading)\(marker)"
        }

        return nil
    }

    private static func orderedListContinuation(trimmed: String, leading: String) -> String? {
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }

        let numberPart = trimmed[..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else { return nil }

        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex, trimmed[afterDot] == " " else { return nil }

        let contentStart = trimmed.index(after: afterDot)
        let content = trimmed[contentStart...].trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else {
            return "\n"
        }

        let nextNumber = (Int(numberPart) ?? 0) + 1
        if isTaskListContent(content) {
            return "\n\(leading)\(nextNumber). [ ] "
        }

        return "\n\(leading)\(nextNumber). "
    }

    private static func isTaskListContent(_ content: String) -> Bool {
        guard content.count >= 4,
              content.first == "[",
              content[content.index(content.startIndex, offsetBy: 2)] == "]",
              content[content.index(content.startIndex, offsetBy: 3)] == " " else {
            return false
        }

        let marker = content[content.index(after: content.startIndex)]
        return taskMarkers.contains(marker)
    }

    private static let taskCheckboxes = ["[ ]", "[x]", "[X]", "[/]", "[-]", "[>]", "[!]", "[?]"]
    private static let taskMarkers = Set(" xX/->!?")
}
