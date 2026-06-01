import Foundation

public struct MarkdownDiagramGraph: Equatable {
    public var kind: DiagramKind
    public var direction: MarkdownDiagramDirection
    public var nodes: [MarkdownDiagramNode]
    public var edges: [MarkdownDiagramEdge]

    public init(
        kind: DiagramKind,
        direction: MarkdownDiagramDirection,
        nodes: [MarkdownDiagramNode],
        edges: [MarkdownDiagramEdge]
    ) {
        self.kind = kind
        self.direction = direction
        self.nodes = nodes
        self.edges = edges
    }
}

public struct MarkdownDiagramNode: Equatable, Hashable, Identifiable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct MarkdownDiagramEdge: Equatable, Hashable {
    public var from: String
    public var to: String
    public var label: String?

    public init(from: String, to: String, label: String? = nil) {
        self.from = from
        self.to = to
        self.label = label
    }
}

public enum MarkdownDiagramDirection: Equatable {
    case leftToRight
    case topToBottom
}

public enum MarkdownDiagramGraphParser {
    public static func parse(kind: DiagramKind, source: String) -> MarkdownDiagramGraph {
        if let cached = cache.graph(kind: kind, source: source) {
            return cached
        }

        var parser = DiagramGraphSourceParser(kind: kind, source: source)
        let graph = parser.parse()
        cache.store(graph, kind: kind, source: source)
        return graph
    }

    public static func clearCache() {
        cache.removeAll()
    }

    private static let cache = MarkdownDiagramGraphParseCache()
}

private final class MarkdownDiagramGraphParseCache: @unchecked Sendable {
    private let cache = NSCache<NSString, MarkdownDiagramGraphBox>()
    private let maxCacheableSourceLength = 65_536

    init() {
        cache.countLimit = 512
        cache.totalCostLimit = 2_000_000
    }

    func graph(kind: DiagramKind, source: String) -> MarkdownDiagramGraph? {
        guard shouldCache(source) else { return nil }
        return cache.object(forKey: key(kind: kind, source: source))?.graph
    }

    func store(_ graph: MarkdownDiagramGraph, kind: DiagramKind, source: String) {
        guard shouldCache(source) else { return }
        let cost = source.utf16.count + graph.nodes.count * 64 + graph.edges.count * 80
        cache.setObject(
            MarkdownDiagramGraphBox(graph),
            forKey: key(kind: kind, source: source),
            cost: cost
        )
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func shouldCache(_ source: String) -> Bool {
        !source.isEmpty && source.utf16.count <= maxCacheableSourceLength
    }

    private func key(kind: DiagramKind, source: String) -> NSString {
        "\(kind.rawValue)\u{1F}\(source)" as NSString
    }
}

private final class MarkdownDiagramGraphBox: @unchecked Sendable {
    let graph: MarkdownDiagramGraph

    init(_ graph: MarkdownDiagramGraph) {
        self.graph = graph
    }
}

private struct DiagramGraphSourceParser {
    let kind: DiagramKind
    let source: String
    var builder: DiagramGraphBuilder
    var direction: MarkdownDiagramDirection

    init(kind: DiagramKind, source: String) {
        self.kind = kind
        self.source = source
        self.builder = DiagramGraphBuilder()
        self.direction = kind == .sequence ? .leftToRight : .topToBottom
    }

    mutating func parse() -> MarkdownDiagramGraph {
        for rawLine in source.components(separatedBy: .newlines) {
            let line = sanitizedLine(rawLine)
            guard !line.isEmpty else { continue }
            guard !isWrapperLine(line) else { continue }

            if let parsedDirection = parseDirection(from: line) {
                direction = parsedDirection
                continue
            }

            if kind == .flowchart, parseFlowchartNodeDefinition(line) {
                continue
            }

            if parseSequenceEdge(line) {
                continue
            }

            if parseGenericEdge(line) {
                continue
            }
        }

        return MarkdownDiagramGraph(
            kind: kind,
            direction: direction,
            nodes: builder.nodes,
            edges: builder.edges
        )
    }

