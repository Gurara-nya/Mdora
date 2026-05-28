import MdoraCore
import SwiftUI

struct MarkdownPreviewStyle: Equatable {
    var bodyFontSize: CGFloat = 16
    var lineWidth: CGFloat = 820
    var animationsEnabled = true
    var syncsToEditor = true
}

private struct MarkdownPreviewStyleKey: EnvironmentKey {
    static let defaultValue = MarkdownPreviewStyle()
}

private extension EnvironmentValues {
    var mdoraPreviewStyle: MarkdownPreviewStyle {
        get { self[MarkdownPreviewStyleKey.self] }
        set { self[MarkdownPreviewStyleKey.self] = newValue }
    }
}

private struct MarkdownReferenceDefinitionsKey: EnvironmentKey {
    static let defaultValue: [String: LinkReferenceDefinition] = [:]
}

private struct MarkdownAbbreviationDefinitionsKey: EnvironmentKey {
    static let defaultValue: [String: AbbreviationDefinition] = [:]
}

private extension EnvironmentValues {
    var mdoraReferenceDefinitions: [String: LinkReferenceDefinition] {
        get { self[MarkdownReferenceDefinitionsKey.self] }
        set { self[MarkdownReferenceDefinitionsKey.self] = newValue }
    }

    var mdoraAbbreviationDefinitions: [String: AbbreviationDefinition] {
        get { self[MarkdownAbbreviationDefinitionsKey.self] }
        set { self[MarkdownAbbreviationDefinitionsKey.self] = newValue }
    }
}

struct MarkdownPreview: View {
    let markdown: String
    let theme: MdoraTheme
    let style: MarkdownPreviewStyle
    let activeLine: Int?
    @State private var updatePulse = false

    private var document: ParsedMarkdownDocument {
        MarkdownParser.parse(markdown)
    }

