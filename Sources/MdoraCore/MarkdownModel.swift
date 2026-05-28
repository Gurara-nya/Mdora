import Foundation

public struct ParsedMarkdownDocument: Equatable {
    public var blocks: [MarkdownBlock]
    public var sourceMap: [MarkdownBlockSourceRange]
    public var outline: [DocumentSymbol]
    public var metadata: [MetadataItem]
    public var markers: MarkdownMarkers
    public var diagnostics: [MarkdownDiagnostic]
    public var stats: MarkdownStats

    public init(
        blocks: [MarkdownBlock],
        sourceMap: [MarkdownBlockSourceRange] = [],
        outline: [DocumentSymbol],
        metadata: [MetadataItem] = [],
        markers: MarkdownMarkers,
        diagnostics: [MarkdownDiagnostic] = [],
        stats: MarkdownStats
    ) {
        self.blocks = blocks
        self.sourceMap = sourceMap
        self.outline = outline
        self.metadata = metadata
        self.markers = markers
        self.diagnostics = diagnostics
        self.stats = stats
    }
}

public struct MarkdownBlockSourceRange: Equatable, Hashable, Identifiable {
    public var id: Int { blockIndex }
    public var blockIndex: Int
    public var startLine: Int
    public var endLine: Int

    public init(blockIndex: Int, startLine: Int, endLine: Int) {
        self.blockIndex = blockIndex
        self.startLine = startLine
        self.endLine = endLine
    }

    public func contains(line: Int) -> Bool {
        (startLine ... endLine).contains(line)
    }
}

public enum MarkdownBlock: Equatable {
    case frontMatter([String])
    case heading(level: Int, text: String, anchor: String)
    case paragraph(String)
    case blockquote(lines: [String], callout: CalloutKind?)
    case unorderedList([ListItem])
    case orderedList([ListItem])
    case taskList([TaskItem])
    case codeBlock(language: String?, code: String)
    case diagram(DiagramBlock)
    case mathBlock(String)
    case table(TableBlock)
    case definitionList([DefinitionItem])
    case footnoteDefinition(identifier: String, text: String)
    case linkReferenceDefinition(LinkReferenceDefinition)
    case image(alt: String, source: String, title: String?)
    case thematicBreak
    case htmlComment(String)
    case html(String)
}

public enum InlineMarkdownSegment: Equatable, Hashable {
    case text(String)
    case strong(String)
    case emphasis(String)
    case strikethrough(String)
    case code(String)
    case link(text: String, destination: String, title: String?)
    case referenceLink(text: String, label: String)
    case image(alt: String, source: String, title: String?)
    case imageReference(alt: String, label: String)
    case autoLink(String)
    case email(String)
    case wikiLink(String)
    case footnote(String)
    case inlineMath(String)
    case tag(String)
    case mention(String)
}

public struct ListItem: Equatable {
    public var text: String
    public var depth: Int

    public init(text: String, depth: Int = 0) {
        self.text = text
        self.depth = depth
    }
}

public struct TaskItem: Equatable {
    public var text: String
    public var isDone: Bool
    public var depth: Int

    public init(text: String, isDone: Bool, depth: Int = 0) {
        self.text = text
        self.isDone = isDone
        self.depth = depth
    }
}

public struct TableBlock: Equatable {
    public var headers: [String]
    public var alignments: [TableAlignment]
    public var rows: [[String]]

    public init(headers: [String], alignments: [TableAlignment], rows: [[String]]) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
    }
}

public struct DiagramBlock: Equatable {
    public var kind: DiagramKind
    public var source: String

    public init(kind: DiagramKind, source: String) {
        self.kind = kind
        self.source = source
    }
}

public enum DiagramKind: String, CaseIterable, Equatable, Hashable {
    case mermaid
    case graphviz
    case plantuml
    case sequence
    case flowchart

    public init?(language: String) {
        let normalized = language.lowercased()

        switch normalized {
        case "mermaid":
            self = .mermaid
        case "dot", "graphviz":
            self = .graphviz
        case "plantuml", "puml":
            self = .plantuml
        case "sequence", "sequence-diagram":
            self = .sequence
        case "flow", "flowchart":
            self = .flowchart
        default:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .mermaid:
            "Mermaid"
        case .graphviz:
            "Graphviz"
        case .plantuml:
            "PlantUML"
        case .sequence:
            "Sequence"
        case .flowchart:
            "Flowchart"
        }
    }
}

public struct DefinitionItem: Equatable {
    public var term: String
    public var definitions: [String]

    public init(term: String, definitions: [String]) {
        self.term = term
        self.definitions = definitions
    }
}

