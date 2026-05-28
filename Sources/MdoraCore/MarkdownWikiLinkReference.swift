import Foundation

public struct MarkdownWikiLinkReference: Equatable, Hashable {
    public var rawValue: String
    public var target: String
    public var alias: String?
    public var path: String
    public var heading: String?
    public var blockID: String?

    public var displayText: String {
        alias ?? target
    }

    public var embedDisplayText: String {
        alias ?? fileName
    }

    public var embedPreviewText: String {
        isImageEmbed ? "[image: \(embedDisplayText)]" : "[embed: \(embedDisplayText)]"
    }

    public var fileName: String {
        let source = path.isEmpty ? target : path
        return source.split(separator: "/").last.map(String.init) ?? source
    }

    public var isImageEmbed: Bool {
        let extensionName = fileName.split(separator: ".").last.map { String($0).lowercased() }
        return extensionName.map(Self.imageExtensions.contains) ?? false
    }

    public var inspectorText: String {
        if let alias {
            return "\(alias) -> \(target)"
        }

        return target
    }

    public var markupText: String {
        if let alias {
            return "[[\(target)|\(alias)]]"
        }

        return "[[\(target)]]"
    }

    public init(rawValue: String) {
        self.rawValue = rawValue

        let parts = Self.splitAlias(in: rawValue)
        let target = parts.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let alias = parts.alias?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetParts = Self.splitTarget(target)

        self.target = target
        self.alias = alias?.isEmpty == false ? alias : nil
        self.path = targetParts.path
        self.heading = targetParts.heading
        self.blockID = targetParts.blockID
    }

    public static func parse(_ rawValue: String) -> MarkdownWikiLinkReference {
        MarkdownWikiLinkReference(rawValue: rawValue)
    }

    private static func splitAlias(in rawValue: String) -> (target: String, alias: String?) {
        var isEscaped = false

        for index in rawValue.indices {
            let character = rawValue[index]
            if isEscaped {
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == "|" {
                let aliasStart = rawValue.index(after: index)
                return (
                    unescapePipe(String(rawValue[..<index])),
                    unescapePipe(String(rawValue[aliasStart...]))
                )
            }
        }

        return (unescapePipe(rawValue), nil)
    }

    private static func splitTarget(_ target: String) -> (path: String, heading: String?, blockID: String?) {
        if let hashIndex = target.firstIndex(of: "#") {
            let path = String(target[..<hashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let fragmentStart = target.index(after: hashIndex)
            let fragment = String(target[fragmentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if fragment.hasPrefix("^") {
                let blockID = String(fragment.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                return (path, nil, blockID.isEmpty ? nil : blockID)
            }

            return (path, fragment.isEmpty ? nil : fragment, nil)
        }

        if let caretIndex = target.firstIndex(of: "^") {
            let path = String(target[..<caretIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let blockStart = target.index(after: caretIndex)
            let blockID = String(target[blockStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (path, nil, blockID.isEmpty ? nil : blockID)
        }

        return (target, nil, nil)
    }

    private static func unescapePipe(_ value: String) -> String {
        value.replacingOccurrences(of: "\\|", with: "|")
    }

    private static let imageExtensions: Set<String> = [
        "apng", "avif", "bmp", "gif", "heic", "jpeg", "jpg", "png", "svg", "tif", "tiff", "webp"
    ]
}