    var body: some View {
        let parsed = document
        let activeBlockIndex = activeBlockIndex(in: parsed)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(parsed.blocks.enumerated()), id: \.offset) { index, block in
                        MarkdownBlockView(
                            block: block,
                            theme: theme,
                            isActive: index == activeBlockIndex
                        )
                        .id(index)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: style.lineWidth, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .environment(\.mdoraPreviewStyle, style)
            .environment(\.mdoraReferenceDefinitions, parsed.referenceDefinitions)
            .environment(\.mdoraAbbreviationDefinitions, parsed.abbreviationDefinitions)
            .background(theme.palette.previewColor)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.palette.accentColor)
                    .frame(height: 2)
                    .opacity(style.animationsEnabled && updatePulse ? 0.75 : 0)
                    .animation(style.animationsEnabled ? .easeOut(duration: 0.28) : nil, value: updatePulse)
            }
            .animation(style.animationsEnabled ? .easeInOut(duration: 0.18) : nil, value: markdown)
            .onChange(of: markdown) { _, _ in
                guard style.animationsEnabled else { return }
                updatePulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    updatePulse = false
                }
            }
            .onChange(of: activeBlockIndex) { _, blockIndex in
                scrollToActiveBlock(blockIndex, proxy: proxy)
            }
            .onChange(of: style.syncsToEditor) { _, _ in
                scrollToActiveBlock(activeBlockIndex, proxy: proxy)
            }
            .onAppear {
                scrollToActiveBlock(activeBlockIndex, proxy: proxy)
            }
        }
    }

    private func activeBlockIndex(in document: ParsedMarkdownDocument) -> Int? {
        guard let activeLine else { return nil }
        return document.sourceMap.first { range in
            range.contains(line: activeLine)
        }?.blockIndex
    }

    private func scrollToActiveBlock(_ blockIndex: Int?, proxy: ScrollViewProxy) {
        guard style.syncsToEditor, let blockIndex else { return }

        withAnimation(style.animationsEnabled ? .easeInOut(duration: 0.18) : nil) {
            proxy.scrollTo(blockIndex, anchor: .center)
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let theme: MdoraTheme
    let isActive: Bool
    @Environment(\.mdoraPreviewStyle) private var style

    var body: some View {
        blockContent
            .padding(.vertical, isActive ? 6 : 0)
            .padding(.horizontal, isActive ? 10 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? theme.palette.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(theme.palette.accentColor)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                }
            }
            .animation(style.animationsEnabled ? .easeInOut(duration: 0.16) : nil, value: isActive)
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block {
        case let .frontMatter(frontMatter):
            FrontMatterView(frontMatter: frontMatter, theme: theme)
        case let .heading(level, text, _):
            HeadingView(level: level, text: text, theme: theme)
        case let .paragraph(text):
            InlineMarkdownText(text, theme: theme)
                .font(.system(size: style.bodyFontSize))
                .lineSpacing(5)
        case let .blockquote(lines, callout):
            BlockquoteView(lines: lines, callout: callout, theme: theme)
        case let .unorderedList(items):
            ListBlockView(items: items, isOrdered: false, theme: theme)
        case let .orderedList(items):
            ListBlockView(items: items, isOrdered: true, theme: theme)
        case let .taskList(items):
            TaskListBlockView(items: items, theme: theme)
        case let .codeBlock(language, code):
            CodeBlockView(language: language, code: code, theme: theme)
        case let .diagram(diagram):
            DiagramBlockView(diagram: diagram, theme: theme)
        case let .mathBlock(expression):
            MathBlockView(expression: expression, theme: theme)
        case let .table(table):
            TableBlockView(table: table, theme: theme)
        case let .definitionList(items):
            DefinitionListView(items: items, theme: theme)
        case let .footnoteDefinition(identifier, text):
            FootnoteDefinitionView(identifier: identifier, text: text, theme: theme)
        case let .linkReferenceDefinition(definition):
            LinkReferenceDefinitionView(definition: definition, theme: theme)
        case let .abbreviationDefinition(definition):
            AbbreviationDefinitionView(definition: definition, theme: theme)
        case let .image(alt, source, title):
            ImageBlockView(alt: alt, source: source, title: title, theme: theme)
        case .thematicBreak:
            Divider()
                .overlay(theme.palette.borderColor)
                .padding(.vertical, 10)
        case let .htmlComment(comment):
            HTMLCommentView(comment: comment, theme: theme)
        case let .html(html):
            HTMLBlockView(html: html, theme: theme)
        }
    }
}

private struct HeadingView: View {
    let level: Int
    let text: String
    let theme: MdoraTheme
    @Environment(\.mdoraPreviewStyle) private var style

    var body: some View {
        InlineMarkdownText(text, theme: theme)
            .font(.system(size: fontSize, weight: fontWeight, design: .default))
            .lineSpacing(2)
            .padding(.top, level == 1 ? 8 : 4)
    }

    private var fontSize: CGFloat {
        let base = style.bodyFontSize
        switch level {
        case 1:
            return base + 16
        case 2:
            return base + 9
        case 3:
            return base + 5
        case 4:
            return base + 2
        default:
            return base
        }
    }

    private var fontWeight: Font.Weight {
        level <= 2 ? .bold : .semibold
    }
}

private struct FrontMatterView: View {
    let frontMatter: FrontMatterBlock
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(frontMatter.kind.title) Front Matter", systemImage: "switch.2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.mutedColor)

            Text(frontMatter.lines.joined(separator: "\n"))
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(theme.palette.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.palette.borderColor.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct BlockquoteView: View {
    let lines: [String]
    let callout: CalloutKind?
    let theme: MdoraTheme

    var body: some View {
        if let callout {
            CalloutView(kind: callout, lines: lines, theme: theme)
        } else {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(theme.palette.borderColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        InlineMarkdownText(line, theme: theme)
                            .foregroundStyle(theme.palette.mutedColor)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CalloutView: View {
    let kind: CalloutKind
    let lines: [String]
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(kind.title, systemImage: kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kind.tint)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    InlineMarkdownText(line, theme: theme)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(kind.tint.opacity(0.36), lineWidth: 1)
        )
    }
}

private struct ListBlockView: View {
    let items: [ListItem]
    let isOrdered: Bool
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(isOrdered ? "\(index + 1)." : "•")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.palette.mutedColor)
                        .frame(width: 28, alignment: .trailing)
                        .padding(.leading, CGFloat(item.depth) * 18)

                    InlineMarkdownText(item.text, theme: theme)
                }
            }
        }
    }
}

