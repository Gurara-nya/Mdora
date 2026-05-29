import Foundation

public struct ParsedMarkdownDocument: Equatable {
    public var blocks: [MarkdownBlock]
    public var sourceMap: [MarkdownBlockSourceRange]
    public var outline: [DocumentSymbol]
    public var metadata: [MetadataItem]
    public var markers: MarkdownMarkers
    public var referenceDefinitions: [String: LinkReferenceDefinition]
    public var abbreviationDefinitions: [String: AbbreviationDefinition]
    public var diagnostics: [MarkdownDiagnostic]
    public var stats: MarkdownStats

    public init(
        blocks: [MarkdownBlock],
        sourceMap: [MarkdownBlockSourceRange] = [],
        outline: [DocumentSymbol],
        metadata: [MetadataItem] = [],
        markers: MarkdownMarkers,
        referenceDefinitions: [String: LinkReferenceDefinition] = [:],
        abbreviationDefinitions: [String: AbbreviationDefinition] = [:],
        diagnostics: [MarkdownDiagnostic] = [],
        stats: MarkdownStats
    ) {
        self.blocks = blocks
        self.sourceMap = sourceMap
        self.outline = outline
        self.metadata = metadata
        self.markers = markers
        self.referenceDefinitions = referenceDefinitions
        self.abbreviationDefinitions = abbreviationDefinitions
        self.diagnostics = diagnostics
        self.stats = stats
    }
}

extension ParsedMarkdownDocument: @unchecked Sendable {}

public extension ParsedMarkdownDocument {
    func blockIndex(containingLine line: Int) -> Int? {
        guard line > 0, !sourceMap.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = sourceMap.count

        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            let range = sourceMap[middle]

            if line < range.startLine {
                upperBound = middle
            } else if line > range.endLine {
                lowerBound = middle + 1
            } else {
                return range.blockIndex
            }
        }

        return nil
    }

    func sourceRange(forBlockIndex blockIndex: Int) -> MarkdownBlockSourceRange? {
        if sourceMap.indices.contains(blockIndex) {
            let range = sourceMap[blockIndex]
            if range.blockIndex == blockIndex {
                return range
            }
        }

        return sourceMap.first { $0.blockIndex == blockIndex }
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
    case frontMatter(FrontMatterBlock)
    case heading(level: Int, text: String, anchor: String)
    case paragraph(String)
    case blockquote(blocks: [MarkdownBlock], callout: Callout?)
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
    case abbreviationDefinition(AbbreviationDefinition)
    case image(alt: String, source: String, title: String?)
    case thematicBreak
    case htmlComment(String)
    case html(String)
}

public struct FrontMatterBlock: Equatable, Hashable {
    public var kind: FrontMatterKind
    public var lines: [String]

    public init(kind: FrontMatterKind, lines: [String]) {
        self.kind = kind
        self.lines = lines
    }
}

public enum FrontMatterKind: String, Equatable, Hashable, CaseIterable {
    case yaml
    case toml
    case json

    public var title: String {
        switch self {
        case .yaml:
            "YAML"
        case .toml:
            "TOML"
        case .json:
            "JSON"
        }
    }
}

public enum InlineMarkdownSegment: Equatable, Hashable {
    case text(String)
    case hardBreak
    case strong(String)
    case emphasis(String)
    case strikethrough(String)
    case highlight(String)
    case superscript(String)
    case subscriptText(String)
    case criticAddition(String)
    case criticDeletion(String)
    case criticSubstitution(original: String, replacement: String)
    case criticComment(String)
    case criticHighlight(String)
    case code(String)
    case link(text: String, destination: String, title: String?)
    case referenceLink(text: String, label: String)
    case image(alt: String, source: String, title: String?)
    case imageReference(alt: String, label: String)
    case autoLink(String)
    case email(String)
    case wikiLink(String)
    case wikiEmbed(String)
    case footnote(String)
    case inlineMath(String)
    case citation(String)
    case emojiShortcode(String)
    case keyboard(String)
    case htmlInline(String)
    case htmlEntity(source: String, character: String)
    case tag(String)
    case mention(String)
}

public struct ListItem: Equatable {
    public var text: String
    public var depth: Int
    public var markerNumber: Int?

