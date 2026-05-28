import MdoraCore
import SwiftUI

struct DocumentInspector: View {
    let document: ParsedMarkdownDocument
    let theme: MdoraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InspectorSection(title: "文档统计", systemImage: "chart.bar", theme: theme) {
                    StatGrid(document: document, theme: theme)
                }

                if !document.metadata.isEmpty {
                    InspectorSection(title: "文档元数据", systemImage: "tag", theme: theme) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(document.metadata) { item in
                                MetadataRow(item: item, theme: theme)
                            }
                        }
                    }
                }

                InspectorSection(title: "兼容性分析", systemImage: "checkmark.seal", theme: theme) {
                    CompatibilitySummary(document: document, theme: theme)
                }

                if !document.diagnostics.isEmpty {
                    InspectorSection(title: "语法诊断", systemImage: "stethoscope", theme: theme) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(document.diagnostics) { diagnostic in
                                DiagnosticRow(diagnostic: diagnostic, theme: theme)
                            }
                        }
                    }
                }

                InspectorSection(title: "标题大纲", systemImage: "list.bullet.indent", theme: theme) {
                    if document.outline.isEmpty {
                        EmptyInspectorText("未检测到标题大纲", theme: theme)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(document.outline) { symbol in
                                OutlineItemRow(symbol: symbol, theme: theme)
                                    .padding(.leading, CGFloat(max(0, symbol.level - 1)) * 12)
                            }
                        }
                    }
                }

                InspectorSection(title: "特征统计", systemImage: "scope", theme: theme) {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkerRow(title: "标签总数", value: document.markers.tags.count, systemImage: "number", theme: theme)
                        MarkerRow(title: "提及用户 (@)", value: document.markers.mentions.count, systemImage: "at", theme: theme)
                        MarkerRow(title: "网页超链接", value: document.markers.links.count, systemImage: "link", theme: theme)
                        MarkerRow(title: "自动识别链接", value: document.markers.autoLinks.count, systemImage: "link.badge.plus", theme: theme)
                        MarkerRow(title: "电子邮箱", value: document.markers.emailLinks.count, systemImage: "envelope", theme: theme)
                        MarkerRow(title: "Wiki 链接", value: document.markers.wikiLinks.count, systemImage: "rectangle.stack", theme: theme)
                        MarkerRow(title: "Wiki 嵌入", value: document.markers.wikiEmbeds.count, systemImage: "paperclip", theme: theme)
                        MarkerRow(title: "块 ID (Block ID)", value: document.markers.blockIDs.count, systemImage: "text.line.first.and.arrowtriangle.forward", theme: theme)
                        MarkerRow(title: "标题锚点", value: document.markers.customAnchors.count, systemImage: "number.square", theme: theme)
                        MarkerRow(title: "缩写词定义", value: document.markers.abbreviations.count, systemImage: "textformat.abc.dottedunderline", theme: theme)
                        MarkerRow(title: "参考链接定义", value: document.markers.linkReferences.count, systemImage: "link.badge.plus", theme: theme)
                        MarkerRow(title: "图片总数", value: document.markers.images.count, systemImage: "photo", theme: theme)
                        MarkerRow(title: "图片参考定义", value: document.markers.imageReferences.count, systemImage: "photo.badge.arrow.down", theme: theme)
                        MarkerRow(title: "脚注定义", value: document.markers.footnotes.count, systemImage: "text.badge.checkmark", theme: theme)
                        MarkerRow(title: "HTML 注释", value: document.markers.htmlComments.count, systemImage: "text.bubble", theme: theme)
                        MarkerRow(title: "行内 HTML", value: document.markers.inlineHTML.count, systemImage: "chevron.left.forwardslash.chevron.right", theme: theme)
                        MarkerRow(title: "HTML 实体", value: document.markers.htmlEntities.count, systemImage: "textformat", theme: theme)
                        MarkerRow(title: "数学公式数", value: document.markers.mathExpressions.count, systemImage: "function", theme: theme)
                        MarkerRow(title: "高亮标记数", value: document.markers.highlights.count, systemImage: "highlighter", theme: theme)
                        MarkerRow(title: "上标文本", value: document.markers.superscripts.count, systemImage: "textformat.superscript", theme: theme)
                        MarkerRow(title: "下标文本", value: document.markers.subscripts.count, systemImage: "textformat.subscript", theme: theme)
                        MarkerRow(title: "审阅批注数", value: document.markers.criticMarkupCount, systemImage: "pencil.and.outline", theme: theme)
                        MarkerRow(title: "学术引用数", value: document.markers.citations.count, systemImage: "quote.bubble", theme: theme)
                        MarkerRow(title: "Emoji 代码", value: document.markers.emojiShortcodes.count, systemImage: "face.smiling", theme: theme)
                        MarkerRow(title: "键盘键帽 (Kbd)", value: document.markers.keyboardShortcuts.count, systemImage: "keyboard", theme: theme)
                        MarkerRow(title: "图表区块", value: document.markers.diagrams.count, systemImage: "point.3.connected.trianglepath.dotted", theme: theme)
                        MarkerRow(title: "任务标记", value: document.markers.taskTokens.count, systemImage: "flag", theme: theme)
                        MarkerRow(title: "待办任务总数", value: document.markers.taskStates.reduce(0) { $0 + $1.count }, systemImage: "checklist", theme: theme)
                        MarkerRow(title: "信息提示框", value: document.markers.callouts.count, systemImage: "exclamationmark.bubble", theme: theme)
                    }
                }

                MarkerList(title: "标签列表", values: document.markers.tags.map { "#\($0)" }, systemImage: "number", theme: theme)
                MarkerList(title: "提及列表", values: document.markers.mentions.map { "@\($0)" }, systemImage: "at", theme: theme)
                MarkerList(title: "代码语言分布", values: document.markers.codeLanguages, systemImage: "chevron.left.forwardslash.chevron.right", theme: theme)
                MarkerList(title: "图表列表", values: document.markers.diagrams.map(\.title), systemImage: "point.3.connected.trianglepath.dotted", theme: theme)
                MarkerList(title: "Wiki 链接列表", values: document.markers.wikiLinks.map { MarkdownWikiLinkReference.parse($0).inspectorText }, systemImage: "rectangle.stack", theme: theme)
                MarkerList(title: "Wiki 嵌入列表", values: document.markers.wikiEmbeds.map { MarkdownWikiLinkReference.parse($0).inspectorText }, systemImage: "paperclip", theme: theme)
                MarkerList(title: "块 ID 列表", values: document.markers.blockIDs.map { "^\($0)" }, systemImage: "text.line.first.and.arrowtriangle.forward", theme: theme)
                MarkerList(title: "标题锚点列表", values: document.markers.customAnchors.map { "{#\($0)}" }, systemImage: "number.square", theme: theme)
                MarkerList(title: "缩写词定义列表", values: document.markers.abbreviations.map { "*[\($0.term)]: \($0.expansion)" }, systemImage: "textformat.abc.dottedunderline", theme: theme)
                MarkerList(title: "参考链接列表", values: document.markers.linkReferences.map { "[\($0)]" }, systemImage: "link.badge.plus", theme: theme)
                MarkerList(title: "任务标记列表", values: document.markers.taskTokens.map { "\($0.kind.title): \($0.text)" }, systemImage: "flag", theme: theme)
                MarkerList(title: "待办任务分布", values: document.markers.taskStates.map { "\($0.state.title): \($0.count)" }, systemImage: "checklist", theme: theme)
                MarkerList(title: "数学公式列表", values: document.markers.mathExpressions, systemImage: "function", theme: theme)
                MarkerList(title: "高亮文本列表", values: document.markers.highlights.map { "==\($0)==" }, systemImage: "highlighter", theme: theme)
                MarkerList(title: "上标文本列表", values: document.markers.superscripts.map { "^\($0)^" }, systemImage: "textformat.superscript", theme: theme)
                MarkerList(title: "下标文本列表", values: document.markers.subscripts.map { "~\($0)~" }, systemImage: "textformat.subscript", theme: theme)
                MarkerList(title: "审阅新增列表", values: document.markers.criticAdditions.map { "{++\($0)++}" }, systemImage: "plus.square", theme: theme)
                MarkerList(title: "审阅删除列表", values: document.markers.criticDeletions.map { "{--\($0)--}" }, systemImage: "minus.square", theme: theme)
                MarkerList(title: "审阅替换列表", values: document.markers.criticSubstitutions.map { "\($0.original) -> \($0.replacement)" }, systemImage: "arrow.left.arrow.right", theme: theme)
                MarkerList(title: "审阅注释列表", values: document.markers.criticComments.map { "{>>\($0)<<}" }, systemImage: "text.bubble", theme: theme)
                MarkerList(title: "审阅高亮列表", values: document.markers.criticHighlights.map { "{==\($0)==}" }, systemImage: "highlighter", theme: theme)
                MarkerList(title: "学术引用列表", values: document.markers.citations.map { "[@\($0)]" }, systemImage: "quote.bubble", theme: theme)
                MarkerList(title: "Emoji 表情列表", values: document.markers.emojiShortcodes.map(MarkdownEmojiShortcode.displayName), systemImage: "face.smiling", theme: theme)
                MarkerList(title: "键盘按键列表", values: document.markers.keyboardShortcuts.map { "<kbd>\($0)</kbd>" }, systemImage: "keyboard", theme: theme)
                MarkerList(title: "信息提示框列表", values: document.markers.callouts.map(\.inspectorText), systemImage: "exclamationmark.bubble", theme: theme)
                MarkerList(title: "超链接列表", values: document.markers.links, systemImage: "link", theme: theme)
                MarkerList(title: "自动链接列表", values: document.markers.autoLinks, systemImage: "link.badge.plus", theme: theme)
                MarkerList(title: "电子邮箱列表", values: document.markers.emailLinks, systemImage: "envelope", theme: theme)
                MarkerList(title: "图片链接列表", values: document.markers.images, systemImage: "photo", theme: theme)
                MarkerList(title: "图片参考定义列表", values: document.markers.imageReferences.map { "![...][\($0)]" }, systemImage: "photo.badge.arrow.down", theme: theme)
                MarkerList(title: "HTML 注释列表", values: document.markers.htmlComments, systemImage: "text.bubble", theme: theme)
                MarkerList(title: "行内 HTML 列表", values: document.markers.inlineHTML, systemImage: "chevron.left.forwardslash.chevron.right", theme: theme)
                MarkerList(title: "HTML 实体列表", values: document.markers.htmlEntities, systemImage: "textformat", theme: theme)

                InspectorSection(title: "分块分布", systemImage: "square.stack.3d.up", theme: theme) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(document.stats.blockKinds.prefix(12)) { block in
                            MarkerRow(title: block.kind, value: block.count, systemImage: "square", theme: theme)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(minWidth: 220, idealWidth: 260)
        .background(theme.palette.surfaceColor.opacity(0.72))
    }
}

