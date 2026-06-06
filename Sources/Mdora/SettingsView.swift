import SwiftUI

struct SettingsView: View {
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @AppStorage("previewLineWidth") private var previewLineWidth = 820.0
    @AppStorage("previewAnimations") private var previewAnimations = true
    @AppStorage("syncPreviewWithEditor") private var syncPreviewWithEditor = true
    @AppStorage("mdoraPerformanceMode") private var performanceMode = false
    @AppStorage("mdoraAnimationCharThreshold") private var animationCharThreshold = 60_000.0
    @AppStorage("mdoraMaxAnimatedBlocks") private var maxAnimatedBlocks = 900.0
    @AppStorage("mdoraMaxTableRows") private var maxTableRows = 120.0
    @AppStorage("mdoraMaxDiagramNodes") private var maxDiagramNodes = 36.0
    @AppStorage("mdoraMaxDiagramEdges") private var maxDiagramEdges = 64.0
    @AppStorage("mdoraMaxMathExpressionLength") private var maxMathExpressionLength = 2_400.0
    @AppStorage("mdoraMaxImagePixelDimension") private var maxImagePixelDimension = 1_600.0

    private var selectedTheme: Binding<MdoraTheme> {
        Binding(
            get: { MdoraTheme(rawValue: themeName) ?? .system },
            set: { themeName = $0.rawValue }
        )
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("常规", systemImage: "gearshape.fill")
                }

            typographyTab
                .tabItem {
                    Label("编辑器与样式", systemImage: "textformat.size")
                }

            shortcutsTab
                .tabItem {
                    Label("快捷键", systemImage: "keyboard.fill")
                }