    public init(text: String, depth: Int = 0, markerNumber: Int? = nil) {
        self.text = text
        self.depth = depth
        self.markerNumber = markerNumber
    }
}

public struct TaskItem: Equatable {
    public var text: String
    public var state: TaskState
    public var depth: Int

    public var isDone: Bool {
        state == .done
    }

    public init(text: String, state: TaskState, depth: Int = 0) {
        self.text = text
        self.state = state
        self.depth = depth
    }

    public init(text: String, isDone: Bool, depth: Int = 0) {
        self.init(text: text, state: isDone ? .done : .todo, depth: depth)
    }
}

public enum TaskState: String, Equatable, Hashable, CaseIterable {
    case todo = " "
    case done = "x"
    case inProgress = "/"
    case canceled = "-"
    case forwarded = ">"
    case important = "!"
    case question = "?"

    public init?(marker: Character) {
        let normalized = String(marker).lowercased()
        self.init(rawValue: normalized)
    }

    public var marker: String {
        rawValue
    }

    public var cssClass: String {
        switch self {
        case .todo:
            "todo"
        case .done:
            "done"
        case .inProgress:
            "in-progress"
        case .canceled:
            "canceled"
        case .forwarded:
            "forwarded"
        case .important:
            "important"
        case .question:
            "question"
        }
    }

    public var title: String {
        switch self {
        case .todo:
            "Todo"
        case .done:
            "Done"
        case .inProgress:
            "In Progress"
        case .canceled:
            "Canceled"
        case .forwarded:
            "Forwarded"
        case .important:
            "Important"
        case .question:
            "Question"
        }
    }
}

public struct TaskStateCount: Equatable, Hashable, Identifiable {
    public var id: String { state.cssClass }
    public var state: TaskState
    public var count: Int