private struct MetadataRow: View {
    let item: MetadataItem
    let theme: MdoraTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(item.key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.accentColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(item.value.isEmpty ? "空值" : item.value)
                .font(.caption)
                .foregroundStyle(theme.palette.mutedColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.palette.previewColor.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct CompatibilitySummary: View {
    let document: ParsedMarkdownDocument
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(detectedFeatures.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.palette.accentColor)

                Text("个已识别的语法家族")
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
            }

            if !document.diagnostics.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)

                    Text("\(document.diagnostics.count) 个诊断提示")
                        .font(.caption)
                        .foregroundStyle(theme.palette.mutedColor)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(detectedFeatures, id: \.self) { feature in
                    Text(feature)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(theme.palette.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var detectedFeatures: [String] {
        var features: [String] = []

        if let kind = frontMatterKind {
            features.append("\(kind.title) 前置数据")
        } else if !document.metadata.isEmpty {
            features.append("前置数据")
        }
        if !document.outline.isEmpty { features.append("大纲标题") }
        appendIfBlock("表格样式", contains: "Table", to: &features)
        appendIfBlock("待办列表", contains: "Task List", to: &features)
        appendIfBlock("代码区块", contains: "Code", to: &features)
        appendIfBlock("专业图表", contains: "Diagram", to: &features)
        appendIfBlock("数学公式", contains: "Math", to: &features)
        appendIfBlock("脚注定义", contains: "Footnote", to: &features)
        appendIfBlock("定义列表", contains: "Definition List", to: &features)
        if !document.markers.wikiLinks.isEmpty { features.append("Wiki 链接") }
        if !document.markers.wikiEmbeds.isEmpty { features.append("Wiki 嵌入") }
        if !document.markers.blockIDs.isEmpty { features.append("块 ID") }
        if !document.markers.customAnchors.isEmpty { features.append("标题锚点") }
        if !document.markers.abbreviations.isEmpty { features.append("缩写词") }
        if !document.markers.linkReferences.isEmpty { features.append("参考链接") }
        if !document.markers.autoLinks.isEmpty || !document.markers.emailLinks.isEmpty { features.append("自动链接") }
        if !document.markers.taskTokens.isEmpty { features.append("任务标记") }
        if !document.markers.taskStates.isEmpty { features.append("任务状态") }
        if !document.markers.highlights.isEmpty { features.append("文本高亮") }
        if !document.markers.superscripts.isEmpty || !document.markers.subscripts.isEmpty { features.append("上/下标") }
        if document.markers.criticMarkupCount > 0 { features.append("CriticMarkup") }
        if !document.markers.citations.isEmpty { features.append("学术引用") }
        if !document.markers.emojiShortcodes.isEmpty { features.append("表情代码") }
        if !document.markers.keyboardShortcuts.isEmpty { features.append("键盘键帽") }
        if !document.markers.callouts.isEmpty { features.append("提示框") }
        if !document.markers.htmlComments.isEmpty { features.append("注释") }
        if !document.markers.inlineHTML.isEmpty { features.append("行内 HTML") }
        if !document.markers.htmlEntities.isEmpty { features.append("HTML 实体") }

        return features.isEmpty ? ["基础 Markdown"] : features
    }

    private func appendIfBlock(_ title: String, contains kind: String, to features: inout [String]) {
        if document.stats.blockKinds.contains(where: { $0.kind == kind }) {
            features.append(title)
        }
    }

    private var frontMatterKind: FrontMatterKind? {
        document.blocks.compactMap { block in
            if case let .frontMatter(frontMatter) = block {
                return frontMatter.kind
            }

            return nil
        }.first
    }
}

private struct DiagnosticRow: View {
    let diagnostic: MarkdownDiagnostic
    let theme: MdoraTheme
    @State private var isHovered = false

    var body: some View {
        Button {
            if let line = diagnostic.line {
                if let url = URL(string: "mdora://line/\(line)") {
                    NotificationCenter.default.post(name: Notification.Name("mdoraNavigateRequested"), object: url)
                }
            } else {
                if let url = URL(string: "mdora://search/\(diagnostic.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? diagnostic.title)") {
                    NotificationCenter.default.post(name: Notification.Name("mdoraNavigateRequested"), object: url)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: diagnostic.severity.systemImage)
                        .foregroundStyle(diagnostic.severity.color)
                        .frame(width: 14)

                    Text(diagnostic.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isHovered ? theme.palette.accentColor : theme.palette.textColor)

                    Spacer(minLength: 6)

                    if let line = diagnostic.line {
                        Text("第 \(line) 行")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.palette.mutedColor)
                    }
                }

                Text(diagnostic.message)
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? theme.palette.accentColor.opacity(0.08) : diagnostic.severity.color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? theme.palette.accentColor : diagnostic.severity.color.opacity(0.26), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let systemImage: String
    let theme: MdoraTheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.mutedColor)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatGrid: View {
    let document: ParsedMarkdownDocument
    let theme: MdoraTheme

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                StatCell(title: "总字数", value: "\(document.stats.words)", theme: theme)
                StatCell(title: "总行数", value: "\(document.stats.lines)", theme: theme)
            }

            GridRow {
                StatCell(title: "总区块数", value: "\(document.stats.blocks)", theme: theme)
                StatCell(title: "阅读时间", value: "\(document.stats.readingMinutes) 分钟", theme: theme)
            }
        }
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    let theme: MdoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.palette.textColor)

            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.palette.mutedColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(theme.palette.previewColor.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MarkerRow: View {
    let title: String
    let value: Int
    let systemImage: String
    let theme: MdoraTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 16)
                .foregroundStyle(theme.palette.accentColor)

            Text(title)
                .font(.caption)

            Spacer()

            Text("\(value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.palette.mutedColor)
        }
    }
}

private struct MarkerList: View {
    let title: String
    let values: [String]
    let systemImage: String
    let theme: MdoraTheme

