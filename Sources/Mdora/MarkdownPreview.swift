import MdoraCore
import AppKit
import SwiftUI
import WebKit

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

private struct MarkdownAssetBaseURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
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

    var mdoraAssetBaseURL: URL? {
        get { self[MarkdownAssetBaseURLKey.self] }
        set { self[MarkdownAssetBaseURLKey.self] = newValue }
    }
}

struct MarkdownPreview: View {
    let markdown: String
    let document: ParsedMarkdownDocument
    let theme: MdoraTheme
    let style: MarkdownPreviewStyle
    let isFrozen: Bool
    let activeLine: Int?
    let documentURL: URL?
    let onTaskStateChange: ((Int, Int, TaskState) -> Void)?
    @State private var updatePulse = false
    @State private var pendingActiveScrollWorkItem: DispatchWorkItem?
    @State private var lastSyncedBlockIndex: Int?

    var body: some View {
        let parsed = document
        let renderStyle = effectiveStyle
        let activeBlockIndex = activeBlockIndex(in: parsed)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(parsed.blocks.indices, id: \.self) { index in
                        let block = parsed.blocks[index]
                        MarkdownBlockView(
                            block: block,
                            blockIndex: index,
                            theme: theme,
                            isActive: index == activeBlockIndex,
                            onTaskStateChange: onTaskStateChange
                        )
                        .id(index)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: renderStyle.lineWidth, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .environment(\.mdoraPreviewStyle, renderStyle)
            .environment(\.mdoraReferenceDefinitions, parsed.referenceDefinitions)
            .environment(\.mdoraAbbreviationDefinitions, parsed.abbreviationDefinitions)
            .environment(\.mdoraAssetBaseURL, documentURL?.deletingLastPathComponent())
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "mdora" {
                    handlePreviewNavigation(url, in: parsed, proxy: proxy)
                    return .handled
                }
                return .systemAction
            })
            .background(theme.palette.previewColor)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.palette.accentColor)
                    .frame(height: 2)
                    .opacity(renderStyle.animationsEnabled && updatePulse ? 0.75 : 0)
                    .animation(renderStyle.animationsEnabled ? .easeOut(duration: 0.28) : nil, value: updatePulse)
            }
            .animation(renderStyle.animationsEnabled ? .easeInOut(duration: 0.18) : nil, value: parsed.blocks.count)
            .onChange(of: markdown) { _, _ in
                guard !isFrozen, renderStyle.animationsEnabled else { return }
                updatePulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    updatePulse = false
                }
            }
            .onChange(of: activeBlockIndex) { _, blockIndex in
                guard !isFrozen else {
                    pendingActiveScrollWorkItem?.cancel()
                    return
                }
                scheduleActiveBlockScroll(blockIndex, proxy: proxy)
            }
            .onChange(of: isFrozen) { _, frozen in
                pendingActiveScrollWorkItem?.cancel()
                if frozen {
                    lastSyncedBlockIndex = nil
                } else {
                    scrollToActiveBlock(activeBlockIndex, proxy: proxy, force: true)
                }
            }
            .onChange(of: style.syncsToEditor) { _, syncsToEditor in
                pendingActiveScrollWorkItem?.cancel()
                guard !isFrozen else {
                    lastSyncedBlockIndex = nil
                    return
                }
                guard syncsToEditor else {
                    lastSyncedBlockIndex = nil
                    return
                }

                scrollToActiveBlock(activeBlockIndex, proxy: proxy, force: true)
            }
            .onAppear {
                guard !isFrozen else { return }
                scrollToActiveBlock(activeBlockIndex, proxy: proxy, force: true)
            }
            .onDisappear {
                pendingActiveScrollWorkItem?.cancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mdoraNavigateRequested)) { notification in
                guard !isFrozen else { return }
                guard let url = notification.object as? URL else { return }
                handlePreviewNavigation(url, in: parsed, proxy: proxy)
            }
        }
    }

    private func activeBlockIndex(in document: ParsedMarkdownDocument) -> Int? {
        guard let activeLine else { return nil }
        return document.blockIndex(containingLine: activeLine)
    }

    private var effectiveStyle: MarkdownPreviewStyle {
        var resolvedStyle = style
        if isFrozen {
            resolvedStyle.animationsEnabled = false
            resolvedStyle.syncsToEditor = false
        }
        if shouldDisablePreviewAnimations {
            resolvedStyle.animationsEnabled = false
        }
        return resolvedStyle
    }

    private var shouldDisablePreviewAnimations: Bool {
        markdown.count > 60_000 || document.blocks.count > 900
    }

    private func scheduleActiveBlockScroll(_ blockIndex: Int?, proxy: ScrollViewProxy) {
        let renderStyle = effectiveStyle
        guard renderStyle.syncsToEditor, let blockIndex, blockIndex != lastSyncedBlockIndex else { return }

        pendingActiveScrollWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            scrollToActiveBlock(blockIndex, proxy: proxy)
        }
        pendingActiveScrollWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: workItem)
    }

    private func scrollToActiveBlock(_ blockIndex: Int?, proxy: ScrollViewProxy, force: Bool = false) {
        let renderStyle = effectiveStyle
        guard renderStyle.syncsToEditor, let blockIndex else { return }
        guard force || blockIndex != lastSyncedBlockIndex else { return }

        lastSyncedBlockIndex = blockIndex

        withAnimation(renderStyle.animationsEnabled ? .easeInOut(duration: 0.18) : nil) {
            proxy.scrollTo(blockIndex, anchor: .center)
        }
    }

    private func handlePreviewNavigation(_ url: URL, in parsed: ParsedMarkdownDocument, proxy: ScrollViewProxy) {
        guard url.scheme == "mdora" else { return }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parameter = path.removingPercentEncoding ?? path

        var targetIndex: Int? = nil

        if url.host == "scroll" {
            targetIndex = MarkdownInternalLinkResolver.indexForAnchor(parameter, in: parsed.blocks)
        } else if url.host == "line" {
            if let line = Int(parameter) {
                targetIndex = parsed.blockIndex(containingLine: line)
            }
        } else if url.host == "search" {
            targetIndex = MarkdownInternalLinkResolver.indexForSearchTerm(parameter, in: parsed.blocks)
        } else if url.host == "wiki" {
            targetIndex = MarkdownInternalLinkResolver.indexForWikiTarget(
                parameter,
                in: parsed.blocks,
                currentDocumentURL: documentURL
            )
            if targetIndex == nil,
               let fileURL = MarkdownInternalLinkResolver.fileURLForWikiTarget(
                   parameter,
                   currentDocumentURL: documentURL
               ) {
                pendingActiveScrollWorkItem?.cancel()
                openMarkdownDocument(at: fileURL)
                return
            }
        } else if url.host == "footnote" {
            targetIndex = MarkdownInternalLinkResolver.indexForFootnote(parameter, in: parsed.blocks)
        } else if url.host == "tag" {
            targetIndex = MarkdownInternalLinkResolver.indexForTag(parameter, in: parsed.blocks)
        } else if url.host == "mention" {
            targetIndex = MarkdownInternalLinkResolver.indexForMention(parameter, in: parsed.blocks)
        }

        if let targetIndex {
            pendingActiveScrollWorkItem?.cancel()
            withAnimation(effectiveStyle.animationsEnabled ? .spring(response: 0.38, dampingFraction: 0.72) : nil) {
                proxy.scrollTo(targetIndex, anchor: .center)
            }
        }
    }

    private func openMarkdownDocument(at url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if error != nil {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let blockIndex: Int?
    let theme: MdoraTheme
    let isActive: Bool
    let onTaskStateChange: ((Int, Int, TaskState) -> Void)?
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
        case let .heading(level, text, _, _):
            HeadingView(level: level, text: text, theme: theme)
        case let .paragraph(text):
            let visibleText = MarkdownBlockIDParser.contentWithoutTrailingIdentifier(text)
            if let embed = standaloneWikiEmbed(in: visibleText) {
                WikiEmbedBlockView(value: embed, theme: theme)
            } else {
                InlineMarkdownText(visibleText, theme: theme)
                    .font(.system(size: style.bodyFontSize))
                    .lineSpacing(5)
            }
        case let .blockquote(blocks, callout):
            BlockquoteView(blocks: blocks, callout: callout, theme: theme)
        case let .unorderedList(items):
            ListBlockView(items: items, isOrdered: false, theme: theme)
        case let .orderedList(items):
            ListBlockView(items: items, isOrdered: true, theme: theme)
        case let .taskList(items):
            TaskListBlockView(
                items: items,
                blockIndex: blockIndex,
                theme: theme,
                onTaskStateChange: onTaskStateChange
            )
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

    private func standaloneWikiEmbed(in text: String) -> String? {
        let segments = InlineMarkdownParser.parse(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard segments.count == 1, case let .wikiEmbed(value) = segments[0] else { return nil }
        return value
    }
}

private struct HeadingView: View {
    let level: Int
    let text: String
    let theme: MdoraTheme
    @Environment(\.mdoraPreviewStyle) private var style

    var body: some View {
        InlineMarkdownText(MarkdownBlockIDParser.contentWithoutTrailingIdentifier(text), theme: theme)
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
    let blocks: [MarkdownBlock]
    let callout: Callout?
    let theme: MdoraTheme

    var body: some View {
        if let callout {
            CalloutView(callout: callout, blocks: blocks, theme: theme)
        } else {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(theme.palette.borderColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks.indices, id: \.self) { index in
                        let block = blocks[index]
                        MarkdownBlockView(
                            block: block,
                            blockIndex: nil,
                            theme: theme,
                            isActive: false,
                            onTaskStateChange: nil
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CalloutView: View {
    let callout: Callout
    let blocks: [MarkdownBlock]
    let theme: MdoraTheme
    @Environment(\.mdoraPreviewStyle) private var style
    @State private var isExpanded: Bool

    init(callout: Callout, blocks: [MarkdownBlock], theme: MdoraTheme) {
        self.callout = callout
        self.blocks = blocks
        self.theme = theme
        _isExpanded = State(initialValue: callout.fold != .collapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard callout.fold != nil else { return }
                withAnimation(style.animationsEnabled ? .easeInOut(duration: 0.16) : nil) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: callout.kind.systemImage)

                    Text(callout.displayTitle)

                    if callout.fold != nil {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(callout.kind.tint)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks.indices, id: \.self) { index in
                        let block = blocks[index]
                        MarkdownBlockView(
                            block: block,
                            blockIndex: nil,
                            theme: theme,
                            isActive: false,
                            onTaskStateChange: nil
                        )
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(callout.kind.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(callout.kind.tint.opacity(0.36), lineWidth: 1)
        )
    }
}

private struct ListBlockView: View {
    let items: [ListItem]
    let isOrdered: Bool
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(markerText(for: item, at: index))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.palette.mutedColor)
                        .frame(width: 28, alignment: .trailing)
                        .padding(.leading, CGFloat(item.depth) * 18)

                    InlineMarkdownText(MarkdownBlockIDParser.contentWithoutTrailingIdentifier(item.text), theme: theme)
                }
            }
        }
    }

    private func markerText(for item: ListItem, at index: Int) -> String {
        guard isOrdered else { return "•" }
        let startNumber = items.first?.markerNumber ?? 1
        let number = item.markerNumber ?? startNumber + index
        return "\(number)."
    }
}

private struct TaskListBlockView: View {
    let items: [TaskItem]
    let blockIndex: Int?
    let theme: MdoraTheme
    let onTaskStateChange: ((Int, Int, TaskState) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { itemIndex in
                let item = items[itemIndex]
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    taskStateControl(for: item, itemIndex: itemIndex)

                    InlineMarkdownText(MarkdownBlockIDParser.contentWithoutTrailingIdentifier(item.text), theme: theme)
                        .foregroundStyle(item.state.isMuted ? theme.palette.mutedColor : theme.palette.textColor)
                        .strikethrough(item.state.isStruckThrough)
                }
            }
        }
    }

    @ViewBuilder
    private func taskStateControl(for item: TaskItem, itemIndex: Int) -> some View {
        if let blockIndex, let onTaskStateChange {
            Button {
                onTaskStateChange(blockIndex, itemIndex, item.state.previewToggleState)
            } label: {
                taskStateIcon(for: item.state, depth: item.depth)
            }
            .buttonStyle(.plain)
            .contextMenu {
                ForEach(TaskState.allCases, id: \.self) { state in
                    Button {
                        onTaskStateChange(blockIndex, itemIndex, state)
                    } label: {
                        Label(state.title, systemImage: state.systemImage)
                    }
                }
            }
            .help("切换任务状态")
        } else {
            taskStateIcon(for: item.state, depth: item.depth)
        }
    }

    private func taskStateIcon(for state: TaskState, depth: Int) -> some View {
        Image(systemName: state.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(state.tint(theme: theme))
            .frame(width: 20)
            .padding(.leading, CGFloat(depth) * 18)
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    let theme: MdoraTheme
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let language, !language.isEmpty {
                        Label(language, systemImage: icon(for: language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.palette.mutedColor)
                            .textCase(.uppercase)
                    }
                    Spacer()
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
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

            if isHovered || showCopied {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(code, forType: .string)

                    withAnimation(.easeInOut(duration: 0.18)) {
                        showCopied = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showCopied ? Color.green.opacity(0.18) : theme.palette.surfaceColor.opacity(0.85))
                    .foregroundColor(showCopied ? .green : theme.palette.textColor)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(showCopied ? Color.green : theme.palette.borderColor.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .padding(.top, 10)
                .padding(.trailing, 10)
            }
        }
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
    @State private var height: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("数学公式", systemImage: "function")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)

            MathWebView(expression: expression, theme: theme, height: $height)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
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

class NonScrollingWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        self.nextResponder?.scrollWheel(with: event)
    }
}

struct MathWebView: NSViewRepresentable {
    let expression: String
    let theme: MdoraTheme
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "heightCallback")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = NonScrollingWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.scrollEnabled = false
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self

        let textColorHex = theme.palette.textColorHex
        let accentColorHex = theme.palette.accentColorHex

        // Safe JavaScript string escape for backslashes and quotes
        let escapedExpr = expression
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 4px 0;
                    background-color: transparent;
                    color: \(textColorHex);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    overflow: hidden;
                }
                .math-container {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    width: 100%;
                    min-height: 20px;
                }
                .katex-display {
                    margin: 0 !important;
                }
                .katex {
                    color: \(textColorHex) !important;
                    font-size: 1.15em !important;
                }
                .katex .keyword, .katex .accent {
                    color: \(accentColorHex) !important;
                }
            </style>
        </head>
        <body>
            <div class="math-container" id="math-target"></div>
            <script>
                try {
                    var expr = "\(escapedExpr)";
                    katex.render(expr, document.getElementById('math-target'), {
                        displayMode: true,
                        throwOnError: false
                    });
                } catch (err) {
                    document.getElementById('math-target').innerText = err.message;
                }

                function reportHeight() {
                    setTimeout(function() {
                        var target = document.getElementById('math-target');
                        var height = target ? target.offsetHeight + 12 : 50;
                        window.webkit.messageHandlers.heightCallback.postMessage(height);
                    }, 50);
                }
                window.onload = reportHeight;
                new ResizeObserver(reportHeight).observe(document.body);
            </script>
        </body>
        </html>
        """
        nsView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MathWebView

        init(_ parent: MathWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightCallback", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    let clampedHeight = max(40, min(600, height))
                    if abs(self.parent.height - clampedHeight) > 2 {
                        self.parent.height = clampedHeight
                    }
                }
            }
        }
    }
}

private extension WKWebView {
    var scrollEnabled: Bool {
        get { true }
        set {
            #if os(macOS)
            if let scrollView = self.enclosingScrollView {
                scrollView.hasVerticalScroller = newValue
                scrollView.hasHorizontalScroller = newValue
            }
            #endif
        }
    }
}

private struct TableBlockView: View {
    let table: TableBlock
    let theme: MdoraTheme

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(table.headers.indices, id: \.self) { index in
                        let header = table.headers[index]
                        TableCell(text: header, alignment: alignment(at: index), isHeader: true, theme: theme)
                    }
                }

                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    let row = table.rows[rowIndex]
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
            .frame(minWidth: 120, maxWidth: .infinity, alignment: alignment)
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
            ForEach(items.indices, id: \.self) { itemIndex in
                let item = items[itemIndex]
                VStack(alignment: .leading, spacing: 6) {
                    InlineMarkdownText(item.term, theme: theme)
                        .font(.system(size: 15, weight: .semibold))

                    ForEach(item.definitions.indices, id: \.self) { definitionIndex in
                        let definition = item.definitions[definitionIndex]
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
    @Environment(\.mdoraAssetBaseURL) private var assetBaseURL
    @State private var isHovered = false
    @State private var loadedLocalImage: CGImage?
    @State private var loadedLocalImageURL: URL?

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                imageView
                    .scaleEffect(isHovered ? 1.015 : 1.0)
                    .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 10 : 3, x: 0, y: isHovered ? 5 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isHovered)
                    .onHover { hovering in
                        isHovered = hovering
                    }

                if isHovered, let localURL = localImageURL {
                    Button {
                        NSWorkspace.shared.open(localURL)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open Original")
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.palette.surfaceColor.opacity(0.85))
                        .foregroundColor(theme.palette.textColor)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(theme.palette.borderColor.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            if !alt.isEmpty || title != nil {
                Text(title ?? alt)
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = MarkdownAssetResolver.remoteURL(for: source) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                imagePlaceholder
            }
            .frame(maxWidth: 760, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let url = localImageURL {
            localImageView(for: url)
        } else {
            imagePlaceholder
        }
    }

    @ViewBuilder
    private func localImageView(for url: URL) -> some View {
        if let image = cachedOrLoadedImage(for: url) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 760, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            imagePlaceholder
                .task(id: url) {
                    await loadLocalImage(from: url)
                }
        }
    }

    private var localImageURL: URL? {
        MarkdownAssetResolver.localFileURL(for: source, relativeTo: assetBaseURL)
    }

    private func cachedOrLoadedImage(for url: URL) -> CGImage? {
        if let cachedImage = MarkdownLocalImageCache.shared.cachedPreviewImage(for: url) {
            return cachedImage
        }

        guard loadedLocalImageURL == url else { return nil }
        return loadedLocalImage
    }

    @MainActor
    private func loadLocalImage(from url: URL) async {
        if let cachedImage = MarkdownLocalImageCache.shared.cachedPreviewImage(for: url) {
            loadedLocalImageURL = url
            loadedLocalImage = cachedImage
            return
        }

        let image = await MarkdownLocalImageCache.shared.loadPreviewImageInBackground(for: url)
        guard !Task.isCancelled, localImageURL == url else { return }
        loadedLocalImageURL = url
        loadedLocalImage = image
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

private struct WikiEmbedBlockView: View {
    let value: String
    let theme: MdoraTheme

    private var reference: MarkdownWikiLinkReference {
        MarkdownWikiLinkReference.parse(value)
    }

    var body: some View {
        if reference.isImageEmbed {
            ImageBlockView(
                alt: reference.embedDisplayText,
                source: reference.target,
                title: reference.alias,
                theme: theme
            )
        } else {
            Label(reference.embedDisplayText, systemImage: "paperclip")
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.palette.accentColor)
                .lineLimit(2)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.palette.borderColor.opacity(0.45), lineWidth: 1)
                )
        }
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
    @Environment(\.openURL) private var openURL

    init(_ text: String, theme: MdoraTheme) {
        self.text = text
        self.theme = theme
    }

    var body: some View {
        Text(attributedString)
            .foregroundStyle(theme.palette.textColor)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                handleOpenURL(url)
            })
    }

    private var attributedString: AttributedString {
        let sortedAbbreviations = sortedAbbreviationsForRender
        return renderInline(text, sortedAbbreviations: sortedAbbreviations)
    }

    private func renderInline(
        _ source: String,
        sortedAbbreviations: [AbbreviationDefinition]
    ) -> AttributedString {
        var result = AttributedString()
        let segments = InlineMarkdownParser.parse(source)
        for segment in segments {
            result.append(attributedString(for: segment, sortedAbbreviations: sortedAbbreviations))
        }
        return result
    }

    private func attributedString(
        for segment: InlineMarkdownSegment,
        sortedAbbreviations: [AbbreviationDefinition]
    ) -> AttributedString {
        var str: AttributedString

        switch segment {
        case let .text(value):
            str = renderText(value, sortedAbbreviations: sortedAbbreviations)
        case .hardBreak:
            str = AttributedString("\n")
        case let .strong(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.font = .system(size: style.bodyFontSize, weight: .bold)
        case let .emphasis(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.font = .system(size: style.bodyFontSize).italic()
        case let .strikethrough(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.strikethroughStyle = .single
        case let .highlight(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.backgroundColor = theme.palette.accentColor.opacity(0.18)
            str.foregroundColor = theme.palette.accentColor
            str.font = .system(size: style.bodyFontSize, weight: .bold)
        case let .superscript(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.font = .system(size: max(10, style.bodyFontSize - 5), weight: .medium)
            str.baselineOffset = 5
        case let .subscriptText(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.font = .system(size: max(10, style.bodyFontSize - 5), weight: .medium)
            str.baselineOffset = -3
        case let .criticAddition(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.foregroundColor = theme.palette.accentColor
            str.underlineStyle = .single
        case let .criticDeletion(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.foregroundColor = theme.palette.mutedColor
            str.strikethroughStyle = .single
        case let .criticSubstitution(original, replacement):
            var origStr = renderInline(original, sortedAbbreviations: sortedAbbreviations)
            origStr.foregroundColor = theme.palette.mutedColor
            origStr.strikethroughStyle = .single

            var separator = AttributedString(" -> ")
            separator.foregroundColor = theme.palette.mutedColor

            var replStr = renderInline(replacement, sortedAbbreviations: sortedAbbreviations)
            replStr.foregroundColor = theme.palette.accentColor
            replStr.underlineStyle = .single

            str = origStr + separator + replStr
        case let .criticComment(value):
            var prefix = AttributedString("[comment: ")
            prefix.foregroundColor = theme.palette.mutedColor

            var content = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            content.foregroundColor = theme.palette.mutedColor
            content.font = .system(size: style.bodyFontSize).italic()

            var suffix = AttributedString("]")
            suffix.foregroundColor = theme.palette.mutedColor

            str = prefix + content + suffix
        case let .criticHighlight(value):
            str = renderInline(value, sortedAbbreviations: sortedAbbreviations)
            str.backgroundColor = Color.yellow.opacity(0.3)
            str.font = .system(size: style.bodyFontSize, weight: .bold)
        case let .code(value):
            str = AttributedString(value)
            str.font = .system(size: max(12, style.bodyFontSize - 2), design: .monospaced)
            str.foregroundColor = theme.palette.accentColor
            str.backgroundColor = theme.palette.codeColor
        case let .link(label, destination, _):
            str = renderInline(label, sortedAbbreviations: sortedAbbreviations)
            str.underlineStyle = .single
            str.foregroundColor = theme.palette.accentColor
            if destination.hasPrefix("#") {
                let anchor = String(destination.dropFirst())
                if let url = internalURL(host: "scroll", parameter: anchor) {
                    str.link = url
                }
            } else if let url = URL(string: destination) {
                str.link = url
            }
        case let .referenceLink(label, reference):
            str = renderInline(label, sortedAbbreviations: sortedAbbreviations)
            str.underlineStyle = .single
            if let definition = resolvedReference(reference) {
                str.foregroundColor = theme.palette.accentColor
                if definition.destination.hasPrefix("#") {
                    let anchor = String(definition.destination.dropFirst())
                    if let url = internalURL(host: "scroll", parameter: anchor) {
                        str.link = url
                    }
                } else if let url = URL(string: definition.destination) {
                    str.link = url
                }
            } else {
                str.foregroundColor = theme.palette.mutedColor
            }
        case let .shortcutReferenceLink(label):
            if let definition = resolvedReference(label) {
                str = renderInline(label, sortedAbbreviations: sortedAbbreviations)
                str.underlineStyle = .single
                str.foregroundColor = theme.palette.accentColor
                if definition.destination.hasPrefix("#") {
                    let anchor = String(definition.destination.dropFirst())
                    if let url = internalURL(host: "scroll", parameter: anchor) {
                        str.link = url
                    }
                } else if let url = URL(string: definition.destination) {
                    str.link = url
                }
            } else {
                str = AttributedString("[\(label)]")
            }
        case let .image(alt, source, _):
            str = AttributedString("[image: \(alt.isEmpty ? source : alt)]")
            str.font = .system(size: max(11, style.bodyFontSize - 4))
            str.foregroundColor = theme.palette.accentColor
            if let url = URL(string: source) {
                str.link = url
            }
        case let .imageReference(alt, label):
            let title = imageReferenceTitle(alt: alt, label: label)
            str = AttributedString("[image: \(title)]")
            str.font = .system(size: max(11, style.bodyFontSize - 4))
            if let definition = resolvedReference(label) {
                str.foregroundColor = theme.palette.accentColor
                if let url = URL(string: definition.destination) {
                    str.link = url
                }
            } else {
                str.foregroundColor = theme.palette.mutedColor
            }
        case let .shortcutImageReference(alt):
            if let definition = resolvedReference(alt) {
                let title = imageReferenceTitle(alt: alt, label: alt)
                str = AttributedString("[image: \(title)]")
                str.font = .system(size: max(11, style.bodyFontSize - 4))
                str.foregroundColor = theme.palette.accentColor
                if let url = URL(string: definition.destination) {
                    str.link = url
                }
            } else {
                str = AttributedString("![\(alt)]")
            }
        case let .autoLink(url):
            str = AttributedString(url)
            str.underlineStyle = .single
            str.foregroundColor = theme.palette.accentColor
            if let linkURL = URL(string: MarkdownAutoLinkScanner.href(for: url)) {
                str.link = linkURL
            }
        case let .email(email):
            str = AttributedString(email)
            str.underlineStyle = .single
            str.foregroundColor = theme.palette.accentColor
            if let mailURL = URL(string: "mailto:\(email)") {
                str.link = mailURL
            }
        case let .wikiLink(value):
            let ref = MarkdownWikiLinkReference.parse(value)
            str = AttributedString(ref.displayText)
            str.foregroundColor = theme.palette.accentColor
            str.font = .system(size: max(13, style.bodyFontSize - 1), weight: .medium)
            if let url = internalURL(host: "wiki", parameter: ref.target) {
                str.link = url
            }
        case let .wikiEmbed(value):
            let ref = MarkdownWikiLinkReference.parse(value)
            str = AttributedString(ref.embedPreviewText)
            str.foregroundColor = theme.palette.accentColor
            str.font = .system(size: max(12, style.bodyFontSize - 3), weight: .medium)
            if let url = internalURL(host: "wiki", parameter: ref.target) {
                str.link = url
            }
        case let .footnote(identifier):
            str = AttributedString("[\(identifier)]")
            str.font = .system(size: max(10, style.bodyFontSize - 5))
            str.baselineOffset = 4
            str.foregroundColor = theme.palette.accentColor
            if let url = internalURL(host: "footnote", parameter: identifier) {
                str.link = url
            }
        case let .inlineMath(value):
            str = parseLaTeXToAttributedString(value, theme: theme, fontSize: max(13, style.bodyFontSize - 1))
            str.foregroundColor = theme.palette.accentColor
        case let .citation(identifier):
            str = AttributedString("[@\(identifier)]")
            str.font = .system(size: max(13, style.bodyFontSize - 1), weight: .medium)
            str.foregroundColor = theme.palette.mutedColor
        case let .emojiShortcode(name):
            let emoji = MarkdownEmojiShortcode.emoji(for: name) ?? ":\(name):"
            str = AttributedString(emoji)
            str.foregroundColor = theme.palette.accentColor
        case let .keyboard(value):
            str = AttributedString(value)
            str.font = .system(size: max(12, style.bodyFontSize - 2), weight: .semibold, design: .monospaced)
            str.foregroundColor = theme.palette.textColor
            str.backgroundColor = theme.palette.surfaceColor
        case let .htmlInline(value):
            str = AttributedString(value)
            str.font = .system(size: max(11, style.bodyFontSize - 3), design: .monospaced)
            str.foregroundColor = theme.palette.mutedColor
            str.backgroundColor = theme.palette.codeColor
        case let .htmlEntity(_, character):
            str = AttributedString(character)
        case let .tag(value):
            str = AttributedString("#\(value)")
            str.font = .system(size: max(13, style.bodyFontSize - 1), weight: .medium)
            str.foregroundColor = theme.palette.accentColor
            if let url = internalURL(host: "tag", parameter: value) {
                str.link = url
            }
        case let .mention(value):
            str = AttributedString("@\(value)")
            str.font = .system(size: max(13, style.bodyFontSize - 1), weight: .medium)
            str.foregroundColor = theme.palette.accentColor
            if let url = internalURL(host: "mention", parameter: value) {
                str.link = url
            }
        }

        return str
    }

    private func resolvedReference(_ label: String) -> LinkReferenceDefinition? {
        referenceDefinitions[LinkReferenceDefinition.normalizedLabel(label)]
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "mdora" {
            NotificationCenter.default.post(name: .mdoraNavigateRequested, object: url)
            return .handled
        }
        return .systemAction
    }

    private func internalURL(host: String, parameter: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mdora"
        components.host = host
        components.path = "/\(parameter)"
        return components.url
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

    private func renderText(
        _ value: String,
        sortedAbbreviations: [AbbreviationDefinition]
    ) -> AttributedString {
        guard !sortedAbbreviations.isEmpty else { return AttributedString(value) }

        var rendered = AttributedString()
        var cursor = value.startIndex

        while cursor < value.endIndex {
            if let definition = matchingAbbreviation(
                in: value,
                at: cursor,
                sortedAbbreviations: sortedAbbreviations
            ) {
                var termStr = AttributedString(definition.term)
                termStr.underlineStyle = .single
                termStr.foregroundColor = theme.palette.accentColor
                rendered.append(termStr)
                cursor = value.index(cursor, offsetBy: definition.term.count)
                continue
            }

            rendered.append(AttributedString(String(value[cursor])))
            cursor = value.index(after: cursor)
        }

        return rendered
    }

    private func matchingAbbreviation(
        in value: String,
        at index: String.Index,
        sortedAbbreviations: [AbbreviationDefinition]
    ) -> AbbreviationDefinition? {
        sortedAbbreviations.first { definition in
            guard value[index...].hasPrefix(definition.term) else { return false }

            let end = value.index(index, offsetBy: definition.term.count)
            return hasAbbreviationBoundary(before: index, in: value, term: definition.term)
                && hasAbbreviationBoundary(after: end, in: value, term: definition.term)
        }
    }

    private var sortedAbbreviationsForRender: [AbbreviationDefinition] {
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

    private func parseLaTeXToAttributedString(_ text: String, theme: MdoraTheme, fontSize: CGFloat, isItalic: Bool = true) -> AttributedString {
        var result = AttributedString()
        var input = text

        let replacements: [(String, String)] = [
            ("\\approx", "≈"),
            ("\\cdots", "···"),
            ("\\cdot", "·"),
            ("\\quad", "   "),
            ("\\qquad", "      "),
            ("\\,", " "),
            ("\\ge", "≥"),
            ("\\geq", "≥"),
            ("\\le", "≤"),
            ("\\leq", "≤"),
            ("\\neq", "≠"),
            ("\\times", "×"),
            ("\\pm", "±"),
            ("\\infty", "∞"),
            ("\\partial", "∂"),
            ("\\alpha", "α"),
            ("\\beta", "β"),
            ("\\gamma", "γ"),
            ("\\delta", "δ"),
            ("\\theta", "θ"),
            ("\\lambda", "λ"),
            ("\\mu", "μ"),
            ("\\pi", "π"),
            ("\\sigma", "σ"),
            ("\\phi", "φ"),
            ("\\omega", "ω"),
            ("\\Delta", "Δ"),
            ("\\Omega", "Ω"),
            ("\\to", "→"),
            ("\\circ", "°"),
            ("\\prime", "′"),
            ("\\ ", " ")
        ]

        for (macro, replacement) in replacements {
            input = input.replacingOccurrences(of: macro, with: replacement)
        }

        var index = input.startIndex
        while index < input.endIndex {
            let char = input[index]

            if char == "\\" {
                let rest = input[index...]
                if rest.hasPrefix("\\mathrm{") {
                    if let startBrace = rest.firstIndex(of: "{") {
                        if let endBrace = findMatchingBrace(in: input, startingAt: startBrace) {
                            let contentStart = input.index(after: startBrace)
                            let content = String(input[contentStart..<endBrace])
                            let subStr = parseLaTeXToAttributedString(content, theme: theme, fontSize: fontSize, isItalic: false)
                            result.append(subStr)
                            index = input.index(after: endBrace)
                            continue
                        }
                    }
                }
            }

            if char == "_" {
                let nextIndex = input.index(after: index)
                if nextIndex < input.endIndex {
                    let nextChar = input[nextIndex]
                    if nextChar == "{" {
                        if let endBrace = findMatchingBrace(in: input, startingAt: nextIndex) {
                            let contentStart = input.index(after: nextIndex)
                            let content = String(input[contentStart..<endBrace])
                            var subStr = parseLaTeXToAttributedString(content, theme: theme, fontSize: max(9, fontSize - 4), isItalic: isItalic)
                            subStr.baselineOffset = -3
                            result.append(subStr)
                            index = input.index(after: endBrace)
                            continue
                        }
                    } else {
                        let content = String(nextChar)
                        var subStr = parseLaTeXToAttributedString(content, theme: theme, fontSize: max(9, fontSize - 4), isItalic: isItalic)
                        subStr.baselineOffset = -3
                        result.append(subStr)
                        index = input.index(after: nextIndex)
                        continue
                    }
                }
            }

            if char == "^" {
                let nextIndex = input.index(after: index)
                if nextIndex < input.endIndex {
                    let nextChar = input[nextIndex]
                    if nextChar == "{" {
                        if let endBrace = findMatchingBrace(in: input, startingAt: nextIndex) {
                            let contentStart = input.index(after: nextIndex)
                            let content = String(input[contentStart..<endBrace])
                            var superStr = parseLaTeXToAttributedString(content, theme: theme, fontSize: max(9, fontSize - 4), isItalic: isItalic)
                            superStr.baselineOffset = 4
                            result.append(superStr)
                            index = input.index(after: endBrace)
                            continue
                        }
                    } else {
                        let content = String(nextChar)
                        var superStr = parseLaTeXToAttributedString(content, theme: theme, fontSize: max(9, fontSize - 4), isItalic: isItalic)
                        superStr.baselineOffset = 4
                        result.append(superStr)
                        index = input.index(after: nextIndex)
                        continue
                    }
                }
            }

            var charStr = AttributedString(String(char))
            if isItalic {
                charStr.font = .system(size: fontSize, weight: .medium, design: .serif).italic()
            } else {
                charStr.font = .system(size: fontSize, weight: .medium, design: .serif)
            }
            charStr.foregroundColor = theme.palette.textColor
            result.append(charStr)
            index = input.index(after: index)
        }

        return result
    }

    private func findMatchingBrace(in text: String, startingAt openBraceIndex: String.Index) -> String.Index? {
        var depth = 0
        var current = openBraceIndex
        while current < text.endIndex {
            let char = text[current]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return current
                }
            }
            current = text.index(after: current)
        }
        return nil
    }
}

private extension CalloutKind {
    var systemImage: String {
        switch self {
        case .abstract:
            "doc.text.magnifyingglass"
        case .note:
            "note.text"
        case .todo:
            "checklist"
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
        case .danger:
            "flame"
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
        case .note, .info, .abstract:
            .blue
        case .tip, .success:
            .green
        case .todo:
            .indigo
        case .important, .example:
            .purple
        case .warning, .caution:
            .orange
        case .question:
            .cyan
        case .failure, .danger, .bug:
            .red
        case .quote:
            .secondary
        }
    }
}

private extension TaskState {
    var systemImage: String {
        switch self {
        case .todo:
            "square"
        case .done:
            "checkmark.square.fill"
        case .inProgress:
            "clock"
        case .canceled:
            "minus.square"
        case .forwarded:
            "arrowshape.turn.up.right"
        case .important:
            "exclamationmark.square.fill"
        case .question:
            "questionmark.square"
        }
    }

    var isMuted: Bool {
        self == .done || self == .canceled
    }

    var isStruckThrough: Bool {
        self == .done || self == .canceled
    }

    var previewToggleState: TaskState {
        self == .done ? .todo : .done
    }

    func tint(theme: MdoraTheme) -> Color {
        switch self {
        case .todo:
            theme.palette.mutedColor
        case .done:
            theme.palette.accentColor
        case .inProgress:
            .orange
        case .canceled:
            theme.palette.mutedColor
        case .forwarded:
            .purple
        case .important:
            .red
        case .question:
            .cyan
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

extension Notification.Name {
    static let mdoraNavigateRequested = Notification.Name("mdoraNavigateRequested")
}