    public init(state: TaskState, count: Int) {
        self.state = state
        self.count = count
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

public struct LinkReferenceDefinition: Equatable, Sendable {
    public var label: String
    public var destination: String
    public var title: String?

    public init(label: String, destination: String, title: String? = nil) {
        self.label = label
        self.destination = destination
        self.title = title
    }

    public var normalizedLabel: String {
        Self.normalizedLabel(label)
    }

    public static func normalizedLabel(_ label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split { character in
                character.isWhitespace || character.isNewline
            }
            .joined(separator: " ")
            .lowercased()
    }
}

public struct AbbreviationDefinition: Equatable, Hashable, Sendable {
    public var term: String
    public var expansion: String

    public init(term: String, expansion: String) {
        self.term = term
        self.expansion = expansion
    }

    public var normalizedTerm: String {
        Self.normalizedTerm(term)
    }

    public static func normalizedTerm(_ term: String) -> String {
        term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split { character in
                character.isWhitespace || character.isNewline
            }
            .joined(separator: " ")
    }
}

public struct CriticSubstitution: Equatable, Hashable {
    public var original: String
    public var replacement: String

    public init(original: String, replacement: String) {
        self.original = original
        self.replacement = replacement
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
    case abstract
    case note
    case todo
    case tip
    case important
    case warning
    case caution
    case info
    case success
    case question
    case failure
    case danger
    case bug
    case example
    case quote

    public init?(marker: String) {
        let normalized = marker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "summary", "tldr":
            self = .abstract
        case "hint":
            self = .tip
        case "check", "done":
            self = .success
        case "help", "faq":
            self = .question
        case "fail", "missing":
            self = .failure
        case "error":
            self = .danger
        case "attention":
            self = .warning
        case "cite":
            self = .quote
        default:
            guard let kind = Self(rawValue: normalized) else { return nil }
            self = kind
        }
    }

    public var title: String {
        rawValue.capitalized
    }
}

public struct Callout: Equatable, Hashable {
    public var kind: CalloutKind
    public var title: String?
    public var fold: CalloutFold?

    public var displayTitle: String {
        guard let title, !title.isEmpty else { return kind.title }
        return title
    }

    public var inspectorText: String {
        if let fold {
            return "\(displayTitle) (\(kind.rawValue), \(fold.title))"
        }

        return "\(displayTitle) (\(kind.rawValue))"
    }

    public init(kind: CalloutKind, title: String? = nil, fold: CalloutFold? = nil) {
        self.kind = kind
        self.title = title
        self.fold = fold
    }
}

public enum CalloutFold: String, Equatable, Hashable {
    case expanded
    case collapsed

    public init?(marker: Character?) {
        switch marker {
        case "+":
            self = .expanded
        case "-":
            self = .collapsed
        default:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .expanded:
            "expanded"
        case .collapsed:
            "collapsed"
        }
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
    public var wikiEmbeds: [String]
    public var blockIDs: [String]
    public var customAnchors: [String]
    public var abbreviations: [AbbreviationDefinition]
    public var footnotes: [String]
    public var linkReferences: [String]
    public var htmlComments: [String]
    public var inlineHTML: [String]
    public var htmlEntities: [String]
    public var taskTokens: [TaskToken]
    public var taskStates: [TaskStateCount]
    public var mathExpressions: [String]
    public var highlights: [String]
    public var superscripts: [String]
    public var subscripts: [String]
    public var criticAdditions: [String]
    public var criticDeletions: [String]
    public var criticSubstitutions: [CriticSubstitution]
    public var criticComments: [String]
    public var criticHighlights: [String]
    public var citations: [String]
    public var emojiShortcodes: [String]
    public var keyboardShortcuts: [String]
    public var codeLanguages: [String]
    public var diagrams: [DiagramKind]
    public var callouts: [Callout]

    public init(
        links: [String] = [],
        autoLinks: [String] = [],
        emailLinks: [String] = [],
        images: [String] = [],
        imageReferences: [String] = [],
        tags: [String] = [],
        mentions: [String] = [],
        wikiLinks: [String] = [],
        wikiEmbeds: [String] = [],
        blockIDs: [String] = [],
        customAnchors: [String] = [],
        abbreviations: [AbbreviationDefinition] = [],
        footnotes: [String] = [],
        linkReferences: [String] = [],
        htmlComments: [String] = [],
        inlineHTML: [String] = [],
        htmlEntities: [String] = [],
        taskTokens: [TaskToken] = [],
        taskStates: [TaskStateCount] = [],
        mathExpressions: [String] = [],
        highlights: [String] = [],
        superscripts: [String] = [],
        subscripts: [String] = [],
        criticAdditions: [String] = [],
        criticDeletions: [String] = [],
        criticSubstitutions: [CriticSubstitution] = [],
        criticComments: [String] = [],
        criticHighlights: [String] = [],
        citations: [String] = [],
        emojiShortcodes: [String] = [],
        keyboardShortcuts: [String] = [],
        codeLanguages: [String] = [],
        diagrams: [DiagramKind] = [],
        callouts: [Callout] = []
    ) {
        self.links = links
        self.autoLinks = autoLinks
        self.emailLinks = emailLinks
        self.images = images
        self.imageReferences = imageReferences
        self.tags = tags
        self.mentions = mentions
        self.wikiLinks = wikiLinks
        self.wikiEmbeds = wikiEmbeds
        self.blockIDs = blockIDs
        self.customAnchors = customAnchors
        self.abbreviations = abbreviations
        self.footnotes = footnotes
        self.linkReferences = linkReferences
        self.htmlComments = htmlComments
        self.inlineHTML = inlineHTML
        self.htmlEntities = htmlEntities
        self.taskTokens = taskTokens
        self.taskStates = taskStates
        self.mathExpressions = mathExpressions
        self.highlights = highlights
        self.superscripts = superscripts
        self.subscripts = subscripts
        self.criticAdditions = criticAdditions
        self.criticDeletions = criticDeletions
        self.criticSubstitutions = criticSubstitutions
        self.criticComments = criticComments
        self.criticHighlights = criticHighlights
        self.citations = citations
        self.emojiShortcodes = emojiShortcodes
        self.keyboardShortcuts = keyboardShortcuts
        self.codeLanguages = codeLanguages
        self.diagrams = diagrams
        self.callouts = callouts
    }

    public var criticMarkupCount: Int {
        criticAdditions.count
            + criticDeletions.count
            + criticSubstitutions.count
            + criticComments.count
            + criticHighlights.count
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
