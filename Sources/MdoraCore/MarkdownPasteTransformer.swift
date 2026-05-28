import Foundation

public enum MarkdownPasteTransformer {
    public static func markdownReplacement(pastedText: String, selectedText: String) -> String? {
        let pasted = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isSingleLine(pasted), isMarkdownURL(pasted) else { return nil }

        if !selected.isEmpty, isSingleLine(selected) {
            let escapedLabel = escapeLinkLabel(selected)
            return isImageURL(pasted) ? "![\(escapedLabel)](\(pasted))" : "[\(escapedLabel)](\(pasted))"
        }

        return isImageURL(pasted) ? "![](\(pasted))" : nil
    }

    private static func isMarkdownURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme) else {
            return false
        }

        if scheme == "mailto" {
            return value.count > "mailto:".count
        }

        return components.host?.isEmpty == false
    }

    private static func isImageURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value) else { return false }
        let pathExtension = (components.path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(pathExtension)
    }

    private static func isSingleLine(_ value: String) -> Bool {
        !value.contains("\n") && !value.contains("\r")
    }

    private static func escapeLinkLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static let imageExtensions: Set<String> = [
        "apng", "avif", "bmp", "gif", "heic", "jpeg", "jpg", "png", "svg", "tif", "tiff", "webp"
    ]
}
