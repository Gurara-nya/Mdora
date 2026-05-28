import Foundation

enum MarkdownAssetResolver {
    static func remoteURL(for source: String) -> URL? {
        guard let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        return url
    }

    static func localFileURL(for source: String, relativeTo baseURL: URL?) -> URL? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           !scheme.isEmpty {
            return scheme == "file" ? url.standardizedFileURL : nil
        }

        let path = trimmed.removingPercentEncoding ?? trimmed
        if path.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        guard let baseURL else { return nil }
        return baseURL.appendingPathComponent(path).standardizedFileURL
    }
}
