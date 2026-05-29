import MdoraCore
import AppKit
import SwiftUI

struct EditorWindow: View {
    @Binding var document: MarkdownDocument
    let documentURL: URL?
    @AppStorage("editorLayoutMode") private var layoutMode = LayoutMode.split.rawValue
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @AppStorage("previewLineWidth") private var previewLineWidth = 820.0
    @AppStorage("previewAnimations") private var previewAnimations = true
    @AppStorage("syncPreviewWithEditor") private var syncPreviewWithEditor = true
    @StateObject private var commandCenter = EditorCommandCenter()
    @State private var isExportingHTML = false
    @State private var exportMessage: String?
    @State private var editorSelection = EditorSelection.start
    @State private var parsedDocument: ParsedMarkdownDocument
    @State private var parsedMarkdown: String
    @State private var pendingParseTask: Task<Void, Never>?
    @State private var pendingEditingIdleTask: Task<Void, Never>?
    @State private var isEditorEditing = false
    @State private var pendingPreviewMarkdown: String?

    init(document: Binding<MarkdownDocument>, documentURL: URL?) {
        self._document = document
        self.documentURL = documentURL

        let initialMarkdown = document.wrappedValue.text
        self._parsedDocument = State(initialValue: MarkdownParser.parse(initialMarkdown))
        self._parsedMarkdown = State(initialValue: initialMarkdown)
    }

