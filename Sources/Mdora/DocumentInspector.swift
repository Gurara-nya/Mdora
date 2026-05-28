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
                        MarkerRow(title: "Images", value: document.markers.images.count, systemImage: "photo", theme: theme)
                        MarkerRow(title: "Footnotes", value: document.markers.footnotes.count, systemImage: "text.badge.checkmark", theme: theme)
                        MarkerRow(title: "Callouts", value: document.markers.callouts.count, systemImage: "exclamationmark.bubble", theme: theme)
                    }
                }

                MarkerList(title: "Tags", values: document.markers.tags.map { "#\($0)" }, systemImage: "number", theme: theme)
                MarkerList(title: "Mentions", values: document.markers.mentions.map { "@\($0)" }, systemImage: "at", theme: theme)
                MarkerList(title: "Code", values: document.markers.codeLanguages, systemImage: "chevron.left.forwardslash.chevron.right", theme: theme)
                MarkerList(title: "Links", values: document.markers.links, systemImage: "link", theme: theme)
                MarkerList(title: "Images", values: document.markers.images, systemImage: "photo", theme: theme)
            }
            .padding(14)
        }
        .frame(minWidth: 220, idealWidth: 260)
        .background(theme.palette.surfaceColor.opacity(0.72))
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