    private func sanitizedLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commentStart = cleaned.range(of: "%%") {
            cleaned = String(cleaned[..<commentStart.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasSuffix(";") {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isWrapperLine(_ line: String) -> Bool {
        let normalized = line.lowercased()
        return normalized == "{" ||
            normalized == "}" ||
            normalized.hasPrefix("@start") ||
            normalized.hasPrefix("@end") ||
            normalized.hasPrefix("digraph ") ||
            normalized.hasPrefix("graph ") && !normalized.hasPrefix("graph lr") && !normalized.hasPrefix("graph td")
    }

    private func parseDirection(from line: String) -> MarkdownDiagramDirection? {
        let normalized = line.lowercased()
        if normalized.contains("rankdir=lr") || normalized.contains("rankdir = lr") {
            return .leftToRight
        }

        let tokens = normalized
            .replacingOccurrences(of: ";", with: " ")
            .split { $0.isWhitespace }
            .map(String.init)
        guard let last = tokens.last else { return nil }

        if ["lr", "rl"].contains(last) { return .leftToRight }
        if ["td", "tb", "bt"].contains(last) { return .topToBottom }
        return nil
    }

    private mutating func parseFlowchartNodeDefinition(_ line: String) -> Bool {
        guard let separator = line.range(of: "=>") else { return false }
        let id = String(line[..<separator.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = String(line[separator.upperBound...])
        guard let titleSeparator = remainder.firstIndex(of: ":") else { return false }

        let title = String(remainder[remainder.index(after: titleSeparator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        builder.addNode(id: id, title: title.isEmpty ? id : title)
        return true
    }

    private mutating func parseSequenceEdge(_ line: String) -> Bool {
        guard kind == .sequence || kind == .plantuml else { return false }
        guard let arrow = firstArrow(in: line, arrows: ["-->>", "->>", "-->", "->", "<--", "<-"]) else {
            return false
        }

        let left = String(line[..<arrow.lowerBound])
        let remainder = String(line[arrow.upperBound...])
        let rightParts = remainder.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let right = rightParts.first else { return false }

        let label = rightParts.count > 1 ? normalizedTitle(String(rightParts[1])) : nil
        let from = parseEndpoint(left)
        let to = parseEndpoint(String(right))
        guard !from.id.isEmpty, !to.id.isEmpty else { return false }

        builder.addNode(from)
        builder.addNode(to)
        builder.addEdge(from: from.id, to: to.id, label: label)
        return true
    }

    private mutating func parseGenericEdge(_ line: String) -> Bool {
        guard let arrow = firstArrow(in: line, arrows: ["-.->", "==>", "-->", "---", "->", "--"]) else {
            return false
        }

        var left = String(line[..<arrow.lowerBound])
        var right = String(line[arrow.upperBound...])
        var label: String?

        if let trailingLabel = parseMermaidPipeLabel(from: &right) {
            label = trailingLabel
        } else if left.hasSuffix("--"),
                  let labeledArrow = line.range(of: "-->") {
            let labeledLeft = String(line[..<labeledArrow.lowerBound])
            if let labelRange = labeledLeft.range(of: "--", options: .backwards) {
                left = String(labeledLeft[..<labelRange.lowerBound])
                label = normalizedTitle(String(labeledLeft[labelRange.upperBound...]))
                right = String(line[labeledArrow.upperBound...])
            }
        } else if let attributeLabel = parseGraphvizAttributeLabel(from: right) {
            label = attributeLabel.label
            right = attributeLabel.endpoint
        }

        let from = parseEndpoint(left)
        let to = parseEndpoint(right)
        guard !from.id.isEmpty, !to.id.isEmpty else { return false }

        builder.addNode(from)
        builder.addNode(to)
        builder.addEdge(from: from.id, to: to.id, label: label)
        return true
    }

    private func firstArrow(in line: String, arrows: [String]) -> Range<String.Index>? {
        arrows.compactMap { arrow in
            line.range(of: arrow)
        }
        .sorted { $0.lowerBound < $1.lowerBound }
        .first
    }

    private func parseMermaidPipeLabel(from right: inout String) -> String? {
        let trimmed = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("|") else { return nil }
        let afterOpen = trimmed.index(after: trimmed.startIndex)
        guard let close = trimmed[afterOpen...].firstIndex(of: "|") else { return nil }

        let label = normalizedTitle(String(trimmed[afterOpen ..< close]))
        right = String(trimmed[trimmed.index(after: close)...])
        return label
    }

    private func parseGraphvizAttributeLabel(from right: String) -> (endpoint: String, label: String)? {
        guard let attributeStart = right.firstIndex(of: "["),
              right.hasSuffix("]") else {
            return nil
        }

        let endpoint = String(right[..<attributeStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = String(right[attributeStart...])
        guard let labelRange = attributes.range(of: "label", options: [.caseInsensitive]),
              let equals = attributes[labelRange.upperBound...].firstIndex(of: "=") else {
            return nil
        }

        let valueStart = attributes.index(after: equals)
        let rawValue = String(attributes[valueStart...])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'\t]"))
        guard !rawValue.isEmpty else { return nil }

        return (endpoint, normalizedTitle(rawValue))
    }

    private func parseEndpoint(_ rawEndpoint: String) -> MarkdownDiagramNode {
        var endpoint = rawEndpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";,"))
        if kind == .graphviz {
            endpoint = stripGraphvizAttributes(from: endpoint)
        }

        let delimiters: [(open: Character, close: Character)] = [
            ("[", "]"),
            ("(", ")"),
            ("{", "}")
        ]

        for delimiter in delimiters {
            guard let open = endpoint.firstIndex(of: delimiter.open),
                  let close = endpoint.lastIndex(of: delimiter.close),
                  open < close else {
                continue
            }

            let id = String(endpoint[..<open])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String(endpoint[endpoint.index(after: open) ..< close])
            let normalizedID = normalizedIdentifier(id.isEmpty ? title : id)
            return MarkdownDiagramNode(
                id: normalizedID,
                title: normalizedTitle(title).nilIfEmpty ?? normalizedID
            )
        }

        let normalizedID = normalizedIdentifier(endpoint)
        return MarkdownDiagramNode(id: normalizedID, title: normalizedTitle(endpoint).nilIfEmpty ?? normalizedID)
    }

    private func stripGraphvizAttributes(from endpoint: String) -> String {
        guard let attributeStart = endpoint.firstIndex(of: "[") else { return endpoint }
        return String(endpoint[..<attributeStart]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedIdentifier(_ value: String) -> String {
        normalizedTitle(value)
            .replacingOccurrences(of: " ", with: "-")
            .nilIfEmpty ?? "node"
    }

    private func normalizedTitle(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DiagramGraphBuilder {
    private(set) var nodes: [MarkdownDiagramNode] = []
    private(set) var edges: [MarkdownDiagramEdge] = []
    private var knownNodeIDs: Set<String> = []

    mutating func addNode(id: String, title: String) {
        addNode(MarkdownDiagramNode(id: id, title: title))
    }

    mutating func addNode(_ node: MarkdownDiagramNode) {
        guard !node.id.isEmpty else { return }
        if knownNodeIDs.insert(node.id).inserted {
            nodes.append(node)
        } else if let index = nodes.firstIndex(where: { $0.id == node.id }),
                  nodes[index].title == nodes[index].id,
                  node.title != node.id {
            nodes[index] = node
        }
    }

    mutating func addEdge(from: String, to: String, label: String?) {
        let edge = MarkdownDiagramEdge(from: from, to: to, label: label?.nilIfEmpty)
        guard !edges.contains(edge) else { return }
        edges.append(edge)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