    private var selectedLayout: Binding<LayoutMode> {
        Binding(
            get: { LayoutMode(rawValue: layoutMode) ?? .split },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.18)) {
                    layoutMode = mode.rawValue
                }
            }
        )
    }

    private var selectedTheme: Binding<MdoraTheme> {
        Binding(
            get: { MdoraTheme(rawValue: themeName) ?? .system },
            set: { themeName = $0.rawValue }
        )
    }

    private var theme: MdoraTheme {
        MdoraTheme(rawValue: themeName) ?? .system
    }

    private var previewStyle: MarkdownPreviewStyle {
        MarkdownPreviewStyle(
            bodyFontSize: CGFloat(previewFontSize.clamped(to: 13 ... 22)),
            lineWidth: CGFloat(previewLineWidth.clamped(to: 620 ... 1040)),
            animationsEnabled: previewAnimations,
            syncsToEditor: syncPreviewWithEditor
        )
    }

    var body: some View {
        let parsed = parsedDocument

        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                HSplitView {
                    if selectedLayout.wrappedValue.showsEditor {
                        MarkdownEditor(
                            text: $document.text,
                            commandCenter: commandCenter,
                            theme: theme,
                            fontSize: CGFloat(editorFontSize.clamped(to: 12 ... 22)),
                            focusMode: focusMode,
                            documentURL: documentURL,
                            onSelectionChange: updateEditorSelection,
                            onEditingActivity: noteEditorEditing
                        )
                            .frame(minWidth: 360, idealWidth: 560)
                    }

                    if selectedLayout.wrappedValue.showsPreview {
                        MarkdownPreview(
                            markdown: parsedMarkdown,
                            document: parsed,
                            theme: theme,
                            style: previewStyle,
                            activeLine: selectedLayout.wrappedValue.showsEditor ? editorSelection.line : nil,
                            documentURL: documentURL,
                            onTaskStateChange: updateTaskState
                        )
                            .frame(minWidth: 360, idealWidth: 560)
                    }

                    if showInspector && !focusMode {
                        DocumentInspector(document: parsed, theme: theme)
                            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .background(theme.palette.windowColor)

                FloatingLayoutPicker(layoutMode: selectedLayout, theme: theme)
                    .padding(.trailing, showInspector && !focusMode ? 276 : 16)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(10)
            }

            StatusBar(
                stats: parsed.stats,
                markers: parsed.markers,
                diagnostics: parsed.diagnostics,
                theme: theme,
                focusMode: focusMode,
                selection: editorSelection,
                message: exportMessage
            )
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(theme.palette.windowColor)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    commandCenter.send(.bold)
                } label: {
                    Image(systemName: "bold")
                }
                .help("加粗 (⌘B)")
                .keyboardShortcut("b", modifiers: .command)

                Button {
                    commandCenter.send(.italic)
                } label: {
                    Image(systemName: "italic")
                }
                .help("斜体 (⌘I)")
                .keyboardShortcut("i", modifiers: .command)

                Button {
                    commandCenter.send(.link)
                } label: {
                    Image(systemName: "link")
                }
                .help("插入超链接 (⌘K)")
                .keyboardShortcut("k", modifiers: .command)

                Menu {
                    Button("删除线") {
                        commandCenter.send(.strikethrough)
                    }

                    Button("高亮") {
                        commandCenter.send(.highlight)
                    }

                    Button("上标") {
                        commandCenter.send(.superscript)
                    }

                    Button("下标") {
                        commandCenter.send(.subscriptText)
                    }

                    Button("行内代码") {
                        commandCenter.send(.inlineCode)
                    }

                    Button("键盘键帽") {
                        commandCenter.send(.keyboard)
                    }

                    Button("学术引用") {
                        commandCenter.send(.citation)
                    }

                    Button("Wiki 链接") {
                        commandCenter.send(.wikiLink)
                    }
                } label: {
                    Image(systemName: "textformat")
                }
                .help("更多文本格式")

                Menu {
                    Button("无序列表") {
                        commandCenter.send(.unorderedList)
                    }
                    .keyboardShortcut("u", modifiers: .command)

                    Button("有序列表") {
                        commandCenter.send(.orderedList)
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button("待办列表") {
                        commandCenter.send(.task)
                    }
                    .keyboardShortcut("t", modifiers: .command)

                    Button("块引用") {
                        commandCenter.send(.quote)
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("列表与引用")

                Menu {
                    Button("插入图片...") {
                        commandCenter.send(.image)
                    }

                    Button("插入表格...") {
                        commandCenter.send(.table)
                    }

                    Button("插入代码区块...") {
                        commandCenter.send(.codeBlock)
                    }
                    .keyboardShortcut("/", modifiers: .command)

                    Button("插入数学公式块...") {
                        commandCenter.send(.mathBlock)
                    }

                    Button("插入脚注定义...") {
                        commandCenter.send(.footnote)
                    }

                    Button("插入参考链接定义...") {
                        commandCenter.send(.linkReference)
                    }

                    Button("插入定义列表...") {
                        commandCenter.send(.definitionList)
                    }

                    Button("自动生成目录 (TOC)...") {
                        commandCenter.send(.tableOfContents(parsed.outline))
                    }

                    Divider()

                    Menu("提示框") {
                        ForEach(CalloutKind.allCases, id: \.self) { kind in
                            Button(kind.title) {
                                commandCenter.send(.callout(kind))
                            }
                        }
                    }

                    Menu("图表") {
                        ForEach(DiagramKind.allCases, id: \.self) { kind in
                            Button(kind.title) {
                                commandCenter.send(.diagram(kind))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus.square")
                }
                .help("插入内容")
            }

            ToolbarItemGroup {
                Picker("主题", selection: selectedTheme) {
                    ForEach(MdoraTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .frame(width: 120)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showInspector.toggle()
                    }
                } label: {
                    Label("大纲分析", systemImage: showInspector ? "sidebar.trailing" : "sidebar.trailing")
                }
                .help("开启/关闭大纲分析栏")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: focusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
                }
                .help("专注模式")

                Menu {
                    Button {
                        refreshPreviewNow()
                    } label: {
                        Label("立即刷新预览/分析", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)

                    Divider()

                    Toggle("启用过渡动画", isOn: $previewAnimations)
                    Toggle("同步滚动跟随", isOn: $syncPreviewWithEditor)
                    Toggle("专注无干扰模式", isOn: $focusMode)

                    Divider()

                    Button("增大编辑器字号") {
                        editorFontSize = (editorFontSize + 1).clamped(to: 12 ... 22)
                    }

                    Button("减小编辑器字号") {
                        editorFontSize = (editorFontSize - 1).clamped(to: 12 ... 22)
                    }

                    Button("增大预览区字号") {
                        previewFontSize = (previewFontSize + 1).clamped(to: 13 ... 22)
                    }

                    Button("减小预览区字号") {
                        previewFontSize = (previewFontSize - 1).clamped(to: 13 ... 22)
                    }

                    Divider()

                    Button("收窄显示边界") {
                        previewLineWidth = (previewLineWidth - 80).clamped(to: 620 ... 1040)
                    }

                    Button("放宽显示边界") {
                        previewLineWidth = (previewLineWidth + 80).clamped(to: 620 ... 1040)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("编辑器与视图排版选项")

                Menu {
                    Button("导出为 HTML 网页...") {
                        isExportingHTML = true
                    }
                    Button("导出为 PDF 电子书...") {
                        exportToPDF()
                    }
                } label: {
                    Label("文件导出", systemImage: "square.and.arrow.up")
                }
                .help("导出当前文档为 HTML 网页或 PDF 格式")
            }
        }
        .fileExporter(
            isPresented: $isExportingHTML,
            document: HTMLExportDocument(markdown: document.text),
            contentType: .html,
            defaultFilename: "Mdora 导出文档.html"
        ) { result in
            switch result {
            case .success:
                exportMessage = "导出 HTML 成功"
            case .failure(let error):
                exportMessage = error.localizedDescription
            }
        }
        .onChange(of: document.text) { _, newMarkdown in
            scheduleParsedDocumentUpdate(for: newMarkdown)
        }
        .onAppear {
            refreshParsedDocumentIfNeeded(for: document.text)
        }
        .onDisappear {
            pendingParseTask?.cancel()
            pendingEditingIdleTask?.cancel()
        }
    }

    private func updateEditorSelection(_ selection: EditorSelection) {
        guard editorSelection != selection else { return }
        editorSelection = selection
    }

    @MainActor
    private func noteEditorEditing() {
        isEditorEditing = true
        pendingEditingIdleTask?.cancel()
        pendingEditingIdleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: editingPreviewPauseDelay)
            } catch {
                return
            }

            finishEditorEditingPause()
        }
    }

    @MainActor
    private func finishEditorEditingPause() {
        isEditorEditing = false
        let markdown = pendingPreviewMarkdown ?? document.text
        pendingPreviewMarkdown = nil
        scheduleParsedDocumentUpdate(for: markdown, force: true)
    }

    @MainActor
    private func refreshPreviewNow() {
        pendingParseTask?.cancel()
        pendingEditingIdleTask?.cancel()
        isEditorEditing = false
        pendingPreviewMarkdown = nil
        refreshParsedDocument(for: document.text)
        exportMessage = "预览与分析已刷新"
    }

    private func updateTaskState(blockIndex: Int, itemIndex: Int, state: TaskState) {
        guard let updatedMarkdown = MarkdownTaskSourceEditor.updatingTaskState(
            in: document.text,
            document: parsedDocument,
            blockIndex: blockIndex,
            itemIndex: itemIndex,
            to: state
        ) else {
            return
        }

        pendingParseTask?.cancel()
        document.text = updatedMarkdown
        parsedDocument = MarkdownParser.parse(updatedMarkdown)
        parsedMarkdown = updatedMarkdown
        editorSelection = EditorSelection(
            line: parsedDocument.sourceRange(forBlockIndex: blockIndex)?.startLine ?? editorSelection.line,
            column: editorSelection.column,
            selectedLength: editorSelection.selectedLength
        )
        exportMessage = "任务状态已更新为 \(state.title)"
    }

    @MainActor
    private func scheduleParsedDocumentUpdate(for markdown: String, force: Bool = false) {
        pendingParseTask?.cancel()

        if isEditorEditing && !force {
            pendingPreviewMarkdown = markdown
            return
        }

        let delay = parseDebounceDelay(for: markdown)
        pendingParseTask = Task {
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            let parsed = await Task.detached(priority: .userInitiated) {
                MarkdownParser.parse(markdown)
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard parsedMarkdown != markdown else { return }
                parsedDocument = parsed
                parsedMarkdown = markdown
            }
        }
    }

    @MainActor
    private func refreshParsedDocumentIfNeeded(for markdown: String) {
        guard parsedMarkdown != markdown else { return }
        refreshParsedDocument(for: markdown)
    }

    @MainActor
    private func refreshParsedDocument(for markdown: String) {
        parsedDocument = MarkdownParser.parse(markdown)
        parsedMarkdown = markdown
    }

    private func parseDebounceDelay(for markdown: String) -> UInt64 {
        markdown.count > 60_000 ? 450_000_000 : 180_000_000
    }

    private var editingPreviewPauseDelay: UInt64 {
        document.text.count > 60_000 ? 1_000_000_000 : 650_000_000
    }

    private func exportToPDF() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let defaultName = documentURL?.deletingPathExtension().lastPathComponent ?? "未命名"
        savePanel.nameFieldStringValue = "\(defaultName).pdf"

        withAnimation {
            exportMessage = "正在准备 PDF..."
        }

        savePanel.begin { response in
            guard response == .OK, let destinationURL = savePanel.url else {
                withAnimation {
                    exportMessage = nil
                }
                return
            }

            withAnimation {
                exportMessage = "正在导出 PDF..."
            }

            PDFExporter.export(
                markdown: document.text,
                title: defaultName,
                baseURL: documentURL?.deletingLastPathComponent(),
                destinationURL: destinationURL
            ) { result in
                DispatchQueue.main.async {
                    withAnimation {
                        switch result {
                        case .success:
                            exportMessage = "导出 PDF 成功"
                        case .failure(let error):
                            exportMessage = "PDF 导出失败: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

enum LayoutMode: String, CaseIterable, Identifiable {
    case editor
    case split
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor:
            "编辑器"
        case .split:
            "双栏分屏"
        case .preview:
            "纯预览区"
        }
    }

    var systemImage: String {
        switch self {
        case .editor:
            "square.and.pencil"
        case .split:
            "rectangle.split.2x1"
        case .preview:
            "doc.richtext"
        }
    }

    var showsEditor: Bool {
        self == .editor || self == .split
    }

    var showsPreview: Bool {
        self == .preview || self == .split
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct FloatingLayoutPicker: View {
    @Binding var layoutMode: LayoutMode
    let theme: MdoraTheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(LayoutMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        layoutMode = mode
                    }
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(layoutMode == mode ? .white : theme.palette.textColor.opacity(0.72))
                        .frame(width: 26, height: 22)
                        .background(layoutMode == mode ? theme.palette.accentColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(mode.title)
            }
        }
        .padding(3)
        .background(theme.palette.surfaceColor.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(theme.palette.borderColor.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .opacity(isHovered ? 1.0 : 0.68)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
