import Foundation

public struct ParsedMarkdownDocument: Equatable {
    public var blocks: [MarkdownBlock]
    public var outline: [DocumentSymbol]
    public var markers: MarkdownMarkers
    public var stats: MarkdownStats

    public init(
        blocks: [MarkdownBlock],
        outline: [DocumentSymbol],
        markers: MarkdownMarkers,
        stats: MarkdownStats
    ) {
        self.blocks = blocks
        self.outline = outline
        self.markers = markers
        self.stats = stats
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
    case table(TableBlock)
    case image(alt: String, source: String, title: String?)
    case thematicBreak
    case html(String)
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
    public var images: [String]
    public var tags: [String]
    public var mentions: [String]
    public var footnotes: [String]
    public var codeLanguages: [String]
    public var callouts: [CalloutKind]

    public init(
        links: [String] = [],
        images: [String] = [],
        tags: [String] = [],
        mentions: [String] = [],
        footnotes: [String] = [],
        codeLanguages: [String] = [],
        callouts: [CalloutKind] = []
    ) {
        self.links = links
        self.images = images
        self.tags = tags
        self.mentions = mentions
        self.footnotes = footnotes
        self.codeLanguages = codeLanguages
        self.callouts = callouts
    }
}

public struct MarkdownStats: Equatable {
    public var words: Int
    public var characters: Int
    public var lines: Int
    public var blocks: Int
    public var readingMinutes: Int

    public init(words: Int, characters: Int, lines: Int, blocks: Int, readingMinutes: Int) {
        self.words = words
        self.characters = characters
        self.lines = lines
        self.blocks = blocks
        self.readingMinutes = readingMinutes
    }
}
