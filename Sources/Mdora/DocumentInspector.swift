import MdoraCore
import SwiftUI

struct DocumentInspector: View {
    let document: ParsedMarkdownDocument
    let theme: MdoraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InspectorSection(title: "Stats", systemImage: "chart.bar", theme: theme) {
                    StatGrid(document: document, theme: theme)
                }

                if !document.metadata.isEmpty {
                    InspectorSection(title: "Metadata", systemImage: "tag", theme: theme) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(document.metadata) { item in
                                MetadataRow(item: item, theme: theme)
                            }
                        }
                    }
                }

                InspectorSection(title: "Compatibility", systemImage: "checkmark.seal", theme: theme) {
                    CompatibilitySummary(document: document, theme: theme)
                }

                if !document.diagnostics.isEmpty {
                    InspectorSection(title: "Diagnostics", systemImage: "stethoscope", theme: theme) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(document.diagnostics) { diagnostic in
                                DiagnosticRow(diagnostic: diagnostic, theme: theme)
                            }
                        }
                    }
                }

                InspectorSection(title: "Outline", systemImage: "list.bullet.indent", theme: theme) {
                    if document.outline.isEmpty {
                        EmptyInspectorText("No headings", theme: theme)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(document.outline) { symbol in
                                Label(symbol.title, systemImage: "textformat.size")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.leading, CGFloat(max(0, symbol.level - 1)) * 10)
                            }
                        }
                    }
                }

                InspectorSection(title: "Markers", systemImage: "scope", theme: theme) {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkerRow(title: "Tags", value: document.markers.tags.count, systemImage: "number", theme: theme)
                        MarkerRow(title: "Mentions", value: document.markers.mentions.count, systemImage: "at", theme: theme)
                        MarkerRow(title: "Links", value: document.markers.links.count, systemImage: "link", theme: theme)
                        MarkerRow(title: "Auto Links", value: document.markers.autoLinks.count, systemImage: "link.badge.plus", theme: theme)
                        MarkerRow(title: "Emails", value: document.markers.emailLinks.count, systemImage: "envelope", theme: theme)
                        MarkerRow(title: "Wiki Links", value: document.markers.wikiLinks.count, systemImage: "rectangle.stack", theme: theme)
                        MarkerRow(title: "References", value: document.markers.linkReferences.count, systemImage: "link.badge.plus", theme: theme)
                        MarkerRow(title: "Images", value: document.markers.images.count, systemImage: "photo", theme: theme)
                        MarkerRow(title: "Image Refs", value: document.markers.imageReferences.count, systemImage: "photo.badge.arrow.down", theme: theme)
                        MarkerRow(title: "Footnotes", value: document.markers.footnotes.count, systemImage: "text.badge.checkmark", theme: theme)
                        MarkerRow(title: "Comments", value: document.markers.htmlComments.count, systemImage: "text.bubble", theme: theme)
                        MarkerRow(title: "Math", value: document.markers.mathExpressions.count, systemImage: "function", theme: theme)
                        MarkerRow(title: "Highlights", value: document.markers.highlights.count, systemImage: "highlighter", theme: theme)
                        MarkerRow(title: "Superscripts", value: document.markers.superscripts.count, systemImage: "textformat.superscript", theme: theme)
                        MarkerRow(title: "Subscripts", value: document.markers.subscripts.count, systemImage: "textformat.subscript", theme: theme)
                        MarkerRow(title: "CriticMarkup", value: document.markers.criticMarkupCount, systemImage: "pencil.and.outline", theme: theme)
                        MarkerRow(title: "Citations", value: document.markers.citations.count, systemImage: "quote.bubble", theme: theme)
                        MarkerRow(title: "Emoji", value: document.markers.emojiShortcodes.count, systemImage: "face.smiling", theme: theme)
                        MarkerRow(title: "Keyboard", value: document.markers.keyboardShortcuts.count, systemImage: "keyboard", theme: theme)
                        MarkerRow(title: "Diagrams", value: document.markers.diagrams.count, systemImage: "point.3.connected.trianglepath.dotted", theme: theme)
                        MarkerRow(title: "Tokens", value: document.markers.taskTokens.count, systemImage: "flag", theme: theme)
                        MarkerRow(title: "Callouts", value: document.markers.callouts.count, systemImage: "exclamationmark.bubble", theme: theme)
                    }
                }

                MarkerList(title: "Tags", values: document.markers.tags.map { "#\($0)" }, systemImage: "number", theme: theme)
                MarkerList(title: "Mentions", values: document.markers.mentions.map { "@\($0)" }, systemImage: "at", theme: theme)
                MarkerList(title: "Code", values: document.markers.codeLanguages, systemImage: "chevron.left.forwardslash.chevron.right", theme: theme)
                MarkerList(title: "Diagrams", values: document.markers.diagrams.map(\.title), systemImage: "point.3.connected.trianglepath.dotted", theme: theme)
                MarkerList(title: "Wiki Links", values: document.markers.wikiLinks.map { "[[\($0)]]" }, systemImage: "rectangle.stack", theme: theme)
                MarkerList(title: "References", values: document.markers.linkReferences.map { "[\($0)]" }, systemImage: "link.badge.plus", theme: theme)
                MarkerList(title: "Tokens", values: document.markers.taskTokens.map { "\($0.kind.title): \($0.text)" }, systemImage: "flag", theme: theme)
                MarkerList(title: "Math", values: document.markers.mathExpressions, systemImage: "function", theme: theme)
                MarkerList(title: "Highlights", values: document.markers.highlights.map { "==\($0)==" }, systemImage: "highlighter", theme: theme)
                MarkerList(title: "Superscripts", values: document.markers.superscripts.map { "^\($0)^" }, systemImage: "textformat.superscript", theme: theme)
                MarkerList(title: "Subscripts", values: document.markers.subscripts.map { "~\($0)~" }, systemImage: "textformat.subscript", theme: theme)
                MarkerList(title: "Critic Additions", values: document.markers.criticAdditions.map { "{++\($0)++}" }, systemImage: "plus.square", theme: theme)
                MarkerList(title: "Critic Deletions", values: document.markers.criticDeletions.map { "{--\($0)--}" }, systemImage: "minus.square", theme: theme)
                MarkerList(title: "Critic Changes", values: document.markers.criticSubstitutions.map { "\($0.original) -> \($0.replacement)" }, systemImage: "arrow.left.arrow.right", theme: theme)
                MarkerList(title: "Critic Notes", values: document.markers.criticComments.map { "{>>\($0)<<}" }, systemImage: "text.bubble", theme: theme)
                MarkerList(title: "Critic Highlights", values: document.markers.criticHighlights.map { "{==\($0)==}" }, systemImage: "highlighter", theme: theme)
                MarkerList(title: "Citations", values: document.markers.citations.map { "[@\($0)]" }, systemImage: "quote.bubble", theme: theme)
                MarkerList(title: "Emoji", values: document.markers.emojiShortcodes.map { ":\($0):" }, systemImage: "face.smiling", theme: theme)
                MarkerList(title: "Keyboard", values: document.markers.keyboardShortcuts.map { "<kbd>\($0)</kbd>" }, systemImage: "keyboard", theme: theme)
                MarkerList(title: "Links", values: document.markers.links, systemImage: "link", theme: theme)
                MarkerList(title: "Auto Links", values: document.markers.autoLinks, systemImage: "link.badge.plus", theme: theme)
                MarkerList(title: "Emails", values: document.markers.emailLinks, systemImage: "envelope", theme: theme)
                MarkerList(title: "Images", values: document.markers.images, systemImage: "photo", theme: theme)
                MarkerList(title: "Image Refs", values: document.markers.imageReferences.map { "![...][\($0)]" }, systemImage: "photo.badge.arrow.down", theme: theme)
                MarkerList(title: "Comments", values: document.markers.htmlComments, systemImage: "text.bubble", theme: theme)

                InspectorSection(title: "Blocks", systemImage: "square.stack.3d.up", theme: theme) {
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

            Text(item.value.isEmpty ? "empty" : item.value)
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

                Text("recognized feature families")
                    .font(.caption)
                    .foregroundStyle(theme.palette.mutedColor)
            }

            if !document.diagnostics.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)

                    Text("\(document.diagnostics.count) diagnostics")
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
            features.append("\(kind.title) Front Matter")
        } else if !document.metadata.isEmpty {
            features.append("Front Matter")
        }
        if !document.outline.isEmpty { features.append("Headings") }
        appendIfBlock("Tables", contains: "Table", to: &features)
        appendIfBlock("Tasks", contains: "Task List", to: &features)
        appendIfBlock("Code", contains: "Code", to: &features)
        appendIfBlock("Diagrams", contains: "Diagram", to: &features)
        appendIfBlock("Math", contains: "Math", to: &features)
        appendIfBlock("Footnotes", contains: "Footnote", to: &features)
        appendIfBlock("Definitions", contains: "Definition List", to: &features)
        if !document.markers.wikiLinks.isEmpty { features.append("Wiki Links") }
        if !document.markers.linkReferences.isEmpty { features.append("References") }
        if !document.markers.autoLinks.isEmpty || !document.markers.emailLinks.isEmpty { features.append("Autolinks") }
        if !document.markers.taskTokens.isEmpty { features.append("Tokens") }
        if !document.markers.highlights.isEmpty { features.append("Highlights") }
        if !document.markers.superscripts.isEmpty || !document.markers.subscripts.isEmpty { features.append("Super/Subscript") }
        if document.markers.criticMarkupCount > 0 { features.append("CriticMarkup") }
        if !document.markers.citations.isEmpty { features.append("Citations") }
        if !document.markers.emojiShortcodes.isEmpty { features.append("Emoji") }
        if !document.markers.keyboardShortcuts.isEmpty { features.append("Keyboard") }
        if !document.markers.callouts.isEmpty { features.append("Callouts") }
        if !document.markers.htmlComments.isEmpty { features.append("Comments") }

        return features.isEmpty ? ["Plain Markdown"] : features
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: diagnostic.severity.systemImage)
                    .foregroundStyle(diagnostic.severity.color)
                    .frame(width: 14)

                Text(diagnostic.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.palette.textColor)

                Spacer(minLength: 6)

                if let line = diagnostic.line {
                    Text("L\(line)")
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
        .background(diagnostic.severity.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(diagnostic.severity.color.opacity(0.26), lineWidth: 1)
        )
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
                StatCell(title: "Words", value: "\(document.stats.words)", theme: theme)
                StatCell(title: "Lines", value: "\(document.stats.lines)", theme: theme)
            }

            GridRow {
                StatCell(title: "Blocks", value: "\(document.stats.blocks)", theme: theme)
                StatCell(title: "Read", value: "\(document.stats.readingMinutes)m", theme: theme)
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
                        Text(value)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.palette.previewColor.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
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