            performanceTab
                .tabItem {
                    Label("性能", systemImage: "speedometer")
                }
        }
        .padding(20)
        .frame(width: 480, height: 380)
    }

    private var generalTab: some View {
        Form {
            Section("界面设置") {
                Picker("应用主题", selection: selectedTheme) {
                    ForEach(MdoraTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.menu)

                Toggle("显示文档大纲检查器", isOn: $showInspector)
                    .help("切换右侧的文档大纲与特征分析栏（包含大纲、标签、链接和诊断等）。")

                Toggle("专注模式 (无干扰写作)", isOn: $focusMode)
                    .help("自动淡化非活动行，隐藏右侧大纲栏，让您更专注于当前创作的文本段落。")
            }
            .padding(.bottom, 12)

            Section("预览偏好设置") {
                Toggle("预览跟随光标同步滚动", isOn: $syncPreviewWithEditor)
                    .help("保持预览区自动滚动，始终与您编辑器中的光标段落居中对齐。")

                Toggle("启用丝滑的动画过渡效果", isOn: $previewAnimations)
                    .help("当预览内容或布局发生改变时，应用精美的平滑过渡动画。")
            }
        }
        .padding(14)
    }

    private var typographyTab: some View {
        Form {
            Section("排版与字号大小调整") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("编辑器字号")
                        Spacer()
                        Text("\(Int(editorFontSize)) pt").foregroundColor(.secondary)
                    }
                    Slider(value: $editorFontSize, in: 12 ... 22, step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("预览区正文字号")
                        Spacer()
                        Text("\(Int(previewFontSize)) pt").foregroundColor(.secondary)
                    }
                    Slider(value: $previewFontSize, in: 13 ... 22, step: 1)
                }
            }
            .padding(.bottom, 10)

            Section("预览排版宽度限制") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("预览区最大阅读宽度")
                        Spacer()
                        Text("\(Int(previewLineWidth)) px").foregroundColor(.secondary)
                    }
                    Slider(value: $previewLineWidth, in: 620 ... 1040, step: 20)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("恢复默认设置", role: .destructive, action: restoreDefaults)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(14)
    }

    private var performanceTab: some View {
        Form {
            Section("2.0 流畅体验") {
                Toggle("开启高性能模式", isOn: $performanceMode)
                    .help("面向超大文档的编辑场景，优先保证输入和滚动顺滑。")

                Toggle("启用动画和同步刷新", isOn: $previewAnimations)
                    .help("若编辑有明显卡顿，可先关闭本项再逐步恢复。")

                Toggle("预览跟随光标同步滚动", isOn: $syncPreviewWithEditor)
                    .help("高性能模式下建议保留开启，避免频繁跳动。")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("预览动画自动降级阈值（字符）")
                        Spacer()
                        Text("\(Int(animationCharThreshold))").foregroundColor(.secondary)
                    }

                    Slider(value: $animationCharThreshold, in: 20_000 ... 200_000, step: 5_000)
                        .help("文本长度超过该值时会自动降级预览动画开销。")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("最大动画块数")
                        Spacer()
                        Text("\(Int(maxAnimatedBlocks))").foregroundColor(.secondary)
                    }

                    Slider(value: $maxAnimatedBlocks, in: 180 ... 2_000, step: 20)
                        .help("超出块数后暂时禁用滚动到位动画，保留编辑功能。")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("表格最大行数（超出折叠）")
                        Spacer()
                        Text("\(Int(maxTableRows))").foregroundColor(.secondary)
                    }

                    Slider(value: $maxTableRows, in: 20 ... 400, step: 10)
                        .help("超大表格仅展示前 N 行并给出裁剪提示。")
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("图谱最大节点数")
                            Spacer()
                            Text("\(Int(maxDiagramNodes))").foregroundColor(.secondary)
                        }
                        Slider(value: $maxDiagramNodes, in: 8 ... 120, step: 4)
                            .help("图谱节点过多时降级为摘要展示。")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("图谱最大连线数")
                            Spacer()
                            Text("\(Int(maxDiagramEdges))").foregroundColor(.secondary)
                        }
                        Slider(value: $maxDiagramEdges, in: 8 ... 240, step: 4)
                            .help("连线过多时不展开全部边信息。")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("数学公式字符上限（超出降级）")
                        Spacer()
                        Text("\(Int(maxMathExpressionLength))").foregroundColor(.secondary)
                    }

                    Slider(value: $maxMathExpressionLength, in: 300 ... 6_000, step: 100)
                        .help("长公式默认保留摘要并可按需手动渲染。")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("本地图片预览边长上限（px）")
                        Spacer()
                        Text("\(Int(maxImagePixelDimension))").foregroundColor(.secondary)
                    }

                    Slider(value: $maxImagePixelDimension, in: 320 ... 3_200, step: 80)
                        .help("越小越省资源；点击「打开原文件」查看全尺寸。")
                }
            }
            .padding(.bottom, 12)

            Section("性能说明") {
                Text("高性能模式会降低部分高消耗样式计算，核心解析、导出和状态统计功能不变。适合处理长文档与多媒体密集文档。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("2.0 预设") {
                HStack(spacing: 10) {
                    Button("极速") {
                        previewAnimations = false
                        performanceMode = true
                        animationCharThreshold = 18_000
                        maxAnimatedBlocks = 240
                        maxTableRows = 40
                        maxDiagramNodes = 16
                        maxDiagramEdges = 28
                        maxMathExpressionLength = 300
                        maxImagePixelDimension = 720
                    }
                    .buttonStyle(.bordered)

                    Button("均衡") {
                        previewAnimations = true
                        performanceMode = true
                        animationCharThreshold = 60_000
                        maxAnimatedBlocks = 700
                        maxTableRows = 120
                        maxDiagramNodes = 36
                        maxDiagramEdges = 64
                        maxMathExpressionLength = 2_400
                        maxImagePixelDimension = 1_600
                    }
                    .buttonStyle(.borderedProminent)

                    Button("完整") {
                        previewAnimations = true
                        performanceMode = false
                        animationCharThreshold = 200_000
                        maxAnimatedBlocks = 2_000
                        maxTableRows = 400
                        maxDiagramNodes = 120
                        maxDiagramEdges = 240
                        maxMathExpressionLength = 6_000
                        maxImagePixelDimension = 3_200
                    }
                    .buttonStyle(.bordered)
                }

                Text("预设会批量调整各性能阈值。若出现卡顿，先切到“极速”并在关键位置逐步恢复。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("恢复默认设置", role: .destructive, action: restoreDefaults)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(14)
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Markdown 常用编辑快捷键")
                    .font(.headline)
                    .padding(.bottom, 4)

                Group {
                    ShortcutRow(keys: "⌘ B", action: "加粗选中文本")
                    ShortcutRow(keys: "⌘ I", action: "倾斜选中文本")
                    ShortcutRow(keys: "⌘ K", action: "插入网页超链接")
                    ShortcutRow(keys: "⌘ Shift K", action: "插入 Wiki 双链链接")
                    ShortcutRow(keys: "⌘ 1/2/3", action: "套用 1/2/3 级标题样式")
                    ShortcutRow(keys: "⌘ U", action: "快速插入无序列表")
                    ShortcutRow(keys: "⌘ O", action: "快速插入有序列表")
                    ShortcutRow(keys: "⌘ T", action: "快速插入待办任务框")
                    ShortcutRow(keys: "⌘ /", action: "将选区包裹为代码区块")
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("智能编辑器书写特性")
                        .font(.subheadline.bold())
                    Text("• 在待办列表、有序/无序列表、引用或首行缩进处按 **回车 (Return)**，会自动在下一行延续排版标记。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                Text("• 在空列表项处按 **回车 (Return)**，会自动清除当前的格式前缀。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
    }

    private func restoreDefaults() {
        withAnimation {
            themeName = MdoraTheme.system.rawValue
            showInspector = true
            focusMode = false
            editorFontSize = 15.0
            previewFontSize = 16.0
            previewLineWidth = 820.0
            previewAnimations = true
            syncPreviewWithEditor = true
            performanceMode = false
            animationCharThreshold = 60_000.0
            maxAnimatedBlocks = 900.0
            maxTableRows = 120.0
            maxDiagramNodes = 36.0
            maxDiagramEdges = 64.0
            maxMathExpressionLength = 2_400.0
            maxImagePixelDimension = 1_600.0
        }
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(action)
                .foregroundColor(.primary)
            Spacer()
            Text(keys)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
        }
    }
}
