import MdoraCore
import SwiftUI

struct StatusBar: View {
    let stats: MarkdownStats
    let markers: MarkdownMarkers
    let diagnostics: [MarkdownDiagnostic]
    let theme: MdoraTheme
    let focusMode: Bool
    let selection: EditorSelection
    let message: String?

    // Toggle states persisted in AppStorage
    @AppStorage("statusBar_showWords") private var showWords = true
    @AppStorage("statusBar_showCharacters") private var showCharacters = true
    @AppStorage("statusBar_showLines") private var showLines = true
    @AppStorage("statusBar_showReadingTime") private var showReadingTime = true
    @AppStorage("statusBar_showBlockKinds") private var showBlockKinds = false
    @AppStorage("statusBar_showLinks") private var showLinks = true
    @AppStorage("statusBar_showEmails") private var showEmails = false
    @AppStorage("statusBar_showTags") private var showTags = true
    @AppStorage("statusBar_showWikiEmbeds") private var showWikiEmbeds = false
    @AppStorage("statusBar_showBlockIDs") private var showBlockIDs = false
    @AppStorage("statusBar_showAnchors") private var showAnchors = false
    @AppStorage("statusBar_showAbbreviations") private var showAbbreviations = false
    @AppStorage("statusBar_showLinkRefs") private var showLinkRefs = false
    @AppStorage("statusBar_showTaskFlags") private var showTaskFlags = false
    @AppStorage("statusBar_showTasks") private var showTasks = true
    @AppStorage("statusBar_showCriticEdits") private var showCriticEdits = false
    @AppStorage("statusBar_showDiagrams") private var showDiagrams = false
    @AppStorage("statusBar_showCallouts") private var showCallouts = false
    @AppStorage("statusBar_showDiagnostics") private var showDiagnostics = true
    @AppStorage("statusBar_showCaretPos") private var showCaretPos = true

    @State private var isShowingConfig = false

    var body: some View {
        HStack(spacing: 12) {
            // Document Status Text Items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if showWords {
                        Text("\(stats.words) 字")
                    }
                    if showCharacters {
                        Text("\(stats.characters) 字符")
                    }
                    if showLines {
                        Text("\(stats.lines) 行")
                    }
                    if showReadingTime {
                        Text("预计阅读 \(stats.readingMinutes) 分")
                    }
                    if showBlockKinds {
                        Text("\(stats.blockKinds.count) 类区块")
                    }
                    if showLinks {
                        Text("\(markers.links.count) 链接")
                    }
                    if showEmails {
                        Text("\(markers.emailLinks.count) 邮箱")
                    }
                    if showTags {
                        Text("\(markers.tags.count) 标签")
                    }
                    if showWikiEmbeds {
                        Text("\(markers.wikiEmbeds.count) 嵌入")
                    }
                    if showBlockIDs {
                        Text("\(markers.blockIDs.count) 块 ID")
                    }
                    if showAnchors {
                        Text("\(markers.customAnchors.count) 锚点")
                    }
                    if showAbbreviations {
                        Text("\(markers.abbreviations.count) 缩写")
                    }
                    if showLinkRefs {
                        Text("\(markers.linkReferences.count) 参考")
                    }
                    if showTaskFlags {
                        Text("\(markers.taskTokens.count) 标记")
                    }
                    if showTasks {
                        Text("\(markers.taskStates.reduce(0) { $0 + $1.count }) 任务")
                    }
                    if showCriticEdits {
                        Text("\(markers.criticMarkupCount) 批注")
                    }
                    if showDiagrams {
                        Text("\(markers.diagrams.count) 图表")
                    }
                    if showCallouts {
                        Text("\(markers.callouts.count) 提示框")
                    }
                    if showDiagnostics {
                        Text("\(diagnostics.count) 警告")
                    }
                    if showCaretPos {
                        Text("行 \(selection.line)，列 \(selection.column)")
                    }

                    if selection.selectedLength > 0 {
                        Text("已选 \(selection.selectedLength) 字")
                    }

                    if focusMode {
                        Text("专注模式")
                            .foregroundStyle(theme.palette.accentColor)
                    }
                }
            }

            Spacer()

            if let message {
                Text(message)
                    .foregroundStyle(theme.palette.accentColor)
                    .transition(.opacity)
            }

            // Customize settings button
            Button {
                isShowingConfig.toggle()
            } label: {
                Image(systemName: "slider.horizontal.2.square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isShowingConfig ? theme.palette.accentColor : theme.palette.mutedColor)
            }
            .buttonStyle(.plain)
            .help("自定义状态栏统计显示")
            .popover(isPresented: $isShowingConfig, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("状态栏统计信息设置")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Divider()

                    Grid(horizontalSpacing: 18, verticalSpacing: 10) {
                        GridRow {
                            Toggle("字数统计", isOn: $showWords)
                            Toggle("字符总数", isOn: $showCharacters)
                            Toggle("文档行数", isOn: $showLines)
                        }
                        GridRow {
                            Toggle("阅读时间", isOn: $showReadingTime)
                            Toggle("分块种类", isOn: $showBlockKinds)
                            Toggle("网页链接", isOn: $showLinks)
                        }
                        GridRow {
                            Toggle("电子邮箱", isOn: $showEmails)
                            Toggle("标签列表", isOn: $showTags)
                            Toggle("Wiki 嵌入", isOn: $showWikiEmbeds)
                        }
                        GridRow {
                            Toggle("块 ID", isOn: $showBlockIDs)
                            Toggle("标题锚点", isOn: $showAnchors)
                            Toggle("缩写定义", isOn: $showAbbreviations)
                        }
                        GridRow {
                            Toggle("参考引用", isOn: $showLinkRefs)
                            Toggle("任务标记", isOn: $showTaskFlags)
                            Toggle("待办任务", isOn: $showTasks)
                        }
                        GridRow {
                            Toggle("审阅批注", isOn: $showCriticEdits)
                            Toggle("图表区块", isOn: $showDiagrams)
                            Toggle("信息提示", isOn: $showCallouts)
                        }
                        GridRow {
                            Toggle("语法诊断", isOn: $showDiagnostics)
                            Toggle("光标位置", isOn: $showCaretPos)
                            Color.clear
                        }
                    }
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                }
                .padding(14)
                .frame(width: 320)
            }
        }
        .font(.system(size: 11, design: .default))
        .foregroundStyle(theme.palette.mutedColor)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(theme.palette.surfaceColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.palette.borderColor.opacity(0.38)),
            alignment: .top
        )
    }
}