    var body: some View {
        if !values.isEmpty {
            InspectorSection(title: title, systemImage: systemImage, theme: theme) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(values.prefix(12), id: \.self) { value in
                        MarkerListItem(value: value, theme: theme)
                    }
                }
            }
        }
    }
}

private struct MarkerListItem: View {
    let value: String
    let theme: MdoraTheme
    @State private var isHovered = false

    var body: some View {
        Button {
            let cleanValue = cleanSearchTerm(value)
            if let url = URL(string: "mdora://search/\(cleanValue.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? cleanValue)") {
                NotificationCenter.default.post(name: Notification.Name("mdoraNavigateRequested"), object: url)
            }
        } label: {
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isHovered ? theme.palette.accentColor.opacity(0.08) : theme.palette.previewColor.opacity(0.72))
                .foregroundColor(isHovered ? theme.palette.accentColor : theme.palette.textColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private func cleanSearchTerm(_ val: String) -> String {
        var str = val

        // Strip CriticMarkup tags
        if str.hasPrefix("{++"), str.hasSuffix("++}") {
            str = String(str.dropFirst(3).dropLast(3))
        } else if str.hasPrefix("{--"), str.hasSuffix("--}") {
            str = String(str.dropFirst(3).dropLast(3))
        } else if str.hasPrefix("{=="), str.hasSuffix("==}") {
            str = String(str.dropFirst(3).dropLast(3))
        } else if str.hasPrefix("{>>"), str.hasSuffix("<<}") {
            str = String(str.dropFirst(3).dropLast(3))
        }

        // Strip bold/italic/highlight wrappers
        if str.hasPrefix("=="), str.hasSuffix("==") {
            str = String(str.dropFirst(2).dropLast(2))
        }

        // Strip WikiLink embeds or tags
        if str.hasPrefix("[["), str.hasSuffix("]]") {
            str = String(str.dropFirst(2).dropLast(2))
        }

        // Strip block IDs prefix
        if str.hasPrefix("^") {
            str = String(str.dropFirst())
        }

        // Strip custom anchors wrapper
        if str.hasPrefix("{#"), str.hasSuffix("}") {
            str = String(str.dropFirst(2).dropLast())
        }

        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct EmptyInspectorText: View {
    let text: String
    let theme: MdoraTheme

    init(_ text: String, theme: MdoraTheme) {
        self.text = text
        self.theme = theme
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(theme.palette.mutedColor)
    }
}

private extension MarkdownDiagnosticSeverity {
    var systemImage: String {
        switch self {
        case .info:
            "info.circle"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "xmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .info:
            .blue
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}

private struct OutlineItemRow: View {
    let symbol: DocumentSymbol
    let theme: MdoraTheme
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: "mdora://scroll/\(symbol.anchor.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? symbol.anchor)") {
                NotificationCenter.default.post(name: Notification.Name("mdoraNavigateRequested"), object: url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.caption2)
                    .foregroundColor(theme.palette.accentColor.opacity(0.68))

                Text(symbol.title)
                    .font(.system(size: 12, weight: isHovered ? .semibold : .regular))
                    .foregroundColor(isHovered ? theme.palette.accentColor : theme.palette.textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovered ? theme.palette.accentColor.opacity(0.08) : Color.clear)
            .contentShape(RoundedRectangle(cornerRadius: 4))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
