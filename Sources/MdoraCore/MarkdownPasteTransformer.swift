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

    public static func markdownReplacement(
        fileURL: URL,
        selectedText: String,
        currentDocumentURL: URL?
    ) -> String? {
        guard fileURL.isFileURL, isImageFileURL(fileURL) else { return nil }

        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let altText = selected.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : selected
        let destination = markdownDestination(for: fileURL, currentDocumentURL: currentDocumentURL)

        return "![\(escapeLinkLabel(altText))](\(destination))"
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

    private static func isImageFileURL(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    private static func markdownDestination(for fileURL: URL, currentDocumentURL: URL?) -> String {
        let destinationPath: String
        if let currentDocumentURL, currentDocumentURL.isFileURL {
            destinationPath = relativePath(
                from: currentDocumentURL.deletingLastPathComponent().standardizedFileURL,
                to: fileURL.standardizedFileURL
            )
        } else {
            destinationPath = fileURL.standardizedFileURL.path
        }

        return percentEncodedPath(destinationPath)
    }

    private static func relativePath(from baseDirectoryURL: URL, to fileURL: URL) -> String {
        let baseComponents = baseDirectoryURL.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        var sharedCount = 0

        while sharedCount < baseComponents.count,
              sharedCount < fileComponents.count,
              baseComponents[sharedCount] == fileComponents[sharedCount] {
            sharedCount += 1
        }

        guard sharedCount > 0 else { return fileURL.standardizedFileURL.path }

        let parentSegments = Array(repeating: "..", count: max(0, baseComponents.count - sharedCount))
        let childSegments = fileComponents.dropFirst(sharedCount)
        let relativeComponents = parentSegments + childSegments
        return relativeComponents.isEmpty ? fileURL.lastPathComponent : relativeComponents.joined(separator: "/")
    }

    private static func percentEncodedPath(_ path: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
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
