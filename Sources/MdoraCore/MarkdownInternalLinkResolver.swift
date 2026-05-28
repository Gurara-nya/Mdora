import Foundation

public enum MarkdownInternalLinkResolver {
    public static func indexForAnchor(_ anchor: String, in blocks: [MarkdownBlock]) -> Int? {
        let normalizedAnchor = anchor.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAnchor.isEmpty else { return nil }

        for (index, block) in blocks.enumerated() {
            if blockContainsAnchor(block, anchor: normalizedAnchor) {
                return index
            }
        }

        return nil
    }

    public static func indexForWikiTarget(
        _ target: String,
        in blocks: [MarkdownBlock],
        currentDocumentURL: URL? = nil
    ) -> Int? {
        let reference = MarkdownWikiLinkReference.parse(target)
        guard isSameDocumentReference(reference, currentDocumentURL: currentDocumentURL) else {
            return nil
        }

        if let blockID = reference.blockID,
           let index = indexForAnchor(blockID, in: blocks) {
            return index
        }

        if let heading = reference.heading,
           let index = indexForHeading(heading, in: blocks) {
            return index
        }

        let searchTerm = reference.path.isEmpty ? reference.displayText : reference.fileName
        return indexForSearchTerm(searchTerm, in: blocks)
    }

    public static func fileURLForWikiTarget(
        _ target: String,
        currentDocumentURL: URL?,
        fileManager: FileManager = .default
    ) -> URL? {
        let reference = MarkdownWikiLinkReference.parse(target)
        guard !reference.path.isEmpty,
              !isSameDocumentReference(reference, currentDocumentURL: currentDocumentURL),
              let currentDocumentURL else {
            return nil
        }

        let baseURL = currentDocumentURL.deletingLastPathComponent()
        let unresolvedURL = unresolvedFileURL(for: reference.path, relativeTo: baseURL)

        for candidate in fileCandidates(for: unresolvedURL) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                continue
            }