private struct TaskListBlockView: View {
    let items: [TaskItem]
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isDone ? theme.palette.accentColor : theme.palette.mutedColor)
                        .frame(width: 20)
                        .padding(.leading, CGFloat(item.depth) * 18)

                    InlineMarkdownText(item.text, theme: theme)
                        .foregroundStyle(item.isDone ? theme.palette.mutedColor : theme.palette.textColor)
                        .strikethrough(item.isDone)
                }
            }
        }
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let language, !language.isEmpty {
                Label(language, systemImage: icon(for: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.palette.mutedColor)
                    .textCase(.uppercase)
            }

            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(theme.palette.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.codeColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.palette.borderColor.opacity(0.42), lineWidth: 1)
        )
    }

    private func icon(for language: String) -> String {
        switch language.lowercased() {
        case "swift":
            "swift"
        case "json", "yaml", "yml", "toml":
            "curlybraces"
        case "sh", "bash", "zsh":
            "terminal"
        case "html", "xml":
            "chevron.left.forwardslash.chevron.right"
        default:
            "doc.plaintext"
        }
    }
}

private struct DiagramBlockView: View {
    let diagram: DiagramBlock
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(diagram.kind.title, systemImage: diagram.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)
                .textCase(.uppercase)

            DiagramPreviewCanvas(kind: diagram.kind, source: diagram.source, theme: theme)

            DisclosureGroup {
                Text(diagram.source)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(theme.palette.mutedColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } label: {
                Text("Source")
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.palette.accentColor.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct DiagramPreviewCanvas: View {
    let kind: DiagramKind
    let source: String
    let theme: MdoraTheme

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0 ..< nodeCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.palette.previewColor)
                        .frame(width: 82, height: 38)
                        .overlay(
                            Text(nodeTitle(index))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.palette.textColor)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.palette.borderColor.opacity(0.5), lineWidth: 1)
                        )

                    if index < nodeCount - 1 {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(theme.palette.accentColor)
                    }
                }
            }

            Text(kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.mutedColor)
        }
        .frame(maxWidth: .infinity, minHeight: 118)
        .padding(12)
        .background(theme.palette.previewColor.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var nodeCount: Int {
        min(4, max(2, source.components(separatedBy: .newlines).filter { !$0.trimmedForPreview.isEmpty }.count))
    }

    private func nodeTitle(_ index: Int) -> String {
        let candidates = source
            .components(separatedBy: .newlines)
            .map(\.trimmedForPreview)
            .filter { !$0.isEmpty }

        guard candidates.indices.contains(index) else {
            return "Node \(index + 1)"
        }

        return String(candidates[index].prefix(18))
    }
}

private struct MathBlockView: View {
    let expression: String
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Math", systemImage: "function")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)

            Text(expression)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.textColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.palette.borderColor.opacity(0.38), lineWidth: 1)
        )
    }
}