public struct LinkReferenceDefinition: Equatable {
    public var label: String
    public var destination: String
    public var title: String?

    public init(label: String, destination: String, title: String? = nil) {
        self.label = label
        self.destination = destination
        self.title = title
    }
}

public struct MetadataItem: Equatable, Hashable, Identifiable {
    public var id: String { key }
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public struct BlockKindCount: Equatable, Hashable, Identifiable {
    public var id: String { kind }
    public var kind: String
    public var count: Int

    public init(kind: String, count: Int) {
        self.kind = kind
        self.count = count
    }
}

public struct MarkdownDiagnostic: Equatable, Hashable, Identifiable {
    public var id: String
    public var severity: MarkdownDiagnosticSeverity
    public var title: String
    public var message: String
    public var line: Int?

    public init(
        id: String,
        severity: MarkdownDiagnosticSeverity,
        title: String,
        message: String,
        line: Int? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.line = line
    }
}

public enum MarkdownDiagnosticSeverity: String, Equatable, Hashable, CaseIterable {
    case info
    case warning
    case error

    public var title: String {
        rawValue.capitalized
    }
}

public enum TableAlignment: String, Equatable {
    case leading
    case center
    case trailing
}

public enum CalloutKind: String, CaseIterable, Equatable, Hashable {
    case note
    case tip
    case important
    case warning
    case caution
    case info
    case success
    case question
    case failure
    case bug
    case example
    case quote

    public init?(marker: String) {
        let normalized = marker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        self.init(rawValue: normalized)
    }

    public var title: String {
        rawValue.capitalized
    }
}

public struct DocumentSymbol: Equatable, Identifiable {
    public var id: String { anchor }
    public var level: Int
    public var title: String
    public var anchor: String

    public init(level: Int, title: String, anchor: String) {
        self.level = level
        self.title = title
        self.anchor = anchor
    }
}

public struct MarkdownMarkers: Equatable {
    public var links: [String]
    public var autoLinks: [String]
    public var emailLinks: [String]
    public var images: [String]
    public var imageReferences: [String]
    public var tags: [String]
    public var mentions: [String]
    public var wikiLinks: [String]
    public var footnotes: [String]
    public var linkReferences: [String]
    public var htmlComments: [String]
    public var taskTokens: [TaskToken]
    public var mathExpressions: [String]
    public var codeLanguages: [String]
    public var diagrams: [DiagramKind]
    public var callouts: [CalloutKind]

    public init(
        links: [String] = [],
        autoLinks: [String] = [],
        emailLinks: [String] = [],
        images: [String] = [],
        imageReferences: [String] = [],
        tags: [String] = [],
        mentions: [String] = [],
        wikiLinks: [String] = [],
        footnotes: [String] = [],
        linkReferences: [String] = [],
        htmlComments: [String] = [],
        taskTokens: [TaskToken] = [],
        mathExpressions: [String] = [],
        codeLanguages: [String] = [],
        diagrams: [DiagramKind] = [],
        callouts: [CalloutKind] = []
    ) {
        self.links = links
        self.autoLinks = autoLinks
        self.emailLinks = emailLinks
        self.images = images
        self.imageReferences = imageReferences
        self.tags = tags
        self.mentions = mentions
        self.wikiLinks = wikiLinks
        self.footnotes = footnotes
        self.linkReferences = linkReferences
        self.htmlComments = htmlComments
        self.taskTokens = taskTokens
        self.mathExpressions = mathExpressions
        self.codeLanguages = codeLanguages
        self.diagrams = diagrams
        self.callouts = callouts
    }
}

public struct TaskToken: Equatable, Hashable {
    public var kind: TaskTokenKind
    public var text: String

    public init(kind: TaskTokenKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

public enum TaskTokenKind: String, CaseIterable, Equatable, Hashable {
    case todo
    case fixme
    case bug
    case hack
    case note
    case important
    case question

    public init?(marker: String) {
        self.init(rawValue: marker.lowercased())
    }

    public var title: String {
        rawValue.uppercased()
    }
}

public struct MarkdownStats: Equatable {
    public var words: Int
    public var characters: Int
    public var lines: Int
    public var blocks: Int
    public var blockKinds: [BlockKindCount]
    public var readingMinutes: Int

    public init(
        words: Int,
        characters: Int,
        lines: Int,
        blocks: Int,
        blockKinds: [BlockKindCount] = [],
        readingMinutes: Int
    ) {
        self.words = words
        self.characters = characters
        self.lines = lines
        self.blocks = blocks
        self.blockKinds = blockKinds
        self.readingMinutes = readingMinutes
    }
}