            return candidate.standardizedFileURL
        }

        return nil
    }

    public static func indexForFootnote(_ identifier: String, in blocks: [MarkdownBlock]) -> Int? {
        let normalizedIdentifier = identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedIdentifier.isEmpty else { return nil }

        return blocks.firstIndex { block in
            if case let .footnoteDefinition(identifier, _) = block {
                return identifier.lowercased() == normalizedIdentifier
            }

            return false
        }
    }

    public static func indexForTag(_ tag: String, in blocks: [MarkdownBlock]) -> Int? {
        indexForSearchTerm("#\(tag)", in: blocks)
    }

    public static func indexForMention(_ mention: String, in blocks: [MarkdownBlock]) -> Int? {
        indexForSearchTerm("@\(mention)", in: blocks)
    }

    public static func indexForSearchTerm(_ term: String, in blocks: [MarkdownBlock]) -> Int? {
        for (index, block) in blocks.enumerated() {
            if blockContainsTerm(block, term: term) {
                return index
            }
        }

        return nil
    }

    private static func indexForHeading(_ heading: String, in blocks: [MarkdownBlock]) -> Int? {
        let normalizedHeading = heading.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let anchor = headingAnchor(for: heading)

        return blocks.firstIndex { block in
            if case let .heading(_, text, blockAnchor) = block {
                return text.lowercased() == normalizedHeading || blockAnchor.lowercased() == anchor
            }

            return false
        }
    }

    private static func blockContainsAnchor(_ block: MarkdownBlock, anchor: String) -> Bool {
        switch block {
        case let .heading(_, _, blockAnchor):
            return blockAnchor.lowercased() == anchor
        case let .paragraph(text):
            return MarkdownBlockIDParser.trailingIdentifier(in: text)?.lowercased() == anchor
        case let .blockquote(blocks, _):
            return blocks.contains { blockContainsAnchor($0, anchor: anchor) }
        case let .unorderedList(items), let .orderedList(items):
            return items.contains {
                MarkdownBlockIDParser.trailingIdentifier(in: $0.text)?.lowercased() == anchor
            }
        case let .taskList(items):
            return items.contains {
                MarkdownBlockIDParser.trailingIdentifier(in: $0.text)?.lowercased() == anchor
            }
        default:
            return false
        }
    }

    private static func blockContainsTerm(_ block: MarkdownBlock, term: String) -> Bool {
        let lowerTerm = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowerTerm.isEmpty else { return false }

        switch block {
        case .frontMatter(let fm):
            return fm.lines.contains { $0.lowercased().contains(lowerTerm) }
        case .heading(_, let text, let anchor):
            return text.lowercased().contains(lowerTerm) || anchor.lowercased().contains(lowerTerm)
        case .paragraph(let text):
            return text.lowercased().contains(lowerTerm)
        case .blockquote(let subBlocks, _):
            return subBlocks.contains { blockContainsTerm($0, term: term) }
        case .unorderedList(let items), .orderedList(let items):
            return items.contains { $0.text.lowercased().contains(lowerTerm) }
        case .taskList(let items):
            return items.contains { $0.text.lowercased().contains(lowerTerm) }
        case .codeBlock(let lang, let code):
            return (lang?.lowercased().contains(lowerTerm) ?? false) || code.lowercased().contains(lowerTerm)
        case .diagram(let diag):
            return diag.kind.rawValue.lowercased().contains(lowerTerm) || diag.source.lowercased().contains(lowerTerm)
        case .mathBlock(let expr):
            return expr.lowercased().contains(lowerTerm)
        case .table(let table):
            return table.headers.contains { $0.lowercased().contains(lowerTerm) } ||
                   table.rows.contains { row in
                       row.contains { $0.lowercased().contains(lowerTerm) }
                   }
        case .definitionList(let defs):
            return defs.contains { definition in
                definition.term.lowercased().contains(lowerTerm) ||
                definition.definitions.contains { $0.lowercased().contains(lowerTerm) }
            }
        case .linkReferenceDefinition(let def):
            return def.label.lowercased().contains(lowerTerm) ||
                   def.destination.lowercased().contains(lowerTerm) ||
                   (def.title?.lowercased().contains(lowerTerm) ?? false)
        case .abbreviationDefinition(let abbr):
            return abbr.term.lowercased().contains(lowerTerm) ||
                   abbr.expansion.lowercased().contains(lowerTerm)
        case .image(let alt, let url, let title):
            return alt.lowercased().contains(lowerTerm) ||
                   url.lowercased().contains(lowerTerm) ||
                   (title?.lowercased().contains(lowerTerm) ?? false)
        case .footnoteDefinition(let identifier, let text):
            return identifier.lowercased().contains(lowerTerm) || text.lowercased().contains(lowerTerm)
        case .thematicBreak, .htmlComment, .html:
            return false
        }
    }

    private static func isSameDocumentReference(
        _ reference: MarkdownWikiLinkReference,
        currentDocumentURL: URL?
    ) -> Bool {
        guard !reference.path.isEmpty else { return true }
        guard let currentDocumentURL else { return false }

        let referenceName = URL(fileURLWithPath: reference.path).lastPathComponent.lowercased()
        let referenceStem = (referenceName as NSString).deletingPathExtension.lowercased()
        let documentName = currentDocumentURL.lastPathComponent.lowercased()
        let documentStem = currentDocumentURL.deletingPathExtension().lastPathComponent.lowercased()

        return referenceName == documentName || referenceName == documentStem || referenceStem == documentStem
    }

    private static func unresolvedFileURL(for path: String, relativeTo baseURL: URL) -> URL {
        let path = path.removingPercentEncoding ?? path
        if path.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        return baseURL.appendingPathComponent(path)
    }

    private static func fileCandidates(for url: URL) -> [URL] {
        guard url.pathExtension.isEmpty else { return [url] }

        return [
            url,
            url.appendingPathExtension("md"),
            url.appendingPathExtension("markdown"),
            url.appendingPathExtension("mdown")
        ]
    }

    private static func headingAnchor(for text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = text.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(filtered)
            .lowercased()
            .split(separator: " ")
            .joined(separator: "-")
            .replacingOccurrences(of: "--", with: "-")

        return slug.isEmpty ? "section" : slug
    }
}