private struct TableBlockView: View {
    let table: TableBlock
    let theme: MdoraTheme

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(table.headers.enumerated()), id: \.offset) { index, header in
                        TableCell(text: header, alignment: alignment(at: index), isHeader: true, theme: theme)
                    }
                }

                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0 ..< max(table.headers.count, row.count), id: \.self) { index in
                            TableCell(
                                text: row.indices.contains(index) ? row[index] : "",
                                alignment: alignment(at: index),
                                isHeader: false,
                                theme: theme
                            )
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.palette.borderColor.opacity(0.55), lineWidth: 1)
            )
        }
    }

    private func alignment(at index: Int) -> Alignment {
        guard table.alignments.indices.contains(index) else { return .leading }

        switch table.alignments[index] {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private struct TableCell: View {
    let text: String
    let alignment: Alignment
    let isHeader: Bool
    let theme: MdoraTheme

    var body: some View {
        InlineMarkdownText(text, theme: theme)
            .font(.system(size: 14, weight: isHeader ? .semibold : .regular))
            .frame(minWidth: 120, maxWidth: 220, alignment: alignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHeader ? theme.palette.surfaceColor : theme.palette.previewColor)
            .border(theme.palette.borderColor.opacity(0.38), width: 0.5)
    }
}

private struct DefinitionListView: View {
    let items: [DefinitionItem]
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 6) {
                    InlineMarkdownText(item.term, theme: theme)
                        .font(.system(size: 15, weight: .semibold))

                    ForEach(Array(item.definitions.enumerated()), id: \.offset) { _, definition in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Rectangle()
                                .fill(theme.palette.borderColor)
                                .frame(width: 3, height: 16)

                            InlineMarkdownText(definition, theme: theme)
                                .foregroundStyle(theme.palette.mutedColor)
                        }
                        .padding(.leading, 12)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FootnoteDefinitionView: View {
    let identifier: String
    let text: String
    let theme: MdoraTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(identifier)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)
                .frame(width: 30, alignment: .trailing)

            InlineMarkdownText(text, theme: theme)
                .font(.caption)
                .foregroundStyle(theme.palette.mutedColor)
        }
        .padding(10)
        .background(theme.palette.surfaceColor.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LinkReferenceDefinitionView: View {
    let definition: LinkReferenceDefinition
    let theme: MdoraTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(definition.label, systemImage: "link.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)
                .frame(minWidth: 80, alignment: .leading)

            Text(definition.destination)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.textColor)

            if let title = definition.title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surfaceColor.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct AbbreviationDefinitionView: View {
    let definition: AbbreviationDefinition
    let theme: MdoraTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(definition.term, systemImage: "textformat.abc.dottedunderline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)
                .frame(minWidth: 80, alignment: .leading)

            Text(definition.expansion)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.textColor)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surfaceColor.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ImageBlockView: View {
    let alt: String
    let source: String
    let title: String?
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = URL(string: source), ["http", "https"].contains(url.scheme?.lowercased()) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    imagePlaceholder
                }
                .frame(maxWidth: 760, maxHeight: 420)
            } else {
                imagePlaceholder
            }

            if !alt.isEmpty || title != nil {
                Text(title ?? alt)
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var imagePlaceholder: some View {
        Label(source, systemImage: "photo")
            .font(.callout)
            .foregroundStyle(theme.palette.mutedColor)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(theme.palette.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.palette.borderColor.opacity(0.45), lineWidth: 1)
            )
    }
}

private struct HTMLCommentView: View {
    let comment: String
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Comment", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.mutedColor)

            Text(comment)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.mutedColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.surfaceColor.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.palette.borderColor.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HTMLBlockView: View {
    let html: String
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.mutedColor)

            Text(html)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(theme.palette.textColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.codeColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct InlineMarkdownText: View {
    private let text: String
    private let theme: MdoraTheme
    @Environment(\.mdoraPreviewStyle) private var style
    @Environment(\.mdoraReferenceDefinitions) private var referenceDefinitions
    @Environment(\.mdoraAbbreviationDefinitions) private var abbreviationDefinitions

    init(_ text: String, theme: MdoraTheme) {
        self.text = text
        self.theme = theme
    }

    var body: some View {
        rendered
            .foregroundStyle(theme.palette.textColor)
            .textSelection(.enabled)
    }

    private var rendered: Text {
        renderInline(text)
    }

    private func renderInline(_ source: String) -> Text {
        InlineMarkdownParser.parse(source).reduce(Text("")) { result, segment in
            result + render(segment)
        }
    }

    private func render(_ segment: InlineMarkdownSegment) -> Text {
        switch segment {
        case let .text(value):
            renderText(value)
        case let .strong(value):
            renderInline(value).bold()
        case let .emphasis(value):
            renderInline(value).italic()
        case let .strikethrough(value):
            renderInline(value).strikethrough()
        case let .highlight(value):
            renderInline(value)
                .bold()
                .foregroundColor(.yellow)
        case let .superscript(value):
            renderInline(value)
                .font(.system(size: max(10, style.bodyFontSize - 5), weight: .medium))
                .baselineOffset(5)
        case let .subscriptText(value):
            renderInline(value)
                .font(.system(size: max(10, style.bodyFontSize - 5), weight: .medium))
                .baselineOffset(-3)
        case let .criticAddition(value):
            renderInline(value)
                .foregroundColor(theme.palette.accentColor)
                .underline()
        case let .criticDeletion(value):
            renderInline(value)
                .foregroundColor(theme.palette.mutedColor)
                .strikethrough()
        case let .criticSubstitution(original, replacement):
            renderInline(original)
                .foregroundColor(theme.palette.mutedColor)
                .strikethrough()
            + Text(" -> ")
                .foregroundColor(theme.palette.mutedColor)
            + renderInline(replacement)
                .foregroundColor(theme.palette.accentColor)
                .underline()
        case let .criticComment(value):
            Text("[comment: ")
                .foregroundColor(theme.palette.mutedColor)
            + renderInline(value)
                .italic()
                .foregroundColor(theme.palette.mutedColor)
            + Text("]")
                .foregroundColor(theme.palette.mutedColor)
        case let .criticHighlight(value):
            renderInline(value)
                .bold()
                .foregroundColor(.yellow)
        case let .code(value):
            Text(value)
                .font(.system(size: max(12, style.bodyFontSize - 2), design: .monospaced))
                .foregroundColor(theme.palette.accentColor)
        case let .link(label, _, _):
            renderInline(label)
                .foregroundColor(theme.palette.accentColor)
                .underline()
        case let .referenceLink(label, reference):
            renderInline(label)
                .foregroundColor(resolvedReference(reference) == nil ? theme.palette.mutedColor : theme.palette.accentColor)
                .underline()
        case let .image(alt, source, _):
            Text("[image: \(alt.isEmpty ? source : alt)]")
                .font(.system(size: max(11, style.bodyFontSize - 4)))
                .foregroundColor(theme.palette.accentColor)
        case let .imageReference(alt, label):
            Text("[image: \(imageReferenceTitle(alt: alt, label: label))]")
                .font(.system(size: max(11, style.bodyFontSize - 4)))
                .foregroundColor(resolvedReference(label) == nil ? theme.palette.mutedColor : theme.palette.accentColor)
        case let .autoLink(url):
            Text(url)
                .foregroundColor(theme.palette.accentColor)
                .underline()
        case let .email(email):
            Text(email)
                .foregroundColor(theme.palette.accentColor)
                .underline()
        case let .wikiLink(value):
            Text("[[\(value)]]")
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium))
                .foregroundColor(theme.palette.accentColor)
        case let .footnote(identifier):
            Text("[\(identifier)]")
                .font(.system(size: max(10, style.bodyFontSize - 5)))
                .baselineOffset(4)
                .foregroundColor(theme.palette.accentColor)
        case let .inlineMath(value):
            Text(value)
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium, design: .serif))
                .foregroundColor(theme.palette.accentColor)
        case let .citation(identifier):
            Text("[@\(identifier)]")
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium))
                .foregroundColor(theme.palette.mutedColor)
        case let .emojiShortcode(name):
            Text(":\(name):")
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium))
                .foregroundColor(theme.palette.accentColor)
        case let .keyboard(value):
            Text(value)
                .font(.system(size: max(12, style.bodyFontSize - 2), weight: .semibold, design: .monospaced))
                .foregroundColor(theme.palette.textColor)
        case let .tag(value):
            Text("#\(value)")
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium))
                .foregroundColor(theme.palette.accentColor)
        case let .mention(value):
            Text("@\(value)")
                .font(.system(size: max(13, style.bodyFontSize - 1), weight: .medium))
                .foregroundColor(theme.palette.accentColor)
        }
    }

    private func resolvedReference(_ label: String) -> LinkReferenceDefinition? {
        referenceDefinitions[LinkReferenceDefinition.normalizedLabel(label)]
    }

    private func imageReferenceTitle(alt: String, label: String) -> String {
        if !alt.isEmpty {
            return alt
        }

        if let reference = resolvedReference(label) {
            return reference.title ?? reference.destination
        }

        return label
    }

    private func renderText(_ value: String) -> Text {
        guard !abbreviationDefinitions.isEmpty else { return Text(value) }

        var rendered = Text("")
        var cursor = value.startIndex

        while cursor < value.endIndex {
            if let definition = matchingAbbreviation(in: value, at: cursor) {
                rendered = rendered
                    + Text(definition.term)
                    .underline(true, color: theme.palette.accentColor)
                    .foregroundColor(theme.palette.accentColor)
                cursor = value.index(cursor, offsetBy: definition.term.count)
                continue
            }

            rendered = rendered + Text(String(value[cursor]))
            cursor = value.index(after: cursor)
        }

        return rendered
    }

    private func matchingAbbreviation(in value: String, at index: String.Index) -> AbbreviationDefinition? {
        sortedAbbreviations.first { definition in
            guard value[index...].hasPrefix(definition.term) else { return false }

            let end = value.index(index, offsetBy: definition.term.count)
            return hasAbbreviationBoundary(before: index, in: value, term: definition.term)
                && hasAbbreviationBoundary(after: end, in: value, term: definition.term)
        }
    }

    private var sortedAbbreviations: [AbbreviationDefinition] {
        abbreviationDefinitions.values.sorted { first, second in
            if first.term.count == second.term.count {
                return first.term < second.term
            }

            return first.term.count > second.term.count
        }
    }

    private func hasAbbreviationBoundary(
        before index: String.Index,
        in value: String,
        term: String
    ) -> Bool {
        guard let first = term.first, first.isLetter || first.isNumber else { return true }
        guard index > value.startIndex else { return true }
        return !value[value.index(before: index)].isAbbreviationWordCharacter
    }

    private func hasAbbreviationBoundary(
        after index: String.Index,
        in value: String,
        term: String
    ) -> Bool {
        guard let last = term.last, last.isLetter || last.isNumber else { return true }
        guard index < value.endIndex else { return true }
        return !value[index].isAbbreviationWordCharacter
    }
}

