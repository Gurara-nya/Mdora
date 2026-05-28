import MdoraCore
import SwiftUI

struct EditorWindow: View {
    @Binding var document: MarkdownDocument
    @AppStorage("editorLayoutMode") private var layoutMode = LayoutMode.split.rawValue
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @AppStorage("previewLineWidth") private var previewLineWidth = 820.0
    @AppStorage("previewAnimations") private var previewAnimations = true
    @StateObject private var commandCenter = EditorCommandCenter()
    @State private var isExportingHTML = false
    @State private var exportMessage: String?

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

    private var parsedDocument: ParsedMarkdownDocument {
        MarkdownParser.parse(document.text)
    }

    private var previewStyle: MarkdownPreviewStyle {
        MarkdownPreviewStyle(
            bodyFontSize: CGFloat(previewFontSize.clamped(to: 13 ... 22)),
            lineWidth: CGFloat(previewLineWidth.clamped(to: 620 ... 1040)),
            animationsEnabled: previewAnimations
        )
    }

    var body: some View {
        let parsed = parsedDocument

        VStack(spacing: 0) {
            HSplitView {
                if selectedLayout.wrappedValue.showsEditor {
                    MarkdownEditor(
                        text: $document.text,
                        commandCenter: commandCenter,
                        theme: theme,
                        fontSize: CGFloat(editorFontSize.clamped(to: 12 ... 22))
                    )
                        .frame(minWidth: 360, idealWidth: 560)
                }

                if selectedLayout.wrappedValue.showsPreview {
                    MarkdownPreview(
                        markdown: document.text,
                        theme: theme,
                        style: previewStyle
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

            StatusBar(
                stats: parsed.stats,
                markers: parsed.markers,
                diagnostics: parsed.diagnostics,
                theme: theme,
                focusMode: focusMode,
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
                .help("Bold")
                .keyboardShortcut("b", modifiers: .command)

                Button {
                    commandCenter.send(.italic)
                } label: {
                    Image(systemName: "italic")
                }
                .help("Italic")
                .keyboardShortcut("i", modifiers: .command)

                Button {
                    commandCenter.send(.strikethrough)
                } label: {
                    Image(systemName: "strikethrough")
                }
                .help("Strikethrough")

                Button {
                    commandCenter.send(.inlineCode)
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Inline code")

                Button {
                    commandCenter.send(.link)
                } label: {
                    Image(systemName: "link")
                }
                .help("Link")
                .keyboardShortcut("k", modifiers: .command)

                Button {
                    commandCenter.send(.wikiLink)
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                }
                .help("Wiki link")

                Divider()

                Menu {
                    ForEach(1 ... 3, id: \.self) { level in
                        Button("Heading \(level)") {
                            commandCenter.send(.heading(level))
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help("Heading")

                Button {
                    commandCenter.send(.unorderedList)
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Bulleted list")

                Button {
                    commandCenter.send(.orderedList)
                } label: {
                    Image(systemName: "list.number")
                }
                .help("Numbered list")

                Button {
                    commandCenter.send(.task)
                } label: {
                    Image(systemName: "checklist")
                }
                .help("Task")

                Button {
                    commandCenter.send(.quote)
                } label: {
                    Image(systemName: "quote.opening")
                }
                .help("Quote")

                Button {
                    commandCenter.send(.codeBlock)
                } label: {
                    Image(systemName: "curlybraces.square")
                }
                .help("Code block")

                Menu {
                    Button("Image") {
                        commandCenter.send(.image)
                    }

                    Button("Table") {
                        commandCenter.send(.table)
                    }

                    Button("Math Block") {
                        commandCenter.send(.mathBlock)
                    }

                    Button("Footnote") {
                        commandCenter.send(.footnote)
                    }

                    Button("Reference Link") {
                        commandCenter.send(.linkReference)
                    }

                    Button("Definition List") {
                        commandCenter.send(.definitionList)
                    }

                    Button("Table of Contents") {
                        commandCenter.send(.tableOfContents(parsed.outline))
                    }

                    Divider()

                    ForEach(DiagramKind.allCases, id: \.self) { kind in
                        Button(kind.title) {
                            commandCenter.send(.diagram(kind))
                        }
                    }
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .help("Insert block")

                Menu {
                    ForEach(CalloutKind.allCases, id: \.self) { kind in
                        Button(kind.title) {
                            commandCenter.send(.callout(kind))
                        }
                    }
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                }
                .help("Callout")
            }

            ToolbarItemGroup {
                Picker("Layout", selection: selectedLayout) {
                    ForEach(LayoutMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Picker("Theme", selection: selectedTheme) {
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
                    Label("Inspector", systemImage: showInspector ? "sidebar.trailing" : "sidebar.trailing")
                }
                .help("Toggle inspector")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: focusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
                }
                .help("Focus mode")

                Menu {
                    Toggle("Preview Animation", isOn: $previewAnimations)
                    Toggle("Focus Mode", isOn: $focusMode)

                    Divider()

                    Button("Editor Font Larger") {
                        editorFontSize = (editorFontSize + 1).clamped(to: 12 ... 22)
                    }

                    Button("Editor Font Smaller") {
                        editorFontSize = (editorFontSize - 1).clamped(to: 12 ... 22)
                    }

                    Button("Preview Font Larger") {
                        previewFontSize = (previewFontSize + 1).clamped(to: 13 ... 22)
                    }

                    Button("Preview Font Smaller") {
                        previewFontSize = (previewFontSize - 1).clamped(to: 13 ... 22)
                    }

                    Divider()

                    Button("Narrow Preview") {
                        previewLineWidth = (previewLineWidth - 80).clamped(to: 620 ... 1040)
                    }

                    Button("Wide Preview") {
                        previewLineWidth = (previewLineWidth + 80).clamped(to: 620 ... 1040)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Writing view options")

                Button {
                    isExportingHTML = true
                } label: {
                    Label("Export HTML", systemImage: "square.and.arrow.up")
                }
                .help("Export this Markdown document as HTML")
            }
        }
        .fileExporter(
            isPresented: $isExportingHTML,
            document: HTMLExportDocument(markdown: document.text),
            contentType: .html,
            defaultFilename: "Mdora Export.html"
        ) { result in
            switch result {
            case .success:
                exportMessage = "Exported HTML"
            case .failure(let error):
                exportMessage = error.localizedDescription
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
            "Editor"
        case .split:
            "Split"
        case .preview:
            "Preview"
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
