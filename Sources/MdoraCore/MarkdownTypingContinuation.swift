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

        if exitsContainerOnReturn(after: linePrefix) {
            return "\n"
        }

        if let quoteContinuation = blockquoteContinuation(trimmed: trimmed, leading: String(leading)) {
            return quoteContinuation
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

    public static func exitsContainerOnReturn(after linePrefix: String) -> Bool {
        let trimmed = linePrefix.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return isEmptyContainerMarker(trimmed)
    }

    private static func isEmptyContainerMarker(_ trimmed: String) -> Bool {
        if trimmed == ">" {
            return true
        }

        if trimmed.hasPrefix(">") {
            let quoted = removingLeadingQuoteMarkers(from: trimmed)
            return quoted.isEmpty || isEmptyContainerMarker(quoted)
        }

        if ["-", "*", "+"].contains(trimmed) {
            return true
        }

        for bullet in ["-", "*", "+"] {
            for checkbox in taskCheckboxes where trimmed == "\(bullet) \(checkbox)" {
                return true
            }
        }

        return isEmptyOrderedContainerMarker(trimmed)
    }

    private static func removingLeadingQuoteMarkers(from text: String) -> String {
        var cursor = text.startIndex

        while cursor < text.endIndex, text[cursor] == ">" {
            cursor = text.index(after: cursor)
            if cursor < text.endIndex, text[cursor] == " " {
                cursor = text.index(after: cursor)
            }
        }

        return String(text[cursor...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isEmptyOrderedContainerMarker(_ trimmed: String) -> Bool {
        guard let delimiterIndex = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return false
        }

        let numberPart = trimmed[..<delimiterIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else { return false }

        let afterDelimiter = trimmed.index(after: delimiterIndex)
        guard afterDelimiter == trimmed.endIndex || trimmed[afterDelimiter] == " " else { return false }

        let content = String(trimmed[afterDelimiter...]).trimmingCharacters(in: .whitespaces)
        return content.isEmpty || taskCheckboxes.contains(content)
    }

    private static func blockquoteContinuation(trimmed: String, leading: String) -> String? {
        guard trimmed.hasPrefix("> ") else { return nil }

        let quoteMarker = "\(leading)> "
        let quotedStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let quoted = String(trimmed[quotedStart...])

        guard !quoted.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "\n\(quoteMarker)"
        }

        if let nestedContinuation = continuation(after: quoted),
           nestedContinuation.hasPrefix("\n") {
            return "\n\(quoteMarker)\(nestedContinuation.dropFirst())"
        }

        return "\n\(quoteMarker)"
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
        guard let delimiterIndex = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }

        let numberPart = trimmed[..<delimiterIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else { return nil }

        let delimiter = trimmed[delimiterIndex]
        let afterDelimiter = trimmed.index(after: delimiterIndex)
        guard afterDelimiter < trimmed.endIndex, trimmed[afterDelimiter] == " " else { return nil }

        let contentStart = trimmed.index(after: afterDelimiter)
        let content = trimmed[contentStart...].trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else {
            return "\n"
        }

        let nextNumber = (Int(numberPart) ?? 0) + 1
        if isTaskListContent(content) {
            return "\n\(leading)\(nextNumber)\(delimiter) [ ] "
        }

        return "\n\(leading)\(nextNumber)\(delimiter) "
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