private extension CalloutKind {
    var systemImage: String {
        switch self {
        case .note:
            "note.text"
        case .tip:
            "lightbulb"
        case .important:
            "star"
        case .warning:
            "exclamationmark.triangle"
        case .caution:
            "hand.raised"
        case .info:
            "info.circle"
        case .success:
            "checkmark.circle"
        case .question:
            "questionmark.circle"
        case .failure:
            "xmark.octagon"
        case .bug:
            "exclamationmark.triangle"
        case .example:
            "shippingbox"
        case .quote:
            "quote.opening"
        }
    }

    var tint: Color {
        switch self {
        case .note, .info:
            .blue
        case .tip, .success:
            .green
        case .important, .example:
            .purple
        case .warning, .caution:
            .orange
        case .question:
            .cyan
        case .failure, .bug:
            .red
        case .quote:
            .secondary
        }
    }
}

private extension DiagramKind {
    var systemImage: String {
        switch self {
        case .mermaid:
            "point.3.connected.trianglepath.dotted"
        case .graphviz:
            "circle.hexagongrid"
        case .plantuml:
            "rectangle.3.group"
        case .sequence:
            "arrow.left.arrow.right"
        case .flowchart:
            "flowchart"
        }
    }
}

private extension String {
    var trimmedForPreview: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Character {
    var isAbbreviationWordCharacter: Bool {
        isLetter || isNumber || self == "_"
    }
}
